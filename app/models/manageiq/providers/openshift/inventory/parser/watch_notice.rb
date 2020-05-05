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

  %w[project route build_config template].each do |kind|
    alias_method :"parse_#{kind}_manager_ref", :parse_default_manager_ref
  end

  def parse_build_manager_ref(build_pod)
    namespace, name = build_pod.metadata.to_h.values_at(:namespace, :name)
    {:namespace => namespace, :name => name}
  end
end
