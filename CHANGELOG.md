# Changelog

## 0.1.0 - Unreleased

- Initial Discourse theme component structure.
- Add configurable short-topic and marked-excerpt source modes.
- Render one random highlight in the topic list through the `before-topic-list-body` connector.
- Add optional composer toolbar button for wrapping selected text in `<mark>...</mark>`.
- Add client-side UI/workflow filters for composer visibility and source authors.
- Add configurable custom row colors for light and dark color schemes.
- Add original-author and neutral/system presentation modes.
- Clamp numeric settings in the component runtime to protect against invalid admin-entered values.
- Preserve and enrich author metadata from topic payloads, and encode profile links.
- Use a safer composer toolbar icon with Discourse source evidence.
- Update installation instructions for the current Discourse Themes & components admin UI.
- Add localized theme metadata and setting descriptions for the Discourse admin UI.
- Add a GitHub bug report template and support instructions.
- Clarify data, cache, migration, and security boundaries in the README.
- Add a SECURITY policy describing report scope and client-side filtering limits.
- Validate support and security entry points in the component validation script.
- Add a public release checklist for install, update, rendering, composer, styling, and tagging gates.
- Report missing validation inputs as structured validation failures instead of crashing.
- Normalize tag, boolean, and trust-level settings before component runtime use.
- Normalize style and author mode enum settings before component runtime use.
- Ignore malformed browser cache and display queue values instead of failing random-row loading.
- Document the source-topic configuration workflow in the README.
- Clarify that queue rotation avoids immediate source-topic repeats, not per-excerpt repeats.
- Guard against tagging the unreleased version before runtime release validation passes.
- Validate LF line-ending rules for tracked component files.
- Add editor configuration guardrails for line endings, charset, final newline, and indentation.
- Add contributor guidance for validation, release checks, and public repository boundaries.
- Guard unreleased `about.json` metadata against premature compatibility or screenshot claims.
- Validate repository URLs across Git remote, `about.json`, README, support links, and the release checklist.
- Guard public distribution against site-specific tag defaults and local maintenance artifacts.
- Document the unreleased validation status in the README.
- Validate the expected public tracked file list.
- Add issue template configuration for structured support reports.

This version is not tagged yet. Tag `v0.1.0` after real Discourse install/update validation passes.
