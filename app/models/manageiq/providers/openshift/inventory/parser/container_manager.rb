class ManageIQ::Providers::Openshift::Inventory::Parser::ContainerManager < ManageIQ::Providers::Kubernetes::Inventory::Parser::ContainerManager
  include ManageIQ::Providers::Openshift::Inventory::Parser::OpenshiftParserMixin

  def ems_inv_populate_collections
    super

    projects
    routes
    builds
    build_pods
    templates
    openshift_images
  end
end
