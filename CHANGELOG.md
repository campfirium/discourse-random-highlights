# Changelog

## Unreleased

## 0.7.4 - 2026-09-20

- Stop persisting excerpt content, remove legacy excerpt caches, and fetch current source content before display.
- Isolate topic caches and rotation queues by visitor identity; do not cache failed tag requests.
- Load only on Latest, share concurrent requests, and cap each load at five topic requests and ten seconds.
- Ignore results after route changes or component destruction.

- Limit the random highlight row to the global Latest topic list.
- Match native mobile topic-row layout and keep desktop columns aligned during bulk selection.
- Support grouped multi-block excerpts with `[wrap=random-highlight]...[/wrap]` while continuing to read legacy standalone `<mark>` excerpts.
- Fall back to the shipped mark colors when a light or dark highlight style setting is empty.

## 0.7.3 - 2026-07-14

- Replace the platform-dependent sparkle emoji in random highlight source labels with a theme-aware rounded diamond marker.

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
