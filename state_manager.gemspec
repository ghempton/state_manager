# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'state_manager/version'

Gem::Specification.new do |spec|
  spec.name          = "state_manager"
  spec.version       = StateManager::VERSION
  spec.authors       = ["Gordon L. Hempton"]
  spec.email         = ["ghempton@gmail.com"]
  spec.summary       = "%Q{Finite state machine implementation.}"
  spec.description   = "Finite state machine implementation that keeps logic separate from model classes and supports sub-states."
  spec.homepage      = "https://github.com/ghempton/state_manager"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'activesupport'
  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
end
