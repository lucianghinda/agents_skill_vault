## [0.2.0] - 2026-01-29

### Breaking Changes

- Renamed `UrlParser::ParseResult#is_skill_file?` to `skill_file?` (follows Ruby naming conventions)

### Refactoring

- Decomposed `Vault` class into 4 included modules:
  - `Vault::ResourceAdder` - resource addition logic
  - `Vault::ResourceSyncer` - resource sync logic
  - `Vault::ResourceValidator` - resource validation logic
  - `Vault::ManifestOperations` - manifest import/export operations
- Reduced `Vault` class from 450 to ~150 lines
- Extracted helper methods to keep all methods under 20 lines
- Reduced `Resource#initialize` parameter count from 15 to 11 using `**validation_attrs` splat
- Simplified `Resource#==` method using `equality_attributes` helper
- Extracted `Resource.from_h` logic into `extract_core_attrs` and `extract_validation_attrs` helpers
- Refactored `SkillValidator.validate` method by extracting `build_skill_data` and `validate_fields` helpers
- Split `UrlParser.parse_path_segments` into smaller methods: `parse_tree_segments`, `parse_blob_segments`, `default_path_data`, `parse_skill_file_segments`

### Code Quality

- All 33 RuboCop offenses resolved (0 remaining)
- All methods under 20 lines (excl. tests)
- All classes under 150 lines (excl. tests)
- Reduced parameter counts to meet style guidelines

## [0.1.0] - 2026-01-25

### Features

- Add GitHub repositories, folders, or individual files to a local vault
- Sync resources to pull latest changes from remote repositories
- Remove tracked resources from the vault
- Sparse checkout support for efficient partial repository cloning
- JSON manifest persistence for tracking resources
- Skill validation for SKILL.md files
- GitHub URL parsing supporting repositories, tree/folder, and blob/file URLs
- Git operations abstraction (clone, sparse checkout, pull)
- Resource labeling with username/repo/skill_name format

### Supported URL Types

- Repository: `https://github.com/user/repo`
- Folder: `https://github.com/user/repo/tree/main/path/to/folder`
- File: `https://github.com/user/repo/blob/main/path/to/file.md`
