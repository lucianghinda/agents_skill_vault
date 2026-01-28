# frozen_string_literal: true

require "yaml"

module AgentsSkillVault
  # Validates SKILL.md files against the Agent Skills specification.
  #
  # Checks for required fields, field formats, and constraints.
  #
  # @example Validate a skill file
  #   result = SkillValidator.validate("/path/to/SKILL.md")
  #   if result[:valid]
  #     puts "Valid skill: #{result[:skill_data][:name]}"
  #   else
  #     puts "Errors: #{result[:errors].join(', ')}"
  #   end
  #
  class SkillValidator
    REQUIRED_FIELDS = %w[name description].freeze
    NAME_MAX_LENGTH = 64
    NAME_MIN_LENGTH = 1
    DESCRIPTION_MAX_LENGTH = 1024
    DESCRIPTION_MIN_LENGTH = 1
    COMPATIBILITY_MAX_LENGTH = 500
    NAME_PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

    # Validates a SKILL.md file.
    #
    # @param skill_file_path [String] Path to the SKILL.md file
    # @return [Hash] Validation result with keys:
    #   - :valid [Boolean] Whether the skill is valid
    #   - :errors [Array<String>] List of validation errors
    #   - :skill_data [Hash] Parsed skill data (name, description, license, etc.)
    #
    # @raise [ArgumentError] if skill_file_path is nil or empty
    #
    def self.validate(skill_file_path)
      raise ArgumentError, "skill_file_path cannot be nil" if skill_file_path.nil?
      raise ArgumentError, "skill_file_path cannot be empty" if skill_file_path.empty?

      errors = []

      # Check file exists and is readable
      unless File.exist?(skill_file_path)
        return { valid: false, errors: ["File does not exist: #{skill_file_path}"], skill_data: {} }
      end

      unless File.readable?(skill_file_path)
        return { valid: false, errors: ["File is not readable: #{skill_file_path}"], skill_data: {} }
      end

      content = File.read(skill_file_path)

      # Parse YAML frontmatter
      frontmatter, = extract_frontmatter(content)
      if frontmatter.nil?
        errors << "No YAML frontmatter found (missing '---' delimiters)"
        return { valid: false, errors:, skill_data: {} }
      end

      # Parse YAML
      parsed_data = parse_yaml(frontmatter, errors)
      return { valid: false, errors:, skill_data: {} } if parsed_data.nil?

      # Validate required fields
      validate_required_fields(parsed_data, errors)

      # Validate name field
      validate_name(parsed_data, errors) if parsed_data["name"]

      # Validate description field
      validate_description(parsed_data, errors) if parsed_data["description"]

      # Validate optional fields if present
      validate_optional_fields(parsed_data, errors)

      # Build skill data hash
      skill_data = {
        name: parsed_data["name"],
        description: parsed_data["description"],
        license: parsed_data["license"],
        compatibility: parsed_data["compatibility"],
        metadata: parsed_data["metadata"],
        allowed_tools: parsed_data["allowed-tools"]
      }

      { valid: errors.empty?, errors:, skill_data: }
    end

    # Extracts YAML frontmatter from content.
    #
    # @param content [String] The full content of the file
    # @return [Array<String, String>] Frontmatter and body, or [nil, nil] if not found
    #
    def self.extract_frontmatter(content)
      return [nil, nil] unless content.start_with?("---")

      parts = content.split(/^---\s*$/)
      return [nil, nil] unless parts.length >= 2

      [parts[1].strip, parts[2..]&.join("---")]
    end

    # Parses YAML string.
    #
    # @param yaml_string [String] The YAML string to parse
    # @param errors [Array] Array to append errors to
    # @return [Hash, nil] Parsed data, or nil if parsing fails
    #
    def self.parse_yaml(yaml_string, errors)
      YAML.safe_load(yaml_string)
    rescue Psych::SyntaxError => e
      errors << "Invalid YAML syntax: #{e.message}"
      nil
    end

    # Validates that all required fields are present.
    #
    # @param data [Hash] Parsed YAML data
    # @param errors [Array] Array to append errors to
    #
    def self.validate_required_fields(data, errors)
      REQUIRED_FIELDS.each do |field|
        errors << "Required field '#{field}' is missing" unless data[field]
      end
    end

    # Validates the name field.
    #
    # @param data [Hash] Parsed YAML data
    # @param errors [Array] Array to append errors to
    #
    def self.validate_name(data, errors)
      name = data["name"]

      if name.empty?
        errors << "Field 'name' cannot be empty"
        return
      end

      errors << "Field 'name' exceeds maximum length of #{NAME_MAX_LENGTH} characters" if name.length > NAME_MAX_LENGTH

      errors << "Field 'name' must be at least #{NAME_MIN_LENGTH} character" if name.length < NAME_MIN_LENGTH

      return if name.match?(NAME_PATTERN)

      errors << "Field 'name' must contain only lowercase letters, numbers, and hyphens (no consecutive or leading/trailing hyphens)"
    end

    # Validates the description field.
    #
    # @param data [Hash] Parsed YAML data
    # @param errors [Array] Array to append errors to
    #
    def self.validate_description(data, errors)
      description = data["description"]

      if description.empty?
        errors << "Field 'description' cannot be empty"
        return
      end

      if description.length > DESCRIPTION_MAX_LENGTH
        errors << "Field 'description' exceeds maximum length of #{DESCRIPTION_MAX_LENGTH} characters"
      end

      return unless description.length < DESCRIPTION_MIN_LENGTH

      errors << "Field 'description' must be at least #{DESCRIPTION_MIN_LENGTH} character"
    end

    # Validates optional fields if present.
    #
    # @param data [Hash] Parsed YAML data
    # @param errors [Array] Array to append errors to
    #
    def self.validate_optional_fields(data, errors)
      # Validate compatibility field if present
      if data["compatibility"]
        compatibility = data["compatibility"]
        if compatibility.length > COMPATIBILITY_MAX_LENGTH
          errors << "Field 'compatibility' exceeds maximum length of #{COMPATIBILITY_MAX_LENGTH} characters"
        end
      end

      # Validate metadata field if present
      if data["metadata"]
        metadata = data["metadata"]
        errors << "Field 'metadata' must be a hash/object" unless metadata.is_a?(Hash)
      end

      # Validate allowed-tools field if present
      return unless data["allowed-tools"]

      allowed_tools = data["allowed-tools"]
      return if allowed_tools.is_a?(String)

      errors << "Field 'allowed-tools' must be a string"
    end
  end
end
