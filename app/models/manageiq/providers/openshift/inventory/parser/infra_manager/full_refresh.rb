class ManageIQ::Providers::Openshift::Inventory::Parser::InfraManager::FullRefresh < ManageIQ::Providers::Kubevirt::Inventory::Parser::FullRefresh
  include ManageIQ::Providers::Openshift::Inventory::Parser::InfraManager::ParserMixin

  def parse
    super

    templates = collector.templates
    @template_collection = persister.template_collection
    process_templates(templates)
  end
end
