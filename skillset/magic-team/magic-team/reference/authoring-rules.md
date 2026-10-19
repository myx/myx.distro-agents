# Authoring rules: rules, instructions, definitions and descriptions

Read this when writing or repairing a rule, an instruction, a definition or a description.

## Contents

- Rule/instruction/definition/description conventions
- A rule statement stays a rule statement
- Generalise a rule, sharpen an instruction
- A rule that was violated is a proven gap

## Rule/instruction/definition/description conventions

- A rule is a short, abstract, present-tense statement, never a narrative. Register by kind: `reference/authoring-rules.md`'s "Generalise a rule, sharpen an instruction".
- Every instruction and document states a durable fact and its reason. Never narrate a past action, a measurement, or session provenance — a task or rule needing narrated text says so explicitly. A pending/settled status marker is allowed.
- A file that includes another may override, extend or waive the included rules, unless the included rule forbids it.
- A term's short definition lives in one terminology list. Each consumer describes its own use of it.
- A help entry or Operation Reference states when to call an operation and what to pass. Nothing about its internals.
- Files following a member or routine contract carry `Verbatim-goals`/`Verbatim-tests` in `# Maintainer Notes`, as their contract states. Other shared files carry none. Inline `**intent:**`/`**test:**`/`**note:**` markers are allowed anywhere. An intent is abstract and self-contained; an entry is authored instruction text, never a quotation.

## A rule statement stays a rule statement

A `CONVENTION`/`INTENT`/`TASK` body states the rule or task, timelessly. Facts, status and dates go to its Context Detail section.

## Generalise a rule, sharpen an instruction

A rule takes the most general form that still covers its intent. A test or instruction takes the most exact form that still allows the intended flexibility. A cap, limit or closed list enters only when he asked for it.

## A rule that was violated is a proven gap

A broken rule is insufficient as written. Find what let it fail — what it does not say, where it is written, what leaves no trace, which rule it loses to — and fix the text or what makes it hold.
