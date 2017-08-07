module ManageIQ::Providers
  module Openshift
    class ContainerManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include ::EmsRefresh::Refreshers::EmsRefresherMixin
      include ManageIQ::Providers::Kubernetes::ContainerManager::RefresherMixin

      KUBERNETES_EMS_TYPE = ManageIQ::Providers::Kubernetes::ContainerManager.ems_type

      OPENSHIFT_ENTITIES = [
        {:name => 'routes'}, {:name => 'projects'},
        {:name => 'build_configs'}, {:name => 'builds'}, {:name => 'templates'}
      ]

      def fetch_hawk_inv(ems)
        hawk = ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::HawkularClient.new(ems, '_ops')
        keys = hawk.strings.query(:miq_metric => true)
        keys.each_with_object({}) do |k, attributes|
          values = hawk.strings.get_data(k.json["id"], :limit => 1, :order => "DESC")
          attributes[k.json["id"]] = values.first["value"] unless values.empty?
        end
      rescue => err
        _log.error err.message
        return nil
      end

      # Full refresh. Collecting immediately. Don't have separate Collector classes.
      def collect_inventory_for_targets(ems, _targets)
        request_entities = OPENSHIFT_ENTITIES.dup
        request_entities << {:name => 'images'} if refresher_options.get_container_images

        kube_inventory = ems.with_provider_connection(:service => KUBERNETES_EMS_TYPE) do |kubeclient|
          fetch_entities(kubeclient, KUBERNETES_ENTITIES)
        end
        openshift_inventory = ems.with_provider_connection do |openshift_client|
          fetch_entities(openshift_client, request_entities)
        end

        inventory = openshift_inventory.merge(kube_inventory)
        inventory["additional_attributes"] = fetch_hawk_inv(ems) || {}
        EmsRefresh.log_inv_debug_trace(inventory, "inv_hash:")
        [[ems, inventory]]
      end

      def parse_targeted_inventory(ems, _target_is_ems, inventory)
        if refresher_options.inventory_object_refresh
          ManageIQ::Providers::Openshift::ContainerManager::RefreshParser.ems_inv_to_inv_collections(ems, inventory, refresher_options)
        else
          ManageIQ::Providers::Openshift::ContainerManager::RefreshParser.ems_inv_to_hashes(inventory, refresher_options)
        end
      end
    end
  end
end
