ManageIQ::Providers::Kubernetes::ContainerManager::ContainerGroup.include(ActsAsStiLeafClass)

class ManageIQ::Providers::Openshift::ContainerManager::ContainerGroup < ManageIQ::Providers::Kubernetes::ContainerManager::ContainerGroup
  private

  def terminal_binary
    "oc"
  end
end
