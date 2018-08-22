class ManageIQ::Providers::Openshift::Inventory::Collector::Watches < ManageIQ::Providers::Kubernetes::Inventory::Collector::Watches
  def templates
    @templates ||= notices['Template']&.map { |template_notice| template_notice.object } || []
  end
end
