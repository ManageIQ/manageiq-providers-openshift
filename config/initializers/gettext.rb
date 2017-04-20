Vmdb::Gettext::Domains.add_domain(
  'ManageIQ_Providers_Openshift',
  ManageIQ::Providers::Openshift::Engine.root.join('locale').to_s,
  :po
)
