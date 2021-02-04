class ManageIQ::Providers::Openshift::Inventory::Parser < ManageIQ::Providers::Kubernetes::Inventory::Parser
  require_nested :ContainerManager
end
