#!/bin/sh
## Stand-in for ldd, for AgentsEmbeddedPythonInstallCheck: says on its error output which C library the rig has
## (RIG_LIBC, musl or glibc), in the words the real ldd uses for --version.
case "${RIG_LIBC:-glibc}" in
	musl) printf 'musl libc (x86_64)\nVersion 1.2.5\n' >&2 ;;
	*) printf 'ldd (GNU libc) 2.35\n' ;;
esac
