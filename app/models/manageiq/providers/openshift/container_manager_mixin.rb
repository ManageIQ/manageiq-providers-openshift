module ManageIQ::Providers::Openshift::ContainerManagerMixin
  extend ActiveSupport::Concern

  include ManageIQ::Providers::Kubernetes::ContainerManagerMixin

  DEFAULT_PORT = 8443
  DEFAULT_EXTERNAL_LOGGING_ROUTE_NAME = "logging-kibana-ops".freeze

  class_methods do
    def raw_connect(hostname, port, options)
      options[:service] ||= "openshift"
      send("#{options[:service]}_connect", hostname, port, options)
    end

    def openshift_connect(hostname, port, options)
      major_version = options[:api_version]&.split(".")&.first

      begin
        # First attempt to connect to the /oapi endpoint and if that fails with
        # a ResourceNotFoundError attempt to connect to /apis/...
        return openshift_v3_connect(hostname, port, options) if major_version.nil? || major_version == "3"
      rescue Kubeclient::ResourceNotFoundError
      end

      openshift_v4_connect(hostname, port, options)
    end

    def openshift_v3_connect(hostname, port, options)
      options = {:path => '/oapi', :version => "v1"}.merge(options)
      kubernetes_connect(hostname, port, options)
    end

    def openshift_v4_connect(hostname, port, options)
      api_group = options[:api_group] || "apps.openshift.io/v1"
      api_path, api_version = api_group.split("/")

      options = {:path => "/apis/#{api_path}", :version => api_version}.merge(options)
      kubernetes_connect(hostname, port, options)
    end

    def api_group_for_kind(kind)
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
  end

  def connect_options(options = {})
    super.tap { |opts| opts[:api_version] ||= api_version.presence }
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
        "hawkular"          => %w[hawkular-metrics openshift-infra],
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
end
