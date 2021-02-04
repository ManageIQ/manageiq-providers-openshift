class ManageIQ::Providers::Openshift::Inventory::Parser::ContainerManager < ManageIQ::Providers::Kubernetes::Inventory::Parser::ContainerManager
  require_nested :WatchNotice

  include ManageIQ::Providers::Openshift::Inventory::Parser::OpenshiftParserMixin

  def ems_inv_populate_collections
    super

    ext_management_system
    projects
    routes
    builds
    build_pods
    templates
    openshift_images
  end

  def ext_management_system
    persister.ext_management_system.build(
      :guid        => collector.manager.guid,
      :api_version => collector.api_version,
      :uid_ems     => collector.cluster_id
    )
  end
end
