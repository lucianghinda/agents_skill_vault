# frozen_string_literal: true

require "addressable/uri"

module AgentsSkillVault
  # Parses GitHub URLs into their component parts.
  #
  # Supports repository URLs, folder URLs (tree), and file URLs (blob).
  #
  # @example Parse a repository URL
  #   result = UrlParser.parse("https://github.com/user/repo")
  #   result.username    # => "user"
  #   result.repo        # => "repo"
  #   result.type        # => :repo
  #
  # @example Parse a folder URL
  #   result = UrlParser.parse("https://github.com/user/repo/tree/main/lib/skills")
  #   result.type           # => :folder
  #   result.relative_path  # => "lib/skills"
  #
  class UrlParser
    GITHUB_HOST = "github.com"

    # Data object for parsed path segments
    PathSegmentsData = Data.define(:type, :branch, :relative_path, :skill_name, :skill_folder_path)

    # Result object returned by UrlParser.parse
    #
    # Contains the parsed components of a GitHub URL.
    #
    class ParseResult
      # @return [String] GitHub username or organization
      attr_reader :username

      # @return [String] Repository name
      attr_reader :repo

      # @return [String] Branch name (defaults to "main")
      attr_reader :branch

      # @return [String, nil] Path within the repository (for folder/file URLs)
      attr_reader :relative_path

      # @return [Symbol] Type of URL (:repo, :folder, or :file)
      attr_reader :type

      # @return [String, nil] The name of the skill (for SKILL.md file URLs)
      attr_reader :skill_name

      # @return [String, nil] The full path to the skill folder (for SKILL.md file URLs)
      attr_reader :skill_folder_path

      # Creates a new ParseResult.
      #
      # @param username [String] GitHub username
      # @param repo [String] Repository name
      # @param type [Symbol] URL type (:repo, :folder, or :file)
      # @param branch [String] Branch name (default: "main")
      # @param relative_path [String, nil] Path within repository
      # @param skill_name [String, nil] The name of the skill (for SKILL.md files)
      # @param skill_folder_path [String, nil] Full path to skill folder (for SKILL.md files)
      #
      def initialize(username:, repo:, type:, branch: "main", relative_path: nil, skill_name: nil,
                     skill_folder_path: nil)
        @username = username
        @repo = repo
        @branch = branch
        @relative_path = relative_path
        @type = type
        @skill_name = skill_name
        @skill_folder_path = skill_folder_path
      end

      # Generates a default label for this URL.
      #
      # For repositories: "username/repo"
      # For SKILL.md files: "username/skill-name"
      # For other folders/files: "username/last-path-component"
      #
      # @return [String] Generated label
      #
      def label
        if type == :repo
          "#{username}/#{repo}"
        elsif is_skill_file?
          "#{username}/#{repo}/#{skill_name}"
        else
          parts = relative_path&.split("/") || []
          folder = parts.last
          "#{username}/#{repo}/#{folder}"
        end
      end

      # Checks if this URL points to a SKILL.md file.
      #
      # @return [Boolean] true if this is a SKILL.md file URL
      #
      def is_skill_file?
        type == :file && skill_name && !skill_name.empty?
      end
    end

    # Parses a GitHub URL into its components.
    #
    # Uses Addressable::URI for robust URL parsing with proper encoding/decoding.
    #
    # @param url [String] A GitHub URL (repository, tree, or blob)
    # @return [ParseResult] Parsed URL components
    # @raise [Errors::InvalidUrl] if the URL is not a valid GitHub URL
    #
    # @example Parse different URL types
    #   UrlParser.parse("https://github.com/user/repo")
    #   UrlParser.parse("https://github.com/user/repo/tree/main/folder")
    #   UrlParser.parse("https://github.com/user/repo/blob/main/file.rb")
    #
    # @example Parse URL with encoded characters
    #   result = UrlParser.parse("https://github.com/user/repo/tree/main/folder%20name")
    #   result.relative_path  # => "folder name"
    #
    def self.parse(url)
      uri = Addressable::URI.parse(url)
      validate_github_url!(uri, url)

      segments = uri.path.sub(%r{^/}, "").split("/").map { |s| Addressable::URI.unencode(s) }
      username = segments[0]
      repo = segments[1]

      path_data = parse_path_segments(segments)

      ParseResult.new(
        username: username,
        repo: repo,
        branch: path_data.branch,
        relative_path: path_data.relative_path,
        type: path_data.type,
        skill_name: path_data.skill_name,
        skill_folder_path: path_data.skill_folder_path
      )
    end

    # Validates that the URI is a GitHub URL with http or https scheme.
    #
    # @param uri [Addressable::URI, nil] The parsed URI
    # @param original_url [String] The original URL string for error messages
    # @raise [Errors::InvalidUrl] if the URL is not a valid GitHub URL
    #
    private_class_method def self.validate_github_url!(uri, original_url)
      return if uri&.host == GITHUB_HOST && %w[http https].include?(uri&.scheme)

      raise Errors::InvalidUrl, "Invalid GitHub URL: #{original_url}. Expected format: https://github.com/username/repo[/tree/branch/path]"
    end

    # Parses URL path segments to determine URL type, branch, and relative path.
    #
    # @param segments [Array<String>] The split path segments
    # @return [PathSegmentsData] Structured data with type, branch, and relative_path
    #
    private_class_method def self.parse_path_segments(segments)
      if segments.length <= 2
        return PathSegmentsData.new(type: :repo, branch: "main", relative_path: nil, skill_name: nil,
                                    skill_folder_path: nil)
      end

      case segments[2]
      when "tree"
        branch = segments[3] || "main"
        path_parts = segments[4..] || []
        if path_parts.empty?
          PathSegmentsData.new(type: :repo, branch: branch, relative_path: nil, skill_name: nil, skill_folder_path: nil)
        else
          PathSegmentsData.new(type: :folder, branch: branch, relative_path: path_parts.join("/"), skill_name: nil,
                               skill_folder_path: nil)
        end
      when "blob"
        branch = segments[3] || "main"
        path_parts = segments[4..] || []
        relative_path = path_parts.join("/")

        # Check if this is a SKILL.md file
        filename = path_parts.last
        if filename == "SKILL.md"
          # Extract skill name from parent folder
          if path_parts.length >= 2
            skill_name = path_parts[-2]
            skill_folder_path = path_parts[0..-2].join("/")
          else
            # SKILL.md is at root, use repo name as skill name
            skill_name = segments[1]
            skill_folder_path = "."
          end

          PathSegmentsData.new(
            type: :file,
            branch: branch,
            relative_path:,
            skill_name:,
            skill_folder_path:
          )
        else
          PathSegmentsData.new(type: :file, branch: branch, relative_path:, skill_name: nil, skill_folder_path: nil)
        end
      else
        PathSegmentsData.new(type: :repo, branch: "main", relative_path: nil, skill_name: nil, skill_folder_path: nil)
      end
    end
  end
end
