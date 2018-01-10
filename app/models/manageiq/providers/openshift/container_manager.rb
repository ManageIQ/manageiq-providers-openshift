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

  # Override HasMonitoringManagerMixin
  has_one :monitoring_manager,
          :foreign_key => :parent_ems_id,
          :class_name  => "ManageIQ::Providers::Openshift::MonitoringManager",
          :autosave    => true,
          :dependent   => :destroy

  delegate :delete_project, :to => :connect

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
  end

  def users_from_provider
    connect.get_users
  end

  def user_from_provider(user_name)
    connect.get_user(user_name)
  end

  def user_exists_in_provider?(user_name)
    !user_from_provider(user_name).nil?
  end

  def add_user_in_provider(user_name)
    user = Kubeclient::Resource.new
    user.metadata = {}
    user.metadata.name = user_name
    user.identities = {}
    user.groups = {}
    connect.create_user(user)
  end

  def supported_catalog_types
    %w(generic_container_template).freeze
  end
end
