require 'concurrent/atomic/atomic_boolean'

class ManageIQ::Providers::Openshift::InfraManager::RefreshWorker::Runner < ManageIQ::Providers::Kubevirt::InfraManager::RefreshWorker::Runner

  private

  #
  # Returns the reference to the manager.
  #
  # @return [ManageIQ::Providers::Kubevirt::InfraManager] The manager.
  #
  def manager
    @manager ||= ManageIQ::Providers::Openshift::InfraManager.find(@cfg[:ems_id])
  end

  #
  # Returns the refresh memory.
  #
  # @return [ManageIQ::Providers::Kubevirt::RefreshMemory] The refresh memory.
  #
  def memory
    @memory ||= ManageIQ::Providers::Openshift::RefreshMemory.new
  end

  #
  # Performs a full refresh.
  #
  def full_refresh
    # Create and populate the collector, persister and parser
    # and parse inventories
    inventory = ManageIQ::Providers::Openshift::Inventory.build(manager, nil)
    collector = inventory.collector
    persister = inventory.parse

    # execute persist:
    persister&.persist!

    # Update the memory:
    memory.add_list_version(:nodes, collector.nodes.resource_version)
    memory.add_list_version(:vms, collector.vms.resource_version)
    memory.add_list_version(:vm_instances, collector.vm_instances.resource_version)
    memory.add_list_version(:templates, collector.templates.resource_version)

    manager.update(:last_refresh_error => nil, :last_refresh_date => Time.now.utc)
  rescue StandardError => error
    _log.error('Full refresh failed.')
    _log.log_backtrace(error)
    manager.update(:last_refresh_error => error.to_s, :last_refresh_date => Time.now.utc)
  end

  #
  # Performs a partial refresh.
  #
  # @param notices [Array] The set of notices to process.
  #
  def partial_refresh(notices)
    # check whether we get error about stale resource version
    if notices.any? { |notice| notice.object&.kind == "Status" && notice.object&.code == 410 }
      # base on the structure we do not know which watch uses stale version so we stop all
      # we can't join with all the threads since we are in one
      stop_watches

      # clear queue
      @queue.clear

      # get the latest state and resource versions
      full_refresh

      # restart watches
      start_watches
      return
    end

    # Filter out the notices that have already been processed:
    notices.reject! do |notice|
      if memory.contains_notice?(notice)
        _log.info(
          "Notice of kind '#{notice.kind}, id '#{notice.uid}', type '#{notice.type}' and version '#{notice.resource_version}' " \
          "has already been processed, will ignore it."
        )
        true
      else
        false
      end
    end

    # The notices returned by the Kubernetes API contain always the complete representation of the object, so it isn't
    # necessary to process all of them, only the last one for each object.
    relevant = notices.reverse!
    relevant.uniq!(&:uid)
    relevant.reverse!

    # Create and populate the collector:
    collector = ManageIQ::Providers::Openshift::Inventory::Collector.new(manager, nil)
    collector.nodes = notices_of_kind(relevant, 'Node')
    collector.vms = notices_of_kind(relevant, 'VirtualMachine')
    collector.vm_instances = notices_of_kind(relevant, 'VirtualMachineInstance')
    collector.templates = notices_of_kind(relevant, 'VirtualMachineTemplate')

    # Create the parser and persister, wire them, and execute the persist:
    persister = ManageIQ::Providers::Openshift::Inventory::Persister.new(manager, nil)
    parser = ManageIQ::Providers::Openshift::Inventory::Parser::PartialRefresh.new
    parser.collector = collector
    parser.persister = persister
    parser.parse
    persister.persist!

    # Update the memory:
    notices.each do |notice|
      memory.add_notice(notice)
    end

    manager.update(:last_refresh_error => nil, :last_refresh_date => Time.now.utc)
  rescue StandardError => error
    _log.error('Partial refresh failed.')
    _log.log_backtrace(error)
    manager.update(:last_refresh_error => error.to_s, :last_refresh_date => Time.now.utc)
  end

  #
  # Returns the notices that contain objects of the given kind.
  #
  # @param notices [Array] An array of notices.
  # @param kind [String] The kind of object, for example `Node`.
  # @return [Array] An array containing the notices that have the given kind.
  #
  def notices_of_kind(notices, kind)
    notices.select { |notice| notice.kind == kind }
  end

  #
  # Start watches
  #
  def start_watches
    # This flag will be used to tell the threads to get out of their loops:
    @finish = Concurrent::AtomicBoolean.new(false)

    # Create the watches:
    @watches = []
    manager.with_provider_connection do |connection|
      @watches << connection.watch_nodes(:resource_version => memory.get_list_version(:nodes))
      @watches << connection.watch_vms(:resource_version => memory.get_list_version(:vms))
      @watches << connection.watch_vm_instances(:resource_version => memory.get_list_version(:vm_instances))
      @watches << connection.watch_templates(:resource_version => memory.get_list_version(:templates))
    end

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

  #
  # Stop all the watches
  #
  def stop_watches
    @finish&.value = true
    @watches&.each(&:finish)
  end
end
