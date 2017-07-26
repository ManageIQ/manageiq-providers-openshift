class ManageIQ::Providers::Openshift::Inventory::Persister < ManagerRefresh::Inventory::Persister
  require_nested :ContainerManager
end
