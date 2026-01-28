#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "agents_skill_vault"
require "fileutils"

# Config
VAULT_PATH = File.expand_path("~/.demo_skill_vault")
AUTO_DELETE = ENV["AUTO_DELETE"] == "true"
URLS = [
  "https://github.com/nateberkopec/dotfiles/tree/main/files/home/.claude/skills",
  "https://github.com/lucianghinda/agentic-skills/skills",
  "https://github.com/thoughtbot/rails-audit-thoughtbot"
].freeze

# Helper methods for output
def section(title)
  puts "\n#{"=" * 70}"
  puts " #{title}"
  puts "=" * 70
end

def print_resource(r)
  status_sym = r.validation_status.to_s.upcase
  status_color = case r.validation_status
                 when :valid_skill then "✓"
                 when :invalid_skill then "✗"
                 when :not_a_skill then "○"
                 else "?"
                 end

  puts "  #{status_color} #{r.label}"
  puts "     Type: #{r.type}, URL: #{r.url}"
  puts "     Local: #{r.local_path}"
  puts "     Skill: #{r.skill_name || "N/A"}"
  puts "     Status: #{status_sym}"
  return unless r.validation_errors.any?

  puts "     Errors: #{r.validation_errors.empty? ? "None" : r.validation_errors.join(", ")}"
end

def print_sync_result(label, result)
  if result.success?
    puts "  ✓ #{label}: Synced successfully"
  else
    puts "  ✗ #{label}: #{result.error}"
  end
end

# # 1. Setup
# section("1. Setup: Create Vault")

# if Dir.exist?(VAULT_PATH)
#   puts "Existing vault found at #{VAULT_PATH}"
#   if AUTO_DELETE
#     puts "Auto mode: Deleting existing vault"
#     FileUtils.rm_rf(VAULT_PATH)
#   else
#     print "Delete and recreate? (y/N): "
#     response = $stdin.gets&.chomp
#     if response && response.downcase == "y"
#       FileUtils.rm_rf(VAULT_PATH)
#       puts "Deleted existing vault"
#     else
#       puts "Using existing vault"
#     end
#   end
# end

vault = AgentsSkillVault::Vault.new(storage_path: VAULT_PATH)
puts "Created vault at: #{vault.storage_path}"

# 2. Add Resources
section("2. Add Resources")

added_resources = {}
URLS.each do |url|
  puts "\nAdding: #{url}"
  result = vault.add(url)
  if result.is_a?(Array)
    puts "  → Added #{result.size} resource(s):"
    result.each do |r|
      print_resource(r)
      added_resources[r.label] = r
    end
  else
    print_resource(result)
    added_resources[result.label] = result
  end
end

# 3. List Resources
section("3. List All Resources")

resources = vault.list
puts "\nTotal resources: #{resources.size}"
resources.each { |r| print_resource(r) }

# 4. Query & Filter
section("4. Query & Filter Resources")

puts "\nFilter by username 'nateberkopec':"
vault.filter_by_username("nateberkopec").each { |r| print_resource(r) }

puts "\nFilter by repo 'dotfiles':"
vault.filter_by_repo("dotfiles").each { |r| print_resource(r) }

puts "\nFilter by skill name (first 5):"
skill_names = resources.map(&:skill_name).compact.uniq.first(5)
skill_names.each do |name|
  results = vault.filter_by_skill_name(name)
  results.each { |r| print_resource(r) }
end

# 5. Validation
section("5. Validation Status")

valid = vault.list_valid_skills
invalid = vault.list_invalid_skills
non_skills = vault.list_non_skills
unvalidated = vault.list_unvalidated

puts "\nValid skills (#{valid.size}):"
valid.each { |r| puts "  ✓ #{r.label}" }

puts "\nInvalid skills (#{invalid.size}):"
invalid.each { |r| puts "  ✗ #{r.label} - #{r.validation_errors.join(", ")}" }

puts "\nNon-skill resources (#{non_skills.size}):"
non_skills.each { |r| puts "  ○ #{r.label}" }

puts "\nUnvalidated resources (#{unvalidated.size}):"
unvalidated.each { |r| puts "  ? #{r.label}" }

# 6. Sync
section("6. Sync Resources")

puts "\nSyncing all resources..."
results = vault.sync_all
results.each { |label, result| print_sync_result(label, result) }

# 7. Remove
section("7. Remove Resource")

if added_resources.any?
  first_label = added_resources.keys.first
  puts "\nRemoving resource: #{first_label}"
  vault.remove(first_label, delete_files: false)
  puts "  Removed from manifest (files kept)"
  puts "\nRemaining resources: #{vault.list.size}"
else
  puts "\nNo resources to remove"
end

# 8. Export
section("8. Export Manifest")

export_path = File.join(Dir.pwd, "demo_manifest.json")
vault.export_manifest(export_path)
puts "Exported manifest to: #{export_path}"

if File.exist?(export_path)
  data = JSON.parse(File.read(export_path))
  puts "\nManifest contents:"
  puts "  Version: #{data["version"]}"
  puts "  Resources: #{data["resources"].size}"
  puts "  Labels: #{data["resources"].map { |r| r["label"] }.join(", ")}"
end

# 9. Cleanup
section("Demo Complete!")
puts "\nYou can paste this script into bin/console or run standalone with:"
puts "  ruby scripts/demo.rb"
