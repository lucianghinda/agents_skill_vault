# AgentsSkillVault

A Ruby gem for managing a local vault of GitHub resources that contains Agent Skill specifications. 
Clone entire repositories or specific folders, keep them synced, and query them by username or repository name.

Currently works only with Github. Future plans will include to support any Git based repository. 

## Overview

AgentsSkillVault helps you maintain a local collection of GitHub resources (repositories, folders, or files) with:

- **Easy addition** - Add resources via GitHub URL
- **Sparse checkout** - Clone only the folders you need, not entire repos
- **Sync management** - Pull latest changes with one command
- **Querying** - Filter resources by username or repository name
- **Manifest tracking** - All resources tracked in a JSON manifest for portability

## Installation

Add this line to your application's Gemfile:

```ruby
gem "agents_skill_vault"
```

And then execute:

```bash
bundle install
```

Or install it yourself:

```bash
gem install agents_skill_vault
```

**Requirements:**
- Ruby 3.4+
- Git 2.25.0+ (for sparse checkout support)

## Quick Start

```ruby
require "agents_skill_vault"

# Create a vault in a directory
vault = AgentsSkillVault::Vault.new(storage_path: "~/.my_vault")

# Add a full repository
vault.add("https://github.com/rails/rails")

# Add a specific folder with a custom label
vault.add(
  "https://github.com/user/dotfiles/tree/main/.claude/skills/deep-research",
  label: "deep-research"
)

# List all resources
vault.list.each do |resource|
  puts "#{resource.label} -> #{resource.local_path}"
end

# Sync a specific resource
result = vault.sync("rails/rails")
puts "Synced!" if result.success?

# Sync all resources
vault.sync_all
```

## API Reference

### Vault

The main interface for managing resources.

#### Creating a Vault

```ruby
vault = AgentsSkillVault::Vault.new(storage_path: "/path/to/vault")
```

#### Adding Resources

```ruby
# Add a repository (auto-generates label: "username/repo")
vault.add("https://github.com/user/repo")

# Add with custom label
vault.add("https://github.com/user/repo", label: "my-custom-label")

# Add a specific folder (uses sparse checkout)
vault.add("https://github.com/user/repo/tree/main/lib/skills")

# Add a specific file
vault.add("https://github.com/user/repo/blob/main/config.yml")
```

#### Querying Resources

```ruby
# List all resources
resources = vault.list

# Find by label (returns nil if not found)
resource = vault.find_by_label("user/repo")

# Fetch by label (raises Errors::NotFound if not found)
resource = vault.fetch("user/repo")

# Filter by GitHub username
vault.filter_by_username("octocat")  # => [Resource, ...]

# Filter by repository name
vault.filter_by_repo("dotfiles")  # => [Resource, ...]
```

#### Syncing Resources

```ruby
# Sync a single resource
result = vault.sync("user/repo")
if result.success?
  puts "Changes: #{result.changes?}"
else
  puts "Error: #{result.error}"
end

# Sync all resources
results = vault.sync_all
results.each do |label, result|
  status = result.success? ? "OK" : result.error
  puts "#{label}: #{status}"
end
```

#### Removing Resources

```ruby
# Remove from manifest only (keep files on disk)
vault.remove("user/repo")

# Remove from manifest AND delete files
vault.remove("user/repo", delete_files: true)
```

#### Backup and Restore

```ruby
# Export manifest for backup
vault.export_manifest("/backups/manifest.json")

# Import manifest (merges with existing resources)
vault.import_manifest("/shared/manifest.json")

# Re-download all resources from scratch
vault.redownload_all
```

### Resource

Represents a tracked GitHub resource.

```ruby
resource = vault.fetch("user/repo")

resource.label          # => "user/repo"
resource.url            # => "https://github.com/user/repo"
resource.username       # => "user"
resource.repo           # => "repo"
resource.type           # => :repo, :folder, or :file
resource.branch         # => "main"
resource.local_path     # => "/vault/user/repo"
resource.relative_path  # => nil (or path within repo for folders/files)
resource.added_at       # => Time
resource.synced_at      # => Time
```

### SyncResult

Returned by sync operations.

```ruby
result = vault.sync("user/repo")

result.success?  # => true/false
result.changes?  # => true/false (did the sync pull new changes?)
result.error     # => nil or error message string
```

### Error Handling

```ruby
begin
  vault.add("invalid-url")
rescue AgentsSkillVault::Errors::InvalidUrl => e
  puts "Bad URL: #{e.message}"
end

begin
  vault.fetch("nonexistent")
rescue AgentsSkillVault::Errors::NotFound => e
  puts "Not found: #{e.message}"
end

begin
  vault.add("https://github.com/user/repo")
  vault.add("https://github.com/other/thing", label: "user/repo")
rescue AgentsSkillVault::Errors::DuplicateLabel => e
  puts "Duplicate: #{e.message}"
end
```

## Common Use Cases

### Managing Claude Code Skills

```ruby
vault = AgentsSkillVault::Vault.new(storage_path: "~/.claude/skill_vault")

# Add skills from various sources
vault.add("https://github.com/anthropics/claude-code/tree/main/skills/web-search")
vault.add("https://github.com/user/my-skills/tree/main/coding-assistant", label: "coding")

# Keep everything up to date
vault.sync_all
```

### Sharing Resource Collections

```ruby
# On machine A: Export your vault configuration
vault.export_manifest("~/Dropbox/vault-manifest.json")

# On machine B: Import and download
new_vault = AgentsSkillVault::Vault.new(storage_path: "~/.vault")
new_vault.import_manifest("~/Dropbox/vault-manifest.json")
new_vault.redownload_all
```

### Selective Repository Checkout

```ruby
# Instead of cloning a huge monorepo, just get the folder you need
vault.add(
  "https://github.com/big-org/monorepo/tree/main/packages/useful-lib",
  label: "useful-lib"
)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests.

```bash
bundle exec rake test
```

You can also run `bin/console` for an interactive prompt.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/lucianghinda/agents_skill_vault.

## License

The gem is available as open source under the terms of the Apache 2.0 License.
