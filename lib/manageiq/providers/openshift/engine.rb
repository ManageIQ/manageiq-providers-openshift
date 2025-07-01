module ManageIQ
  module Providers
    module Openshift
      class Engine < ::Rails::Engine
        isolate_namespace ManageIQ::Providers::Openshift

        config.autoload_paths << root.join('lib').to_s

        def self.vmdb_plugin?
          true
        end

        def self.plugin_name
          _('OpenShift Provider')
        end
      end
    end
  end
end
