class ManageIQ::Providers::Openshift::Inventory::Collector < ManageIQ::Providers::Kubernetes::Inventory::Collector
  require_nested :ContainerManager
  require_nested :WatchNotice
end
