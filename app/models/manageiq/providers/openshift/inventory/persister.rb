class ManageIQ::Providers::Openshift::Inventory::Persister < ManagerRefresh::Inventory::Persister
  require_nested :TargetCollection
  require_nested :ContainerManager

  def add_collection_directly(collection)
    @collections[collection.name] = collection
  end

  # ManagerRefresh::InventoryCollection.inventory_object_attributes
  # are not defined
  def make_builder_settings(extra_settings = {})
    opts = super
    opts[:auto_inventory_attributes] = false
    opts
  end
end
