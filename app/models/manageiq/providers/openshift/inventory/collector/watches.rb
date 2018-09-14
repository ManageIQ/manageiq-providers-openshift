class ManageIQ::Providers::Openshift::Inventory::Collector::Watches < ManageIQ::Providers::Kubernetes::Inventory::Collector::Watches
  def template_notices
    @templates ||= notices['Template'] || []
  end
end
