# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'manageiq/providers/openshift/version'

Gem::Specification.new do |spec|
  spec.name          = "manageiq-providers-openshift"
  spec.version       = ManageIQ::Providers::Openshift::VERSION
  spec.authors       = ["ManageIQ Authors"]

  spec.summary       = "ManageIQ plugin for the OpenShift provider."
  spec.description   = "ManageIQ plugin for the OpenShift provider."
  spec.homepage      = "https://github.com/ManageIQ/manageiq-providers-openshift"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "manageiq-providers-kubernetes", "~> 0.1.0"

  spec.add_development_dependency "recursive-open-struct", "~> 1.0.0"
  spec.add_development_dependency "simplecov"
end
