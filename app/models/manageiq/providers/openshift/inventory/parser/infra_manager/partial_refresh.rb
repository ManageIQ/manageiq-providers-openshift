class ManageIQ::Providers::Openshift::Inventory::Parser::InfraManager::PartialRefresh < ManageIQ::Providers::Kubevirt::Inventory::Parser::PartialRefresh
  include ManageIQ::Providers::Openshift::Inventory::Parser::InfraManager::ParserMixin

  def parse
    templates = collector.templates
    template_ids = get_object_ids(templates.map(&:object))
    discard_deleted_notices(templates)
    @template_collection = persister.template_collection(:targeted => true, :ids => template_ids)
    process_templates(templates.map(&:object))
  end
end
