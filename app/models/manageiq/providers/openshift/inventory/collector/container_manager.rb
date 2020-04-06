class ManageIQ::Providers::Openshift::Inventory::Collector::ContainerManager < ManageIQ::Providers::Kubernetes::Inventory::Collector::ContainerManager
  attr_reader :version

  def routes
    @routes ||= fetch_entity(openshift_connection("route.openshift.io"), "routes")
  end

  def projects
    @projects ||= fetch_entity(openshift_connection("project.openshift.io"), "projects")
  end

  def build_configs
    @build_configs ||= fetch_entity(openshift_connection("build.openshift.io"), "build_configs")
  end

  def builds
    @builds ||= fetch_entity(openshift_connection("build.openshift.io"), "builds")
  end

  def templates
    @templates ||= fetch_entity(openshift_connection("template.openshift.io"), "templates")
  end

  def images
    @images ||= refresher_options.get_container_images ? fetch_entity(openshift_connection("image.openshift.io"), "images") : {}
  end

  private

  def connect(service, opts = {})
    manager.connect(opts.merge(:service => service))
  rescue KubeException
    nil
  end

  def openshift_connection(group)
    detect_openshift_version! if version.nil?
    send("openshift_connection_#{version}", group)
  end

  def detect_openshift_version!
    @version = "v3" if openshift_connection_v3.present?
    @version = "v4" if @version.nil? && openshift_connection_v4("project.openshift.io").present?
    raise "Failed to detect OpenShift version" if @version.nil?
  end

  def openshift_connection_v3(_group = nil)
    @openshift_connection_v3 ||= connect("openshift")
  end

  def openshift_connection_v4(group)
    @openshift_connection_v4 ||= {}
    @openshift_connection_v4[group] ||= connect("openshift", :path => "/apis/#{group}")
  end
end
