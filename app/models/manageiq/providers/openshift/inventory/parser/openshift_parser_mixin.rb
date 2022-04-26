module ManageIQ::Providers::Openshift::Inventory::Parser::OpenshiftParserMixin
  extend ActiveSupport::Concern

  # For now, we're reusing @data_index-reading-and-writing code path for images.
  def openshift_images
    return unless refresher_options.get_container_images

    opts = {:store_new_images => refresher_options.store_unused_images}

    collector.images.each do |image|
      openshift_result = parse_openshift_image(image)

      id  = openshift_result.delete(:id)
      ref = openshift_result.delete(:ref)

      # This hides @data_index reading and writing.
      parse_container_image(id, ref, opts)&.merge!(openshift_result)
    end
  end

  def projects
    collector.projects.each do |project|
      parse_project(project)
    end
  end

  def routes
    collector.routes.each do |data|
      h = parse_route(data)
      h[:container_project] = lazy_find_project(:name => h[:namespace])
      h[:container_service] = lazy_find_service(h.delete(:container_service_ref))
      custom_attrs = h.extract!(:labels)
      tags = h.delete(:tags)

      container_route = persister.container_routes.build(h)

      custom_attributes(container_route, custom_attrs)
      taggings(container_route, tags)
    end
  end

  def builds
    collector.build_configs.each do |data|
      h = parse_build(data)
      h[:container_project] = lazy_find_project(:name => h[:namespace])
      custom_attrs = h.extract!(:labels)
      tags = h.delete(:tags)

      container_build = persister.container_builds.build(h)

      custom_attributes(container_build, custom_attrs)
      taggings(container_build, tags)
    end
  end

  def build_pods
    collector.builds.each do |data|
      h = parse_build_pod(data)
      h[:container_build] = lazy_find_build(h.delete(:build_config_ref))
      custom_attrs = h.extract!(:labels)
      container_build_pod = persister.container_build_pods.build(h)

      custom_attributes(container_build_pod, custom_attrs)
    end
  end

  def templates
    collector.templates.each do |data|
      h = parse_template(data)
      h[:container_project] = lazy_find_project(:name => h[:namespace])
      parameters = h.delete(:container_template_parameters)
      custom_attrs = h.extract!(:labels)

      container_template = persister.container_templates.build(h)

      template_parameters(container_template, parameters)
      custom_attributes(container_template, custom_attrs)
    end
  end

  def template_parameters(parent, parameters)
    parameters.each do |h|
      h[:container_template] = parent
      persister.container_template_parameters.build(h)
    end
  end

  def lazy_find_service(hash)
    return nil if hash.nil?
    search = {:container_project => lazy_find_project(:name => hash[:namespace]), :name => hash[:name]}
    persister.container_services.lazy_find_by(search, :ref => :by_container_project_and_name)
  end

  def lazy_find_build(hash)
    return nil if hash.nil?
    persister.container_builds.lazy_find_by(hash, :ref => :by_namespace_and_name)
  end

  ## Shared parsing methods

  def parse_project(project_item)
    namespace = collector.namespaces_by_name[project_item.metadata.name]
    return if namespace.nil?

    container_project = persister.container_projects.find_or_build(namespace.metadata.uid)

    display_name = project_item.metadata.annotations['openshift.io/display-name']
    container_project.display_name = display_name if display_name

    container_project
  end

  def service_name(route)
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
    service_name = service_name(route)
    unless service_name.nil?
      # In same namespace:  https://docs.openshift.org/latest/rest_api/openshift_v1.html#v1-routetargetreference
      new_result[:container_service_ref] = {:namespace => new_result[:namespace], :name => service_name}
    end

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
      :build_config_ref              => status[:config].to_h,
    )
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
    new_result[:type] = "ManageIQ::Providers::Openshift::ContainerManager::ContainerTemplate"
    new_result[:object_labels] = template.labels.to_h
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
    new_result = {
      :id  => id,
      :ref => "#{ContainerImage::DOCKER_PULLABLE_PREFIX}#{id}",
    }

    new_result[:type] = 'ManageIQ::Providers::Openshift::ContainerManager::ManagedContainerImage'

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
