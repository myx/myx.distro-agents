#!/usr/bin/env awk
# The text of a routine run inline (F6.6): the routine as mixed, without its frontmatter block and without its
# `# Maintainer Notes` section (down to the next top-level heading, or the end). A `#` inside a code fence is no heading.
NR == 1 && $0 == "---" { inFront = 1 ; next ; }
inFront && $0 == "---" { inFront = 0 ; next ; }
inFront { next ; }
/^```/ { fence = ! fence ; }
! fence && $0 == "# Maintainer Notes" { skipNotes = 1 ; next ; }
skipNotes && ! fence && /^# / { skipNotes = 0 ; }
skipNotes { next ; }
{ print ; }
