class ManageIQ::Providers::Openshift::Inventory::Collector::ContainerManager < ManageIQ::Providers::Kubernetes::Inventory::Collector::ContainerManager
  attr_reader :version

  def routes
    @routes ||= fetch_entity(openshift_connection("route.openshift.io/v1"), "routes")
  end

  def namespaces_by_name
    @namespaces_by_name ||= namespaces.index_by { |ns| ns.metadata.name }
  end

  def projects
    @projects ||= fetch_entity(openshift_connection("project.openshift.io/v1"), "projects")
  end

  def build_configs
    @build_configs ||= fetch_entity(openshift_connection("build.openshift.io/v1"), "build_configs")
  end

  def builds
    @builds ||= fetch_entity(openshift_connection("build.openshift.io/v1"), "builds")
  end

  def templates
    @templates ||= fetch_entity(openshift_connection("template.openshift.io/v1"), "templates")
  end

  def images
    @images ||= refresher_options.get_container_images ? fetch_entity(openshift_connection("image.openshift.io/v1"), "images") : {}
  end

  private

  def openshift_connection(group)
    detect_openshift_version! if version.nil?
    send("openshift_connection_#{version}", group)
  end

  def detect_openshift_version!
    @version = begin
      openshift_connection_v3
      "v3"
    rescue Kubeclient::ResourceNotFoundError
      nil
    end

    @version ||= begin
      openshift_connection_v4("project.openshift.io/v1")
      "v4"
    rescue Kubeclient::ResourceNotFoundError
      nil
    end

    raise "Failed to detect OpenShift version" if @version.nil?
  end

  def openshift_connection_v3(_group = nil)
    @openshift_connection_v3 ||= begin
      opts = manager.connect_options
      manager.class.openshift_v3_connect(opts[:hostname], opts[:port], opts)
    end
  end

  def openshift_connection_v4(group)
    @openshift_connection_v4 ||= {}
    @openshift_connection_v4[group] ||= begin
      opts = manager.connect_options(:api_group => group)
      manager.class.openshift_v4_connect(opts[:hostname], opts[:port], opts)
    end
  end
end
