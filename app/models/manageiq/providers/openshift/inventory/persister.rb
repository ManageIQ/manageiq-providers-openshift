class ManageIQ::Providers::Openshift::Inventory::Persister < ManagerRefresh::Inventory::Persister
  require_nested :TargetCollection
  require_nested :ContainerManager
end
