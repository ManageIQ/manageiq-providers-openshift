require 'concurrent/atomic/atomic_boolean'

class ManageIQ::Providers::Openshift::InfraManager::RefreshWorker::Runner < ManageIQ::Providers::Kubevirt::InfraManager::RefreshWorker::Runner
  private

  def provider_class
    ManageIQ::Providers::Openshift
  end

  def collector_class
    ManageIQ::Providers::Openshift::Inventory::Collector::InfraManager
  end

  def partial_refresh_parser_class
    ManageIQ::Providers::Openshift::Inventory::Parser::InfraManager::PartialRefresh
  end

  def persister_class
    ManageIQ::Providers::Openshift::Inventory::Persister::InfraManager
  end
end
