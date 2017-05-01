module ManageIQ::Providers::Openshift::ContainerManagerMixin
  extend ActiveSupport::Concern

  include ManageIQ::Providers::Kubernetes::ContainerManagerMixin

  DEFAULT_PORT = 8443
  DEFAULT_EXTERNAL_LOGGING_ROUTE_NAME = "logging-kibana-ops".freeze

  included do
    has_many :container_routes, :foreign_key => :ems_id, :dependent => :destroy
  end

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
      require 'kubeclient'

      Kubeclient::Client.new(
        raw_api_endpoint(hostname, port, '/oapi'),
        options[:version] || api_version,
        :ssl_options    => Kubeclient::Client::DEFAULT_SSL_OPTIONS.merge(options[:ssl_options] || {}),
        :auth_options   => kubernetes_auth_options(options),
        :http_proxy_uri => VMDB::Util.http_proxy_uri,
        :timeouts       => {
          :open => Settings.ems.ems_kubernetes.open_timeout.to_f_with_method,
          :read => Settings.ems.ems_kubernetes.read_timeout.to_f_with_method
        }
      )
    end
  end

  def connect_client(api_version, method_name)
    @clients ||= {}
    api, version = api_version.split('/', 2)
    if version
      @clients[api_version] ||= connect(:service => 'kubernetes', :version => version, :path => '/apis/' + api)
    else
      openshift = 'oapi' + api_version
      kubernetes = 'api' + api_version
      @clients[openshift] ||= connect(:version => api_version)
      @clients[kubernetes] ||= connect(:service => 'kubernetes', :version => api_version)
      @clients[openshift].respond_to?(method_name) ? @clients[openshift] : @clients[kubernetes]
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
