class ManageIQ::Providers::Openshift::Inventory::Parser::ContainerManager::WatchNotice < ManageIQ::Providers::Kubernetes::Inventory::Parser::ContainerManager::WatchNotice
  include ManageIQ::Providers::Openshift::Inventory::Parser::OpenshiftParserMixin

  def parse
    super

    projects
    routes
    builds
    build_pods
    templates
    openshift_images
    container_images
    container_image_registries
  end

  %w[project route build_config template].each do |kind|
    alias_method :"parse_#{kind}_manager_ref", :parse_default_manager_ref
  end

  def parse_build_manager_ref(build_pod)
    namespace, name = build_pod.metadata.to_h.values_at(:namespace, :name)
    {:namespace => namespace, :name => name}
  end

  def parse_image_manager_ref(image)
    parse_openshift_image(image)[:ref]
  end
end
