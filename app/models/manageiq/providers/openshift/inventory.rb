class ManageIQ::Providers::Openshift::Inventory < ManageIQ::Providers::Kubernetes::Inventory
  def self.parser_class_for(ems, target)
    if !ems.kind_of?(EmsInfra)
      super
    else
      ManageIQ::Providers::Openshift::Inventory::Parser::InfraManager::FullRefresh
    end
  end

  def self.build(ems, target)
    if !ems.kind_of?(EmsInfra)
      super
    else
      collector = collector_class_for(ems, target).new(ems, target)
      persister = persister_class_for(ems, target).new(ems, target)
      new(
        persister,
        collector,
        parser_classes_for(ems, target).map(&:new)
      )
    end
  end
end
