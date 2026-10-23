class ManageIQ::Providers::Openshift::InfraManager::EventCatcher < ManageIQ::Providers::BaseManager::EventCatcher
  def self.settings_name
    :event_catcher_openshift_infra
  end
end
