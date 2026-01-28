# frozen_string_literal: true

module AgentsSkillVault
  # Scans directories for SKILL.md files.
  #
  # Recursively searches for SKILL.md files and extracts metadata
  # including the skill name and folder path.
  #
  # @example Scan a directory for skills
  #   skills = SkillScanner.scan_directory("/path/to/repo")
  #   skills.each do |skill|
  #     puts "Found skill: #{skill[:skill_name]} at #{skill[:relative_path]}"
  #   end
  #
  class SkillScanner
    SKILL_FILE_NAME = "SKILL.md"

    # Scans a directory for all SKILL.md files.
    #
    # @param base_path [String] The base directory to scan
    # @return [Array<Hash>] Array of skill metadata with keys:
    #   - :relative_path [String] Path relative to base_path
    #   - :skill_folder [String] Full folder path containing SKILL.md
    #   - :skill_name [String] The name of the skill (parent folder name)
    #   - :folder_path [String] Alias for skill_folder
    #
    # @raise [ArgumentError] if base_path is nil or doesn't exist
    #
    def self.scan_directory(base_path)
      raise ArgumentError, "base_path cannot be nil" if base_path.nil?
      raise ArgumentError, "base_path does not exist: #{base_path}" unless Dir.exist?(base_path)

      skills = []
      scan_recursive(base_path, base_path, skills)
      skills
    end

    # Recursively scans directory for SKILL.md files.
    #
    # @param current_dir [String] Current directory being scanned
    # @param base_path [String] Original base path for relative path calculation
    # @param skills [Array] Array to collect found skills
    #
    def self.scan_recursive(current_dir, base_path, skills)
      # Check if current directory has a SKILL.md file
      skill_file = File.join(current_dir, SKILL_FILE_NAME)
      skills << extract_skill_metadata(skill_file, base_path) if File.exist?(skill_file)

      # Scan subdirectories
      Dir.glob(File.join(current_dir, "*")).each do |entry|
        scan_recursive(entry, base_path, skills) if File.directory?(entry)
      end
    end

    # Extracts skill metadata from a SKILL.md file path.
    #
    # @param skill_file_path [String] Full path to SKILL.md file
    # @param base_path [String] Base path for calculating relative paths
    # @return [Hash] Skill metadata
    #
    def self.extract_skill_metadata(skill_file_path, base_path)
      skill_dir = File.dirname(skill_file_path)
      skill_name = File.basename(skill_dir)
      relative_path = Pathname.new(skill_dir).relative_path_from(Pathname.new(base_path)).to_s

      {
        relative_path:,
        skill_folder: relative_path,
        skill_name:,
        folder_path: relative_path
      }
    end
  end
end
