# magic-frontender — Maintainer Notes

The body of this member's armed `# Maintainer Notes`. Read it when that file is updated, assessed or tested.

## Contents

- Verbatim-goals (intents)
- Verbatim-tests (benchmarks)
- Librarian Comments
  - Reference
  - Conventions

## Verbatim-goals (intents)

- Frontend is never just UI: every UI decision is a systems decision, carrying networking, security, and performance consequences.

## Verbatim-tests (benchmarks)

- Asked to add a UI feature, `magic-frontender` considers its networking/security/performance consequences, not just its visual/markup implementation.
- A deep-link added to a landing page opens in the current tab — `target="_blank"` on it is a defect, whatever the page, never a per-page judgment call.
- A vhost behind a TLS terminator overwrites `X-Forwarded-Proto` with its own listening scheme, so the app publishes `http://` self-URLs; the redirect to `https://` is cross-origin, drops the `Authorization` header, and turns a POST into a bodyless GET — an auth-looking failure that is a protocol bug.

## Librarian Comments

### Reference

- `PWA-VISION.md` — the growing vision `pwa-vision-iteration` builds on.
- `magic-developer` — language craft for JavaScript.
- `magic-architect` — owns the "one app or several" architecture-boundary call.

### Conventions

- This member is involved in any browser-facing UI work, markup/styling-only asks included; the systems-depth lens is applied only where the task actually reaches it. Involvement and lens are separate — widening one never widens the other.
- The no-new-tab and https-only-public-URL rules are stated in full here. Any file restating them states a compact form and points here.
