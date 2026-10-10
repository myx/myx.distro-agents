# ADR-007: Render team documents as HTML pages

- **Status:** Accepted
- **Date:** 2026-10-10
- **Deciders:** magic-architect, magic-frontender

## Context

Team documents are written in Markdown. The email converter covers only
paragraphs, emphasis, code and links, so a heading or a table arrives as raw
text. See [the email converter](sh-lib/AgentsEmailHtmlBuild.awk) for what it
already does.

> Every document a reader opens should look like a document,
> not like its *source*.

## Decision

Add a document mode, `AgentsMarkdownHtmlDocument.awk`, beside the email mode:

1. Keep the email converter byte-for-byte unchanged.
2. Convert headings, lists, tables, quotes and images.
   - Nested lists follow indentation.
   - Image sources stay as written.
3. Escape every `<`, `>`, `&` and `"` in text, so R&D <notes> stay text.

### Options considered

| Option | Cost | Risk |
| :--- | :---: | ---: |
| Extend the email converter | Low | **High** |
| A separate document converter | Medium | Low |
| A Python renderer | Low | New dependency |

## Consequences

The publish step rewrites image sources, so
![Context diagram](images/context.svg "Context") stays as given here.

---

_Superseded by:_ none.
