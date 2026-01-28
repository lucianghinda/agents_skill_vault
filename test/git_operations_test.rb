# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"
require "mocha/minitest"

class GitOperationsTest < Minitest::Test
  def setup
    Dir.mktmpdir("git_test")
  end

  def teardown
    FileUtils.rm_rf(Dir.glob("#{Dir.tmpdir}/git_test*"))
  end

  def test_check_git_available_when_installed
    AgentsSkillVault::GitOperations.stubs(:git_installed?).returns(true)

    assert_silent do
      AgentsSkillVault::GitOperations.check_git_available!
    end
  end

  def test_check_git_available_raises_when_not_installed
    AgentsSkillVault::GitOperations.stubs(:git_installed?).returns(false)

    assert_raises(AgentsSkillVault::Errors::GitNotInstalled) do
      AgentsSkillVault::GitOperations.check_git_available!
    end
  end

  def test_check_git_version_when_valid
    AgentsSkillVault::GitOperations.stubs(:git_version).returns(Gem::Version.new("2.30.0"))

    assert_silent do
      AgentsSkillVault::GitOperations.check_git_version!
    end
  end

  def test_check_git_version_raises_when_old
    AgentsSkillVault::GitOperations.stubs(:git_version).returns(Gem::Version.new("2.10.0"))

    assert_raises(AgentsSkillVault::Errors::GitVersion) do
      AgentsSkillVault::GitOperations.check_git_version!
    end
  end

  def test_clone_repo
    temp_dir = Dir.mktmpdir("git_test")
    target_path = File.join(temp_dir, "repo")

    AgentsSkillVault::GitOperations.expects(:run_command).with("git clone  https://github.com/user/repo #{target_path}")

    AgentsSkillVault::GitOperations.clone_repo("https://github.com/user/repo", target_path)

    FileUtils.rm_rf(temp_dir)
  end

  def test_clone_repo_with_branch
    temp_dir = Dir.mktmpdir("git_test")
    target_path = File.join(temp_dir, "repo")

    cmd = "git clone --branch main https://github.com/user/repo #{target_path}"
    AgentsSkillVault::GitOperations.expects(:run_command).with(cmd)

    AgentsSkillVault::GitOperations.clone_repo("https://github.com/user/repo", target_path, branch: "main")

    FileUtils.rm_rf(temp_dir)
  end

  def test_current_branch
    temp_dir = Dir.mktmpdir("git_test")

    AgentsSkillVault::GitOperations.expects(:run_command).with("git branch --show-current").returns(["main\n", ""])

    result = AgentsSkillVault::GitOperations.current_branch(temp_dir)

    assert_equal "main", result

    FileUtils.rm_rf(temp_dir)
  end

  def test_pull
    temp_dir = Dir.mktmpdir("git_test")

    AgentsSkillVault::GitOperations.expects(:run_command).with("git fetch origin")
    AgentsSkillVault::GitOperations.expects(:run_command).with("git reset --hard origin/$(git branch --show-current)")

    AgentsSkillVault::GitOperations.pull(temp_dir)

    FileUtils.rm_rf(temp_dir)
  end

  def test_sparse_checkout
    temp_dir = Dir.mktmpdir("git_test")
    url = "https://github.com/user/repo"
    branch = "main"
    paths = ["path/to/folder"]

    expected_commands = [
      "git init #{temp_dir}",
      "git remote add origin #{url}",
      "git sparse-checkout init --no-cone",
      "git sparse-checkout set path/to/folder",
      "git fetch origin #{branch}",
      "git checkout #{branch}"
    ]

    expected_commands.each do |cmd|
      AgentsSkillVault::GitOperations.expects(:run_command).with(cmd)
    end

    Dir.expects(:chdir).with(temp_dir).yields

    AgentsSkillVault::GitOperations.sparse_checkout(url, temp_dir, branch: branch, paths: paths)

    FileUtils.rm_rf(temp_dir)
  end

  def test_sparse_checkout_with_multiple_paths
    temp_dir = Dir.mktmpdir("git_test")
    url = "https://github.com/user/repo"
    branch = "main"
    paths = %w[path1 path2]

    expected_commands = [
      "git init #{temp_dir}",
      "git remote add origin #{url}",
      "git sparse-checkout init --no-cone",
      "git sparse-checkout set path1 path2",
      "git fetch origin #{branch}",
      "git checkout #{branch}"
    ]

    expected_commands.each do |cmd|
      AgentsSkillVault::GitOperations.expects(:run_command).with(cmd)
    end

    Dir.expects(:chdir).with(temp_dir).yields

    AgentsSkillVault::GitOperations.sparse_checkout(url, temp_dir, branch: branch, paths: paths)

    FileUtils.rm_rf(temp_dir)
  end

  def test_clone_repo_without_extra_spaces
    temp_dir = Dir.mktmpdir("git_test")
    target_path = File.join(temp_dir, "repo")

    cmd = "git clone  https://github.com/user/repo #{target_path}"
    AgentsSkillVault::GitOperations.expects(:run_command).with(cmd)

    AgentsSkillVault::GitOperations.clone_repo("https://github.com/user/repo", target_path)

    FileUtils.rm_rf(temp_dir)
  end
end
