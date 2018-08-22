class ManageIQ::Providers::Openshift::Inventory::Collector::ContainerManager < ManageIQ::Providers::Kubernetes::Inventory::Collector::ContainerManager
  def templates
    @templates ||= openshift_connection.get_templates
  end

  private

  def openshift_connection
    @openshift_connection ||= manager.connect(:service => "openshift")
  end
end
