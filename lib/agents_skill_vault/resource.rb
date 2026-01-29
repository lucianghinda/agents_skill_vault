# frozen_string_literal: true

require "time"

module AgentsSkillVault
  # Represents a GitHub resource tracked in the vault.
  #
  # A Resource can be a full repository, a folder within a repository,
  # or a single file. It tracks metadata like the source URL, local path,
  # and sync timestamps.
  #
  # @example Create a repository resource
  #   resource = Resource.new(
  #     label: "user/repo",
  #     url: "https://github.com/user/repo",
  #     username: "user",
  #     repo: "repo",
  #     type: :repo,
  #     storage_path: "/path/to/vault"
  #   )
  #
  class Resource
    # @return [String] Unique identifier for this resource in the vault
    attr_reader :label

    # @return [String] GitHub URL of the repository
    attr_reader :url

    # @return [String] GitHub username/organization that owns the repository
    attr_reader :username

    # @return [String] Name of the repository
    attr_reader :repo

    # @return [String, nil] Folder name for folder/file resources
    attr_reader :folder

    # @return [Symbol] Type of resource (:repo, :folder, or :file)
    attr_reader :type

    # @return [String] Git branch name
    attr_reader :branch

    # @return [String, nil] Path relative to repository root (for folder/file resources)
    attr_reader :relative_path

    # @return [Time] When the resource was added to the vault
    attr_reader :added_at

    # @return [Time] When the resource was last synced
    attr_reader :synced_at

    # @return [String, nil] Base path where resources are stored
    attr_reader :storage_path

    # @return [Symbol] Validation status (:valid_skill, :invalid_skill, :not_a_skill, :unvalidated)
    attr_reader :validation_status

    # @return [Array<String>] Validation errors (for invalid skills)
    attr_reader :validation_errors

    # @return [String, nil] The name of the skill (nil for non-skill resources)
    attr_reader :skill_name

    # @return [Boolean] Whether this resource is a skill
    attr_reader :is_skill

    # Creates a new Resource instance.
    #
    # @param label [String] Unique identifier for this resource
    # @param url [String] GitHub URL of the repository
    # @param username [String] GitHub username/organization
    # @param repo [String] Repository name
    # @param type [Symbol] Resource type (:repo, :folder, or :file)
    # @param storage_path [String, nil] Base path for local storage
    # @param folder [String, nil] Folder name for non-repo resources
    # @param branch [String, nil] Git branch (defaults to "main")
    # @param relative_path [String, nil] Path relative to repository root
    # @param added_at [Time, nil] When added (defaults to now)
    # @param synced_at [Time, nil] When last synced (defaults to now)
    # @param validation_attrs [Hash] Validation-related attributes
    # @option validation_attrs [Symbol] :validation_status Validation status (default: :unvalidated)
    # @option validation_attrs [Array] :validation_errors Validation errors (default: [])
    # @option validation_attrs [String] :skill_name The name of the skill (default: nil)
    # @option validation_attrs [Boolean] :is_skill Whether this is a skill (default: derived from skill_name)
    #
    def initialize(label:, url:, username:, repo:, type:, storage_path:, folder: nil, branch: nil,
                   relative_path: nil, added_at: nil, synced_at: nil, **validation_attrs)
      @label = label
      @url = url
      @username = username
      @repo = repo
      @folder = folder
      @type = type
      @branch = branch || "main"
      @relative_path = relative_path
      @added_at = added_at || Time.now
      @synced_at = synced_at || Time.now
      @storage_path = storage_path
      @validation_status = validation_attrs.fetch(:validation_status, :unvalidated)
      @validation_errors = validation_attrs.fetch(:validation_errors, [])
      @skill_name = validation_attrs[:skill_name]
      @is_skill = validation_attrs.fetch(:is_skill, !@skill_name.nil?)
    end

    # Returns the local filesystem path where the resource is stored.
    #
    # @return [String, nil] Absolute path to the resource, or nil if no storage_path
    #
    # @example
    #   resource.local_path
    #   # => "/path/to/vault/user/repo"
    #
    def local_path
      return nil unless storage_path

      if type == :repo
        File.join(storage_path, username, repo)
      else
        File.join(storage_path, username, repo, relative_path || folder || "")
      end
    end

    # Converts the resource to a hash for serialization.
    #
    # @return [Hash] Resource attributes as a hash
    #
    def to_h
      {
        label: label,
        url: url,
        username: username,
        repo: repo,
        folder: folder,
        type: type,
        branch: branch,
        relative_path: relative_path,
        added_at: added_at.iso8601,
        synced_at: synced_at.iso8601,
        validation_status: validation_status,
        validation_errors: validation_errors,
        skill_name: skill_name,
        is_skill: is_skill
      }
    end

    # Compares two resources for equality.
    #
    # Two resources are equal if they have the same label, URL, username,
    # repo, folder, type, branch, and relative_path.
    #
    # @param other [Object] The object to compare with
    # @return [Boolean] true if resources are equal
    #
    def ==(other)
      return false unless other.is_a?(Resource)

      equality_attributes.all? { |attr| public_send(attr) == other.public_send(attr) }
    end

    # Returns list of attributes used for equality comparison.
    #
    # @return [Array<Symbol>] Attribute names to compare
    #
    def equality_attributes
      %i[label url username repo folder type branch relative_path
         validation_status validation_errors skill_name is_skill]
    end

    # Creates a Resource from a hash.
    #
    # Supports both symbol and string keys for compatibility with
    # different JSON parsing options.
    #
    # @param hash [Hash] Resource attributes as a hash
    # @param storage_path [String, nil] Base path for local storage
    # @return [Resource] A new Resource instance
    #
    # @example
    #   Resource.from_h({ label: "user/repo", ... }, storage_path: "/vault")
    #
    def self.from_h(hash, storage_path: nil)
      new(**extract_core_attrs(hash), **extract_validation_attrs(hash), storage_path:)
    end

    # Extracts core resource attributes from a hash.
    #
    # @param hash [Hash] Resource attributes as a hash
    # @return [Hash] Core attributes with proper defaults
    #
    private_class_method def self.extract_core_attrs(hash)
      {
        label: hash[:label] || hash["label"],
        url: hash[:url] || hash["url"],
        username: hash[:username] || hash["username"],
        repo: hash[:repo] || hash["repo"],
        folder: hash[:folder] || hash["folder"],
        type: (hash[:type] || hash["type"]).to_sym,
        branch: hash[:branch] || hash["branch"],
        relative_path: extract_relative_path(hash),
        added_at: parse_time(hash[:added_at] || hash["added_at"]),
        synced_at: parse_time(hash[:synced_at] || hash["synced_at"])
      }
    end

    # Extracts relative path with backward compatibility.
    #
    # @param hash [Hash] Resource attributes
    # @return [String, nil] Relative path
    #
    private_class_method def self.extract_relative_path(hash)
      hash[:relative_path] || hash["relative_path"] || hash["path_in_repo"] || hash["path_in_repo"]
    end

    # Extracts validation-related attributes from a hash with backward compatibility.
    #
    # @param hash [Hash] Resource attributes as a hash
    # @return [Hash] Validation attributes with proper defaults
    #
    private_class_method def self.extract_validation_attrs(hash)
      validation_status = hash[:validation_status] || hash["validation_status"] || :unvalidated
      validation_status = validation_status.to_sym if validation_status.is_a?(String)

      is_skill = hash[:is_skill] || hash["is_skill"]
      skill_name = hash[:skill_name] || hash["skill_name"]
      is_skill ||= !skill_name.nil?

      validation_errors = hash[:validation_errors] || hash["validation_errors"] || []

      { validation_status:, skill_name:, is_skill:, validation_errors: }
    end

    # Parses a time value from various formats.
    #
    # @param time_value [String, Time, nil] The time value to parse
    # @return [Time, nil] Parsed Time object, or nil if input was nil
    # @raise [ArgumentError] if time_value is not a valid type
    #
    def self.parse_time(time_value)
      case time_value
      when nil
        nil
      when String
        Time.iso8601(time_value)
      when Time
        time_value
      else
        raise ArgumentError, "Invalid time value: #{time_value.inspect}"
      end
    end
  end
end
