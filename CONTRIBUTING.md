# Contributing

Random Highlights is a Discourse theme component. Keep changes scoped to the public component files and avoid adding a build step unless Discourse theme tooling requires it.

## Before Opening A Pull Request

- Update `CHANGELOG.md` for user-visible behavior, settings, documentation, or release-process changes.
- Confirm README setting names match `settings.yml` and the implemented behavior.
- Confirm `locales/en.yml` includes metadata for new public settings.
- Keep `.lab/`, `.agents/`, local migration records, API keys, logs, and one-off maintenance scripts out of Git.
- Use `docs/release-checklist.md` for changes that affect install/update behavior, topic-list rendering, composer behavior, styling, or release tagging.

## Boundaries

- Do not describe client-side user ID or trust-level settings as security boundaries.
- Do not add default site-specific tag names to public settings or README examples.
- Do not add `minimum_discourse_version`, screenshots, or a release tag until runtime validation on a real Discourse site proves the release scope.
- Do not publish local validation scripts, Campfirium migration scripts, or local repair data as part of the component.
