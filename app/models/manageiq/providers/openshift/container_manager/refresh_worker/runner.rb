class ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker::Runner < ManageIQ::Providers::BaseManager::RefreshWorker::Runner
  include ManageIQ::Providers::Kubernetes::ContainerManager::StreamingRefreshMixin
end
