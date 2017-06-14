module ManageIQ::Providers
  class Openshift::MonitoringManager < ManageIQ::Providers::MonitoringManager
    require_nested :EventCatcher
    include ManageIQ::Providers::Kubernetes::MonitoringManagerMixin

    belongs_to :parent_manager,
               :foreign_key => :parent_ems_id,
               :class_name  => "ManageIQ::Providers::Openshift::ContainerManager",
               :inverse_of  => :monitoring_manager

    def self.ems_type
      @ems_type ||= "openshift_monitor".freeze
    end

    def self.description
      @description ||= "Openshift Monitor".freeze
    end

    def self.event_monitor_class
      ManageIQ::Providers::Openshift::MonitoringManager::EventCatcher
    end
  end
end
