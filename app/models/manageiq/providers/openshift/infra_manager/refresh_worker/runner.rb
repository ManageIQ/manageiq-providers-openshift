require 'concurrent/atomic/atomic_boolean'

class ManageIQ::Providers::Openshift::InfraManager::RefreshWorker::Runner < ManageIQ::Providers::Kubevirt::InfraManager::RefreshWorker::Runner
  private

  def provider_class
    ManageIQ::Providers::Openshift
  end

  def partial_refresh_collector_class
    ManageIQ::Providers::Openshift::Inventory::Collector::InfraManager::PartialRefresh
  end

  def partial_refresh_parser_class
    ManageIQ::Providers::Openshift::Inventory::Parser::InfraManager::PartialRefresh
  end

  def persister_class
    ManageIQ::Providers::Openshift::Inventory::Persister::InfraManager
  end

  #
  # Performs a full refresh.
  #
  def full_refresh
    # Create and populate the collector, persister and parser
    # and parse inventories
    inventory = provider_class::Inventory.build(manager, nil)
    collector = inventory.collector
    persister = inventory.parse

    # execute persist:
    persister&.persist!

    # Update the memory:
    memory.add_list_version(:nodes, collector.nodes.resourceVersion)
    memory.add_list_version(:vms, collector.vms.resourceVersion)
    memory.add_list_version(:vm_instances, collector.vm_instances.resourceVersion)
    memory.add_list_version(:templates, collector.templates.resourceVersion)
    memory.add_list_version(:instance_types, collector.instance_types.resourceVersion)

    manager.update(:last_refresh_error => nil, :last_refresh_date => Time.now.utc)
  rescue StandardError => error
    _log.error('Full refresh failed.')
    _log.log_backtrace(error)
    manager.update(:last_refresh_error => error.to_s, :last_refresh_date => Time.now.utc)
  end

  #
  # Start watches
  #
  def start_watches
    # This flag will be used to tell the threads to get out of their loops:
    @finish = Concurrent::AtomicBoolean.new(false)

    # Create the watches:
    @watches = []
    @watches << @manager.kubeclient.watch_nodes(:resource_version => memory.get_list_version(:nodes))
    @watches << @manager.kubeclient("kubevirt.io/v1").watch_virtual_machines(:resource_version => memory.get_list_version(:vms))
    @watches << @manager.kubeclient("kubevirt.io/v1").watch_virtual_machine_instances(:resource_version => memory.get_list_version(:vm_instances))
    @watches << @manager.kubeclient("template.openshift.io/v1").watch_templates(:resource_version => memory.get_list_version(:templates))
    @watches << @manager.kubeclient("instancetype.kubevirt.io/v1beta1").watch_virtual_machine_cluster_instancetypes(:resource_version => memory.get_list_version(:instance_types))

    # Create the threads that run the watches and put the notices in the queue:
    @watchers = []
    @watches.each do |watch|
      thread = Thread.new do
        until @finish.value
          watch.each do |notice|
            @queue.push(notice)
          end
        end
      end
      @watchers << thread
    end
  end
end
