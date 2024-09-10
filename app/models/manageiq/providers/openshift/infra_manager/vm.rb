ManageIQ::Providers::Kubevirt::InfraManager::Vm.include(ActsAsStiLeafClass)

class ManageIQ::Providers::Openshift::InfraManager::Vm < ManageIQ::Providers::Kubevirt::InfraManager::Vm
  def self.display_name(number = 1)
    n_('Virtual Machine (OpenShift Virtualization)', 'Virtual Machines (OpenShift Virtualization)', number)
  end
end
