describe :placeholders do
  include_examples :placeholders, ManageIQ::Providers::Openshift::Engine.root.join('locale').to_s
end
