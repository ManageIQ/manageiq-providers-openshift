module ManageIQ::Providers
  module Openshift
    class ContainerManager::RefreshParser < ManageIQ::Providers::Kubernetes::ContainerManager::RefreshParser

      include ContainerManager::InventoryCollections

      def ems_inv_to_hashes(inventory, options = Config::Options.new)
        super(inventory, options)
        get_projects(inventory)
        get_routes(inventory)
        get_builds(inventory)
        get_build_pods(inventory)
        get_templates(inventory)
        get_openshift_images(inventory) if options.get_container_images
        EmsRefresh.log_inv_debug_trace(@data, "data:")
        @data
      end

      def ems_inv_to_inv_collections(ems, inventory, options = Config::Options.new)
        super
      end

      def get_openshift_images(inventory)
        inventory["image"].each { |img| parse_openshift_image(img) }
      end

      def get_builds(inventory)
        key = path_for_entity("build_config")
        process_collection(inventory["build_config"], key) { |n| parse_build(n) }

        @data[key].each do |ns|
          @data_index.store_path(key, :by_name, ns[:name], ns)
        end
      end

      def get_build_pods(inventory)
        key = path_for_entity("build")
        process_collection(inventory["build"], key) { |n| parse_build_pod(n) }

        @data[key].each do |ns|
          @data_index.store_path(key, :by_name, ns[:name], ns)
        end
      end

      def get_routes(inventory)
        process_collection(inventory["route"], path_for_entity("route")) { |n| parse_route(n) }
      end

      def get_projects(inventory)
        key = path_for_entity("project")
        inventory["project"].each { |item| parse_project(item) }

        @data[key].each do |ns|
          @data_index.store_path(key, :by_name, ns[:name], ns)
        end
      end

      def get_templates(inventory)
        key = path_for_entity("template")
        process_collection(inventory["template"], key) { |n| parse_template(n) }

        @data[key].each do |ct|
          @data_index.store_path(key, :by_namespace_and_name, ct[:namespace], ct[:name], ct)
        end
      end

      def parse_project(project_item)
        project = @data_index.fetch_path(path_for_entity("project"), :by_name, project_item.metadata.name)
        return if project.nil? # ignore openshift projects without an underlying kubernetes namespace
        project[:display_name] = project_item.metadata.annotations['openshift.io/display-name'] unless
            project_item.metadata.annotations.nil?
      end

      def get_service_name(route)
        route.spec.try(:to).try(:kind) == 'Service' ? route.spec.try(:to).try(:name) : nil
      end

      def parse_route(route)
        new_result = parse_base_item(route)

        labels = parse_labels(route)
        new_result.merge!(
          # TODO: persist tls
          :host_name => route.spec.try(:host),
          :labels    => labels,
          :tags      => map_labels('ContainerRoute', labels),
          :path      => route.path
        )

        new_result[:project] = @data_index.fetch_path(path_for_entity("project"), :by_name,
                                                      route.metadata.namespace)
        new_result[:container_service] = @data_index.fetch_path(path_for_entity("service"), :by_namespace_and_name,
                                                                new_result[:namespace], get_service_name(route))
        new_result
      end

      def parse_build_source(source_item)
        {
          :build_source_type  => source_item.try(:type),
          :source_binary      => source_item.try(:binary).try(:asFile),
          :source_dockerfile  => source_item.try(:dockerfile),
          :source_git         => source_item.try(:git).try(:uri),
          :source_context_dir => source_item.try(:contextDir),
          :source_secret      => source_item.try(:secret).try(:name)
        }
      end

      def parse_build(build)
        new_result = parse_base_item(build)
        new_result.merge! parse_build_source(build.spec.source)
        labels = parse_labels(build)
        new_result.merge!(
          :labels                      => labels,
          :tags                        => map_labels('ContainerBuild', labels),
          :service_account             => build.spec.serviceAccount,
          :completion_deadline_seconds => build.spec.try(:completionDeadlineSeconds),
          :output_name                 => build.spec.try(:output).try(:to).try(:name)
        )

        new_result[:project] = @data_index.fetch_path(path_for_entity("project"), :by_name,
                                                      build.metadata.namespace)
        new_result
      end

      def parse_build_pod(build_pod)
        new_result = parse_base_item(build_pod)
        status = build_pod.status
        new_result.merge!(
          :labels                        => parse_labels(build_pod),
          :message                       => status[:message],
          :phase                         => status[:phase],
          :reason                        => status[:reason],
          :duration                      => status[:duration],
          :completion_timestamp          => status[:completionTimestamp],
          :start_timestamp               => status[:startTimestamp],
          :output_docker_image_reference => status[:outputDockerImageReference],
        )
        new_result[:build_config] = @data_index.fetch_path(path_for_entity("build_config"), :by_name,
                                                           build_pod.status.config.try(:name))
        new_result
      end

      def parse_template_parameters(parameters)
        parameters.to_a.collect do |param|
          {
            :name         => param['name'],
            :display_name => param['displayName'],
            :description  => param['description'],
            :value        => param['value'],
            :generate     => param['generate'],
            :from         => param['from'],
            :required     => param['required']
          }
        end
      end

      def parse_template(template)
        new_result = parse_base_item(template)
        new_result[:container_template_parameters] = parse_template_parameters(template.parameters)
        new_result[:labels] = parse_labels(template)
        new_result[:objects] = template.objects.to_a.collect(&:to_h)
        new_result[:container_project] = @data_index.fetch_path(path_for_entity("project"), :by_name, new_result[:namespace])
        new_result
      end

      def parse_exposed_ports(exposed_ports)
        exposed_ports.to_h.keys.each_with_object({}) do |port, h|
          n, p = port.to_s.split('/', 2)
          h[p] = n
        end
      end

      def parse_env_variables(env_variables)
        env_variables.to_a.each_with_object({}) do |var_def, h|
          name, value = var_def.split('=', 2)
          h[name] = value
        end
      end

      def parse_openshift_image(openshift_image)
        id = openshift_image[:dockerImageReference] || openshift_image[:metadata][:name]
        ref = "#{ContainerImage::DOCKER_PULLABLE_PREFIX}#{id}"
        new_result = parse_container_image(id, ref)

        if openshift_image[:dockerImageManifest].present?
          begin
            json = JSON.parse(openshift_image[:dockerImageManifest])
            new_result[:tag] ||= json["tag"] if json.keys.include?("tag")
          rescue => err
            _log.warn("Docker manifest for - #{ref} was in bad format - #{err}")
          end
        end

        docker_metadata = openshift_image[:dockerImageMetadata]
        if docker_metadata.present?
          new_result.merge!(
            :architecture   => docker_metadata[:Architecture],
            :author         => docker_metadata[:Author],
            :docker_version => docker_metadata[:DockerVersion],
            :size           => docker_metadata[:Size],
            :labels         => parse_labels(openshift_image)
          )
          docker_config = docker_metadata[:Config]
          if docker_config.present?
            new_result.merge!(
              :command               => docker_config[:Cmd],
              :entrypoint            => docker_config[:Entrypoint],
              :exposed_ports         => parse_exposed_ports(docker_config[:ExposedPorts]),
              :environment_variables => parse_env_variables(docker_config[:Env]),
              :docker_labels         => parse_identifying_attributes(docker_config[:Labels],
                                                                     'docker_labels', "openshift")
            )
          end
        end

        openshift_metadata = openshift_image[:metadata]
        new_result[:registered_on] = if openshift_metadata && openshift_metadata[:creationTimestamp]
                                       Time.parse(openshift_metadata[:creationTimestamp]).utc
                                     end

        new_result
      end
    end
  end
end
