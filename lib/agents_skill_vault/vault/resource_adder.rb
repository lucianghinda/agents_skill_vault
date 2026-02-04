# frozen_string_literal: true

module AgentsSkillVault
  class Vault
    # Module for adding resources to the vault.
    #
    module ResourceAdder
      private

      # Adds a repository resource, scanning for all skills.
      #
      # @param parsed_url [UrlParser::ParseResult] Parsed URL
      # @param label [String, nil] Custom label
      # @return [Array<Resource>] Created resources (one per skill found)
      #
      def add_repository_resource(parsed_url, label:)
        clone_repository(parsed_url)
        skills = SkillScanner.scan_directory(local_repo_path(parsed_url))

        if skills.empty?
          add_non_skill_repo(parsed_url, label:)
        else
          add_skill_repo_resources(parsed_url, skills, label:)
        end
      end

      # Adds a folder resource.
      #
      # @param parsed_url [UrlParser::ParseResult] Parsed URL
      # @param label [String, nil] Custom label
      # @return [Resource, Array<Resource>] Created resource(s)
      #
      def add_folder_resource(parsed_url, label:)
        setup_repo_folder(parsed_url)
        target_path = File.join(local_repo_path(parsed_url), parsed_url.relative_path)
        skills = SkillScanner.scan_directory(target_path)

        case skills.length
        when 0 then add_non_skill_folder(parsed_url, label:)
        when 1 then add_single_skill_folder(parsed_url, skills.first, label:, target_path:)
        else add_multi_skill_folder(parsed_url, skills, label:, target_path:)
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

        if parsed_url.skill_file?
          add_skill_file(parsed_url, repo_url, label:)
        else
          add_non_skill_file(parsed_url, repo_url, label:)
        end
      end

      # Creates a resource from parsed URL with optional label.
      #
      # @param parsed_url [UrlParser::ParseResult] Parsed URL
      # @param label [String, nil] Custom label
      # @return [Resource] Created resource
      #
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

      # Clones a repository to the vault.
      #
      # @param parsed_url [UrlParser::ParseResult] Parsed URL
      # @return [void]
      #
      def clone_repository(parsed_url)
        target_path = local_repo_path(parsed_url)
        FileUtils.mkdir_p(File.dirname(target_path))
        repo_url = "https://github.com/#{parsed_url.username}/#{parsed_url.repo}"
        GitOperations.clone_repo(repo_url, target_path, branch: parsed_url.branch)
      end

      # Adds a non-skill repository resource.
      #
      # @param parsed_url [UrlParser::ParseResult] Parsed URL
      # @param label [String, nil] Custom label
      # @return [Array<Resource>] Created resources
      #
      def add_non_skill_repo(parsed_url, label:)
        resource = create_resource(parsed_url, label: label || parsed_url.label)
        resource = Resource.from_h(
          resource.to_h.merge(
            validation_status: :not_a_skill,
            is_skill: false
          ),
          storage_path: storage_path
        )
        manifest.add_resource(resource)
        [resource]
      end

      # Adds skill resources for a repository.
      #
      # @param parsed_url [UrlParser::ParseResult] Parsed URL
      # @param skills [Array<Hash>] List of skills found
      # @param label [String, nil] Custom label
      # @return [Array<Resource>] Created resources
      #
      def add_skill_repo_resources(parsed_url, skills, label:)
        target_path = local_repo_path(parsed_url)
        repo_url = "https://github.com/#{parsed_url.username}/#{parsed_url.repo}"

        skills.map do |skill|
          skill_label = if label
                          "#{label}-#{skill[:skill_name]}"
                        else
                          "#{parsed_url.username}/#{parsed_url.repo}/#{skill[:skill_name]}"
                        end

          resource = build_skill_resource(
            skill_label, repo_url, parsed_url, skill[:folder_path],
            skill[:folder_path], target_path, skill[:folder_path]
          )

          validate_and_update_resource(resource, skill[:folder_path], target_path)
          manifest.add_resource(resource)
          resource
        end
      end

      # Adds a non-skill folder resource.
      #
      # @param parsed_url [UrlParser::ParseResult] Parsed URL
      # @param label [String, nil] Custom label
      # @return [Resource] Created resource
      #
      def add_non_skill_folder(parsed_url, label:)
        skill_name = File.basename(parsed_url.relative_path)
        resource_label = label || "#{parsed_url.username}/#{parsed_url.repo}/#{skill_name}"
        repo_url = "https://github.com/#{parsed_url.username}/#{parsed_url.repo}"

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
      end

      # Adds a single skill folder resource.
      #
      # @param parsed_url [UrlParser::ParseResult] Parsed URL
      # @param skill [Hash] Skill data
      # @param label [String, nil] Custom label
      # @param target_path [String] Target path for validation
      # @return [Resource] Created resource
      #
      def add_single_skill_folder(parsed_url, skill, label:, target_path:)
        skill_name = skill[:skill_name]
        resource_label = label || "#{parsed_url.username}/#{parsed_url.repo}/#{skill_name}"

        skill_relative_path = if skill[:relative_path] == "."
                                parsed_url.relative_path
                              else
                                File.join(parsed_url.relative_path, skill[:relative_path])
                              end

        repo_url = "https://github.com/#{parsed_url.username}/#{parsed_url.repo}"

        resource = build_skill_resource(
          resource_label, repo_url, parsed_url, parsed_url.relative_path,
          skill_relative_path, target_path, skill[:relative_path]
        )

        validate_and_update_resource(resource, skill[:relative_path], target_path)
        manifest.add_resource(resource)
        resource
      end

      # Adds multiple skill folder resources.
      #
      # @param parsed_url [UrlParser::ParseResult] Parsed URL
      # @param skills [Array<Hash>] List of skills found
      # @param label [String, nil] Custom label
      # @param target_path [String] Target path for validation
      # @return [Array<Resource>] Created resources
      #
      def add_multi_skill_folder(parsed_url, skills, label:, target_path:)
        repo_url = "https://github.com/#{parsed_url.username}/#{parsed_url.repo}"

        skills.map do |skill|
          skill_name = skill[:skill_name]
          skill_label = label ? "#{label}/#{skill_name}" : "#{parsed_url.username}/#{parsed_url.repo}/#{skill_name}"

          skill_relative_path = if skill[:relative_path] == "."
                                  parsed_url.relative_path
                                else
                                  File.join(parsed_url.relative_path, skill[:relative_path])
                                end

          resource = build_skill_resource(
            skill_label, repo_url, parsed_url, parsed_url.relative_path,
            skill_relative_path, target_path, skill[:relative_path]
          )

          validate_and_update_resource(resource, skill[:relative_path], target_path)
          manifest.add_resource(resource)
          resource
        end
      end

      # Adds a skill file resource.
      #
      # @param parsed_url [UrlParser::ParseResult] Parsed URL
      # @param repo_url [String] Repository URL
      # @param label [String, nil] Custom label
      # @return [Resource] Created resource
      #
      def add_skill_file(parsed_url, repo_url, label:)
        setup_skill_file_path(parsed_url)
        target_path = File.join(local_repo_path(parsed_url), parsed_url.skill_folder_path)
        result = SkillValidator.validate(File.join(target_path, "SKILL.md"))

        resource = create_skill_file_resource(parsed_url, repo_url, label, result)
        manifest.add_resource(resource)
        resource
      end

      # Creates a skill file resource.
      #
      # @param parsed_url [UrlParser::ParseResult] Parsed URL
      # @param repo_url [String] Repository URL
      # @param label [String, nil] Custom label
      # @param result [Hash] Validation result
      # @return [Resource] Created resource
      #
      def create_skill_file_resource(parsed_url, repo_url, label, result)
        resource_label = label || "#{parsed_url.username}/#{parsed_url.repo}/#{parsed_url.skill_name}"

        Resource.new(
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
      end

      # Adds a non-skill file resource.
      #
      # @param parsed_url [UrlParser::ParseResult] Parsed URL
      # @param repo_url [String] Repository URL
      # @param label [String, nil] Custom label
      # @return [Resource] Created resource
      #
      def add_non_skill_file(parsed_url, _repo_url, label:)
        parent_path = File.dirname(parsed_url.relative_path)
        setup_non_skill_file_path(parsed_url, parent_path)

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

      # Builds a skill resource from parsed data.
      #
      # @param label [String] Resource label
      # @param repo_url [String] Repository URL
      # @param parsed_url [UrlParser::ParseResult] Parsed URL
      # @param folder [String] Folder path
      # @param relative_path [String] Relative path
      # @param target_path [String] Target path for type detection
      # @param skill_relative_path [String, nil] Relative path for skill
      # @return [Resource] Created resource
      #
      def build_skill_resource(label, repo_url, parsed_url, folder, relative_path, _target_path,
                               skill_relative_path = nil)
        Resource.new(
          label: label,
          url: repo_url,
          username: parsed_url.username,
          repo: parsed_url.repo,
          folder: folder,
          type: parsed_url.type,
          branch: parsed_url.branch,
          relative_path: relative_path,
          storage_path: storage_path,
          skill_name: skill_relative_path ? label.split("/").last : nil,
          is_skill: true
        )
      end

      # Validates and updates a resource.
      #
      # @param resource [Resource] Resource to validate
      # @param relative_path [String] Relative path for validation
      # @param target_path [String] Target path
      # @return [Resource] Updated resource
      #
      def validate_and_update_resource(resource, relative_path, target_path)
        skill_file = File.join(target_path, relative_path, "SKILL.md")
        result = SkillValidator.validate(skill_file)

        Resource.from_h(
          resource.to_h.merge(
            validation_status: result[:valid] ? :valid_skill : :invalid_skill,
            validation_errors: result[:errors]
          ),
          storage_path: storage_path
        )
      end

      # Returns the local path for a repository.
      #
      # @param parsed_url [UrlParser::ParseResult] Parsed URL
      # @return [String] Local path
      #
      def local_repo_path(parsed_url)
        File.join(storage_path, parsed_url.username, parsed_url.repo)
      end

      # Sets up repository folder for sparse checkout.
      #
      # @param parsed_url [UrlParser::ParseResult] Parsed URL
      # @return [void]
      #
      def setup_repo_folder(parsed_url)
        repo_path = local_repo_path(parsed_url)
        FileUtils.mkdir_p(repo_path)
        repo_url = "https://github.com/#{parsed_url.username}/#{parsed_url.repo}"
        paths = [parsed_url.relative_path]
        GitOperations.sparse_checkout(repo_url, repo_path, branch: parsed_url.branch, paths: paths)
      end

      # Sets up skill file path for download.
      #
      # @param parsed_url [UrlParser::ParseResult] Parsed URL
      # @return [void]
      #
      def setup_skill_file_path(parsed_url)
        repo_path = local_repo_path(parsed_url)
        FileUtils.mkdir_p(repo_path)
        repo_url = "https://github.com/#{parsed_url.username}/#{parsed_url.repo}"
        paths = [parsed_url.skill_folder_path]
        GitOperations.sparse_checkout(repo_url, repo_path, branch: parsed_url.branch, paths: paths)
      end

      # Sets up non-skill file path for download.
      #
      # @param parsed_url [UrlParser::ParseResult] Parsed URL
      # @param parent_path [String] Parent path
      # @return [void]
      #
      def setup_non_skill_file_path(parsed_url, parent_path)
        repo_path = local_repo_path(parsed_url)
        FileUtils.mkdir_p(repo_path)
        repo_url = "https://github.com/#{parsed_url.username}/#{parsed_url.repo}"
        paths = [parent_path]
        GitOperations.sparse_checkout(repo_url, repo_path, branch: parsed_url.branch, paths: paths)
      end
    end
  end
end
