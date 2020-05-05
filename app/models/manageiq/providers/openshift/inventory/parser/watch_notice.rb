class ManageIQ::Providers::Openshift::Inventory::Parser::WatchNotice < ManageIQ::Providers::Kubernetes::Inventory::Parser::WatchNotice
  include ManageIQ::Providers::Openshift::Inventory::Parser::OpenshiftParserMixin

  def parse
    super

    projects
    routes
    builds
    build_pods
    templates
    # TODO: openshift images
  end
end
