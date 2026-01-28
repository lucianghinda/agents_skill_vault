# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class ResourceTest < Minitest::Test
  def setup
    @storage_path = Dir.mktmpdir("resource_test")
  end

  def teardown
    FileUtils.rm_rf(@storage_path)
  end

  def test_initializes_with_all_attributes
    resource = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      branch: "main",
      storage_path: @storage_path
    )

    assert_equal "user/repo", resource.label
    assert_equal "https://github.com/user/repo", resource.url
    assert_equal "user", resource.username
    assert_equal "repo", resource.repo
    assert_equal :repo, resource.type
    assert_equal "main", resource.branch
  end

  def test_local_path_for_repo_type
    resource = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      storage_path: @storage_path
    )

    expected_path = File.join(@storage_path, "user", "repo")
    assert_equal expected_path, resource.local_path
  end

  def test_local_path_for_folder_type
    resource = AgentsSkillVault::Resource.new(
      label: "user/folder",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      folder: "folder",
      type: :folder,
      storage_path: @storage_path
    )

    expected_path = File.join(@storage_path, "user", "repo", "folder")
    assert_equal expected_path, resource.local_path
  end

  def test_to_h
    resource = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      branch: "main",
      storage_path: @storage_path
    )

    hash = resource.to_h

    assert_equal "user/repo", hash[:label]
    assert_equal "https://github.com/user/repo", hash[:url]
    assert_equal "user", hash[:username]
    assert_equal "repo", hash[:repo]
    assert_equal :repo, hash[:type]
    assert_equal "main", hash[:branch]
    assert_kind_of String, hash[:added_at]
    assert_kind_of String, hash[:synced_at]
  end

  def test_equality
    resource1 = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      storage_path: @storage_path
    )

    resource2 = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      storage_path: @storage_path
    )

    resource3 = AgentsSkillVault::Resource.new(
      label: "user/other",
      url: "https://github.com/user/other",
      username: "user",
      repo: "other",
      type: :repo,
      storage_path: @storage_path
    )

    assert_equal resource1, resource2
    refute_equal resource1, resource3
  end

  def test_from_h
    hash = {
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      branch: "main",
      added_at: "2024-01-15T10:30:00Z",
      synced_at: "2024-01-15T10:30:00Z"
    }

    resource = AgentsSkillVault::Resource.from_h(hash, storage_path: @storage_path)

    assert_equal "user/repo", resource.label
    assert_equal "https://github.com/user/repo", resource.url
    assert_equal "user", resource.username
    assert_equal "repo", resource.repo
    assert_equal :repo, resource.type
    assert_equal "main", resource.branch
  end

  def test_from_h_with_string_keys
    hash = {
      "label" => "user/repo",
      "url" => "https://github.com/user/repo",
      "username" => "user",
      "repo" => "repo",
      "type" => "repo",
      "branch" => "main",
      "added_at" => "2024-01-15T10:30:00Z",
      "synced_at" => "2024-01-15T10:30:00Z"
    }

    resource = AgentsSkillVault::Resource.from_h(hash, storage_path: @storage_path)

    assert_equal "user/repo", resource.label
    assert_equal "user", resource.username
  end

  def test_parse_time_with_string
    time_string = "2024-01-15T10:30:00Z"
    result = AgentsSkillVault::Resource.parse_time(time_string)

    assert_kind_of Time, result
    assert_equal "2024-01-15 10:30:00 UTC", result.strftime("%Y-%m-%d %H:%M:%S %Z")
  end

  def test_parse_time_with_time
    time = Time.now
    result = AgentsSkillVault::Resource.parse_time(time)

    assert_equal time, result
  end

  def test_parse_time_with_nil
    result = AgentsSkillVault::Resource.parse_time(nil)

    assert_nil result
  end

  def test_parse_time_with_invalid_type
    error = assert_raises(ArgumentError) do
      AgentsSkillVault::Resource.parse_time(12_345)
    end
    assert_match(/Invalid time value/, error.message)
  end

  def test_local_path_returns_nil_without_storage_path
    resource = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      storage_path: nil
    )

    assert_nil resource.local_path
  end

  def test_local_path_for_folder_with_nil_folder
    resource = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :folder,
      storage_path: @storage_path,
      folder: nil
    )

    expected_path = File.join(@storage_path, "user", "repo", "")
    assert_equal expected_path, resource.local_path
  end

  def test_equality_with_non_resource
    resource = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      storage_path: @storage_path
    )

    refute_equal resource, "not a resource"
    refute_equal resource, { label: "user/repo" }
  end

  def test_initializes_with_custom_branch
    custom_branch = "develop"
    resource = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      branch: custom_branch,
      storage_path: @storage_path
    )

    assert_equal custom_branch, resource.branch
  end

  def test_initializes_defaults_branch_to_main
    resource = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      storage_path: @storage_path
    )

    assert_equal "main", resource.branch
  end

  def test_to_h_serializes_times
    resource = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      storage_path: @storage_path
    )

    hash = resource.to_h

    assert_kind_of String, hash[:added_at]
    assert_kind_of String, hash[:synced_at]
    assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})/, hash[:added_at])
    assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})/, hash[:synced_at])
  end
end
