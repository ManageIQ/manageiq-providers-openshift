class ManageIQ::Providers::Openshift::ContainerManager::ContainerTemplate < ManageIQ::Providers::ContainerManager::ContainerTemplate
  include ManageIQ::Providers::Kubernetes::ContainerManager::ContainerTemplateMixin
end
