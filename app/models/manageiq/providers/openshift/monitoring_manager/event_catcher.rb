class ManageIQ::Providers::Openshift::MonitoringManager::EventCatcher < ManageIQ::Providers::BaseManager::EventCatcher
  require_nested :Runner

  def self.settings_name
    :event_catcher_prometheus
  end
end
