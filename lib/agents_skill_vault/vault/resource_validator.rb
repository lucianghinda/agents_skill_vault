# frozen_string_literal: true

module AgentsSkillVault
  class Vault
    # Module for validating resources in vault.
    #
    module ResourceValidator
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

        updated_resource = if resource.is_skill
                             validate_skill_resource(resource)
                           else
                             Resource.from_h(
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

      private

      # Validates a skill resource.
      #
      # @param resource [Resource] Skill resource to validate
      # @return [Resource] Updated resource
      #
      def validate_skill_resource(resource)
        skill_file = File.join(resource.local_path, "SKILL.md")
        result = SkillValidator.validate(skill_file)

        Resource.from_h(
          resource.to_h.merge(
            validation_status: result[:valid] ? :valid_skill : :invalid_skill,
            validation_errors: result[:errors]
          ),
          storage_path: storage_path
        )
      end
    end
  end
end
