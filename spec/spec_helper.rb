if ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

Dir[Rails.root.join("spec/shared/**/*.rb")].each { |f| require f }
Dir[ManageIQ::Providers::Kubernetes::Engine.root.join("spec/support/**/*.rb")].each { |f| require f }
Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

require "manageiq-providers-openshift"

VCR.configure do |config|
  config.ignore_hosts 'codeclimate.com' if ENV['CI']
  config.cassette_library_dir = File.join(ManageIQ::Providers::Openshift::Engine.root, 'spec/vcr_cassettes')
end
