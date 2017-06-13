class ManageIQ::Providers::Openshift::ContainerManager < ManageIQ::Providers::ContainerManager
  include ManageIQ::Providers::Openshift::ContainerManagerMixin

  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :MetricsCollectorWorker
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :OrchestrationStack

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

  def create_project(project)
    connect.create_project_request(project)
  rescue KubeException => e
    raise MiqException::MiqProvisionError, "Unexpected Exception while creating project: #{e}"
  end
end
