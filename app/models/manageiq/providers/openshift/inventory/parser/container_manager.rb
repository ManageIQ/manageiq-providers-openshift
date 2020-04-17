class ManageIQ::Providers::Openshift::Inventory::Parser::ContainerManager < ManageIQ::Providers::Kubernetes::Inventory::Parser::ContainerManager
  def ems_inv_populate_collections(inventory, options = Config::Options.new)
    super
    merge_projects_into_namespaces_graph(inventory)
    get_routes_graph(inventory)
    get_builds_graph(inventory)
    get_build_pods_graph(inventory)
    get_templates_graph(inventory)
    # For now, we're reusing @data_index-reading-and-writing code path for images.
    get_or_merge_openshift_images(inventory) if options.get_container_images
  end

  ## hashes -> save_inventory_container methods

  def get_or_merge_openshift_images(inventory)
    inventory["image"].each { |img| get_or_merge_openshift_image(img) }
  end

  def get_or_merge_openshift_image(openshift_image)
    openshift_result = parse_openshift_image(openshift_image)
    # This hides @data_index reading and writing.
    container_result = parse_container_image(openshift_result.delete(:id),
                                             openshift_result.delete(:ref),
                                             :store_new_images => refresher_options.store_unused_images)
    return if container_result.nil? # not storing because store_unused_images = false and wasn't mentioned by any pod
    container_result.merge!(openshift_result)
    container_result
  end

  def get_builds(inventory)
    key = path_for_entity("build_config")
    process_collection(inventory["build_config"], key) { |n| parse_build(n) }

    @data[key].each do |b|
      b[:project] = @data_index.fetch_path(path_for_entity("namespace"), :by_name, b[:namespace])
      @data_index.store_path(key, :by_namespace_and_name, b[:namespace], b[:name], b)
    end
  end

  def get_build_pods(inventory)
    key = path_for_entity("build")
    process_collection(inventory["build"], key) { |n| parse_build_pod(n) }

    @data[key].each do |bp|
      config_ref = bp.delete(:build_config_ref)
      bp[:build_config] = config_ref && @data_index.fetch_path(
        path_for_entity("build_config"),
        :by_namespace_and_name, config_ref[:namespace], config_ref[:name]
      )
      @data_index.store_path(key, :by_name, bp[:name], bp)
    end
  end

  def get_routes(inventory)
    key = path_for_entity("route")
    process_collection(inventory["route"], path_for_entity("route")) { |n| parse_route(n) }

    @data[key].each do |r|
      r[:project] = @data_index.fetch_path(path_for_entity("namespace"), :by_name, r[:namespace])
      service_ref = r.delete(:container_service_ref)
      r[:container_service] = service_ref && @data_index.fetch_path(
        path_for_entity("service"),
        :by_namespace_and_name, service_ref[:namespace], service_ref[:name]
      )
    end
  end

  # Merge into results of parse_namespace
  def merge_projects_into_namespaces(inventory)
    key = path_for_entity("namespace")
    inventory["project"].each do |item|
      project = parse_project(item)
      name = project.delete(:name)

      namespace = @data_index.fetch_path(key, :by_name, name)
      next if namespace.nil? # ignore openshift projects without an underlying kubernetes namespace
      namespace.merge!(project)
    end
  end

  def get_templates(inventory)
    key = path_for_entity("template")
    process_collection(inventory["template"], key) { |n| parse_template(n) }

    @data[key].each do |ct|
      ct[:container_project] = @data_index.fetch_path(path_for_entity("project"), :by_name, ct[:namespace])
      @data_index.store_path(key, :by_namespace_and_name, ct[:namespace], ct[:name], ct)
    end
  end

  ## InventoryObject refresh methods

  def merge_projects_into_namespaces_graph(inventory)
    collection = @inv_collections[:container_projects]

    inventory["project"].each do |data|
      h = parse_project(data)
      # Assumes full refresh, and running after get_namespaces_graph.
      # Will be a problem with partial refresh.
      namespace = collection.find(h.delete(:name), :ref => :by_name)
      next if namespace.nil? # ignore openshift projects without an underlying kubernetes namespace
      namespace.data.merge!(h)
    end
  end

  def get_routes_graph(inventory)
    collection = @inv_collections[:container_routes]

    inventory["route"].each do |data|
      h = parse_route(data)
      h[:container_project] = lazy_find_project(:name => h[:namespace])
      h[:container_service] = lazy_find_service(h.delete(:container_service_ref))
      custom_attrs = h.extract!(:labels)
      tags = h.delete(:tags)

      container_route = collection.build(h)

      get_custom_attributes_graph(container_route, custom_attrs)
      get_taggings_graph(container_route, tags)
    end
  end

  def get_builds_graph(inventory)
    collection = @inv_collections[:container_builds]

    inventory["build_config"].each do |data|
      h = parse_build(data)
      h[:container_project] = lazy_find_project(:name => h[:namespace])
      custom_attrs = h.extract!(:labels)
      tags = h.delete(:tags)

      container_build = collection.build(h)

      get_custom_attributes_graph(container_build, custom_attrs)
      get_taggings_graph(container_build, tags)
    end
  end

  def get_build_pods_graph(inventory)
    collection = @inv_collections[:container_build_pods]

    inventory["build"].each do |data|
      h = parse_build_pod(data)
      h[:container_build] = lazy_find_build(h.delete(:build_config_ref))
      custom_attrs = h.extract!(:labels)
      container_build_pod = collection.build(h)

      get_custom_attributes_graph(container_build_pod, custom_attrs)
    end
  end

  def get_templates_graph(inventory)
    collection = @inv_collections[:container_templates]

    inventory["template"].each do |data|
      h = parse_template(data)
      h[:container_project] = lazy_find_project(:name => h[:namespace])
      parameters = h.delete(:container_template_parameters)
      custom_attrs = h.extract!(:labels)

      container_template = collection.build(h)

      get_template_parameters_graph(container_template, parameters)
      get_custom_attributes_graph(container_template, custom_attrs)
    end
  end

  def get_template_parameters_graph(parent, parameters)
    collection = @inv_collections[:container_template_parameters]

    parameters.each do |h|
      h[:container_template] = parent
      collection.build(h)
    end
  end

  def lazy_find_service(hash)
    return nil if hash.nil?
    search = {:container_project => lazy_find_project(:name => hash[:namespace]), :name => hash[:name]}
    @inv_collections[:container_services].lazy_find_by(search, :ref => :by_container_project_and_name)
  end

  def lazy_find_build(hash)
    return nil if hash.nil?
    @inv_collections[:container_builds].lazy_find_by(hash, :ref => :by_namespace_and_name)
  end

  ## Shared parsing methods

  def parse_project(project_item)
    new_result = {:name => project_item.metadata.name}
    unless project_item.metadata.annotations.nil?
      new_result[:display_name] = project_item.metadata.annotations['openshift.io/display-name']
    end
    new_result
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
    service_name = get_service_name(route)
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

    new_result[:type] = 'ManageIQ::Providers::Openshift::ContainerManager::ContainerImage'

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
