class ManageIQ::Providers::Openshift::Inventory < ManagerRefresh::Inventory
  require_nested :Persister
end
