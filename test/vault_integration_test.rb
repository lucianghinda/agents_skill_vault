# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class VaultIntegrationTest < Minitest::Test
  def setup
    @storage_path = TestHelper.temp_vault_path
    FileUtils.mkdir_p(@storage_path)
    @vault = AgentsSkillVault::Vault.new(storage_path: @storage_path)
  end

  def teardown
    FileUtils.rm_rf(@storage_path)
  end

  def stub_sparse_checkout_with_structure(url, path, opts = {})
    AgentsSkillVault::GitOperations.stubs(:sparse_checkout).with(url, path, opts) do
      FileUtils.mkdir_p(path)
      yield(path) if block_given?
      true
    end
  end

  def test_add_folder_with_multiple_skills
    url = "https://github.com/lucianghinda/agentic-skills/tree/main/skills"

    stub_sparse_checkout_with_structure(url, File.join(@storage_path, "lucianghinda/agentic-skills/skills"),
                                        branch: "main", paths: ["skills"]) do |target_path|
      FileUtils.mkdir_p(File.join(target_path, "commit-message"))
      FileUtils.mkdir_p(File.join(target_path, "improving-testing"))
      FileUtils.mkdir_p(File.join(target_path, "pr-description"))

      File.write(File.join(target_path, "commit-message/SKILL.md"), "# Commit Message Skill")
      File.write(File.join(target_path, "improving-testing/SKILL.md"), "# Improving Testing Skill")
      File.write(File.join(target_path, "pr-description/SKILL.md"), "# PR Description Skill")
    end

    resources = @vault.add(url)

    assert_equal 3, resources.length

    labels = resources.map(&:label).sort
    expected_labels = [
      "lucianghinda/agentic-skills/commit-message",
      "lucianghinda/agentic-skills/improving-testing",
      "lucianghinda/agentic-skills/pr-description"
    ]
    assert_equal expected_labels, labels

    resources.each do |resource|
      assert_equal true, resource.is_skill
      assert File.directory?(resource.local_path)
      assert File.exist?(File.join(resource.local_path, "SKILL.md"))
    end
  end

  def test_add_specific_skill_folder
    url = "https://github.com/lucianghinda/agentic-skills/tree/main/skills/commit-message"
    expected_path = File.join(@storage_path, "lucianghinda/agentic-skills/skills/commit-message")

    stub_sparse_checkout_with_structure(url, expected_path, branch: "main",
                                                            paths: ["skills/commit-message"]) do |target_path|
      File.write(File.join(target_path, "SKILL.md"), "# Commit Message Skill")
    end

    resource = @vault.add(url)

    assert_equal "lucianghinda/agentic-skills/commit-message", resource.label
    assert_equal true, resource.is_skill
    assert_equal expected_path, resource.local_path
    assert File.exist?(File.join(expected_path, "SKILL.md"))
  end

  def test_add_skill_file_url
    url = "https://github.com/lucianghinda/agentic-skills/blob/main/skills/commit-message/SKILL.md"
    expected_path = File.join(@storage_path, "lucianghinda/agentic-skills/skills/commit-message")

    stub_sparse_checkout_with_structure(url, expected_path, branch: "main",
                                                            paths: ["skills/commit-message"]) do |target_path|
      File.write(File.join(target_path, "SKILL.md"), "# Commit Message Skill")
    end

    resource = @vault.add(url)

    assert_equal "lucianghinda/agentic-skills/commit-message", resource.label
    assert_equal true, resource.is_skill
    assert_equal expected_path, resource.local_path
    assert File.exist?(File.join(expected_path, "SKILL.md"))
  end

  def test_add_deeply_nested_skill_file
    url = "https://github.com/nateberkopec/dotfiles/tree/main/files/home/.claude/skills/skill-creator"
    expected_path = File.join(@storage_path, "nateberkopec/dotfiles/files/home/.claude/skills/skill-creator")

    stub_sparse_checkout_with_structure(url, expected_path, branch: "main",
                                                            paths: ["files/home/.claude/skills/skill-creator"]) do |target_path|
      File.write(File.join(target_path, "SKILL.md"), "# Skill Creator")
      File.write(File.join(target_path, "LICENSE.txt"), "License")
      FileUtils.mkdir_p(File.join(target_path, "scripts"))
      File.write(File.join(target_path, "scripts", "init_skill.py"), "# init")
    end

    resource = @vault.add(url)

    assert_equal "nateberkopec/dotfiles/skill-creator", resource.label
    assert_equal true, resource.is_skill
    assert_equal expected_path, resource.local_path
    assert File.exist?(File.join(expected_path, "SKILL.md"))
    assert File.exist?(File.join(expected_path, "LICENSE.txt"))
  end

  def test_add_folder_with_no_skills
    url = "https://github.com/user/repo/tree/main/docs"
    expected_path = File.join(@storage_path, "user/repo/docs")

    stub_sparse_checkout_with_structure(url, expected_path, branch: "main", paths: ["docs"]) do |target_path|
      File.write(File.join(target_path, "README.md"), "# Documentation")
    end

    resource = @vault.add(url)

    assert_equal "user/repo/docs", resource.label
    assert_equal false, resource.is_skill
    assert_equal expected_path, resource.local_path
  end

  def test_add_folder_with_single_nested_skill
    url = "https://github.com/user/repo/tree/main/skills"
    expected_path = File.join(@storage_path, "user/repo/skills")

    stub_sparse_checkout_with_structure(url, expected_path, branch: "main", paths: ["skills"]) do |target_path|
      FileUtils.mkdir_p(File.join(target_path, "my-skill"))
      File.write(File.join(target_path, "my-skill/SKILL.md"), "# My Skill")
    end

    resource = @vault.add(url)

    assert_equal "user/repo/my-skill", resource.label
    assert_equal true, resource.is_skill
    assert_equal File.join(@storage_path, "user/repo/skills/my-skill"), resource.local_path
  end

  def test_multiple_skills_with_custom_label
    url = "https://github.com/lucianghinda/agentic-skills/tree/main/skills"

    stub_sparse_checkout_with_structure(url, File.join(@storage_path, "lucianghinda/agentic-skills/skills"),
                                        branch: "main", paths: ["skills"]) do |target_path|
      FileUtils.mkdir_p(File.join(target_path, "commit-message"))
      FileUtils.mkdir_p(File.join(target_path, "pr-description"))

      File.write(File.join(target_path, "commit-message/SKILL.md"), "# Commit Message")
      File.write(File.join(target_path, "pr-description/SKILL.md"), "# PR Description")
    end

    resources = @vault.add(url, label: "my-skills")

    labels = resources.map(&:label).sort
    assert_equal ["my-skills/commit-message", "my-skills/pr-description"], labels
  end
end
