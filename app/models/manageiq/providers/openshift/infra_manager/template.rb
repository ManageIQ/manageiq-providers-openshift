ManageIQ::Providers::Kubevirt::InfraManager::Template.include(ActsAsStiLeafClass)

class ManageIQ::Providers::Openshift::InfraManager::Template < ManageIQ::Providers::Kubevirt::InfraManager::Template
  def self.display_name(number = 1)
    n_('Template (OpenShift Virtualization)', 'Templates (OpenShift Virtualization)', number)
  end
end
