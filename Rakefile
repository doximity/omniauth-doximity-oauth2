# frozen_string_literal: true

require File.join("bundler", "gem_tasks")
require File.join("rspec", "core", "rake_task")

FileList["tasks/*.rake"].each { |task| load task }

RSpec::Core::RakeTask.new(:spec)

task default: :spec
