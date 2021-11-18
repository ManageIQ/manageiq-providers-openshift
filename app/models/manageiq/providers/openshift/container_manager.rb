ManageIQ::Providers::Kubernetes::ContainerManager.include(ActsAsStiLeafClass)

class ManageIQ::Providers::Openshift::ContainerManager < ManageIQ::Providers::Kubernetes::ContainerManager
  DEFAULT_PORT = 8443
  DEFAULT_EXTERNAL_LOGGING_ROUTE_NAME = "logging-kibana-ops".freeze

  require_nested :Container
  require_nested :ContainerGroup
  require_nested :ContainerNode
  require_nested :ContainerImage
  require_nested :ContainerTemplate
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :MetricsCollectorWorker
  require_nested :OrchestrationStack
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :Options

  include ManageIQ::Providers::Openshift::ContainerManager::Options

  # Override HasMonitoringManagerMixin
  has_one :monitoring_manager,
          :foreign_key => :parent_ems_id,
          :class_name  => "ManageIQ::Providers::Openshift::MonitoringManager",
          :autosave    => true,
          :dependent   => :destroy

  supports :catalog

  def self.ems_type
    @ems_type ||= "openshift".freeze
  end

  def self.description
    @description ||= "OpenShift".freeze
  end

  def self.event_monitor_class
    ManageIQ::Providers::Openshift::ContainerManager::EventCatcher
  end

  def self.default_port
    DEFAULT_PORT
  end

  def self.raw_connect(hostname, port, options)
    options[:service] ||= "openshift"
    send("#{options[:service]}_connect", hostname, port, options)
  end

  def self.openshift_connect(hostname, port, options)
    # First attempt to connect to the /oapi endpoint and if that fails with
    # a ResourceNotFoundError attempt to connect to /apis/...
    openshift_v3_connect(hostname, port, options)
  rescue Kubeclient::ResourceNotFoundError
    openshift_v4_connect(hostname, port, options)
  end

  def self.openshift_v3_connect(hostname, port, options)
    options = {:path => '/oapi', :version => "v1"}.merge(options)
    kubernetes_connect(hostname, port, options)
  end

  def self.openshift_v4_connect(hostname, port, options)
    api_group = options[:api_group] || "apps.openshift.io/v1"
    api_path, api_version = api_group.split("/")

    options = {:path => "/apis/#{api_path}", :version => api_version}.merge(options)
    kubernetes_connect(hostname, port, options)
  end

  def self.api_group_for_kind(kind)
    # TODO: is there a more general way of detecting this?
    case kind
    when "BuildConfig", "Build"
      "build.openshift.io/v1"
    when "DeploymentConfig"
      "apps.openshift.io/v1"
    when "Image"
      "image.openshift.io/v1"
    when "Project"
      "project.openshift.io/v1"
    when "Route"
      "route.openshift.io/v1"
    when "Template"
      "template.openshift.io/v1"
    end
  end

  def v3?
    api_version.to_s.split(".").first == "3"
  end

  def v4?
    api_version.to_s.split(".").first == "4"
  end

  def connect_client(kind, api_version, method_name)
    @clients ||= {}
    api, version = api_version.split('/', 2)
    if version
      @clients[api_version] ||= connect(:service => 'kubernetes', :version => version, :path => '/apis/' + api)
    else
      # If we're given an OpenShift object lookup its v4 API Group
      api_group = self.class.api_group_for_kind(kind)
      path      = api_group ? "/apps/#{api_group}" : "/oapi"

      openshift_client_key  = File.join(path, api_version)
      kubernetes_client_key = File.join("/api", api_version)

      @clients[openshift_client_key] ||= connect(:api_group => api_group, :version => api_version)
      @clients[kubernetes_client_key] ||= connect(:service => 'kubernetes', :version => api_version)
      @clients[openshift_client_key].respond_to?(method_name) ? @clients[openshift_client_key] : @clients[kubernetes_client_key]
    end
  end

  def openshift_version
    @openshift_version ||= begin
      version = begin
        self.class.openshift_v3_connect(address, port, connect_options)
        "v3"
      rescue Kubeclient::ResourceNotFoundError
        nil
      end

      version ||= begin
        self.class.openshift_v4_connect(address, port, connect_options)
        "v4"
      rescue Kubeclient::ResourceNotFoundError
        nil
      end

      version
    end
  end

  def hostname_for_service(service_type)
    openshift_route_and_project = {
      "v3" => {
        "prometheus"        => %w[prometheus openshift-metrics],
        "prometheus_alerts" => %w[alerts openshift-metrics]
      },
      "v4" => {
        "prometheus" => %w[prometheus-k8s openshift-monitoring],
      }
    }

    route_name, project_name = openshift_route_and_project[openshift_version][service_type]
    return if route_name.nil?

    routes = connect(:service => "openshift", :api_group => "route.openshift.io/v1")
    routes.get_route(route_name, project_name)&.spec&.host
  end

  def external_logging_route_name
    DEFAULT_EXTERNAL_LOGGING_ROUTE_NAME
  end

  def external_logging_query
    nil # should be empty to return all
  end

  def external_logging_path
    '/'
  end

  def create_project(project)
    connect(:api_group => "project.openshift.io/v1").create_project_request(project)
  rescue KubeException => e
    raise MiqException::MiqProvisionError, "Unexpected Exception while creating project: #{e}"
  end

  def self.catalog_types
    {"generic_container_template" => N_("OpenShift Template")}
  end

  def self.display_name(number = 1)
    n_('Container Provider (OpenShift)', 'Container Providers (OpenShift)', number)
  end
end
