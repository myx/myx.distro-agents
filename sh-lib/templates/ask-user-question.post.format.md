---
maintainers: [magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner]
---
# ask-user-question post — the post of a call under the second name `AskUserQuestion`

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the fixed skeleton of the question a member posts with `AskUserQuestion`, the second name of the four tools that ask. That name takes every field with any `kind`, so its post shows every field it is given, as it always did. The tool fills its slots and sends it as that member's own message, through the member send. It is not an event-track post.

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
  - post
- Contract

# Summary

One skeleton for every kind: the title of the kind, the question, then each field the call gave, in one fixed order, and how to answer. Everything that belongs to a kind is taken from that kind's own template: its title, the refused call of a permission, the line of each option, the lines that say how to answer, the emoji placed under the post, its marks and its returned hint.

## Goals

- A call under the second name shows every heading it showed before the four tools had templates of their own.
- Nothing a kind owns is written twice: only the headings of the fields are held here, in their old order.

## Scope

- Does: fix which fields a call under the second name shows, and their order.
- Doesn't: hold a title, an answer line, an option line or an emoji. Those are in `ask-question.post.format.md`, `confirm-readback.post.format.md`, `escalate-decision.post.format.md` and `request-permission.post.format.md`, by the kind of the call.

# Skeleton

## post

```
{{kind-title}}

{{question}}

[[**📥 What I understood**
{{understood}}

]][[**📎 Where it came from**
{{source}}

]][[**▶️ What I will do if confirmed**
{{will-do}}

]][[{{refused-call}}

]][[**❔ Why this task needs it**
{{reason}}

]][[**🗂 Task**
{{task}}

]][[**📋 Options**
{{options}}

]][[**⚙ Context**
{{context}}

]][[**✅ How to answer**
{{how-to-answer}}]]
```

# Contract

- rule: The post is the one fenced block under `## post`, sent as the asking member's own message through the member send. It names its addressee as every member message does.
- rule: `{{kind-title}}` is the title line of the template of the call's kind, filled as that template fills it: its icon and word, the question's number where it shares a thread, and the revised mark on the question asked again, changed.
- rule: Required: `{{question}}`. Every other field is shown where the call gave it, under its own heading, in this order, whatever the kind. Which fields a kind needs is decided by the tool, as for the tool of that kind.
- rule: A slot outside `[[ … ]]` is required: with one empty, nothing is posted. Text in `[[ … ]]` is kept only when every slot in it has a value, and a group may span lines, so a heading is left out together with its empty field. No field is ever shown as a placeholder.
- rule: `{{refused-call}}` is the part of that name in the template of the call's kind (its `# Parts`), filled exactly as that kind's own post has it. Only a permission's template has it, so the refused call is shown for a permission and for no other kind, and it is shown whole even where its refusal record leaves a value empty.
- rule: `{{options}}`, `{{how-to-answer}}`, the emoji placed under the post, the marks and the returned hint are those of the template of the call's kind, by its answer form, exactly as a call of that kind's own tool has them.
- rule: A post that no longer takes an answer is this same text without its `How to answer` group, as for the tool of its kind.
- rule: Every text outside the slots and the marks is posted exactly as written here.
