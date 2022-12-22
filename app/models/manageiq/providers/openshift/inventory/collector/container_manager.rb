class ManageIQ::Providers::Openshift::Inventory::Collector::ContainerManager < ManageIQ::Providers::Kubernetes::Inventory::Collector::ContainerManager
  require_nested :WatchNotice

  def api_version
    @api_version ||= cluster_version.status.desired.version
  end

  def cluster_id
    @cluster_id ||= cluster_version.spec.clusterID
  end

  def cluster_version
    @cluster_version ||= openshift_connection("config.openshift.io/v1").get_cluster_version("version")
  end

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
    @openshift_connection ||= {}
    @openshift_connection[group] ||= begin
      opts = manager.connect_options(:api_group => group)
      manager.class.openshift_connect(opts[:hostname], opts[:port], opts)
    end
  end
end
