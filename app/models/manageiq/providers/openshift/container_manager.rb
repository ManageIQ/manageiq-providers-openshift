class ManageIQ::Providers::Openshift::ContainerManager < ManageIQ::Providers::ContainerManager
  include ManageIQ::Providers::Openshift::ContainerManagerMixin

  require_nested :ContainerImage
  require_nested :ContainerTemplate
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :InventoryCollectorWorker
  require_nested :MetricsCollectorWorker
  require_nested :OrchestrationStack
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :Options

  include ManageIQ::Providers::Openshift::ContainerManager::Options
  include ManageIQ::Providers::Kubernetes::ContainerManager::AlertLabels

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

  def supported_catalog_types
    %w(generic_container_template).freeze
  end

  def self.display_name(number = 1)
    n_('Container Provider (OpenShift)', 'Container Providers (OpenShift)', number)
  end
end
