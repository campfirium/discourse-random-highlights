# Random Highlights for Discourse

Random Highlights is a Discourse theme component that shows one curated random highlight above the topic list. Highlights can come from tagged short topics or from `<mark>...</mark>` excerpts inside longer source topics.

It installs directly from Git as a standard Discourse theme component. No backend plugin, package registry, build step, external service, or database migration is required.

## Version

Current component version: `0.7.0`.

## Installation

1. Open `Admin > Appearance > Themes & components`.
2. Install a component from `https://github.com/campfirium/discourse-random-highlights`.
3. Add the component to the theme where it should appear.
4. Configure `short_topic_tag`, `excerpt_topic_tag`, or both.

## Source Modes

Short-topic mode uses the first post of each tagged topic as a complete random item. Set `short_topic_tag` to the tag used by those topics.

Excerpt mode reads marked excerpts from the first post of each tagged source topic. Wrap each reusable excerpt in `<mark>...</mark>` and set `excerpt_topic_tag` to that tag.

If both settings use the same tag, marked excerpts are preferred and unmarked topics can fall back to first-post text. The component does not ship with site-specific default tags.

## Behavior

The random row links back to the source topic and reuses available Discourse topic metadata for author, reply count, view count, and activity time on desktop.

The browser caches the tagged topic list and the last resolved random item for `topic_cache_minutes`, which defaults to 7 days. This lets repeat visits render immediately while the next random item refreshes in the background. Session storage is used only to avoid immediate repeats from the same topic during the current browsing session.

## Composer Button

When `show_composer_button` is enabled, the composer toolbar includes a highlighter button that wraps the selected inline text in `<mark>...</mark>`.

`composer_allowed_user_ids` and `composer_min_trust_level` only control whether the button is shown in the UI. They are not access-control or security boundaries.

## Styling

Marked text uses a configurable highlighter style for both cooked posts and composer preview. Site admins can adjust light and dark colors from component settings:

- `highlight_light_background`, `highlight_light_text`, `highlight_light_opacity`
- `highlight_dark_background`, `highlight_dark_text`, `highlight_dark_opacity`

Leave a color setting at its default value to use the shipped style. To return a changed setting to the shipped behavior, reset that setting in the Discourse component settings UI.

## Settings

- `short_topic_tag`: tag for short topics. Leave empty to disable this source mode.
- `excerpt_topic_tag`: tag for source topics containing marked excerpts. Leave empty to disable this source mode.
- `highlight_selector`: CSS selector used to find excerpts in cooked post HTML. Defaults to `mark`.
- `max_excerpt_length`: maximum displayed highlight length.
- `topic_cache_minutes`: browser cache duration for tagged topic lists and the last resolved random item. Defaults to 7 days.
- `show_composer_button`: shows or hides the composer toolbar button.
- `composer_allowed_user_ids`: optional comma-separated UI allowlist for the composer button.
- `composer_min_trust_level`: optional minimum trust level for the composer button.
- `allowed_author_user_ids`: optional comma-separated source-author allowlist.
- `allowed_author_min_trust_level`: optional minimum source-author trust level.
- `highlight_light_background`, `highlight_light_text`, `highlight_light_opacity`: marked-text styling for light color schemes.
- `highlight_dark_background`, `highlight_dark_text`, `highlight_dark_opacity`: marked-text styling for dark color schemes.
- `random_item_author_mode`: show the original source author, or hide avatar/user-card presentation with `system`.

## Compatibility

This component targets modern Discourse theme components using Glimmer `.gjs` connectors and the Discourse theme API initializer. Validate install, Git update, topic-list rendering, composer behavior, and styling on your target Discourse version before tagging or deploying a release theme.

## Data and Security

The component reads Discourse JSON endpoints that the current visitor can already access. It does not add server-side permissions, expose private topics, migrate content, or write database records.

Marked excerpts are rendered as escaped text. Source post HTML is parsed only to find matching excerpt elements and extract text.

Author and composer filters are client-side presentation and workflow filters only. Use Discourse server-side permissions for access control. For security reports, see `SECURITY.md`.

## Support

Report issues at `https://github.com/campfirium/discourse-random-highlights/issues`. Include your Discourse version, installed component commit, relevant settings, reproduction steps, browser console errors, and screenshots for visual problems.

## License

Random Highlights is released under the [MIT License](LICENSE).
