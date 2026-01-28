# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class UrlParserTest < Minitest::Test
  def test_parses_full_repo_url
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/maquina-app/rails-upgrade-skill"
    )

    assert_equal "maquina-app", result.username
    assert_equal "rails-upgrade-skill", result.repo
    assert_equal "main", result.branch
    assert_nil result.relative_path
    assert_equal :repo, result.type
    assert_equal "maquina-app/rails-upgrade-skill", result.label
  end

  def test_parses_folder_url
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/nateberkopec/dotfiles/tree/main/files/home/.claude/skills/deep-research"
    )

    assert_equal "nateberkopec", result.username
    assert_equal "dotfiles", result.repo
    assert_equal "main", result.branch
    assert_equal "files/home/.claude/skills/deep-research", result.relative_path
    assert_equal :folder, result.type
    assert_equal "nateberkopec/dotfiles/deep-research", result.label
  end

  def test_parses_file_url
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/lucianghinda/agentic-skills/blob/main/skills/improving-testing/SKILL.md"
    )

    assert_equal "lucianghinda", result.username
    assert_equal "agentic-skills", result.repo
    assert_equal "main", result.branch
    assert_equal "skills/improving-testing/SKILL.md", result.relative_path
    assert_equal :file, result.type
    assert_equal "improving-testing", result.skill_name
    assert_equal "lucianghinda/agentic-skills/improving-testing", result.label
  end

  def test_raises_on_invalid_url
    assert_raises(AgentsSkillVault::Errors::InvalidUrl) do
      AgentsSkillVault::UrlParser.parse("not-a-github-url")
    end
  end

  def test_raises_on_non_github_url
    assert_raises(AgentsSkillVault::Errors::InvalidUrl) do
      AgentsSkillVault::UrlParser.parse("https://gitlab.com/user/repo")
    end
  end

  def test_parse_http_url
    result = AgentsSkillVault::UrlParser.parse(
      "http://github.com/maquina-app/rails-upgrade-skill"
    )

    assert_equal "maquina-app", result.username
    assert_equal "rails-upgrade-skill", result.repo
    assert_equal "main", result.branch
    assert_equal :repo, result.type
    assert_equal "maquina-app/rails-upgrade-skill", result.label
  end

  def test_parse_repo_with_custom_branch
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/maquina-app/rails-upgrade-skill/tree/develop"
    )

    assert_equal "maquina-app", result.username
    assert_equal "rails-upgrade-skill", result.repo
    assert_equal "develop", result.branch
    assert_nil result.relative_path
    assert_equal :repo, result.type
  end

  def test_parse_folder_without_subfolder
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/user/repo/tree/main/folder"
    )

    assert_equal "user", result.username
    assert_equal "repo", result.repo
    assert_equal "main", result.branch
    assert_equal "folder", result.relative_path
    assert_equal :folder, result.type
    assert_equal "user/repo/folder", result.label
  end

  def test_parse_nested_folder
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/user/repo/tree/main/nested/folder/path"
    )

    assert_equal "user", result.username
    assert_equal "repo", result.repo
    assert_equal "main", result.branch
    assert_equal "nested/folder/path", result.relative_path
    assert_equal :folder, result.type
    assert_equal "user/repo/path", result.label
  end

  def test_parse_file_in_subfolder
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/user/repo/blob/develop/docs/README.md"
    )

    assert_equal "user", result.username
    assert_equal "repo", result.repo
    assert_equal "develop", result.branch
    assert_equal "docs/README.md", result.relative_path
    assert_equal :file, result.type
    assert_equal "user/repo/README.md", result.label
  end

  def test_parse_url_with_dash_in_name
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/my-user/my-repo"
    )

    assert_equal "my-user", result.username
    assert_equal "my-repo", result.repo
    assert_equal "my-user/my-repo", result.label
  end

  def test_parse_url_with_dot_in_name
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/my.user/my.repo"
    )

    assert_equal "my.user", result.username
    assert_equal "my.repo", result.repo
    assert_equal "my.user/my.repo", result.label
  end

  def test_parse_url_with_underscore_in_name
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/my_user/my_repo"
    )

    assert_equal "my_user", result.username
    assert_equal "my_repo", result.repo
    assert_equal "my_user/my_repo", result.label
  end

  def test_parse_url_with_trailing_slash
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/user/repo/"
    )

    assert_equal "user", result.username
    assert_equal "repo", result.repo
    assert_equal "main", result.branch
    assert_equal :repo, result.type
  end

  def test_parse_url_with_query_string
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/user/repo?tab=readme"
    )

    assert_equal "user", result.username
    assert_equal "repo", result.repo
    assert_equal "main", result.branch
    assert_equal :repo, result.type
  end

  def test_parse_url_with_fragment
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/user/repo#readme"
    )

    assert_equal "user", result.username
    assert_equal "repo", result.repo
    assert_equal "main", result.branch
    assert_equal :repo, result.type
  end

  def test_parse_url_with_encoded_path
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/user/repo/tree/main/folder%20name/file%20name.md"
    )

    assert_equal "user", result.username
    assert_equal "repo", result.repo
    assert_equal "main", result.branch
    assert_equal "folder name/file name.md", result.relative_path
    assert_equal :folder, result.type
  end

  def test_parses_skill_file_url
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/lucianghinda/agentic-skills/blob/main/skills/improving-testing/SKILL.md"
    )

    assert_equal "lucianghinda", result.username
    assert_equal "agentic-skills", result.repo
    assert_equal "main", result.branch
    assert_equal "skills/improving-testing/SKILL.md", result.relative_path
    assert_equal :file, result.type
    assert_equal "improving-testing", result.skill_name
    assert_equal "skills/improving-testing", result.skill_folder_path
    assert result.is_skill_file?
    assert_equal "lucianghinda/agentic-skills/improving-testing", result.label
  end

  def test_parses_non_skill_file_url
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/user/repo/blob/main/docs/README.md"
    )

    assert_equal "user", result.username
    assert_equal "repo", result.repo
    assert_equal "main", result.branch
    assert_equal "docs/README.md", result.relative_path
    assert_equal :file, result.type
    assert_nil result.skill_name
    assert_nil result.skill_folder_path
    refute result.is_skill_file?
    assert_equal "user/repo/README.md", result.label
  end

  def test_parses_nested_skill_file
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/user/repo/blob/main/deep/nested/skills/test-skill/SKILL.md"
    )

    assert_equal "user", result.username
    assert_equal "repo", result.repo
    assert_equal "main", result.branch
    assert_equal "deep/nested/skills/test-skill/SKILL.md", result.relative_path
    assert_equal :file, result.type
    assert_equal "test-skill", result.skill_name
    assert_equal "deep/nested/skills/test-skill", result.skill_folder_path
    assert result.is_skill_file?
    assert_equal "user/repo/test-skill", result.label
  end

  def test_parses_skill_file_at_root
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/user/repo/blob/main/SKILL.md"
    )

    assert_equal "user", result.username
    assert_equal "repo", result.repo
    assert_equal "main", result.branch
    assert_equal "SKILL.md", result.relative_path
    assert_equal :file, result.type
    # At root, parent folder is the repo name
    assert_equal "repo", result.skill_name
    assert_equal ".", result.skill_folder_path
    assert result.is_skill_file?
    assert_equal "user/repo/repo", result.label
  end

  def test_parses_skill_file_with_custom_branch
    result = AgentsSkillVault::UrlParser.parse(
      "https://github.com/user/repo/blob/develop/skills/my-skill/SKILL.md"
    )

    assert_equal "user", result.username
    assert_equal "repo", result.repo
    assert_equal "develop", result.branch
    assert_equal "skills/my-skill/SKILL.md", result.relative_path
    assert_equal "my-skill", result.skill_name
    assert_equal "skills/my-skill", result.skill_folder_path
    assert result.is_skill_file?
    assert_equal "user/repo/my-skill", result.label
  end
end
