# Java

Read this for Java idiom and style axioms — independent of any single repository's own project conventions. [code-craft.md](code-craft.md) applies on top of this one for any Java code actually being written: straight-line, top-to-bottom, structure only where the code genuinely has structure.

## Contents

- Allocation
- Reflection
- Runtime lookup
- Source-file launch

## Allocation

- **An immutable array/collection literal identical across every call is a `static final` field, never a fresh inline allocation per call.** A literal like `new String[]{"application/xhtml+xml"}` written inline inside a hot per-request/per-call method allocates the same fixed contents on every single invocation. That is needless garbage-collector pressure for zero benefit, since the contents never change. Hoist it to a `static final` field instead. Follow whatever sibling constant convention already exists in the same class/file/package (naming case, visibility) rather than inventing a new one. The correct pattern is often already sitting in the same file: a sibling `static final` constant the class itself references a few lines from the inline allocation.

## Reflection

- **A reflection-mediated read is confirmed at the invocation, never at the declaration.** A method declared with the expected return type is the middle of the chain. Whether the value arrives also depends on the access check its call passes, and on the receiver it runs against.
- **A name-to-property layer is a link of its own, and it is not in `java.lang.reflect`.** Where a system maps a reflective method name onto a property a caller reads, that mapping is that system's own machinery. Confirm it in that system's source. The JDK's own getter mapping is `java.beans.Introspector`, in `java.desktop`, deriving `name` from `getName()` and `active` from `isActive()`. A record's component is the one name-and-accessor pair `java.lang.reflect` does hold, and it exists for records alone.

## Runtime lookup

- **A class absent at run time reports one of two errors, set by how it is reached.** A reference the class loader resolves when the running code first reaches it throws `NoClassDefFoundError`. The same class looked up by name at run time throws `ClassNotFoundException`. Measured on Temurin 25.0.2 with `--limit-modules java.base`: a class using `javax.tools.ToolProvider` directly gives `NoClassDefFoundError: javax/tools/ToolProvider` over a `Caused by: java.lang.ClassNotFoundException`. A `Class.forName` of that same name gives `ClassNotFoundException`, with no cause line after it.
- **Class resolution is lazy, so the linked route fails where the reference is reached, not where the class loads.** A reference inside a branch the code never enters is never resolved, and the run completes. Measured on Temurin 25.0.2 under `--limit-modules java.base`: a class holding `javax.tools.ToolProvider` in an uncalled method prints its lines either side and exits 0. The same class with that method called throws `NoClassDefFoundError`.

## Source-file launch

- **A `package` declaration binds the path tail.** A source-launched file whose path tail does not match its package aborts, rc 1.
- **Siblings compile on demand, and only where referenced.** A `.java` file the program names is compiled from the derived source root. One it does not name is never read, so a broken sibling beside a working program is silent.
- **A sibling source shadows a classpath class of the same name.** The source wins, with no warning.
- **A source-launched class reaches a classpath class only through public members.** Anything less is an `IllegalAccessError` at run time, because the two sit in different loaders. A sibling source is in the same loader, so a package-private member there is reachable.
- **`--source` is required for a file not named `*.java` and honoured for one that is.** It sets the source level. It does not select source-file mode. Measured on Temurin 25.0.2: `java --source 17 Plain.java` runs, `java NotJava` refuses the class, and `java --source 17 NotJava` runs.
- **`new String(bytes, UTF_8)` and `Files.readString` are not interchangeable.** The first substitutes U+FFFD for a malformed sequence, the second throws `MalformedInputException`. Pick by whether the code mirrors a lenient or a strict reader.
- **`trim()` and `strip()` both leave a leading BOM.** U+FEFF is not whitespace to either, so a BOM-stripping step is its own line.
- **`--limit-modules` and source-file mode combine only where `jdk.compiler` is allowed.** Measured on Temurin 25.0.2: `java --limit-modules java.base Prog.java` aborts rc 1 with `InternalError: Module jdk.compiler not in boot Layer`. The launcher needs `jdk.compiler`, and the limit excludes it. Listing that module works too, and makes `javax.tools` reachable to the program. Compile first, then run the class with `-cp`, and the limit then applies to the program.
