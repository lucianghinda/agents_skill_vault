# Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/lucianghinda/agents_skill_vault.

## Development Setup

1. Clone the repository
2. Install dependencies: `bundle install`

## Running Tests

Run the full test suite:
```bash
bundle exec rake
```

Run specific tests:
```bash
bundle exec ruby -Ilib:test test/some_test.rb
```

## Code Style

Run RuboCop to check code style:
```bash
bundle exec rake rubocop
```

Auto-fix style issues:
```bash
bundle exec rubocop -a
```

## Development Workflow

1. Create a new branch for your feature or bugfix
2. Write tests for your changes
3. Make your changes
4. Run `bundle exec rake` to ensure tests pass and code style is correct
5. Commit your changes with a clear message
6. Push to your fork and submit a pull request

## Code Style Guidelines

- Follow Ruby style as configured in `.rubocop.yml`
- Use double quotes for strings
- Include `frozen_string_literal: true` in all Ruby files
- Max method length: 20 lines
- Max class length: 150 lines
- Write YARD-style documentation for public methods

## Architecture

The codebase is organized into several core components:

- `Vault` - Main interface for managing resources
- `UrlParser` - Parses GitHub URLs into components
- `GitOperations` - Git commands wrapper
- `Resource` - Data object representing a tracked resource
- `Manifest` - JSON manifest persistence
- `SkillScanner` - Scans directories for SKILL.md files
- `SkillValidator` - Validates SKILL.md file structure

See `AGENTS.md` for more detailed architecture documentation.