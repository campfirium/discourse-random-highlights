# Random Highlights for Discourse

A Discourse theme component that displays a random highlight at the top of the topic list using Discourse plugin outlet connectors.

It supports two source modes:

- Short-topic mode: tag a short topic and show the first post as a random highlight.
- Excerpt mode: tag a longer topic and mark parts of the first post with `<mark>...</mark>`; each marked excerpt can appear as a random highlight.

Clicking a highlight opens the source topic. On desktop, the component reuses topic metadata from Discourse tag JSON for the poster avatar, post count, view count, and activity time. The display row is rendered through the `before-topic-list-body` outlet instead of mutating the topic list DOM after load.

## Installation

1. Open Discourse admin: `/admin/customize/themes`.
2. Install a theme component from this repository URL.
3. Add the component to your active theme.
4. Configure `short_topic_tag` and/or `excerpt_topic_tag` in the component settings.

No package registry or external service is required. Public distribution is normally done by publishing a Git repository and, if desired, posting a topic in the Discourse Meta theme category.

## Settings

- `short_topic_tag`: tag used for short topics. The first post is used as one random item. Leave empty to disable this source mode.
- `excerpt_topic_tag`: tag used for long-form source topics. Each `<mark>` excerpt in the first post is used as one random item. Leave empty to disable this source mode.
- `highlight_selector`: selector used to extract marked excerpts. Defaults to `mark`.
- `max_excerpt_length`: maximum displayed text length.
- `topic_cache_minutes`: how long tagged topic lists are cached in the browser.
- `show_composer_button`: adds a composer toolbar button that wraps selected text in `<mark>`.
- `composer_allowed_user_ids`: optional UI allowlist for the composer button.
- `composer_min_trust_level`: optional minimum trust level for the composer button.
- `allowed_author_user_ids`: optional author allowlist for displayed source topics.
- `allowed_author_min_trust_level`: optional minimum trust level for displayed source topics.
- `highlight_style_mode`: choose this component's custom row styling or the site's native topic-list styling.
- `highlight_light_background`, `highlight_light_text`, `highlight_light_border`: custom row colors for light color schemes.
- `highlight_dark_background`, `highlight_dark_text`, `highlight_dark_border`: custom row colors for dark color schemes.
- `random_item_author_mode`: choose `original_author` to show the source topic author avatar, or `system` to hide author avatar/user-card presentation.

The component does not ship with opinionated default tag names. Sites can choose separate tags for short topics and excerpt topics, or set both settings to the same tag to combine both modes into one pool.

## Notes

The allowlist settings are client-side filtering suitable for presentation and workflow control. They are not a security boundary.
