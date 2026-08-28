# Java

Read this for Java idiom and style axioms — independent of any single repository's own project conventions. [code-craft.md](code-craft.md) applies on top of this one for any Java code actually being written: straight-line, top-to-bottom, structure only where the code genuinely has structure.

## Allocation

- **An immutable array/collection literal identical across every call is a `static final` field, never a fresh inline allocation per call.** A literal like `new String[]{"application/xhtml+xml"}` written inline inside a hot per-request/per-call method allocates the same fixed contents on every single invocation — needless garbage-collector pressure for zero benefit, since the contents never change. Hoist it to a `static final` field instead, following whatever sibling constant convention already exists in the same class/file/package (naming case, visibility) rather than inventing a new one — the correct pattern is often already sitting in the same file (found live in AE3's `WebContextType.createMatchingContext`: the same file already referenced a sibling `static final String[]` constant from `WebContextOutputRegistry`, so the correct convention was already in view when the bad inline allocation was written next to it).
