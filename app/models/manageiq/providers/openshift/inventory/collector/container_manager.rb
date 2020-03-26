class ManageIQ::Providers::Openshift::Inventory::Collector::ContainerManager < ManageIQ::Providers::Kubernetes::Inventory::Collector::ContainerManager
  def collect
    super

    entities = openshift_entities.dup
    entities << "images" if refresher_options.get_container_images

    @inventory.merge!(fetch_entities(openshift_connection, entities))
  end

  private

  def openshift_connection
    @openshift_connection ||= connect("openshift")
  end

  def openshift_entities
    %w[routes projects build_configs builds templates]
  end
end
