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
    include ResourceAdder
    include ResourceSyncer
    include ResourceValidator
    include ManifestOperations

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
    # @return [Array<Resource>] Resources owned by specified user
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
    # @return [Array<Resource>] Resources matching skill name
    #
    def filter_by_skill_name(name)
      list.select { |r| r.skill_name == name }
    end

    # Finds a resource by its label without raising an error.
    #
    # @param label [String] The unique label of resource
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
    # @param label [String] The unique label of resource
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

    # Removes a resource from vault.
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

    private

    def default_manifest_data
      { version: Manifest::VERSION, resources: [] }
    end
  end
end
