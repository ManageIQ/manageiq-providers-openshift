class ManageIQ::Providers::Openshift::ContainerManager::ContainerTemplate < ManageIQ::Providers::ContainerManager::ContainerTemplate
  include ManageIQ::Providers::Kubernetes::ContainerManager::ContainerTemplateMixin

  def self.display_name(number = 1)
    n_('Container Template (OpenShift)', 'Container Templates (OpenShift)', number)
  end
end
