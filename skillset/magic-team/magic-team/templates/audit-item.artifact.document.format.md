---
maintainers: [magic-librarian, magic-coordinator, human-owner]
---
# audit-item.artifact document — the shape of one artifact

Normative contract: `audit-item.artifact.contract.format.md`. Where it and this skeleton disagree, the contract wins. This file carries the skeleton only.

## Contents

- Summary
- Skeleton

# Summary

The record of one published document, rewritten whole at each of its states. Written by the tooling when a document is claimed and published, never by hand.

The skeleton is shown for reading and for tests; this document is not written by hand.

# Skeleton

The required keys, and an optional key only where it is the usual case, marked optional. The other optional keys and the keys the tooling stamps are in the contract's Keys table.

```
---
document-contract: audit-item.artifact
type: artifact
number: <CODE-NNN, or ->
kind: <CODE, or ->
title: <text>
url: <url, or ->
member: <member>
session: <session-id, or ->
date: <date-time>
state: <reserved, published or released>
---
# <number>: <title>
```
