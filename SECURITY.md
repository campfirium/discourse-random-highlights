# Security Policy

Random Highlights is a Discourse theme component. It runs in the browser and reads only Discourse JSON endpoints that the current visitor can already access.

## Reporting

Report suspected security issues at:

https://github.com/campfirium/discourse-random-highlights/issues

Include the Discourse version, installed component commit, affected settings, reproduction steps, and any relevant browser console or network details. If the report contains sensitive site data, describe the issue without posting private content publicly.

## Scope

Security-relevant issues include:

- The component exposing private topics or posts to users who cannot already access them in Discourse.
- The component writing or mutating Discourse data unexpectedly.
- Cross-site scripting caused by this component rendering untrusted source content unsafely.
- A documented security boundary being bypassed.

The following are not treated as security boundaries:

- `composer_allowed_user_ids`
- `composer_min_trust_level`
- `allowed_author_user_ids`
- `allowed_author_min_trust_level`

Those settings are client-side workflow and presentation filters only. Use Discourse server-side permissions for access control.
