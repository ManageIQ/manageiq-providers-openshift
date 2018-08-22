class ManageIQ::Providers::Openshift::Inventory::Collector < ManageIQ::Providers::Kubernetes::Inventory::Collector
  require_nested :TargetCollection
  require_nested :Watches
end
