ManageIQ::Providers::Kubevirt::InfraManager.include(ActsAsStiLeafClass)

class ManageIQ::Providers::OpenShift::InfraManager < ManageIQ::Providers::Kubevirt::InfraManager
  belongs_to :parent_manager,
             :foreign_key => :parent_ems_id,
             :class_name  => "ManageIQ::Providers::ContainerManager"

  delegate :authentication_check,
           :authentication_for_summary,
           :authentication_token,
           :authentications,
           :endpoints,
           :default_endpoint,
           :zone,
           :to        => :parent_manager,
           :allow_nil => true

  #
  # This is the list of features that this provider supports:
  #
  supports :catalog
  supports :provisioning

  def self.ems_type
    @ems_type ||= "openshift".freeze
  end

  def self.description
    @description ||= "OpenShift".freeze
  end

  def self.catalog_types
    {"openshift" => N_("OpenShift Virtualization")}
  end

  def authentication_status_ok?(type = :openshift)
    authentication_best_fit(type).try(:status) == "Valid"
  end

  def authentication_for_providers
    authentications.where(:authtype => :openshift)
  end

  #
  # The ManageIQ core calls this method whenever a connection to the server is needed.
  #
  # @param opts [Hash] The options provided by the ManageIQ core.
  #
  def connect(opts = {})
    # Get the authentication token:
    token = opts[:token] || authentication_token(:openshift)

    # Create and return the connection:
    endpoint = default_endpoint
    self.class::Connection.new(
      :host      => endpoint.hostname,
      :port      => endpoint.port,
      :token     => token,
      :namespace => ""
    )
  end

  def virtualization_endpoint
    connection_configurations.kubevirt.try(:endpoint)
  end

  def default_authentication_type
    :openshift
  end

  def self.display_name(number = 1)
    n_('Infrastructure Provider (OpenShift Virtualization)', 'Infrastructure Providers (OpenShift Virtualization)', number)
  end
end
