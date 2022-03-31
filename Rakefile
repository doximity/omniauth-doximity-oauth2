# frozen_string_literal: true

require File.join("bundler", "gem_tasks")
require File.join("rspec", "core", "rake_task")
require "sdoc"

FileList["tasks/*.rake"].each { |task| load task }

RSpec::Core::RakeTask.new(:spec)

task default: :spec

RDoc::Task.new do |rdoc|
  rdoc.main = "README.md"
  rdoc.markup = "tomdoc"
  rdoc.options << "--format=sdoc"
  rdoc.options << "--github --encoding=UTF-8"
  rdoc.rdoc_dir = "doc"
  rdoc.rdoc_files.exclude("vendor", "tmp")
  rdoc.rdoc_files.include("README.md", "lib", "*.rb")
  rdoc.template = "rails"
  rdoc.title = "omniauth-doximity Documentation"
end
