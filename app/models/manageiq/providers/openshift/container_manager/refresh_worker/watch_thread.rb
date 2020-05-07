class ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker::WatchThread < ManageIQ::Providers::Kubernetes::ContainerManager::RefreshWorker::WatchThread
  def self.start!(ems, queue, entity_type, resource_version)
    connect_options = ems.connect_options
    ems_klass       = ems.class

    # Handle openshift entity types with different API paths
    connect_options[:api_group] = ems_klass.api_group_for_kind(entity_type.camelize.singularize)
    connect_options[:service]   = connect_options[:api_group] ? "openshift" : "kubernetes"

    new(connect_options, ems_klass, queue, entity_type, resource_version).tap(&:start!)
  end
end
