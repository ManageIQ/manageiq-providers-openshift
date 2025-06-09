ManageIQ::Providers::Kubevirt::InfraManager.include(ActsAsStiLeafClass)

class ManageIQ::Providers::Openshift::InfraManager < ManageIQ::Providers::Kubevirt::InfraManager
  belongs_to :parent_manager,
             :foreign_key => :parent_ems_id,
             :inverse_of  => :infra_manager,
             :class_name  => "ManageIQ::Providers::Openshift::ContainerManager"

  has_many :flavors, :dependent => :destroy, :foreign_key => :ems_id, :inverse_of => :ext_management_system

  #
  # This is the list of features that this provider supports:
  #
  supports :catalog
  supports :provisioning

  class << self
    delegate :refresh_ems, :to => ManageIQ::Providers::Openshift::ContainerManager
  end

  def self.ems_type
    @ems_type ||= "openshift_infra".freeze
  end

  def self.description
    @description ||= "OpenShift Virtualization".freeze
  end

  def self.catalog_types
    {"openshift" => N_("OpenShift Virtualization")}
  end

  def self.vendor
    "openshift_infra".freeze
  end

  def self.product_name
    "OpenShift Virtualization".freeze
  end

  def self.version
    "0.1.0".freeze
  end

  def self.display_name(number = 1)
    n_('Infrastructure Provider (OpenShift Virtualization)', 'Infrastructure Providers (OpenShift Virtualization)', number)
  end
end
