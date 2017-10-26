class ManageIQ::Providers::Openshift::Inventory::Collector < ManagerRefresh::Inventory::Collector
  require_nested :TargetCollection
end
