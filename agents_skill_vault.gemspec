# frozen_string_literal: true

require_relative "lib/agents_skill_vault/version"

Gem::Specification.new do |spec|
  spec.name = "agents_skill_vault"
  spec.version = AgentsSkillVault::VERSION
  spec.authors = ["Lucian Ghinda"]
  spec.email = ["lucian@shortruby.com"]

  spec.summary = "A Ruby gem for managing AI agent skills from GitHub repositories."
  spec.description = "AgentsSkillVault provides a simple interface to clone, " \
                     "sync, and manage AI agent skills stored in GitHub repositories, " \
                     "supporting full repos, folders, and individual files."
  spec.homepage = "https://github.com/lucianghinda/agents_skill_vault"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/lucianghinda/agents_skill_vault/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "addressable", "~> 2.8"
  spec.add_dependency "zeitwerk", "~> 2.6"

  spec.add_development_dependency "mocha", "~> 2.0"
end
