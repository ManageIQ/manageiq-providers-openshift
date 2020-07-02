class ManageIQ::Providers::Openshift::ContainerManager < ManageIQ::Providers::ContainerManager
  include ManageIQ::Providers::Openshift::ContainerManagerMixin

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

  def v3?
    api_version.to_s.split(".").first == "3"
  end

  def v4?
    api_version.to_s.split(".").first == "4"
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
