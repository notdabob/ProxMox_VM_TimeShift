# Smart Commit with Version Management

Execute the smart commit functionality that automatically handles version bumps and changelog updates.

This command provides smart commit functionality with automatic version management:

- Auto-detects commit type (patch/minor/major) from file changes
- Updates docs/CHANGELOG.md with new version entry and proper formatting
- Updates docs/file-structure.md with current project structure using mermaid diagram
- Updates README.md to be concise and reference docs/file-structure.md
- Creates properly formatted git commits with Claude Code attribution
- Uses docs/CHANGELOG.md as the single source of truth for version tracking
- Generates unique changelog section headers to avoid MD024 linter conflicts

**Important**: Changelog sections use version-specific headers with timestamps to prevent markdown linter conflicts:

- Use format like "### Added in v2.4.0 at 2025-01-02 10:11:37 EST" instead of just "### Added"
- Include version number AND timestamp in section headers
- This prevents MD024/no-duplicate-heading errors across different versions

Version increment logic:

- **patch**: Bug fixes, documentation updates, small improvements
- **minor**: New features, script additions, significant enhancements
- **major**: Breaking changes, major architectural updates

The script intelligently determines whether changes warrant patch (bug fixes), minor (new features), or major (breaking changes) version increments based on the files modified.

When creating changelog entries, always use version-specific section headers with timestamps like:

- "### Added in v2.4.0 at 2025-01-02 10:11:37 EST"
- "### Changed in v2.4.0 at 2025-01-02 10:11:37 EST"
- "### Removed in v2.4.0 at 2025-01-02 10:11:37 EST"
- "### Enhanced in v2.4.0 at 2025-01-02 10:11:37 EST"
