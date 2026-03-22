class ManageIQ::Providers::Openshift::Inventory::Collector::InfraManager::FullRefresh < ManageIQ::Providers::Kubevirt::Inventory::Collector::FullRefresh
  include ManageIQ::Providers::Openshift::Inventory::Collector::InfraManager::CollectorMixin

  def initialize(manager, refresh_target)
    super

    @templates  = @manager.kubeclient("template.openshift.io/v1").get_templates
  end
end
