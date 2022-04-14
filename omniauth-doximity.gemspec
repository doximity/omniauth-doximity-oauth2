# coding: utf-8

require File.expand_path("../lib/omniauth-doximity/version", __FILE__)

Gem::Specification.new do |spec|
  spec.name          = "omniauth-doximity"
  spec.version       = Omniauth::Doximity::VERSION
  spec.authors       = ["Doximity"]
  spec.email         = ["support@doximity.com"]
  spec.description   = %q(OmniAuth strategy for Doximity)
  spec.summary       = %q(OmniAuth strategy for Doximity)
  spec.homepage      = "https://github.com/doximity/omniauth-doximity.git"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "json"
  spec.add_runtime_dependency "jwt"
  spec.add_runtime_dependency "omniauth-oauth2"
  spec.add_runtime_dependency "openssl"

  spec.add_development_dependency "bundler", "~> 2.1.4"
  spec.add_development_dependency "dox-best-practices"
  spec.add_development_dependency "dox-style"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "sdoc"
end
