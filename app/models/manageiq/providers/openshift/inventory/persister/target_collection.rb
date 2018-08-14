class ManageIQ::Providers::Openshift::Inventory::Persister::TargetCollection < ManageIQ::Providers::Openshift::Inventory::Persister::ContainerManager
  def targeted?
    true
  end

  def strategy
    :local_db_find_missing_references
  end
end
