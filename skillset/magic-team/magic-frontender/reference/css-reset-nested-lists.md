# Universal CSS resets can break nested-list indentation

The body of the section of the same name in this member's armed content.

A blanket `* { padding: 0 }` (or `margin: 0`) reset zeros every element's box-model spacing, including `ul`/`ol`. Their nested-list indentation comes from the browser's own default `padding-left` on those elements. Zeroing it flattens every nesting depth to the same visual indent, with no depth-based offset.

Prefer Josh Comeau's modern CSS reset shape
(joshwcomeau.com/css/custom-css-reset): universal `margin: 0` only, never
`padding`. No element gets its padding zeroed specifically, so list
indentation survives untouched. A narrower alternative, excluding `ul`/`ol` from the reset explicitly, also works when a more surgical change is preferred.

Watch for this wherever nested lists, or anything else relying on browser-default box-model spacing, sit downstream of a blanket universal reset. A concrete instance lives in the owning `keeper-*`'s domain knowledge.
