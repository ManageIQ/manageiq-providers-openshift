module ManageIQ::Providers::Openshift::ContainerManagerMixin
  extend ActiveSupport::Concern

  include ManageIQ::Providers::Kubernetes::ContainerManagerMixin

  DEFAULT_PORT = 8443
  DEFAULT_EXTERNAL_LOGGING_ROUTE_NAME = "logging-kibana-ops".freeze

  # This is the API version that we use and support throughout the entire code
  # (parsers, events, etc.). It should be explicitly selected here and not
  # decided by the user nor out of control in the defaults of openshift gem
  # because it's not guaranteed that the next default version will work with
  # our specific code in ManageIQ.
  delegate :api_version, :to => :class

  def api_version=(_value)
    raise 'OpenShift api_version cannot be modified'
  end

  class_methods do
    def api_version
      'v1'
    end

    def raw_connect(hostname, port, options)
      options[:service] ||= "openshift"
      send("#{options[:service]}_connect", hostname, port, options)
    end

    def openshift_connect(hostname, port, options)
      # First attempt to connect to the /oapi endpoint and if that fails with
      # a ResourceNotFoundError attempt to connect to /apis/...
      openshift_v3_connect(hostname, port, options)
    rescue Kubeclient::ResourceNotFoundError
      openshift_v4_connect(hostname, port, options)
    end

    def openshift_v3_connect(hostname, port, options)
      options = {:path => '/oapi', :version => api_version}.merge(options)
      kubernetes_connect(hostname, port, options)
    end

    def openshift_v4_connect(hostname, port, options)
      api_group = options[:api_group] || "apps.openshift.io"
      options = {:path => "/apis/#{api_group}", :version => api_version}.merge(options)
      kubernetes_connect(hostname, port, options)
    end

    def api_group_for_kind(kind)
      # TODO: is there a more general way of detecting this?
      case kind
      when "BuildConfig", "Build"
        "build.openshift.io"
      when "DeploymentConfig"
        "apps.openshift.io"
      when "Image"
        "image.openshift.io"
      when "Project"
        "project.openshift.io"
      when "Route"
        "route.openshift.io"
      when "Template"
        "template.openshift.io"
      end
    end
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
