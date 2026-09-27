class ManageIQ::Providers::Openshift::Inventory::Collector::InfraManager::PartialRefresh < ManageIQ::Providers::Kubevirt::Inventory::Collector::PartialRefresh
  include ManageIQ::Providers::Openshift::Inventory::Collector::InfraManager::CollectorMixin

  def initialize(manager, notices)
    super

    @templates = notices_of_kind(notices, 'VirtualMachineTemplate')
  end
end
