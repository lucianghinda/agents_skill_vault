# frozen_string_literal: true

require "fileutils"
require "pathname"

module AgentsSkillVault
  # Main interface for managing a vault of GitHub resources.
  #
  # A Vault stores cloned repositories and folders from GitHub in a local directory,
  # tracking them via a manifest file. Resources can be synced, queried, and managed.
  #
  # @example Create a vault and add resources
  #   vault = AgentsSkillVault::Vault.new(storage_path: "~/.skills")
  #   vault.add("https://github.com/user/repo")
  #   vault.add("https://github.com/user/repo/tree/main/skills/my-skill", label: "my-skill")
  #
  # @example Query and sync resources
  #   vault.filter_by_username("user")  # => [Resource, ...]
  #   vault.fetch("user/repo")          # => Resource (raises if not found)
  #   vault.sync("user/repo")           # => SyncResult
  #
  class Vault
    # @return [String] The absolute path to the vault's storage directory
    attr_reader :storage_path

    # @return [Manifest] The manifest managing resource metadata
    attr_reader :manifest

    # Creates a new Vault instance.
    #
    # @param storage_path [String] Path to the directory where resources will be stored
    # @param manifest_file [String] Name of the manifest file (default: "manifest.json")
    # @raise [Errors::GitNotInstalled] if git is not installed
    # @raise [Errors::GitVersion] if git version is below 2.25.0
    #
    # @example
    #   vault = Vault.new(storage_path: "/path/to/vault")
    #
    def initialize(storage_path:, manifest_file: "manifest.json")
      @storage_path = File.expand_path(storage_path)
      FileUtils.mkdir_p(@storage_path)
      @manifest_path = File.join(@storage_path, manifest_file)
      @manifest = Manifest.new(path: @manifest_path)
      @manifest.save(default_manifest_data) unless File.exist?(@manifest_path)

      GitOperations.check_git_available!
      GitOperations.check_git_version!

      # Auto-validate unvalidated resources if manifest exists
      validate_all if File.exist?(@manifest_path) && !list_unvalidated.empty?
    end

    # Adds a new resource from a GitHub URL.
    #
    # Clones the repository or performs a sparse checkout for folders/files,
    # validates skills if present, then adds the resource to the manifest.
    #
    # For repositories, scans for all SKILL.md files and creates separate entries for each.
    # For folders and files, validates if they contain a SKILL.md.
    #
    # @param url [String] GitHub URL (repository, folder, or file)
    # @param label [String, nil] Custom label for the resource; auto-generated if nil
    # @return [Resource, Array<Resource>] The newly created resource(s)
    # @raise [Errors::InvalidUrl] if URL is not a valid GitHub URL
    # @raise [Errors::DuplicateLabel] if a resource with the same label already exists
    #
    # @example Add a full repository with skills
    #   resources = vault.add("https://github.com/user/repo")
    #
    # @example Add a specific folder with skill
    #   resource = vault.add("https://github.com/user/repo/tree/main/skills/my-skill")
    #
    # @example Add a SKILL.md file
    #   resource = vault.add("https://github.com/user/repo/blob/main/skills/my-skill/SKILL.md")
    #
    def add(url, label: nil)
      parsed_url = UrlParser.parse(url)

      case parsed_url.type
      when :repo
        add_repository_resource(parsed_url, label: label)
      when :folder
        add_folder_resource(parsed_url, label: label)
      when :file
        add_file_resource(parsed_url, label: label)
      else
        raise Errors::InvalidUrl, "Unknown URL type: #{parsed_url.type}"
      end
    end

    # Lists all resources in the vault.
    #
    # @return [Array<Resource>] All resources currently tracked in the manifest
    #
    # @example
    #   vault.list.each { |r| puts r.label }
    #
    def list
      manifest.resources.map { |r| Resource.from_h(r, storage_path: storage_path) }
    end

    # Filters resources by GitHub username.
    #
    # @param username [String] The GitHub username to filter by
    # @return [Array<Resource>] Resources owned by the specified user
    #
    # @example
    #   vault.filter_by_username("octocat")
    #   # => [Resource(label: "octocat/repo1"), Resource(label: "octocat/repo2")]
    #
    def filter_by_username(username)
      list.select { |r| r.username == username }
    end

    # Filters resources by repository name.
    #
    # @param repo_name [String] The repository name to filter by
    # @return [Array<Resource>] Resources from repositories with the specified name
    #
    # @example
    #   vault.filter_by_repo("dotfiles")
    #
    def filter_by_repo(repo_name)
      list.select { |r| r.repo == repo_name }
    end

    # Lists all valid skills.
    #
    # @return [Array<Resource>] Resources with validation_status == :valid_skill
    #
    def list_valid_skills
      list.select { |r| r.validation_status == :valid_skill }
    end

    # Lists all invalid skills.
    #
    # @return [Array<Resource>] Resources with validation_status == :invalid_skill
    #
    def list_invalid_skills
      list.select { |r| r.validation_status == :invalid_skill }
    end

    # Lists all non-skill resources.
    #
    # @return [Array<Resource>] Resources with validation_status == :not_a_skill
    #
    def list_non_skills
      list.select { |r| r.validation_status == :not_a_skill }
    end

    # Lists all unvalidated resources.
    #
    # @return [Array<Resource>] Resources with validation_status == :unvalidated
    #
    def list_unvalidated
      list.select { |r| r.validation_status == :unvalidated }
    end

    # Filters resources by skill name.
    #
    # @param name [String] The skill name to filter by
    # @return [Array<Resource>] Resources matching the skill name
    #
    def filter_by_skill_name(name)
      list.select { |r| r.skill_name == name }
    end

    # Finds a resource by its label without raising an error.
    #
    # @param label [String] The unique label of the resource
    # @return [Resource, nil] The resource if found, nil otherwise
    #
    # @example
    #   resource = vault.find_by_label("user/repo")
    #   puts resource&.local_path
    #
    def find_by_label(label)
      manifest.find_resource(label)
    end

    # Retrieves a resource by its label, raising an error if not found.
    #
    # @param label [String] The unique label of the resource
    # @return [Resource] The resource with the specified label
    # @raise [Errors::NotFound] if no resource with the label exists
    #
    # @example
    #   resource = vault.fetch("user/repo")
    #   puts resource.local_path
    #
    def fetch(label)
      find_by_label(label) || raise(Errors::NotFound, "Resource '#{label}' not found in vault at #{storage_path}. " \
                                                   "Available labels: #{list.map(&:label).join(", ").then do |s|
                                                     s.empty? ? "(none)" : s
                                                   end}")
    end

    # Syncs a resource by pulling the latest changes from GitHub.
    #
    # For repository-type resources, re-scans for new skills and re-validates existing ones.
    # For folder and file-type resources, re-validates the skill if present.
    #
    # @param label [String] The label of the resource to sync
    # @return [SyncResult] Result indicating success/failure and whether changes occurred
    # @raise [Errors::NotFound] if the resource doesn't exist
    #
    # @example
    #   result = vault.sync("user/repo")
    #   puts "Synced successfully" if result.success?
    #
    def sync(label)
      resource = fetch(label)
      sync_resource(resource)
    end

    # Syncs all resources in the vault.
    #
    # @return [Hash{String => SyncResult}] Map of resource labels to their sync results
    #
    # @example
    #   results = vault.sync_all
    #   results.each do |label, result|
    #     puts "#{label}: #{result.success? ? 'OK' : result.error}"
    #   end
    #
    def sync_all
      results = {}
      list.each do |resource|
        results[resource.label] = sync_resource(resource)
      end
      results
    end

    # Removes a resource from the vault.
    #
    # @param label [String] The label of the resource to remove
    # @param delete_files [Boolean] Whether to also delete the local files (default: false)
    # @raise [Errors::NotFound] if the resource doesn't exist
    #
    # @example Remove from manifest only (keep files)
    #   vault.remove("user/repo")
    #
    # @example Remove from manifest and delete files
    #   vault.remove("user/repo", delete_files: true)
    #
    def remove(label, delete_files: false)
      resource = fetch(label)

      FileUtils.rm_rf(resource.local_path) if delete_files && resource.local_path

      manifest.remove_resource(label)
    end

    # Validates a specific resource.
    #
    # Re-validates the skill file and updates the validation status.
    #
    # @param label [String] The label of the resource to validate
    # @return [Resource] The updated resource
    # @raise [Errors::NotFound] if the resource doesn't exist
    #
    def validate_resource(label)
      resource = fetch(label)

      if resource.is_skill
        skill_file = File.join(resource.local_path, "SKILL.md")
        result = SkillValidator.validate(skill_file)

        updated_resource = Resource.from_h(
          resource.to_h.merge(
            validation_status: result[:valid] ? :valid_skill : :invalid_skill,
            validation_errors: result[:errors]
          ),
          storage_path: storage_path
        )
      else
        updated_resource = Resource.from_h(
          resource.to_h.merge(validation_status: :not_a_skill),
          storage_path: storage_path
        )
      end

      manifest.update_resource(updated_resource)
      updated_resource
    end

    # Validates all resources in the vault.
    #
    # Re-validates all resources and updates their validation status.
    #
    # @return [Hash] Summary of validation results
    #   - :valid [Integer] Count of valid skills
    #   - :invalid [Integer] Count of invalid skills
    #   - :not_a_skill [Integer] Count of non-skill resources
    #   - :unvalidated [Integer] Count of resources that couldn't be validated
    #
    def validate_all
      results = { valid: 0, invalid: 0, not_a_skill: 0, unvalidated: 0 }

      list.each do |resource|
        validate_resource(resource.label)

        case resource.validation_status
        when :valid_skill
          results[:valid] += 1
        when :invalid_skill
          results[:invalid] += 1
        when :not_a_skill
          results[:not_a_skill] += 1
        else
          results[:unvalidated] += 1
        end
      end

      results
    end

    # Removes all invalid skills from the vault.
    #
    # Deletes local files and removes from manifest for all resources with
    # validation_status == :invalid_skill.
    #
    # @return [Integer] Number of skills removed
    #
    def cleanup_invalid_skills
      invalid_resources = list_invalid_skills

      invalid_resources.each do |resource|
        FileUtils.rm_rf(resource.local_path) if resource.local_path
        manifest.remove_resource(resource.label)
      end

      invalid_resources.size
    end

    # Re-downloads all resources from scratch.
    #
    # Deletes local files and performs a fresh clone/checkout for each resource.
    # Useful for recovering from corruption or ensuring a clean state.
    #
    # @return [void]
    #
    def redownload_all
      list.each do |resource|
        FileUtils.rm_rf(resource.local_path) if resource.local_path
        download_resource(resource)
        updated_resource = Resource.from_h(resource.to_h.merge(synced_at: Time.now), storage_path: storage_path)
        manifest.update_resource(updated_resource)
      end
    end

    # Exports the manifest to a file for backup or sharing.
    #
    # @param export_path [String] Path where the manifest should be exported
    # @return [void]
    #
    # @example
    #   vault.export_manifest("/backups/manifest.json")
    #
    def export_manifest(export_path)
      FileUtils.cp(@manifest_path, export_path)
    end

    # Imports and merges a manifest from another vault.
    #
    # Resources from the imported manifest are merged with existing resources.
    # If a label exists in both, the imported resource overwrites the existing one.
    # Note: This only updates the manifest; files are not downloaded automatically.
    #
    # @param import_path [String] Path to the manifest file to import
    # @return [void]
    #
    # @example
    #   vault.import_manifest("/shared/manifest.json")
    #   vault.redownload_all  # Download the imported resources
    #
    def import_manifest(import_path)
      imported_data = JSON.parse(File.read(import_path), symbolize_names: true)
      current_data = manifest.load

      merged_resources = merge_resources(current_data[:resources] || [], imported_data[:resources] || [])

      manifest.save(version: Manifest::VERSION, resources: merged_resources)
    end

    private

    def default_manifest_data
      { version: Manifest::VERSION, resources: [] }
    end

    # Adds a repository resource, scanning for all skills.
    #
    # @param parsed_url [UrlParser::ParseResult] Parsed URL
    # @param label [String, nil] Custom label
    # @return [Array<Resource>] Created resources (one per skill found)
    #
    def add_repository_resource(parsed_url, label:)
      target_path = File.join(storage_path, parsed_url.username, parsed_url.repo)
      FileUtils.mkdir_p(File.dirname(target_path))

      repo_url = "https://github.com/#{parsed_url.username}/#{parsed_url.repo}"
      GitOperations.clone_repo(repo_url, target_path, branch: parsed_url.branch)

      skills = SkillScanner.scan_directory(target_path)

      if skills.empty?
        # No skills found, create single resource for repo
        resource = create_resource(parsed_url, label: label || parsed_url.label)
        resource = Resource.from_h(
          resource.to_h.merge(
            validation_status: :not_a_skill,
            is_skill: false
          ),
          storage_path: storage_path
        )
        manifest.add_resource(resource)
        return [resource]
      end

      # Create resource for each skill found
      skills.map do |skill|
        skill_label = label ? "#{label}-#{skill[:skill_name]}" : "#{parsed_url.username}/#{parsed_url.repo}/#{skill[:skill_name]}"

        resource = Resource.new(
          label: skill_label,
          url: repo_url,
          username: parsed_url.username,
          repo: parsed_url.repo,
          folder: skill[:folder_path],
          type: :repo,
          branch: parsed_url.branch,
          relative_path: skill[:folder_path],
          storage_path: storage_path,
          validation_status: :unvalidated,
          validation_errors: [],
          skill_name: skill[:skill_name],
          is_skill: true
        )

        skill_file = File.join(target_path, skill[:folder_path], "SKILL.md")
        result = SkillValidator.validate(skill_file)

        resource = Resource.from_h(
          resource.to_h.merge(
            validation_status: result[:valid] ? :valid_skill : :invalid_skill,
            validation_errors: result[:errors]
          ),
          storage_path: storage_path
        )

        manifest.add_resource(resource)
        resource
      end
    end

    # Adds a folder resource.
    #
    # @param parsed_url [UrlParser::ParseResult] Parsed URL
    # @param label [String, nil] Custom label
    # @return [Resource] Created resource
    #
    def add_folder_resource(parsed_url, label:)
      repo_path = File.join(storage_path, parsed_url.username, parsed_url.repo)
      target_path = File.join(repo_path, parsed_url.relative_path)
      FileUtils.mkdir_p(repo_path)

      repo_url = "https://github.com/#{parsed_url.username}/#{parsed_url.repo}"
      paths = [parsed_url.relative_path]
      GitOperations.sparse_checkout(repo_url, repo_path, branch: parsed_url.branch, paths: paths)

      skills = SkillScanner.scan_directory(target_path)

      if skills.empty?
        skill_name = File.basename(parsed_url.relative_path)
        resource_label = label || "#{parsed_url.username}/#{parsed_url.repo}/#{skill_name}"

        resource = Resource.new(
          label: resource_label,
          url: repo_url,
          username: parsed_url.username,
          repo: parsed_url.repo,
          folder: parsed_url.relative_path,
          type: :folder,
          branch: parsed_url.branch,
          relative_path: parsed_url.relative_path,
          storage_path: storage_path,
          validation_status: :not_a_skill,
          validation_errors: [],
          skill_name: nil,
          is_skill: false
        )

        manifest.add_resource(resource)
        resource
      elsif skills.length == 1
        skill = skills.first
        skill_name = skill[:skill_name]
        resource_label = label || "#{parsed_url.username}/#{parsed_url.repo}/#{skill_name}"

        skill_relative_path = if skill[:relative_path] == "."
                                parsed_url.relative_path
                              else
                                File.join(
                                  parsed_url.relative_path, skill[:relative_path]
                                )
                              end

        resource = Resource.new(
          label: resource_label,
          url: repo_url,
          username: parsed_url.username,
          repo: parsed_url.repo,
          folder: parsed_url.relative_path,
          type: :folder,
          branch: parsed_url.branch,
          relative_path: skill_relative_path,
          storage_path: storage_path,
          skill_name: skill_name,
          is_skill: true
        )

        skill_file = File.join(target_path, skill[:relative_path], "SKILL.md")
        result = SkillValidator.validate(skill_file)

        resource = Resource.from_h(
          resource.to_h.merge(
            validation_status: result[:valid] ? :valid_skill : :invalid_skill,
            validation_errors: result[:errors]
          ),
          storage_path: storage_path
        )

        manifest.add_resource(resource)
        resource
      else
        skills.map do |skill|
          skill_name = skill[:skill_name]
          skill_label = label ? "#{label}/#{skill_name}" : "#{parsed_url.username}/#{parsed_url.repo}/#{skill_name}"

          skill_relative_path = if skill[:relative_path] == "."
                                  parsed_url.relative_path
                                else
                                  File.join(
                                    parsed_url.relative_path, skill[:relative_path]
                                  )
                                end

          resource = Resource.new(
            label: skill_label,
            url: repo_url,
            username: parsed_url.username,
            repo: parsed_url.repo,
            folder: parsed_url.relative_path,
            type: :folder,
            branch: parsed_url.branch,
            relative_path: skill_relative_path,
            storage_path: storage_path,
            skill_name: skill_name,
            is_skill: true
          )

          skill_file = File.join(target_path, skill[:relative_path], "SKILL.md")
          result = SkillValidator.validate(skill_file)

          resource = Resource.from_h(
            resource.to_h.merge(
              validation_status: result[:valid] ? :valid_skill : :invalid_skill,
              validation_errors: result[:errors]
            ),
            storage_path: storage_path
          )

          manifest.add_resource(resource)
          resource
        end
      end
    end

    # Adds a file resource.
    #
    # @param parsed_url [UrlParser::ParseResult] Parsed URL
    # @param label [String, nil] Custom label
    # @return [Resource] Created resource
    #
    def add_file_resource(parsed_url, label:)
      repo_url = "https://github.com/#{parsed_url.username}/#{parsed_url.repo}"

      if parsed_url.is_skill_file?
        # This is a SKILL.md file, download the parent folder
        repo_path = File.join(storage_path, parsed_url.username, parsed_url.repo)
        target_path = File.join(repo_path, parsed_url.skill_folder_path)
        FileUtils.mkdir_p(repo_path)

        paths = [parsed_url.skill_folder_path]
        GitOperations.sparse_checkout(repo_url, repo_path, branch: parsed_url.branch, paths: paths)

        skill_file = File.join(target_path, "SKILL.md")
        result = SkillValidator.validate(skill_file)

        resource_label = label || "#{parsed_url.username}/#{parsed_url.repo}/#{parsed_url.skill_name}"
        resource = Resource.new(
          label: resource_label,
          url: repo_url,
          username: parsed_url.username,
          repo: parsed_url.repo,
          folder: parsed_url.skill_folder_path,
          type: :file,
          branch: parsed_url.branch,
          relative_path: parsed_url.skill_folder_path,
          storage_path: storage_path,
          validation_status: result[:valid] ? :valid_skill : :invalid_skill,
          validation_errors: result[:errors],
          skill_name: parsed_url.skill_name,
          is_skill: true
        )

        manifest.add_resource(resource)
        resource
      else
        # Non-SKILL.md file, download the parent folder
        parent_path = File.dirname(parsed_url.relative_path)
        repo_path = File.join(storage_path, parsed_url.username, parsed_url.repo)
        FileUtils.mkdir_p(repo_path)

        paths = [parent_path]
        GitOperations.sparse_checkout(repo_url, repo_path, branch: parsed_url.branch, paths: paths)

        resource = Resource.new(
          label: label || parsed_url.label,
          url: parsed_url.url,
          username: parsed_url.username,
          repo: parsed_url.repo,
          folder: parent_path,
          type: :file,
          branch: parsed_url.branch,
          relative_path: parsed_url.relative_path,
          storage_path: storage_path,
          validation_status: :not_a_skill,
          validation_errors: [],
          skill_name: nil,
          is_skill: false
        )

        manifest.add_resource(resource)
        resource
      end
    end

    def create_resource(parsed_url, label:)
      label ||= parsed_url.label

      Resource.new(
        label: label,
        url: "https://github.com/#{parsed_url.username}/#{parsed_url.repo}",
        username: parsed_url.username,
        repo: parsed_url.repo,
        folder: parsed_url.type == :repo ? nil : File.basename(parsed_url.relative_path || ""),
        type: parsed_url.type,
        branch: parsed_url.branch,
        relative_path: parsed_url.relative_path,
        storage_path: storage_path
      )
    end

    def download_resource(resource)
      target_path = resource.local_path
      parent_dir = File.dirname(target_path)
      FileUtils.mkdir_p(parent_dir)

      if resource.type == :repo
        GitOperations.clone_repo(resource.url, target_path, branch: resource.branch)
      else
        paths = [resource.relative_path]
        GitOperations.sparse_checkout(resource.url, target_path, branch: resource.branch, paths: paths)
      end
    end

    def sync_resource(resource)
      return SyncResult.new(success: false, error: "Resource has no local path") unless resource.local_path

      unless Dir.exist?(resource.local_path)
        return SyncResult.new(success: false,
                              error: "Path does not exist: #{resource.local_path}")
      end

      GitOperations.pull(resource.local_path)

      # For repo type resources, re-scan for skills and re-validate
      if resource.type == :repo
        sync_repository_resource(resource)
      else
        # For folder/file type resources, just re-validate
        validate_resource(resource.label)
      end

      # Update synced_at for all resources from this repo
      repo_resources = list.select { |r| r.repo == resource.repo && r.username == resource.username }
      repo_resources.each do |r|
        updated = Resource.from_h(r.to_h.merge(synced_at: Time.now), storage_path: storage_path)
        manifest.update_resource(updated)
      end

      SyncResult.new(success: true, changes: true)
    rescue Errors::Error => e
      SyncResult.new(success: false, error: e.message)
    end

    # Syncs a repository-type resource, re-scanning for skills.
    #
    # @param resource [Resource] The resource to sync
    #
    def sync_repository_resource(resource)
      skills = SkillScanner.scan_directory(resource.local_path)

      # Get existing skills for this repo
      existing_resources = list.select do |r|
        r.repo == resource.repo && r.username == resource.username && r.type == :repo
      end

      # Process each found skill
      skills.each do |skill|
        skill_label = "#{resource.username}/#{resource.repo}/#{skill[:skill_name]}"
        existing = existing_resources.find { |r| r.skill_name == skill[:skill_name] }

        if existing
          # Re-validate existing skill
          skill_file = File.join(resource.local_path, skill[:folder_path], "SKILL.md")
          result = SkillValidator.validate(skill_file)

          updated = Resource.from_h(
            existing.to_h.merge(
              validation_status: result[:valid] ? :valid_skill : :invalid_skill,
              validation_errors: result[:errors]
            ),
            storage_path: storage_path
          )
          manifest.update_resource(updated)
        else
          # Add new skill
          new_resource = Resource.new(
            label: skill_label,
            url: resource.url,
            username: resource.username,
            repo: resource.repo,
            folder: skill[:folder_path],
            type: :repo,
            branch: resource.branch,
            relative_path: skill[:folder_path],
            storage_path: storage_path,
            validation_status: :unvalidated,
            validation_errors: [],
            skill_name: skill[:skill_name],
            is_skill: true
          )

          skill_file = File.join(resource.local_path, skill[:folder_path], "SKILL.md")
          result = SkillValidator.validate(skill_file)

          new_resource = Resource.from_h(
            new_resource.to_h.merge(
              validation_status: result[:valid] ? :valid_skill : :invalid_skill,
              validation_errors: result[:errors]
            ),
            storage_path: storage_path
          )

          manifest.add_resource(new_resource)
        end
      end
    end

    def merge_resources(current_resources, imported_resources)
      merged = current_resources.dup

      imported_resources.each do |imported|
        existing_index = merged.find_index { |r| r[:label] == imported[:label] }

        if existing_index
          merged[existing_index] = imported
        else
          merged << imported
        end
      end

      merged
    end
  end
end
