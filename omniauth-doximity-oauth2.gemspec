# coding: utf-8

require File.expand_path("../lib/omniauth-doximity-oauth2/version", __FILE__)

Gem::Specification.new do |spec|
  spec.name          = "omniauth-doximity-oauth2"
  spec.version       = Omniauth::DoximityOauth2::VERSION
  spec.authors       = ["William Harvey"]
  spec.email         = ["wharvey@doximity.com"]
  spec.description   = %q(OmniAuth strategy for Doximity, supporting OIDC, and using PKCE)
  spec.summary       = %q(OmniAuth strategy for Doximity)
  spec.homepage      = "https://github.com/doximity/omniauth-doximity-oauth2.git"
  spec.license       = "Apache-2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/doximity/omniauth-doximity-oauth2/blob/master/CHANGELOG.md"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "activesupport", "< 7"
  spec.add_runtime_dependency "faraday"
  spec.add_runtime_dependency "jwt"
  spec.add_runtime_dependency "multi_json"
  spec.add_runtime_dependency "omniauth-oauth2"
  spec.add_runtime_dependency "openssl"

  spec.add_development_dependency "bundler", "~> 2.3.12"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "sdoc"
end
