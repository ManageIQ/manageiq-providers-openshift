class ManageIQ::Providers::Openshift::Inventory < ManageIQ::Providers::Kubernetes::Inventory
  def self.parser_class_for(ems, target)
    if !ems.kind_of?(EmsInfra)
      super
    else
      parser_type = if target_is_vm?(target)
                      "PartialTargetRefresh"
                    else
                      "FullRefresh"
                    end
      "ManageIQ::Providers::Openshift::Inventory::Parser::InfraManager::#{parser_type}".safe_constantize
    end
  end

  def self.build(ems, target)
    if !ems.kind_of?(EmsInfra)
      super
    else
      collector_class = collector_class_for(ems, target)

      collector = if target_is_vm?(target)
                    collector_class.new(ems, target)
                  else
                    collector_class.new(ems, ems)
                  end

      persister = persister_class_for(ems, target).new(ems, target)
      new(
        persister,
        collector,
        parser_classes_for(ems, target).map(&:new)
      )
    end
  end

  def self.target_is_vm?(target)
    target.kind_of?(ManageIQ::Providers::Openshift::InfraManager::Vm)
  end
end
