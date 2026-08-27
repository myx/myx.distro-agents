# Eclipse workspace metadata — what is authoritative, and what is not

Read this before removing, moving, or hand-editing anything under an Eclipse workspace's
`.metadata/`, and before concluding from those files where a project lives.

The theme running through all three sections: these files look like a cache that Eclipse would
rebuild, and they are not one. They are the state itself.

## The project list is state, not a rebuildable cache

`.metadata/.plugins/org.eclipse.core.resources/.root/<n>.tree` is authoritative for which projects
the workspace contains.

- With it removed, Eclipse starts on an empty workspace and commits that empty state as a new tree.
  It does not fail, and it does not warn.
- Project membership is not reconstructed from the `.projects/<name>/` directories that remain.
  Those directories surviving is not the project surviving.
- So removing this file is a loss of state, not a cache invalidation.

## The safetable is a chunky file — the last chunk wins

`.metadata/.plugins/org.eclipse.core.resources/.safetable/org.eclipse.core.resources` is written by
Eclipse's `SafeChunkyOutputStream`.

- The properties block appears several times over, each occurrence behind a 16-byte marker. The
  reader takes the last valid chunk.
- Patching the first occurrence only — the shape a `re.search` plus a slice produces — leaves the
  winning chunk stale. The edit reports success and changes nothing Eclipse reads.
- A patch here replaces every occurrence and preserves byte length.

## `.location` does not mean the project is external

A `.projects/<name>/.location` file carries referenced-project names, not a filesystem URI. Its
presence is no evidence that the project lives outside the workspace root.

## Reading list

- `magic-librarian.armed.md` — this module's owner, and the reference-module role generally.
- `magic-team/magic-team.armed.md`, "Engineering & operating discipline" — the general rule that a
  check must be able to fail, which is what a first-occurrence-only patch here defeats.
