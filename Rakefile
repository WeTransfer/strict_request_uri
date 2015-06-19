# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require_relative 'lib/strict_request_uri'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  gem.version = StrictRequestUri::VERSION
  gem.name = "strict_request_uri"
  gem.homepage = "https://gitlab.wetransfer.net/julik/strict_request_uri"
  gem.license = "Proprietary"
  gem.description = %Q{Reject Rack requests with an invalid URL}
  gem.summary = %Q{and show an error page instead}
  gem.email = "me@julik.nl"
  gem.authors = ["Julik Tarkhanov"]
  # dependencies defined in Gemfile
end
# Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

desc "Code coverage detail"
task :simplecov do
  ENV['COVERAGE'] = "true"
  Rake::Task['spec'].execute
end

task :default => :spec

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "strict_request_uri #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
