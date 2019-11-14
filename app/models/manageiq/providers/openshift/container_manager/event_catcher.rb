class ManageIQ::Providers::Openshift::ContainerManager::EventCatcher < ManageIQ::Providers::BaseManager::EventCatcher
  require_nested :Runner
end
