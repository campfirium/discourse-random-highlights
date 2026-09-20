# Release Checklist

Use this checklist before tagging a public release of Random Highlights.

This repository intentionally does not ship a build step. Static validation is necessary, but a release is not ready until the component has also been installed and updated from Git on a real Discourse test site.

## Static Gate

- Confirm `about.json` has `"component": true` and the intended `theme_version`.
- Confirm `CHANGELOG.md` has an entry for the version being released.
- Confirm README settings match `settings.yml` and the implemented behavior.
- Confirm `locales/en.yml` has theme metadata for every public setting.
- Confirm `SECURITY.md` and the GitHub issue template still describe the supported report path and client-side filtering limits.
- Confirm no `.lab/`, `.agents/`, `.tmp/`, local validation scripts, logs, API keys, or site migration data are tracked.

## Discourse Test Site Gate

Use a disposable Discourse site or a non-production theme on a real site.

- Install from `https://github.com/campfirium/discourse-random-highlights`.
- Add the component to an active test theme.
- Confirm the component settings page shows all public settings.
- Confirm the component can be updated from Git after a follow-up commit.
- Record the Discourse version or commit and the installed component commit.

Do not tag a release if the target Discourse version cannot load `.gjs` connectors, the `before-topic-list-body` outlet, or the composer toolbar API used by this component.

## Source Modes

Create public test topics for these cases:

- A short-topic tag with at least two topics.
- An excerpt-topic tag with a first post containing multiple `[wrap=random-highlight]` excerpts.
- A grouped excerpt containing a heading, multiple paragraphs, and a list.
- An excerpt-topic tag with a legacy standalone `<mark>` excerpt.
- An excerpt-topic tag topic without any marked excerpts.
- A combined tag used for both short-topic and excerpt modes.

Validate these settings:

- Both source tags empty: no random row and no topic-list breakage.
- Short-topic tag only: first-post text appears.
- Excerpt-topic tag only: marked excerpts appear and unmarked topics are skipped.
- Same tag for both settings: marked topics use marked text and unmarked topics can fall back to first-post text.
- Missing or private tag plus one valid tag: the valid source still works.
- Invalid `highlight_selector`: topic list still renders; a console warning is acceptable.

## Rendering

Check desktop and mobile topic lists.

- The random row aligns with native topic-list columns.
- The random row appears on the global Latest route, including the homepage when Latest is configured as the homepage.
- The random row does not appear on category or tag lists, Top, Hot, New, Unread, or suggested topics below a topic.
- Mobile view has no broken extra cells, overlap, or unusable tap target.
- Highlight text respects `max_excerpt_length`.
- Clicking the title opens the source topic.
- `original_author` mode shows real source author presentation when data exists.
- `system` mode hides author avatar and user-card presentation while preserving row alignment.
- Post count, views, and activity time come from Discourse topic data.

## Cache, Permissions, and Request Budget

- Seed an old `randomHighlightsEntryCacheV2:` localStorage entry; mounting removes it without displaying its content.
- Switch from a user with access to a private source to one without access; the private excerpt never appears.
- Revoke source access or delete the source, then re-enter Latest; a 403/404 never restores the old excerpt.
- Edit or redact source text, then re-enter Latest; only the updated content can appear.
- Open other list routes; no highlight requests start. Leave Latest during a pending load; its result is ignored.
- Verify each load makes at most five topic requests and aborts pending fetches at ten seconds.
- Return a temporary tag error; re-enter Latest after recovery and verify the source is retried.
- Destroy the component during a pending load; no state update or retained route listener remains.

## Composer

Check with a logged-in test user.

- `show_composer_button: true` shows the toolbar button when filters pass.
- `show_composer_button: false` hides the toolbar button.
- Non-matching `composer_allowed_user_ids` hides the button.
- `composer_min_trust_level` hides the button below the configured trust level.
- The registered `highlighter` toolbar icon renders on the target Discourse version.
- Selected inline text becomes `[wrap=random-highlight]selected text[/wrap]`.
- A multi-line selection becomes one block wrap with the opening and closing tags on their own lines.
- Headings and lists inside a block wrap retain their Markdown structure in preview.
- Empty selection inserts the localized example text.
- Repeating the action around an existing wrap does not create nested wraps.
- Legacy standalone `<mark>` excerpts still render and enter the random pool.

## Styling

Check both light and dark color schemes.

- Default colors are readable in the target site's actual palette.
- Edited light and dark colors apply after saving settings.
- Empty or reset color settings return to the shipped component defaults.
- Marked text is readable in cooked posts and composer preview.

## Release Decision

Before tagging:

- Save screenshots for desktop light, desktop dark, mobile, composer toolbar, settings page, mark styling, and system author mode.
- Decide whether the oldest validated Discourse version should be recorded in `about.json` as `minimum_discourse_version`.
- Tag `v0.7.0` only after install, update, rendering, composer, styling, and source-mode checks pass.
- If any runtime item fails, fix the component or narrow the documented compatibility range before tagging.
