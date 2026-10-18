# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# CI exercises the minimum Tool API as well as the current tested minor release.
gem "ruby_llm", ENV.fetch("RUBY_LLM_VERSION", ">= 2.0"), "< 3"

group :development, :test do
  gem "activejob", ENV.fetch("RAILS_VERSION", "~> 8.1.0")
  gem "activerecord", ENV.fetch("RAILS_VERSION", "~> 8.1.0")
  gem "bundler-audit", "~> 0.9", require: false
  gem "railties", ENV.fetch("RAILS_VERSION", "~> 8.1.0"), require: false
  gem "rake", "~> 13.0"
  gem "rspec", "~> 3.13"
  gem "rubocop", "~> 1.70", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rubocop-rspec", require: false
  gem "sqlite3", ">= 2.0"
  gem "webmock", "~> 3.26"
end
