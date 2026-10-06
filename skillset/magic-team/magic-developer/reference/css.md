# CSS

Starter module — tentative, not yet confirmed this module belongs in magic-developer (`magic-frontender` owns CSS and browser-facing craft; this module holds only language-level axioms that hold in any project). Seeded with first axioms; grows as real estate work surfaces more.

## Axioms

- Native features first: Grid and Flexbox for layout, custom properties for theming, `:has()` and container queries before any JS-driven styling. No preprocessor unless a project already uses one.
- Keep specificity low and flat. Style by class, wrap shared base rules in `:where()`, and order whole layers with `@layer` rather than winning fights with selectors. `!important` is never a fix.
- Theme through custom properties on `:root`, and switch them under `prefers-color-scheme` — never by duplicating rule sets.
- Use logical properties (`margin-inline`, `padding-block`, `inset-inline-start`) over physical left/right where direction could ever change.
- Size text and spacing in `rem`, so user font settings scale the page. Pixels only for hairlines and fixed media.
- Mobile-first: base rules for the narrowest viewport, `min-width` queries (or container queries) to add, not `max-width` overrides to undo.
- Respect user preferences: motion behind `prefers-reduced-motion: no-preference`, never motion-only meaning.
- A reset zeroes `margin`, never `padding` globally (see `magic-frontender`'s reset note).
- No hand-written vendor prefixes for features that ship unprefixed in the supported browsers.

## Open

- Confirm module ownership with `magic-frontender`.
- Populate from real estate stylesheets (ACM skins, PWA work).
