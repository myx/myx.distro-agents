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
- Words
  - untitled
- Contract

# Summary

One block for each tool: its first line, which says what kind of report this is, then each field the call gave, under its own label.

## Goals

- A reader knows what kind of report it is from its first line.
- A field the call did not give leaves its label out: a label over nothing would say the writer looked and found nothing.
- Changing a label or a first line is an edit to this file, not to the tool that fills it.

## Scope

- Does: fix the first line of each report, its labels and their order.
- Doesn't: decide who a report goes to, or under which identity. The tool does, from its `to` and `as_bot`.
- Doesn't: hold the plain-language limits. The member send measures the member's own words, never a label.

# Skeleton

One block for each tool, under the tool's own name.

## SubagentHandback

```
Handback

[[Task as given:
{{task}}

]]Outcome:
{{outcome}}

[[Findings:
{{findings}}

]][[Unfinished, and what was not checked:
{{unfinished}}

]][[Answers collected, and questions still open:
{{collected}}]]
```

## ReportFindings

```
Findings: {{subject}}

What was established:
{{findings}}

[[Evidence:
{{evidence}}

]][[Confidence, and what was not checked:
{{confidence}}]]
```

## PushNotification

```
{{severity}} -- {{headline}}

[[Detail:
{{detail}}

]][[Action required:
{{action-required}}]]
```

## Artifact

```
{{title}}

[[Kind:
{{kind}}

]]Link:
{{url}}

[[Summary:
{{summary}}]]
```

# Severity

The word a notification opens with, by its `severity`.

## info

```
INFO
```

## warn

```
WARN
```

## alert

```
ALERT
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
- rule: `## SubagentHandback`: `{{outcome}}` is required. `{{task}}`, `{{findings}}` and `{{unfinished}}` are the call's `task`, `findings` and `unfinished`. `{{collected}}` is the tooling's own: the answers it collected for the session's questions nobody waited on, and the questions still open.
- rule: `## ReportFindings`: `{{subject}}` and `{{findings}}` are required. `{{evidence}}` and `{{confidence}}` are the call's own fields.
- rule: `## PushNotification`: `{{headline}}` is required. `{{severity}}` is the block under `# Severity` named for the call's `severity`, which is `info`, `warn` or `alert` and never defaulted: a call naming another is refused. `{{detail}}` and `{{action-required}}` are the call's `detail` and `action_required`.
- rule: `## Artifact`: `{{url}}` is required, the link of a document that exists. `{{title}}` is the call's `title`, else the `## untitled` word under `# Words`. `{{kind}}` and `{{summary}}` are the call's own fields.
- rule: Every text outside the slots is posted exactly as written here.
