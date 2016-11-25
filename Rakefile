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
  gem.homepage = "https://github.com/WeTransfer/strict_request_uri"
  gem.license = "MIT"
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

namespace :fury do
  desc "Pick up the .gem file from pkg/ and push it to Gemfury"
  task :release do
    # IMPORTANT: You need to have the `fury` gem installed, and you need to be logged in.
    # Please DO READ about "impersonation", which is how you push to your company account instead
    # of your personal account!
    # https://gemfury.com/help/collaboration#impersonation
    paths = Dir.glob(__dir__ + '/pkg/*.gem')
    if paths.length != 1
      raise "Must have found only 1 .gem path, but found %s" % paths.inspect
    end
    escaped_gem_path = Shellwords.escape(paths.shift)
    `fury push #{escaped_gem_path} --as=wetransfer`
  end
end
task :release => [:clean, 'gemspec:generate', 'git:release', :build, 'fury:release']
