class ManageIQ::Providers::Openshift::ContainerManager::InventoryCollectorWorker < ManageIQ::Providers::BaseManager::InventoryCollectorWorker
  require_nested :Runner
end
