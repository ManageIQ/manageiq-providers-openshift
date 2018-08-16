class ManageIQ::Providers::Openshift::Inventory::Collector::ContainerManager < ManageIQ::Providers::Kubernetes::Inventory::Collector::ContainerManager
  def images
    @images ||= openshift_connection.get_images
  end

  def templates
    @templates ||= openshift_connection.get_templates
  end

  private

  def openshift_connection
    @openshift_connection ||= manager.connect
  end
end
