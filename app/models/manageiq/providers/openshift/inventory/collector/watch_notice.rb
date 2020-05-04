class ManageIQ::Providers::Openshift::Inventory::Collector::WatchNotice < ManageIQ::Providers::Kubernetes::Inventory::Collector::WatchNotice
  attr_reader :build_configs, :builds, :projects, :routes, :templates

  def initialize_collections!
    super

    @build_configs = []
    @builds = []
    @projects = []
    @routes = []
    @templates = []
  end
end
