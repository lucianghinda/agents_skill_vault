# frozen_string_literal: true

module AgentsSkillVault
  class Vault
    # Module for manifest operations in vault.
    #
    module ManifestOperations
      # Exports manifest to a file for backup or sharing.
      #
      # @param export_path [String] Path where manifest should be exported
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
      # Resources from imported manifest are merged with existing resources.
      # If a label exists in both, imported resource overwrites existing one.
      # Note: This only updates manifest; files are not downloaded automatically.
      #
      # @param import_path [String] Path to manifest file to import
      # @return [void]
      #
      # @example
      #   vault.import_manifest("/shared/manifest.json")
      #   vault.redownload_all  # Download imported resources
      #
      def import_manifest(import_path)
        imported_data = JSON.parse(File.read(import_path), symbolize_names: true)
        current_data = manifest.load

        merged_resources = merge_resources(current_data[:resources] || [], imported_data[:resources] || [])

        manifest.save(version: Manifest::VERSION, resources: merged_resources)
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

      private

      # Merges current and imported resources.
      #
      # @param current_resources [Array<Hash>] Current resource hashes
      # @param imported_resources [Array<Hash>] Imported resource hashes
      # @return [Array<Hash>] Merged resources
      #
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
end
