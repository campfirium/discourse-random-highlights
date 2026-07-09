# Changelog

## 0.7.2 - 2026-07-09

- Fix random-row reply and view counts so they match Discourse topic-list semantics and formatting.

## 0.7.1 - 2026-07-09

- Fix random-row activity dates by using Discourse's built-in tiny date formatter.

## 0.7.0 - 2026-07-08

- Add the initial Discourse theme component for random highlights above the topic list.
- Support short-topic sources and marked-excerpt sources from tagged public topics.
- Add browser caching for the tagged topic list and last resolved random item.
- Add session rotation to reduce immediate repeats from the same source topic.
- Render source-topic metadata in the topic-list row on desktop when available.
- Add optional original-author or neutral/system presentation for random rows.
- Add a composer toolbar button for wrapping selected inline text in `<mark>...</mark>`.
- Add client-side UI filters for composer visibility and source author selection.
- Add configurable light and dark mark styling for cooked posts and composer preview.
- Add localized theme metadata and setting descriptions for the Discourse admin UI.
- Document installation, settings, data boundaries, security scope, support, and release checks.
- Add public issue reporting, security policy, contribution guidance, and MIT license files.
