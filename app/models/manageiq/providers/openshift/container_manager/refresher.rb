module ManageIQ::Providers
  module Openshift
    class ContainerManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include ManageIQ::Providers::Kubernetes::ContainerManager::RefresherMixin

      KUBERNETES_EMS_TYPE = ManageIQ::Providers::Kubernetes::ContainerManager.ems_type

      OPENSHIFT_ENTITIES = [
        {:name => 'routes'}, {:name => 'projects'},
        {:name => 'build_configs'}, {:name => 'builds'}, {:name => 'templates'}
      ]

      def target_collection_collector_class
        ManageIQ::Providers::Openshift::Inventory::Collector::TargetCollection
      end

      def refresh_parser_class
        ManageIQ::Providers::Openshift::ContainerManager::RefreshParser
      end

      def all_entities
        OPENSHIFT_ENTITIES + KUBERNETES_ENTITIES + [{:name => 'images'}]
      end

      def collect_full_inventory(ems)
        request_entities = OPENSHIFT_ENTITIES.dup
        request_entities << {:name => 'images'} if refresher_options.get_container_images

        kube_inventory = ems.with_provider_connection(:service => KUBERNETES_EMS_TYPE) do |kubeclient|
          fetch_entities(kubeclient, KUBERNETES_ENTITIES)
        end
        openshift_inventory = ems.with_provider_connection do |openshift_client|
          fetch_entities(openshift_client, request_entities)
        end

        inventory = openshift_inventory.merge(kube_inventory)
        inventory
      end
    end
  end
end
