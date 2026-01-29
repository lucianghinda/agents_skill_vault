# frozen_string_literal: true

require "json"

module AgentsSkillVault
  # Manages the JSON manifest file that tracks all resources in a vault.
  #
  # The manifest stores metadata about each resource including labels, URLs,
  # and sync timestamps. It persists to disk as a JSON file.
  #
  # @example
  #   manifest = Manifest.new(path: "/vault/manifest.json")
  #   manifest.add_resource(resource)
  #   manifest.find_resource("user/repo")
  #
  class Manifest
    # Current manifest file format version
    VERSION = "1.0"

    # @return [String] Absolute path to the manifest JSON file
    attr_reader :path

    # Creates a new Manifest instance.
    #
    # @param path [String] Path to the manifest JSON file
    #
    def initialize(path:)
      @path = path
    end

    # Loads the manifest data from disk.
    #
    # @return [Hash] The manifest data with :version and :resources keys
    #
    def load
      return default_manifest unless File.exist?(path)

      JSON.parse(File.read(path), symbolize_names: true)
    end

    # Saves manifest data to disk.
    #
    # @param data [Hash] The manifest data to save
    # @return [void]
    #
    def save(data)
      File.write(path, JSON.pretty_generate(data))
    end

    # Returns all resource hashes from the manifest.
    #
    # @return [Array<Hash>] Array of resource attribute hashes
    #
    def resources
      load[:resources] || []
    end

    # Adds a new resource to the manifest.
    #
    # @param resource [Resource] The resource to add
    # @raise [Errors::DuplicateLabel] if a resource with the same label exists
    # @return [void]
    #
    def add_resource(resource)
      data = load
      data[:resources] ||= []

      if data[:resources].any? { |r| r[:label] == resource.label }
        raise Errors::DuplicateLabel, "Resource with label '#{resource.label}' already exists. " \
                                      "Use a custom label with: add(url, label: 'custom-label')"
      end

      data[:resources] << resource.to_h
      save(data)
    end

    # Removes a resource from the manifest by label.
    #
    # Does nothing if the label doesn't exist (no error raised).
    #
    # @param label [String] The label of the resource to remove
    # @return [void]
    #
    def remove_resource(label)
      data = load
      data[:resources]&.reject! { |r| r[:label] == label }
      save(data)
    end

    # Updates an existing resource in the manifest.
    #
    # @param resource [Resource] The resource with updated attributes
    # @return [Boolean] true if the resource was found and updated, false otherwise
    #
    def update_resource(resource) # rubocop:disable Naming/PredicateMethod
      data = load
      data[:resources] ||= []
      index = data[:resources].find_index { |r| r[:label] == resource.label }

      return false unless index

      data[:resources][index] = resource.to_h
      save(data)
      true
    end

    # Finds a resource by its label.
    #
    # @param label [String] The label to search for
    # @param storage_path [String, nil] Storage path to set on the returned Resource
    # @return [Resource, nil] The resource if found, nil otherwise
    #
    def find_resource(label, storage_path: nil)
      hash = resources.find { |r| r[:label] == label }
      return nil unless hash

      Resource.from_h(hash, storage_path: storage_path || storage_path_from_manifest)
    end

    # Clears all resources from the manifest.
    #
    # @return [void]
    #
    def clear
      save(default_manifest)
    end

    private

    def default_manifest
      { version: VERSION, resources: [] }
    end

    def storage_path_from_manifest
      File.dirname(path)
    end
  end
end
