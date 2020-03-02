# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'strict_request_uri/version'

Gem::Specification.new do |s|
  s.name = "strict_request_uri"
  s.version = StrictRequestUri::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Julik Tarkhanov"]
  s.description = "Reject Rack requests with an invalid URL"
  s.email = "me@julik.nl"

  # Prevent pushing this gem to RubyGems.org.
  # To allow pushes either set the 'allowed_push_host'
  # To allow pushing to a single host or delete this section to allow pushing to any host.
  if s.respond_to?(:metadata)
    s.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end
  
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  s.homepage = "https://github.com/WeTransfer/strict_request_uri"
  s.licenses = ["MIT"]
  s.rubygems_version = "2.4.5.1"
  s.summary = "and show an error page instead"

  s.specification_version = 4
  s.add_runtime_dependency 'rack', '1.6.13'
  s.add_development_dependency 'rake', '~> 13'
  s.add_development_dependency 'rspec', '~> 3'
  s.add_development_dependency 'rdoc', '~> 6'
  s.add_development_dependency 'bundler'
  s.add_development_dependency 'simplecov', '>= 0'
end
