---
maintainers: [magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner]
---
# report post — the posts of the four report tools

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — these are the fixed shapes of what a member posts with `SubagentHandback`, `ReportFindings`, `PushNotification` and `Artifact`. Each tool fills the block of its own name and sends it through the member send, as that member's own message, or as the team bot's where `as_bot` says so. None of them asks anything: a question is posted from the template of the tool that asks it. None is an event-track post.

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
  - SubagentHandback
  - ReportFindings
  - PushNotification
  - Artifact
- Severity
  - info
  - warn
  - alert
- Lines
  - task
- Words
  - untitled
- Contract

# Summary

One block for each tool, in the form the ask posts have: a title that says what kind of report this is, with its icon, then the task it belongs to, in words, where the session has one, then each field the call gave, under its own label.

## Goals

- A reader knows what kind of report it is from its title, as with a question or a permission.
- A reader knows what the report is about without looking anything up: the task stands in words, and the name of its item follows the words, never leads a line.
- A field the call did not give leaves its label out: a label over nothing would say the writer looked and found nothing.
- Changing a label or a title is an edit to this file, not to the tool that fills it.

## Scope

- Does: fix the title of each report, its labels and their order.
- Doesn't: decide who a report goes to, or under which identity. The tool does, from its `to` and `as_bot`.
- Doesn't: hold the plain-language limits. The member send measures the member's own words, never a label.

# Skeleton

One block for each tool, under the tool's own name.

## SubagentHandback

```
# 🏁 Handback

[[**🗂 Task**
{{task}}

]]**📦 Outcome**
{{outcome}}

[[**🔍 Findings**
{{findings}}

]][[**⏳ Unfinished, and what was not checked**
{{unfinished}}

]][[**📬 Answers collected, and questions still open**
{{collected}}]]
```

## ReportFindings

```
# 🔍 Findings

{{subject}}

[[**🗂 Task**
{{task}}

]]**📌 What was established**
{{findings}}

[[**📎 Evidence**
{{evidence}}

]][[**⚖️ Confidence, and what was not checked**
{{confidence}}]]
```

## PushNotification

```
# {{severity}}

{{headline}}

[[**🗂 Task**
{{task}}

]][[**📋 Detail**
{{detail}}

]][[**👉 What you need to do**
{{action-required}}]]
```

## Artifact

```
# 📘 {{title}}

[[**🗂 Task**
{{task}}

]][[**🏷 Kind**
{{kind}}

]]**🔗 Link**
{{url}}

[[**📝 Summary**
{{summary}}]]
```

# Severity

The title of a notification, by its `severity`: what it is, in a word, with its icon.

## info

```
ℹ️ Notice
```

## warn

```
⚠️ Warning
```

## alert

```
🚨 Alert
```

# Lines

What stands under a label, filled on its own.

## task

```
{{task-title}}[[ · {{task-names}}]][[
{{task-given}}]]
```

# Words

A value a block above takes where the call gives none.

## untitled

```
Document
```

# Contract

- rule: A report is the one fenced block under `# Skeleton` named for its tool, sent through the member send as the member's own message, or as the team bot's where `as_bot` says so. Trailing blank lines are dropped.
- rule: Who a report is addressed to is the tool's to settle, from what its call names, and is named by the send, in the author line of the message, never in the body: no block shows an addressee. A tool that names one gives it to its block as `{{address-to}}`.
- rule: A slot outside `[[ … ]]` is required, and the tool refuses a call that leaves one empty before anything is filled. Text in `[[ … ]]` is kept only when every slot in it has a value, and a group may span lines, so a label is left out together with its empty field. No field is ever shown as a placeholder.
- rule: `{{task}}` in every block is the tooling's own, never a field of the call: the task of the session that posts, from the board item its spawn was dispatched for, as the block under `# Lines` named `task`. `{{task-title}}` is that task in words, and it leads. `{{task-names}}` are the names of its item and its dispatch, each in backticks, after the words and never ahead of them. `{{task-given}}` is the call's own `task`, which a handback alone takes, on a line of its own under them. A session with no such item shows no `Task` label, except a handback whose call gives a `task`: that text then stands under the label alone.
- rule: `## SubagentHandback`: `{{outcome}}` is required. `{{findings}}` and `{{unfinished}}` are the call's `findings` and `unfinished`. `{{collected}}` is the tooling's own: the answers it collected for the session's questions nobody waited on, and the questions still open.
- rule: `## ReportFindings`: `{{subject}}` and `{{findings}}` are required. `{{evidence}}` and `{{confidence}}` are the call's own fields.
- rule: `## PushNotification`: `{{headline}}` is required. `{{severity}}` is the block under `# Severity` named for the call's `severity`, which is `info`, `warn` or `alert` and never defaulted: a call naming another is refused. It is the title of the post. `{{detail}}` and `{{action-required}}` are the call's `detail` and `action_required`.
- rule: `## Artifact`: `{{url}}` is required, the link of a document that exists. `{{title}}` is the call's `title`, else the `## untitled` word under `# Words`: it is the title of the post, so the number of a numbered document leads it. `{{kind}}` and `{{summary}}` are the call's own fields.
- rule: No line of a report starts with an identifier a person has to look up: a name of an item, a session or a file follows the words it belongs to.
- rule: Every text outside the slots is posted exactly as written here.
