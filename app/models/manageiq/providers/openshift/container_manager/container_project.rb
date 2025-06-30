ManageIQ::Providers::Kubernetes::ContainerManager::ContainerProject.include(ActsAsStiLeafClass)

class ManageIQ::Providers::Openshift::ContainerManager::ContainerProject < ManageIQ::Providers::Kubernetes::ContainerManager::ContainerProject
  def self.display_name(number = 1)
    n_('Container Project (OpenShift)', 'Container Projects (OpenShift)', number)
  end
end
