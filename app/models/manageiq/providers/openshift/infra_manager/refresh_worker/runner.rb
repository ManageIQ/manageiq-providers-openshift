require 'concurrent/atomic/atomic_boolean'

class ManageIQ::Providers::Openshift::InfraManager::RefreshWorker::Runner < ManageIQ::Providers::Kubevirt::InfraManager::RefreshWorker::Runner
  private

  def provider_class
    ManageIQ::Providers::Openshift
  end
end
