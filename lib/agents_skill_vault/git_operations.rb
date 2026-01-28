# frozen_string_literal: true

require "open3"

module AgentsSkillVault
  # Provides Git operations for cloning, syncing, and managing repositories.
  #
  # All methods are class methods that execute git commands via the shell.
  # Requires Git 2.25.0+ for sparse checkout support.
  #
  # @example Clone a repository
  #   GitOperations.clone_repo("https://github.com/user/repo", "/path/to/target")
  #
  # @example Sparse checkout for a specific folder
  #   GitOperations.sparse_checkout(
  #     "https://github.com/user/repo",
  #     "/path/to/target",
  #     branch: "main",
  #     paths: ["lib/skills"]
  #   )
  #
  class GitOperations
    # Minimum required Git version for sparse checkout support
    MIN_VERSION = "2.25.0"

    class << self
      # Checks if git is installed and available in PATH.
      #
      # @raise [Errors::GitNotInstalled] if git is not available
      # @return [void]
      #
      def check_git_available!
        return if git_installed?

        raise Errors::GitNotInstalled, "Git is not installed or not available in PATH"
      end

      # Checks if the installed git version meets minimum requirements.
      #
      # @raise [Errors::GitVersion] if git version is below 2.25.0
      # @return [void]
      #
      def check_git_version!
        version = git_version
        return unless version < Gem::Version.new(MIN_VERSION)

        raise Errors::GitVersion, "Git version #{version} is too old. Minimum required: #{MIN_VERSION}"
      end

      # Clones a git repository.
      #
      # @param url [String] The repository URL to clone
      # @param target_path [String] Local path where the repository will be cloned
      # @param branch [String, nil] Specific branch to clone (optional)
      # @return [void]
      # @raise [Error] if the clone command fails
      #
      # @example Clone with default branch
      #   GitOperations.clone_repo("https://github.com/user/repo", "/local/path")
      #
      # @example Clone specific branch
      #   GitOperations.clone_repo("https://github.com/user/repo", "/local/path", branch: "develop")
      #
      def clone_repo(url, target_path, branch: nil)
        branch_flag = branch ? "--branch #{branch}" : ""
        run_command("git clone #{branch_flag} #{url} #{target_path}")
      end

      # Performs a sparse checkout to clone only specific paths.
      #
      # Uses modern git sparse-checkout commands to download only the specified
      # directories or files from the repository (requires Git 2.25.0+).
      #
      # @param url [String] The repository URL
      # @param target_path [String] Local path for the checkout
      # @param branch [String] Branch to checkout
      # @param paths [Array<String>] Paths within the repository to include
      # @return [void]
      # @raise [Error] if any git command fails
      #
      # @example Checkout a single folder
      #   GitOperations.sparse_checkout(
      #     "https://github.com/user/repo",
      #     "/local/path",
      #     branch: "main",
      #     paths: ["lib/skills/my-skill"]
      #   )
      #
      def sparse_checkout(url, target_path, branch:, paths:)
        run_command("git init #{target_path}")
        Dir.chdir(target_path) do
          run_command("git remote add origin #{url}")
          run_command("git sparse-checkout init --no-cone")
          run_command("git sparse-checkout set #{paths.join(" ")}")
          run_command("git fetch origin #{branch}")
          run_command("git checkout #{branch}")
        end
      end

      # Pulls the latest changes from the remote.
      #
      # Performs a fetch and hard reset to match the remote branch.
      #
      # @param path [String] Path to the local repository
      # @return [void]
      # @raise [Error] if the pull command fails
      #
      def pull(path)
        Dir.chdir(path) do
          run_command("git fetch origin")
          run_command("git reset --hard origin/$(git branch --show-current)")
        end
      end

      # Gets the current branch name of a repository.
      #
      # @param path [String] Path to the local repository
      # @return [String] The current branch name
      #
      def current_branch(path)
        Dir.chdir(path) do
          stdout, = run_command("git branch --show-current")
          stdout.strip
        end
      end

      private

      def git_installed?
        system("which git > /dev/null 2>&1")
      end

      def git_version
        stdout, = run_command("git --version")
        version_string = stdout.match(/git version (\d+\.\d+\.\d+)/)[1]
        Gem::Version.new(version_string)
      end

      def run_command(command)
        stdout, stderr, status = Open3.capture3(command)

        raise Error, "Command failed: #{command}\n#{stderr}" unless status.success?

        [stdout, stderr]
      end
    end
  end
end
