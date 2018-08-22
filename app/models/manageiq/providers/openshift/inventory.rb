class ManageIQ::Providers::Openshift::Inventory < ManageIQ::Providers::Kubernetes::Inventory
  require_nested :Collector
  require_nested :Parser
  require_nested :Persister
end
