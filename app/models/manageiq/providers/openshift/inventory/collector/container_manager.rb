class ManageIQ::Providers::Openshift::Inventory::Collector::ContainerManager < ManageIQ::Providers::Kubernetes::Inventory::Collector::ContainerManager
  def routes
    @routes ||= fetch_entity(openshift_connection, "routes")
  end

  def projects
    @projects ||= fetch_entity(openshift_connection, "projects")
  end

  def build_configs
    @build_configs ||= fetch_entity(openshift_connection, "build_configs")
  end

  def builds
    @builds ||= fetch_entity(openshift_connection, "builds")
  end

  def templates
    @templates ||= fetch_entity(openshift_connection, "templates")
  end

  def images
    @images ||= refresher_options.get_container_images ? fetch_entity(openshift_connection, "images") : {}
  end

  private

  def openshift_connection
    @openshift_connection ||= connect("openshift")
  end
end
