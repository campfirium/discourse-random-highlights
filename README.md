# Random Highlights for Discourse

Random Highlights is a Discourse theme component that places one curated random highlight above the topic list. It is intended for forums that want a lightweight "quote of the moment", study prompt, writing excerpt, or recurring reminder without installing a backend plugin.

The component supports two source modes:

- Short-topic mode: tag short topics and use each first post as a complete random item.
- Excerpt mode: tag longer source topics and mark useful inline excerpts with `<mark>...</mark>`; each marked excerpt can appear as a random item.

The rendered row keeps Discourse topic-list structure: the random text is shown first, the source topic title appears underneath with a subtle `✨` prefix, and clicking the row opens the source topic. On desktop, available topic metadata is reused for author presentation, reply count, view count, and activity time.

## Release Status

`v0.7.0` is not tagged yet. The current `main` branch is suitable for final validation from Git, but run the install, Git update, topic-list rendering, composer behavior, and styling checks on a non-production Discourse theme before using it as a production component.

See [the release checklist](docs/release-checklist.md) before tagging a public release.

## Installation

1. Open Discourse admin: `Admin > Appearance > Themes & components`.
2. Install a component from this repository URL: `https://github.com/campfirium/discourse-random-highlights`.
3. Add the component to the active theme that should show random highlights.
4. Configure at least one source tag through `short_topic_tag` or `excerpt_topic_tag`.

No package registry, build step, external service, backend plugin, or database migration is required.

## Quick Setup

Use short-topic mode when every tagged topic is itself a short item:

1. Create one or more public topics.
2. Put the full highlight text in the first post.
3. Add the same tag to those topics.
4. Set `short_topic_tag` to that tag.

Use excerpt mode when highlights come from longer source posts:

1. Create or choose public source topics.
2. Wrap each useful inline excerpt in `<mark>...</mark>`.
3. Add the same tag to those topics.
4. Set `excerpt_topic_tag` to that tag.

To combine both modes into one pool, set `short_topic_tag` and `excerpt_topic_tag` to the same topic tag. The component does not ship with opinionated default tag names.

## Composer Button

When `show_composer_button` is enabled, the composer toolbar gets a highlighter button that wraps the current inline selection in mark tags. The button is designed for short inline selections. Check composer preview before relying on complex multi-line or cross-structure selections as excerpt sources.

The composer button can be limited by `composer_allowed_user_ids` and `composer_min_trust_level`. These settings control UI workflow only; they are not a security boundary.

## Random Row Behavior

The browser preloads the next random item as the component script loads. It caches tagged topic lists and the last resolved random item for `topic_cache_minutes`, so repeat visits can render the row immediately while the next item refreshes in the background.

The display queue is stored only in `sessionStorage`. It is used to avoid immediate repeats from the same topic during a browsing session, not to guarantee perfect per-excerpt rotation across every visitor.

## Styling

Marked text uses a configurable reader-style highlight instead of the default browser/Discourse mark styling. Light and dark color schemes have separate background, text color, and opacity settings:

- `highlight_light_background`, `highlight_light_text`, `highlight_light_opacity`
- `highlight_dark_background`, `highlight_dark_text`, `highlight_dark_opacity`

The default style keeps the text color on `var(--primary)`, applies a translucent highlight fill behind the text, and uses a stronger lower stroke for a highlighter-like finish. Site admins can change colors and opacity from the component settings; no custom CSS is required for normal color changes.

## Settings

- `short_topic_tag`: tag used for short topics. The first post is used as one random item. Leave empty to disable this source mode.
- `excerpt_topic_tag`: tag used for long-form source topics. Each `<mark>` excerpt in the first post is used as one random item. Leave empty to disable this source mode.
- `highlight_selector`: selector used to extract marked excerpts. Defaults to `mark`.
- `max_excerpt_length`: maximum displayed text length.
- `topic_cache_minutes`: how long tagged topic lists and the last resolved random item are cached in the browser. Defaults to 7 days.
- `show_composer_button`: adds a composer toolbar button that marks selected text as a highlight.
- `composer_allowed_user_ids`: optional UI allowlist for the composer button.
- `composer_min_trust_level`: optional minimum trust level for the composer button.
- `allowed_author_user_ids`: optional author allowlist for displayed source topics.
- `allowed_author_min_trust_level`: optional minimum trust level for displayed source topics.
- `highlight_light_background`, `highlight_light_text`, `highlight_light_opacity`: background color, text color, and opacity for marked text in light color schemes.
- `highlight_dark_background`, `highlight_dark_text`, `highlight_dark_opacity`: background color, text color, and opacity for marked text in dark color schemes.
- `random_item_author_mode`: choose `original_author` to show the source topic author avatar, or `system` to hide author avatar/user-card presentation.

Discourse theme settings have defaults. If a site changes a setting and later wants the shipped behavior again, reset that setting to the value shown by the component default.

## Updates

Discourse installs and updates theme components from Git. After updating the component, refresh the installed theme component from the admin UI and verify the topic list and composer behavior on the target site.

## Compatibility

This component targets modern Discourse theme components using Glimmer `.gjs` connectors and the Discourse plugin API initializer. Validate it on your target Discourse version before enabling it on a production theme.

## Data and Security

The component reads source data from Discourse JSON endpoints that the current visitor can already access. It does not add server-side permissions, expose private topics, migrate old content, or write database records.

Marked excerpts are rendered as escaped text. The component parses cooked post HTML only to find matching highlight elements and extract their text; it does not render source post HTML inside the topic list row.

The author and composer allowlist settings are client-side filtering for presentation and workflow control. They are not a security boundary. For security-sensitive reports, see `SECURITY.md`.

## Maintenance

Run the local validation script before committing component changes:

```bash
node scripts/validate-component.mjs
```

It checks component metadata, setting references, README coverage, locale keys, support/security entry points, expected public files, and compatibility guardrails. It does not replace real Discourse install/update validation.

## Support

Report issues at `https://github.com/campfirium/discourse-random-highlights/issues`. Include your Discourse version, installed component commit, relevant component settings, reproduction steps, browser console errors, and screenshots for rendering or styling problems.

## License

Random Highlights is released under the [MIT License](LICENSE).
