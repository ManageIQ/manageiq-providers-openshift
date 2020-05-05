class ManageIQ::Providers::Openshift::Inventory::Collector::WatchNotice < ManageIQ::Providers::Kubernetes::Inventory::Collector::WatchNotice
  attr_reader :build_configs, :builds, :routes, :templates

  def initialize_collections!
    super

    @build_configs = []
    @builds = []
    @projects = []
    @routes = []
    @templates = []
  end

  def namespaces_by_name
    @namespaces_by_name ||= begin
      projects # Make sure that we collect missing namespaces first
      namespaces.index_by { |ns| ns.metadata.name }
    end
  end

  def projects
    unless @projects_collected
      @namespaces += get_missing("namespaces")
      @projects_collected = true
    end

    @projects
  end

  def missing_namespaces
    project_targets - namespace_targets
  end

  def project_targets
    @projects.map { |proj| name_and_namespace(proj) }
  end

  def namespace_targets
    @namespaces.map { |ns| name_and_namespace(ns) }
  end
end
