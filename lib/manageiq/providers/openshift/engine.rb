module ManageIQ
  module Providers
    module Openshift
      class Engine < ::Rails::Engine
        isolate_namespace ManageIQ::Providers::Openshift
      end
    end
  end
end
