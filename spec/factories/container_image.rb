FactoryBot.define do
  factory :openshift_container_image, :class => "ManageIQ::Providers::Openshift::ContainerManager::ContainerImage" do
    sequence(:name) { |n| "openshift_container_image_#{seq_padded_for_sorting(n)}" }
  end
end
