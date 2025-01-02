ManageIQ::Providers::Kubernetes::ContainerManager.include(ActsAsStiLeafClass)

class ManageIQ::Providers::Openshift::ContainerManager < ManageIQ::Providers::Kubernetes::ContainerManager
  DEFAULT_EXTERNAL_LOGGING_ROUTE_NAME = "logging-kibana-ops".freeze

  has_one :infra_manager,
          :foreign_key => :parent_ems_id,
          :class_name  => "ManageIQ::Providers::Openshift::InfraManager",
          :autosave    => true,
          :inverse_of  => :parent_manager,
          :dependent   => :destroy

  include ManageIQ::Providers::Openshift::ContainerManager::Options

  supports :catalog
  supports :create
  supports :external_logging

  def self.ems_type
    @ems_type ||= "openshift".freeze
  end

  def self.description
    @description ||= "OpenShift".freeze
  end

  def self.event_monitor_class
    ManageIQ::Providers::Openshift::ContainerManager::EventCatcher
  end

  def self.virtualization_options
    [
      {
        :label => _('Disabled'),
        :value => 'none',
      },
      {
        :label => _('OpenShift Virtualization'),
        :value => 'kubevirt',
        :pivot => 'endpoints.kubevirt.hostname',
      },
    ]
  end

  def self.raw_connect(hostname, port, options)
    options[:service] ||= "openshift"
    send("#{options[:service]}_connect", hostname, port, options)
  end

  def self.openshift_connect(hostname, port, options)
    api_group = options[:api_group] || "config.openshift.io/v1"
    api_path, api_version = api_group.split("/")

    options = {:path => "/apis/#{api_path}", :version => api_version}.merge(options)
    kubernetes_connect(hostname, port, options)
  end

  def self.verify_default_credentials(hostname, port, options)
    return false unless super

    ocp = openshift_connect(hostname, port, options)
    !!ocp&.api_valid?
  rescue Kubeclient::ResourceNotFoundError
    # If the /apis/config.openshift.io/v1 endpoint isn't available then we have
    # connected to an unsupported version of openshift
    raise MiqException::Error, _("Unsupported OpenShift version")
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
      kubernetes_client_key = File.join("/api", api_version)
      @clients[kubernetes_client_key] ||= connect(:service => 'kubernetes', :version => api_version)

      # If we're given an OpenShift object lookup its v4 API Group
      api_group = self.class.api_group_for_kind(kind)
      if api_group
        openshift_client_key = File.join(path, "/apps/#{api_group}")
        @clients[openshift_client_key] ||= connect(:api_group => api_group, :version => api_version)
      end

      @clients[openshift_client_key].respond_to?(method_name) ? @clients[openshift_client_key] : @clients[kubernetes_client_key]
    end
  end

  def hostname_for_service(service_type)
    openshift_route_and_project = {
      "prometheus" => %w[prometheus-k8s openshift-monitoring],
    }

    route_name, project_name = openshift_route_and_project[service_type]
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
