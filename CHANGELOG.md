## [Unreleased]

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
