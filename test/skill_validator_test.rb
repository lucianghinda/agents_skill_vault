# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class SkillValidatorTest < Minitest::Test
  def setup
    @test_dir = File.join(Dir.tmpdir, "skill_validator_test")
    FileUtils.mkdir_p(@test_dir)
  end

  def teardown
    FileUtils.rm_rf(@test_dir)
  end

  def test_valid_skill_with_all_fields
    skill_content = <<~YAML
      ---
      name: pdf-processing
      description: Extracts text and tables from PDF files, fills PDF forms, and merges multiple PDFs.
      license: Apache-2.0
      compatibility: Designed for Claude Code
      metadata:
        author: example-org
        version: "1.0"
      allowed-tools: Bash(git:*) Read
      ---
      # Instructions here
    YAML

    skill_file = File.join(@test_dir, "SKILL.md")
    File.write(skill_file, skill_content)

    result = AgentsSkillVault::SkillValidator.validate(skill_file)

    assert result[:valid]
    assert_empty result[:errors]
    assert_equal "pdf-processing", result[:skill_data][:name]
    assert_equal "Extracts text and tables from PDF files, fills PDF forms, and merges multiple PDFs.",
                 result[:skill_data][:description]
    assert_equal "Apache-2.0", result[:skill_data][:license]
  end

  def test_valid_skill_minimal
    skill_content = <<~YAML
      ---
      name: data-analysis
      description: A comprehensive skill for analyzing and processing data.
      ---
      # Instructions here
    YAML

    skill_file = File.join(@test_dir, "SKILL.md")
    File.write(skill_file, skill_content)

    result = AgentsSkillVault::SkillValidator.validate(skill_file)

    assert result[:valid]
    assert_empty result[:errors]
  end

  def test_missing_name_field
    skill_content = <<~YAML
      ---
      description: A skill without a name
      ---
      # Instructions
    YAML

    skill_file = File.join(@test_dir, "SKILL.md")
    File.write(skill_file, skill_content)

    result = AgentsSkillVault::SkillValidator.validate(skill_file)

    refute result[:valid]
    assert_includes result[:errors], "Required field 'name' is missing"
  end

  def test_missing_description_field
    skill_content = <<~YAML
      ---
      name: my-skill
      ---
      # Instructions
    YAML

    skill_file = File.join(@test_dir, "SKILL.md")
    File.write(skill_file, skill_content)

    result = AgentsSkillVault::SkillValidator.validate(skill_file)

    refute result[:valid]
    assert_includes result[:errors], "Required field 'description' is missing"
  end

  def test_invalid_name_uppercase
    skill_content = <<~YAML
      ---
      name: PDF-Processing
      description: A skill with uppercase name
      ---
      # Instructions
    YAML

    skill_file = File.join(@test_dir, "SKILL.md")
    File.write(skill_file, skill_content)

    result = AgentsSkillVault::SkillValidator.validate(skill_file)

    refute result[:valid]
    assert_includes result[:errors],
                    "Field 'name' must contain only lowercase letters, numbers, and hyphens (no consecutive or leading/trailing hyphens)"
  end

  def test_invalid_name_leading_hyphen
    skill_content = <<~YAML
      ---
      name: -pdf
      description: A skill with leading hyphen
      ---
      # Instructions
    YAML

    skill_file = File.join(@test_dir, "SKILL.md")
    File.write(skill_file, skill_content)

    result = AgentsSkillVault::SkillValidator.validate(skill_file)

    refute result[:valid]
    assert_includes result[:errors],
                    "Field 'name' must contain only lowercase letters, numbers, and hyphens (no consecutive or leading/trailing hyphens)"
  end

  def test_invalid_name_trailing_hyphen
    skill_content = <<~YAML
      ---
      name: pdf-
      description: A skill with trailing hyphen
      ---
      # Instructions
    YAML

    skill_file = File.join(@test_dir, "SKILL.md")
    File.write(skill_file, skill_content)

    result = AgentsSkillVault::SkillValidator.validate(skill_file)

    refute result[:valid]
    assert_includes result[:errors],
                    "Field 'name' must contain only lowercase letters, numbers, and hyphens (no consecutive or leading/trailing hyphens)"
  end

  def test_invalid_name_consecutive_hyphens
    skill_content = <<~YAML
      ---
      name: pdf--processing
      description: A skill with consecutive hyphens
      ---
      # Instructions
    YAML

    skill_file = File.join(@test_dir, "SKILL.md")
    File.write(skill_file, skill_content)

    result = AgentsSkillVault::SkillValidator.validate(skill_file)

    refute result[:valid]
    assert_includes result[:errors],
                    "Field 'name' must contain only lowercase letters, numbers, and hyphens (no consecutive or leading/trailing hyphens)"
  end

  def test_invalid_name_too_long
    skill_content = <<~YAML
      ---
      name: #{"a" * 65}
      description: A skill with too long name
      ---
      # Instructions
    YAML

    skill_file = File.join(@test_dir, "SKILL.md")
    File.write(skill_file, skill_content)

    result = AgentsSkillVault::SkillValidator.validate(skill_file)

    refute result[:valid]
    assert_includes result[:errors], "Field 'name' exceeds maximum length of 64 characters"
  end

  def test_invalid_name_empty
    skill_content = <<~YAML
      ---
      name: ""
      description: A skill with empty name
      ---
      # Instructions
    YAML

    skill_file = File.join(@test_dir, "SKILL.md")
    File.write(skill_file, skill_content)

    result = AgentsSkillVault::SkillValidator.validate(skill_file)

    refute result[:valid]
    assert_includes result[:errors], "Field 'name' cannot be empty"
  end

  def test_invalid_description_empty
    skill_content = <<~YAML
      ---
      name: my-skill
      description: ""
      ---
      # Instructions
    YAML

    skill_file = File.join(@test_dir, "SKILL.md")
    File.write(skill_file, skill_content)

    result = AgentsSkillVault::SkillValidator.validate(skill_file)

    refute result[:valid]
    assert_includes result[:errors], "Field 'description' cannot be empty"
  end

  def test_invalid_description_too_long
    skill_content = <<~YAML
      ---
      name: my-skill
      description: #{"a" * 1025}
      ---
      # Instructions
    YAML

    skill_file = File.join(@test_dir, "SKILL.md")
    File.write(skill_file, skill_content)

    result = AgentsSkillVault::SkillValidator.validate(skill_file)

    refute result[:valid]
    assert_includes result[:errors], "Field 'description' exceeds maximum length of 1024 characters"
  end

  def test_invalid_compatibility_too_long
    skill_content = <<~YAML
      ---
      name: my-skill
      description: A skill
      compatibility: #{"a" * 501}
      ---
      # Instructions
    YAML

    skill_file = File.join(@test_dir, "SKILL.md")
    File.write(skill_file, skill_content)

    result = AgentsSkillVault::SkillValidator.validate(skill_file)

    refute result[:valid]
    assert_includes result[:errors], "Field 'compatibility' exceeds maximum length of 500 characters"
  end

  def test_no_frontmatter
    skill_content = <<~YAML
      # Just markdown content, no frontmatter
      This is a skill description.
    YAML

    skill_file = File.join(@test_dir, "SKILL.md")
    File.write(skill_file, skill_content)

    result = AgentsSkillVault::SkillValidator.validate(skill_file)

    refute result[:valid]
    assert_includes result[:errors], "No YAML frontmatter found (missing '---' delimiters)"
  end

  def test_file_does_not_exist
    result = AgentsSkillVault::SkillValidator.validate("/nonexistent/SKILL.md")

    refute result[:valid]
    assert(result[:errors].any? { |e| e.include?("File does not exist") })
  end

  def test_multiple_errors_returned
    skill_content = <<~YAML
      ---
      name: Invalid-Name
      description: ""
      ---
      # Instructions
    YAML

    skill_file = File.join(@test_dir, "SKILL.md")
    File.write(skill_file, skill_content)

    result = AgentsSkillVault::SkillValidator.validate(skill_file)

    refute result[:valid]
    assert result[:errors].length >= 2
    assert(result[:errors].any? { |e| e.include?("name") })
    assert(result[:errors].any? { |e| e.include?("description") })
  end

  def test_valid_name_with_numbers
    skill_content = <<~YAML
      ---
      name: skill-123
      description: A skill with numbers
      ---
      # Instructions
    YAML

    skill_file = File.join(@test_dir, "SKILL.md")
    File.write(skill_file, skill_content)

    result = AgentsSkillVault::SkillValidator.validate(skill_file)

    assert result[:valid]
    assert_empty result[:errors]
  end

  def test_valid_single_word_name
    skill_content = <<~YAML
      ---
      name: skill
      description: A skill with single word name
      ---
      # Instructions
    YAML

    skill_file = File.join(@test_dir, "SKILL.md")
    File.write(skill_file, skill_content)

    result = AgentsSkillVault::SkillValidator.validate(skill_file)

    assert result[:valid]
    assert_empty result[:errors]
  end
end
