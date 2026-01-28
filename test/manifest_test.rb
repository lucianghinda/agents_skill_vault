# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class ManifestTest < Minitest::Test
  def setup
    @manifest_path = File.join(Dir.mktmpdir("manifest_test"), "manifest.json")
    @manifest = AgentsSkillVault::Manifest.new(path: @manifest_path)
  end

  def teardown
    FileUtils.rm_rf(File.dirname(@manifest_path))
  end

  def test_loads_default_manifest_when_file_missing
    data = @manifest.load

    assert_equal "1.0", data[:version]
    assert_equal [], data[:resources]
  end

  def test_saves_and_loads_manifest
    resource_hash = {
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      branch: "main",
      added_at: Time.now.iso8601,
      synced_at: Time.now.iso8601
    }

    @manifest.save(version: "1.0", resources: [resource_hash])
    loaded = @manifest.load

    assert_equal "1.0", loaded[:version]
    assert_equal 1, loaded[:resources].length
    assert_equal "user/repo", loaded[:resources].first[:label]
  end

  def test_adds_resource
    storage_path = File.dirname(@manifest_path)
    resource = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      storage_path: storage_path
    )

    @manifest.add_resource(resource)
    loaded = @manifest.load

    assert_equal 1, loaded[:resources].length
    assert_equal "user/repo", loaded[:resources].first[:label]
  end

  def test_raises_on_duplicate_label
    storage_path = File.dirname(@manifest_path)
    resource1 = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      storage_path: storage_path
    )

    resource2 = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/other",
      username: "user",
      repo: "other",
      type: :repo,
      storage_path: storage_path
    )

    @manifest.add_resource(resource1)

    assert_raises(AgentsSkillVault::Errors::DuplicateLabel) do
      @manifest.add_resource(resource2)
    end
  end

  def test_removes_resource
    storage_path = File.dirname(@manifest_path)
    resource = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      storage_path: storage_path
    )

    @manifest.add_resource(resource)
    @manifest.remove_resource("user/repo")
    loaded = @manifest.load

    assert_equal [], loaded[:resources]
  end

  def test_updates_resource
    storage_path = File.dirname(@manifest_path)
    resource1 = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      storage_path: storage_path
    )

    resource2 = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      branch: "develop",
      storage_path: storage_path
    )

    @manifest.add_resource(resource1)
    result = @manifest.update_resource(resource2)

    assert result
    loaded = @manifest.load
    assert_equal "develop", loaded[:resources].first[:branch]
  end

  def test_finds_resource
    storage_path = File.dirname(@manifest_path)
    resource = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      storage_path: storage_path
    )

    @manifest.add_resource(resource)
    found = @manifest.find_resource("user/repo", storage_path: storage_path)

    assert_kind_of AgentsSkillVault::Resource, found
    assert_equal "user/repo", found.label
  end

  def test_finds_resource_returns_nil_when_not_found
    storage_path = File.dirname(@manifest_path)
    found = @manifest.find_resource("nonexistent", storage_path: storage_path)

    assert_nil found
  end

  def test_clear
    storage_path = File.dirname(@manifest_path)
    resource = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      storage_path: storage_path
    )

    @manifest.add_resource(resource)
    @manifest.clear
    loaded = @manifest.load

    assert_equal [], loaded[:resources]
  end

  def test_resources_returns_empty_when_no_resources
    assert_equal [], @manifest.resources
  end

  def test_resources_returns_all_resources
    storage_path = File.dirname(@manifest_path)
    resource1 = AgentsSkillVault::Resource.new(
      label: "user/repo1",
      url: "https://github.com/user/repo1",
      username: "user",
      repo: "repo1",
      type: :repo,
      storage_path: storage_path
    )

    resource2 = AgentsSkillVault::Resource.new(
      label: "user/repo2",
      url: "https://github.com/user/repo2",
      username: "user",
      repo: "repo2",
      type: :repo,
      storage_path: storage_path
    )

    @manifest.add_resource(resource1)
    @manifest.add_resource(resource2)

    resources = @manifest.resources
    assert_equal 2, resources.length
    assert_equal "user/repo1", resources.first[:label]
    assert_equal "user/repo2", resources.last[:label]
  end

  def test_handles_corrupted_json_file
    File.write(@manifest_path, "invalid json {{{")

    assert_raises(JSON::ParserError) do
      @manifest.load
    end
  end

  def test_loads_existing_manifest_file
    storage_path = File.dirname(@manifest_path)
    resource = AgentsSkillVault::Resource.new(
      label: "user/repo",
      url: "https://github.com/user/repo",
      username: "user",
      repo: "repo",
      type: :repo,
      storage_path: storage_path
    )

    @manifest.add_resource(resource)

    new_manifest = AgentsSkillVault::Manifest.new(path: @manifest_path)
    loaded = new_manifest.load

    assert_equal 1, loaded[:resources].length
    assert_equal "user/repo", loaded[:resources].first[:label]
  end

  def test_save_creates_file
    data = { version: "1.0", resources: [] }
    @manifest.save(data)

    assert File.exist?(@manifest_path)
  end

  def test_remove_resource_does_not_fail_on_nonexistent_label
    assert_silent do
      @manifest.remove_resource("nonexistent")
    end

    loaded = @manifest.load
    assert_equal [], loaded[:resources]
  end
end
