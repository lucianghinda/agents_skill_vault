## [0.3.0] - 2026-02-04

### Bug Fixes

- **Sync works for individual skills from multi-skill repositories**
  Previously, syncing a skill like `vault.sync("user/repo/skill-name")` would fail if the resource was added as part of a full repository. The sync operation would try to re-add the skill instead of updating it, causing a `DuplicateLabel` error. Now it correctly finds and updates existing skills.

- **Legacy resources are now upgraded automatically**
  Resources added before version 0.3.0 had `nil` values for `skill_name`. Syncing these resources now automatically fills in the missing `skill_name`, upgrading them to the current format.

- **Fixed crash when adding repositories**
  Adding a repository would crash with `uninitialized constant Errors::Error`. This was caused by a missing require statement in the git operations module. The error is now properly raised and handled.

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
