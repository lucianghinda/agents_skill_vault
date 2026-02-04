# frozen_string_literal: true

module AgentsSkillVault
  class Vault
    # Module for syncing resources in vault.
    #
    module ResourceSyncer
      private

      # Syncs a resource by pulling latest changes.
      #
      # @param resource [Resource] Resource to sync
      # @return [SyncResult] Sync result
      #
      def sync_resource(resource)
        return SyncResult.new(success: false, error: "Resource has no local path") unless resource.local_path

        unless Dir.exist?(resource.local_path)
          return SyncResult.new(success: false, error: "Path does not exist: #{resource.local_path}")
        end

        sync_by_type(resource)
        update_synced_at(resource)

        SyncResult.new(success: true, changes: true)
      rescue Errors::Error => e
        SyncResult.new(success: false, error: e.message)
      end

      # Syncs a repository-type resource, re-scanning for skills.
      #
      # @param resource [Resource] The resource to sync
      # @return [void]
      #
      def sync_repository_resource(resource)
        skills = SkillScanner.scan_directory(resource.local_path)
        existing_resources = repo_resources(resource)

        skills.each do |skill|
          process_skill_sync(resource, skill, existing_resources)
        end
      end

      # Downloads a resource from GitHub.
      #
      # @param resource [Resource] Resource to download
      # @return [void]
      #
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

      # Syncs resource based on its type.
      #
      # @param resource [Resource] Resource to sync
      # @return [void]
      #
      def sync_by_type(resource)
        GitOperations.pull(resource.local_path)

        if resource.type == :repo
          sync_repository_resource(resource)
        else
          validate_resource(resource.label)
        end
      end

      # Updates synced_at timestamp for all repo resources.
      #
      # @param resource [Resource] Resource to update
      # @return [void]
      #
      def update_synced_at(resource)
        repo_resources = list.select { |r| r.repo == resource.repo && r.username == resource.username }
        repo_resources.each do |r|
          updated = Resource.from_h(r.to_h.merge(synced_at: Time.now), storage_path: storage_path)
          manifest.update_resource(updated)
        end
      end

      # Returns all resources for a repository.
      #
      # @param resource [Resource] Resource to match
      # @return [Array<Resource>] Matching resources
      #
      def repo_resources(resource)
        list.select do |r|
          r.repo == resource.repo && r.username == resource.username && r.type == :repo
        end
      end

      # Processes skill during sync (add or update).
      #
      # @param resource [Resource] Parent resource
      # @param skill [Hash] Skill data
      # @param existing_resources [Array<Resource>] Existing resources
      # @return [void]
      #
      def process_skill_sync(resource, skill, existing_resources)
        skill_label = "#{resource.username}/#{resource.repo}/#{skill[:skill_name]}"
        existing = existing_resources.find { |r| r.skill_name == skill[:skill_name] }
        existing ||= existing_resources.find { |r| r.label == skill_label }

        if existing
          revalidate_existing_skill(resource, existing, skill)
        else
          add_new_skill_from_sync(resource, skill, skill_label)
        end
      end

      # Re-validates an existing skill.
      #
      # @param resource [Resource] Parent resource
      # @param existing [Resource] Existing skill resource
      # @param skill [Hash] Skill data
      # @return [void]
      #
      def revalidate_existing_skill(resource, existing, skill)
        skill_file = File.join(resource.local_path, skill[:folder_path], "SKILL.md")
        result = SkillValidator.validate(skill_file)

        updated = Resource.from_h(
          existing.to_h.merge(
            validation_status: result[:valid] ? :valid_skill : :invalid_skill,
            validation_errors: result[:errors],
            skill_name: existing.skill_name || skill[:skill_name],
            is_skill: true
          ),
          storage_path: storage_path
        )
        manifest.update_resource(updated)
      end

      # Adds a new skill found during sync.
      #
      # @param resource [Resource] Parent resource
      # @param skill [Hash] Skill data
      # @param skill_label [String] Skill label
      # @return [void]
      #
      def add_new_skill_from_sync(resource, skill, skill_label)
        new_resource = create_new_skill_resource(resource, skill, skill_label)
        new_resource = validate_and_update_skill(resource, new_resource, skill)
        manifest.add_resource(new_resource)
      end

      # Creates a new skill resource.
      #
      # @param resource [Resource] Parent resource
      # @param skill [Hash] Skill data
      # @param skill_label [String] Skill label
      # @return [Resource] Created resource
      #
      def create_new_skill_resource(resource, skill, skill_label)
        Resource.new(
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
      end

      # Validates and updates a skill resource.
      #
      # @param resource [Resource] Parent resource
      # @param new_resource [Resource] Skill resource to validate
      # @param skill [Hash] Skill data
      # @return [Resource] Updated resource
      #
      def validate_and_update_skill(resource, new_resource, skill)
        skill_file = File.join(resource.local_path, skill[:folder_path], "SKILL.md")
        result = SkillValidator.validate(skill_file)

        Resource.from_h(
          new_resource.to_h.merge(
            validation_status: result[:valid] ? :valid_skill : :invalid_skill,
            validation_errors: result[:errors]
          ),
          storage_path: storage_path
        )
      end
    end
  end
end
