class ManageIQ::Providers::Openshift::ContainerManager::OrchestrationStack < ManageIQ::Providers::ContainerManager::OrchestrationStack
  require_nested :Status
end
