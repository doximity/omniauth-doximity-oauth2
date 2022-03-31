# frozen_string_literal: true

namespace :ci do
  desc "Run tests"
  task :specs do
    sh "bundle exec rspec --color spec --format progress"
  end

  desc "Run rubocop"
  task :rubocop do
    sh "bundle exec rubocop --display-cop-names --extra-details --display-style-guide"
  end

  desc "Build documentation"
  task doc: :rdoc
end
