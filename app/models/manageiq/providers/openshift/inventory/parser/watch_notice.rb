class ManageIQ::Providers::Openshift::Inventory::Parser::WatchNotice < ManageIQ::Providers::Kubernetes::Inventory::Parser::WatchNotice
  include ManageIQ::Providers::Openshift::Inventory::Parser::OpenshiftParserMixin

  def parse
    super

    # TODO: projects only set the display_name and labels on top of namespaces
    # projects
    routes
    builds
    build_pods
    templates
    # TODO: openshift images
  end
end
