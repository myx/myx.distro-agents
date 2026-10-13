#!/usr/bin/env bash
##
## AgentsRunTests.sh -- runs sh-test/*.test.sh in parallel (myx.common lib/parallel) and keeps
## one log and one receipt per test in a run folder:
##   $MMDAPP/.local/temp/mdat-tests/<UTC-stamp>/<test>.log      the test's whole output
##     (<UTC-stamp>-<pid> for a run started in the same second as another)
##   $MMDAPP/.local/temp/mdat-tests/<UTC-stamp>/<test>.receipt  rc, seconds, last line
##   $MMDAPP/.local/temp/mdat-tests/<UTC-stamp>/summary.txt     PASS / FAIL per test, totals
## and points $MMDAPP/.local/temp/mdat-tests/latest at it.
##
## Usage: AgentsRunTests.sh [-w <workers>] [-t <timeout-seconds>] [--stall-margin <seconds>] [<name-substring>...]
##        AgentsRunTests.sh --passed [<name-substring>...]
##   no substrings: every *.test.sh; otherwise the tests whose name contains any of them.
##   --passed runs nothing: for each of those tests it prints one line, `<test> <when>`, the
##   time it passed on the very state it would run on now, or `<test> -` where no such pass
##   is on record (the pass record, below).
##   Workers: lib/parallel's own default (ENV_PARALLEL_WORKER_COUNT, else 4) unless -w is given.
##   Each line of the run list is `<test> <timeout-seconds>`; -t sets the timeout written
##   into each line (default 900).
##   Status: 0 every test passed, 1 a test did not or the run was refused, 124 the run stood
##   still and was ended (A RUN THAT STANDS STILL, below).
##
## Each test gets a test-only session identity, so no test can write into a live session store.
## And nothing of the session its runner was started in. A member's session that a spawn started
## holds more than its id and its member: its coworking session and that session's thread, the
## conversations it continues, its sandbox, its launch marker, whether its caller waits. Every
## MDAT_SPAWN_* and MDAT_SESSION_* variable is taken out, and MDAT_CONVERSATION_THREADS: a rig
## that found them was no session of its own. Its spawn joined that session and took its thread,
## its question to a member went there, its harness kept its scratch in that member's sandbox.
## And its waits remind no ask (MDAT_WAIT_REMIND=off, AgentsTools.MemberWait.include): the asks of
## a rig carry the ts its fake Slack gives, years old, so every wait that brings nothing would
## remind them, one more post than a scenario counts. A test of the reminders unsets it.
##
## ONE FULL SUITE AT A TIME, MACHINE-WIDE. A run of every test (no name given) waits its turn,
## in arrival order, and says in one line that it waits and behind whom; a run of named tests
## is never queued. The line is one folder on the machine, $HOME/.agents/magic-team/suite-queue,
## never a folder of the package: a runner started from any copy of the package (MDLT_ORIGIN)
## stands in the same line. A ticket is a file named by its arrival time, holding the pid of
## its runner; one whose runner no longer exists is taken out by whoever waits behind it, so
## no turn is held by the dead.
## The hand rule this replaces, `mkdir $MMDAPP/.local/temp/suite-run.lock` around a full suite,
## is kept by both sides, so a session on the hand rule and a queued run never run at once: a
## run at its turn takes that lock itself and gives it back when it ends, and waits while
## another holds it. A lock taken by hand is no turn: one whose note names the folder this
## run's source root is in, under $MMDAPP/.local/temp, is the caller's own, and the run starts
## under it only when its own turn in the line has come, leaving it for the caller to remove;
## with any full suite ahead of it in the line the run is refused, saying so, since the runs
## ahead wait behind that very lock. A lock left by a runner that no longer exists is removed;
## one taken by hand never is.
##
## ONE BUDGET OF TEST WORKERS FOR THE WHOLE MACHINE, shared by every runner, of a full suite
## or of named tests, from any copy of the package: a test takes a worker slot before it
## starts and gives it back when it ends, so the tests running at once on the machine never
## pass the budget, whatever each runner's own number of workers. The budget is half the
## machine's cores unless $HOME/.agents/magic-team/suite-workers/budget holds a number. Slots
## are asked for in arrival order, across runners, so a run of named tests is not starved by
## a full suite; the runner says in one line when a test of its waits, and how many slots
## are in use. A slot is held by the test's own process: one whose process no longer exists
## is given back by whoever asks next. Tests run at a lowered priority (nice 10, or the
## runner's own where that is lower still), so a person's own work on the machine comes first.
## The hand rule the budget replaces, `mkdir $MMDAPP/.local/temp/one-test-run.lock` with a
## file `owner` naming the session's scratch folder around any test run, is honoured for as
## long as any session still holds it: no test takes a slot while another session holds that
## lock, and the runner says whose it is. A run can tell whose it is only by the folder its
## own source root is in, under $MMDAPP/.local/temp: a lock naming that folder is its
## caller's own, and so is any such lock to a run from a tree that is no scratch folder.
##
## THE DRIVER IS HANDED ITS WORKERS, NEVER THE TESTS. lib/parallel starts a job for each line
## it reads and, once as many run as it has workers, waits to be told that one has ended
## before it reads on. It is told through a helper process of its own, and a driver whose
## helper is gone is never told: it waits for ever with no test running, and no job is left
## to wake it (2026-10-13: 192 named tests, 56 run, then more than an hour of standing
## still; the helper of that run was gone, and nothing of the driver looks after it). So the
## driver reads one line for each worker and no more: it starts them all at once and has
## nothing to wait for but their end. Each worker takes the tests of the run list one after
## another, each time the first that no worker has taken, until none is left. A test is
## taken by whoever makes its log, which is made whole or not at all, so no test is run
## twice and none is left out. What runs at once, and the order in which the tests start
## and ask for their slots, are as they were: as many tests as workers, in the order of the
## list.
##
## A RUN THAT STANDS STILL IS ENDED, AND SAYS SO. Every start and every end of a test is
## written in the run folder, and so are each line a test prints and the note, made again
## each minute, that a test waits for a slot. A watch beside the run looks at the folder.
## Once nothing in it has changed for longer than a test may take (-t) and a margin more
## (--stall-margin, default 120 seconds), no test of the run is running and none waits, so
## the run is ended: the driver is stopped with what is left under it, the summary is written
## with what did end, the tests that never ran and those that started and never ended are
## named, in the output and in <run folder>/stalled.txt, and the status is 124. The watch
## counts the time as it goes and never reads it off the clock, so a machine that slept is
## not taken for a run that stood still. A margin under 61 seconds is for a rig alone: a
## test that waits for a slot is seen to wait once a minute. A run whose tests have no time
## limit (-t 0, or no number) has no watch: there is no time by which a test must have ended.
##
## A PASS IS KEPT BY THE CONTENT IT WAS EARNED ON. After a test passes, the pass goes on
## record under a key made from the content of everything the test can read: every file of
## the copy of the package this runner is in (its tests and their fixtures, sh-lib,
## sh-scripts, the skillset, the docs, project.inf, this runner), every file of the tooling's
## other packages under the same source root (myx.distro-*, myx.common), of myx.common as it
## is installed (MYXROOT), and of the member set the environment hands the tests
## (MDAT_SKILLSET_ROOT, which a test started from a scratch copy still reads from the
## workspace), with the shell and the system the tests run under. Paths below those roots
## and content only, never where a root lies: a copy that is byte for byte another shares
## its passes. The key is made before the test starts and again once it has passed, and the
## pass is kept only where the two agree, so a pass on a tree that moved under the test is
## kept for no state. Only a pass is kept: a failure is no record, whatever made the test
## fail. Not in the key: the workspace's own data and the machine's state, which the rigs of
## the tests stand in for. The record is one folder on the machine,
## $HOME/.agents/magic-team/suite-results, a folder for each test and in it a file named by
## the key; a pass is believed for seven days, and every run removes the ones older than
## that, of every test. A run reads none of it and runs what it is told: `--passed` is the
## one reader, for whoever decides what is left to run, as the retest queue does
## (sh-lib/AgentsTools.MemberRetest.include).
##

set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

testDir="$( cd "$( dirname "$0" )" && pwd )"
runWorkers="" runTimeout=900 runPassed="" runStallMargin=120
while [ $# -gt 0 ] ; do
	case "$1" in
		-w|--workers) runWorkers="$2" ; shift 2 ;;
		-t|--timeout) runTimeout="$2" ; shift 2 ;;
		--stall-margin)
			case "$2" in ''|*[!0123456789]*) echo "⛔ ERROR: AgentsRunTests.sh: --stall-margin takes a number of seconds: $2" >&2 ; exit 1 ;; esac
			runStallMargin="$2" ; shift 2
		;;
		--passed) runPassed=1 ; shift ;;
		--) shift ; break ;;
		-*) echo "⛔ ERROR: AgentsRunTests.sh: unknown option: $1" >&2 ; exit 1 ;;
		*) break ;;
	esac
done

runQueueDir="${HOME:-}/.agents/magic-team/suite-queue"
runHandLock="$MMDAPP/.local/temp/suite-run.lock"
runTicket="" runLockMine=""
runSlotDir="${HOME:-}/.agents/magic-team/suite-workers"
runSlotDefault="$( sysctl -n hw.ncpu 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2 )"
case "$runSlotDefault" in ''|*[!0123456789]*) runSlotDefault=2 ;; esac
runSlotDefault=$(( runSlotDefault / 2 ))
[ "$runSlotDefault" -ge 1 ] || runSlotDefault=1
runTestLock="$MMDAPP/.local/temp/one-test-run.lock"
## the folder this run's source root is in, under the workspace's temp: empty for any other tree
runOwnFolder="${MDLT_ORIGIN#"$MMDAPP/.local/temp/"}"
if [ "$runOwnFolder" != "$MDLT_ORIGIN" ] ; then runOwnFolder="${runOwnFolder%%/*}" ; else runOwnFolder="" ; fi

## The slot keeper, one small program for both ends of a slot: every change to the one state
## file ($runSlotDir/state: `H <pid>` a slot held, `W <pid>` one asked for, in arrival order)
## is made under an exclusive lock on $runSlotDir/lock, which the system gives back by itself
## when its holder dies, and an entry whose process no longer exists is dropped at every read.
##   take <dir> <default budget> <fd to say it on> <said marker> <started file> <hand lock> <own folder> <timeout> <command...>
##     asks for a slot as this very process, waits its place in the line, and while another
##     session holds the hand lock, then lowers its priority, sets the test's own time limit
##     and becomes the command: the slot is held by the test's own pid from before it starts
##     until that process is gone.
##   give <dir> <pid>   gives that process's slot back at once, where the runner saw it end.
runSlotKeeper="$( cat <<'RUNSLOTKEEPER'
use strict ; use warnings ; use Fcntl qw( :flock ) ;
my ( $mode, $dir ) = ( shift @ARGV, shift @ARGV ) ;
sub locked {
	my ( $code ) = @_ ;
	open( my $lock, ">>", "$dir/lock" ) or die "AgentsRunTests.sh: cannot open $dir/lock: $!\n" ;
	flock( $lock, LOCK_EX ) or die "AgentsRunTests.sh: cannot lock $dir/lock: $!\n" ;
	my @out = $code->() ;
	close( $lock ) ;
	return @out ;
}
sub alive {
	my ( $pid ) = @_ ;
	return 1 if kill( 0, $pid ) ;
	return $!{EPERM} ? 1 : 0 ;
}
sub load {
	my ( @held, @asked ) ;
	if ( open( my $in, "<", "$dir/state" ) ) {
		while ( my $line = <$in> ) {
			push @held, $1 if $line =~ /^H ([0-9]+)$/ ;
			push @asked, $1 if $line =~ /^W ([0-9]+)$/ ;
		}
		close( $in ) ;
	}
	return ( [ grep { alive( $_ ) } @held ], [ grep { alive( $_ ) } @asked ] ) ;
}
sub save {
	my ( $held, $asked ) = @_ ;
	open( my $out, ">", "$dir/state.$$" ) or die "AgentsRunTests.sh: cannot write $dir/state.$$: $!\n" ;
	print $out map( { "H $_\n" } @$held ), map( { "W $_\n" } @$asked ) ;
	close( $out ) or die "AgentsRunTests.sh: cannot write $dir/state.$$: $!\n" ;
	rename( "$dir/state.$$", "$dir/state" ) or die "AgentsRunTests.sh: cannot replace $dir/state: $!\n" ;
}
if ( $mode eq "give" ) {
	my ( $pid ) = @ARGV ;
	locked( sub {
		my ( $held, $asked ) = load() ;
		save( [ grep { $_ != $pid } @$held ], [ grep { $_ != $pid } @$asked ] ) ;
		return () ;
	} ) ;
	exit 0 ;
}
my ( $default, $say, $said, $started, $hand, $own, $timeout, @command ) = @ARGV ;
## The hand lock, where another session holds it: what that session wrote in it, on one line.
## Held by no other: none held, one naming the folder this run starts from, or any at all for
## a run that starts from no scratch folder and so cannot tell. (No apostrophe in this program:
## it stands in a here-document inside a command substitution, which an old bash reads wrongly.)
sub held_by_another {
	return "" if $own eq "" || ! -d $hand ;
	my $note = "" ;
	for my $file ( glob( "$hand/*" ) ) { if ( open( my $in, "<", $file ) ) { local $/ ; my $text = <$in> ; close( $in ) ; $note .= " $text" if defined $text ; } }
	$note =~ s/\s+/ /g ; $note =~ s/^ | $//g ;
	return "" if grep { $_ eq $own } split( /[^A-Za-z0-9._-]+/, $note ) ;
	return $note eq "" ? "(no owner written in it)" : substr( $note, 0, 200 ) ;
}
while ( 1 ) {
	my ( $got, $used, $budget, $tell, $other ) = locked( sub {
		my ( $held, $asked ) = load() ;
		my $budget = $default ;
		if ( open( my $in, "<", "$dir/budget" ) ) {
			my $set = <$in> ;
			close( $in ) ;
			if ( defined $set ) { $set =~ s/\s+$// ; $budget = $set if $set =~ /^[1-9][0-9]*$/ ; }
		}
		push @$asked, $$ unless grep { $_ == $$ } @$asked ;
		my ( $place ) = grep { $asked->[ $_ ] == $$ } 0 .. $#$asked ;
		my ( $got, $tell ) = ( 0, 0 ) ;
		my $other = held_by_another() ;
		if ( $other eq "" && $place < $budget - @$held ) {
			splice( @$asked, $place, 1 ) ;
			push @$held, $$ ;
			$got = 1 ;
		} else {
			## said once a minute at most for a whole run, whichever of its tests waits
			my @mark = stat( $said ) ;
			if ( ! @mark || time - $mark[ 9 ] >= 60 ) {
				if ( open( my $mark, ">", $said ) ) { close( $mark ) ; }
				$tell = 1 ;
			}
		}
		save( $held, $asked ) ;
		return ( $got, scalar( @$held ), $budget, $tell, $other ) ;
	} ) ;
	last if $got ;
	if ( $tell && open( my $out, ">&", $say ) ) {
		if ( $other ne "" ) {
			print $out "# AgentsRunTests.sh: a test waits: another session holds $hand by hand ($other), and no test starts beside a run that holds it\n" ;
		} else {
			print $out "# AgentsRunTests.sh: a test waits for a worker slot: $used of $budget in use on this machine, the one budget every runner shares ($dir)\n" ;
		}
		close( $out ) ;
	}
	select( undef, undef, undef, 0.2 ) ;
}
if ( open( my $out, ">", $started ) ) { print $out time, "\n" ; close( $out ) ; }
if ( open( my $drop, ">&=", $say ) ) { close( $drop ) ; }
setpriority( 0, 0, 10 ) if getpriority( 0, 0 ) < 10 ;
alarm( $timeout ) ;
exec( @command ) or die "AgentsRunTests.sh: cannot start @command: $!\n" ;
RUNSLOTKEEPER
)"

runPassDir="${HOME:-}/.agents/magic-team/suite-results"
runPassAge=$(( 7 * 86400 ))
## What a pass is keyed by, each `<name>=<folder>`: the copy of the package this runner is
## in, myx.common as it is installed, the member set the environment hands the tests, and the
## tooling's other packages under the source root.
runPassRoots=( "package=$( cd "$testDir/.." && pwd -P )" "myxroot=${MYXROOT:-/usr/local/share/myx.common}" )
[ -z "${MDAT_SKILLSET_ROOT:-}" ] || runPassRoots[${#runPassRoots[@]}]="members=$MDAT_SKILLSET_ROOT"
for runPassRoot in "$MDLT_ORIGIN"/myx/myx.distro-* "$MDLT_ORIGIN"/myx/myx.common ; do
	[ -d "$runPassRoot" ] || continue
	[ "$( cd "$runPassRoot" 2>/dev/null && pwd -P )" != "${runPassRoots[0]#package=}" ] || continue
	runPassRoots[${#runPassRoots[@]}]="tooling/${runPassRoot##*/}=$runPassRoot"
done
runPassWith="bash $BASH_VERSION, $( uname -srm 2>/dev/null )"

## The pass keeper, the one maker of a key and the one reader of the record.
##   key <dir> <age seconds> <what the tests run under> <name>=<folder>... -- <test>...
##     prints for each test `<test> <key> <when>`: the key of the state it would run on now,
##     and the time of the pass on record under it, where one younger than the age is; `-`
##     for a key that cannot be made (a file that cannot be read, or one gone mid-read: no
##     key, so no pass is kept or found), and for no pass. A root is every file below it,
##     links followed and .git left out, by its path below the root, whether it may be run,
##     and its content.
##   prune <dir> <age seconds>   removes every record older than the age, of every test.
## (No apostrophe in this program either, for the reason the slot keeper gives.)
runPassKeeper="$( cat <<'RUNPASSKEEPER'
use strict ; use warnings ; use Digest::SHA ; use File::Find ; use Cwd qw( realpath ) ;
my ( $mode, $dir, $age ) = ( shift @ARGV, shift @ARGV, shift @ARGV ) ;
sub entries {
	my ( $in ) = @_ ;
	opendir( my $list, $in ) or return () ;
	my @names = grep { $_ ne "." && $_ ne ".." } readdir( $list ) ;
	closedir( $list ) ;
	return @names ;
}
if ( $mode eq "prune" ) {
	for my $test ( entries( $dir ) ) {
		next unless -d "$dir/$test" ;
		for my $file ( entries( "$dir/$test" ) ) {
			my @at = stat( "$dir/$test/$file" ) ;
			unlink( "$dir/$test/$file" ) if @at && time - $at[ 9 ] >= $age ;
		}
		rmdir( "$dir/$test" ) ;
	}
	exit 0 ;
}
sub digest {
	my ( $root ) = @_ ;
	my $real = realpath( $root ) ;
	return "none" unless defined $real && -d $real ;
	my %found ;
	find( { follow_fast => 1, follow_skip => 2, no_chdir => 1, dangling_symlinks => 0, wanted => sub {
		my $path = $File::Find::name ;
		if ( -d $path ) { $File::Find::prune = 1 if $path =~ m{/\.git$} ; return ; }
		$found{ substr( $path, length( $real ) + 1 ) } = $path ;
	} }, $real ) ;
	my $all = Digest::SHA->new( 256 ) ;
	for my $name ( sort keys %found ) {
		my @at = stat( $found{ $name } ) ;
		my $content = ( @at && -f _ ) ? Digest::SHA->new( 256 )->addfile( $found{ $name } )->hexdigest : "gone" ;
		$all->add( $name . "\0" . ( ( @at && ( $at[ 2 ] & 0111 ) ) ? "x" : "-" ) . "\0" . $content . "\n" ) ;
	}
	return $all->hexdigest ;
}
my ( $with, @rest ) = @ARGV ;
my ( @roots, @tests ) ;
while ( @rest ) {
	my $word = shift @rest ;
	if ( $word eq "--" ) { @tests = @rest ; last ; }
	push @roots, $word ;
}
my $state = eval {
	my $text = "AgentsRunTests.sh pass v1\n" ;
	for my $root ( sort @roots ) {
		my ( $name, $folder ) = split( /=/, $root, 2 ) ;
		$text .= "$name " . digest( $folder ) . "\n" ;
	}
	$text . "with $with\n" ;
} ;
for my $test ( @tests ) {
	my ( $key, $when ) = ( "-", "-" ) ;
	if ( defined $state ) {
		$key = Digest::SHA::sha256_hex( $state . "test $test\n" ) ;
		my @at = stat( "$dir/$test/$key" ) ;
		if ( @at && time - $at[ 9 ] < $age && open( my $in, "<", "$dir/$test/$key" ) ) {
			while ( my $line = <$in> ) { $when = $1 if $line =~ /^passed=([0-9TZ:-]+)$/ ; }
			close( $in ) ;
		}
	}
	print "$test $key $when\n" ;
}
RUNPASSKEEPER
)"
AgentsRunPassKey(){ ## test name... -- for each, on a line: the test, the key of the state it would run on now, when it passed on that state
	perl -e "$runPassKeeper" key "$runPassDir" "$runPassAge" "$runPassWith" "${runPassRoots[@]}" -- "$@" 2>/dev/null
}
AgentsRunPassKeep(){ ## test name, key, seconds -- that pass on record, whole or not at all
	mkdir -p "$runPassDir/$1" 2>/dev/null || return 1
	printf 'passed=%s\nseconds=%s\norigin=%s\n' "$( date -u +%Y-%m-%dT%H:%M:%SZ )" "$3" "$MDLT_ORIGIN" > "$runPassDir/$1/.$2.$$" 2>/dev/null \
		&& mv -f "$runPassDir/$1/.$2.$$" "$runPassDir/$1/$2" 2>/dev/null || { rm -f "$runPassDir/$1/.$2.$$" 2>/dev/null ; return 1 ; }
}
AgentsRunNames(){ ## name-substring... -- the tests of this copy, one on a line: every *.test.sh, or those whose name contains any of the substrings
	local namesTest namesName namesWant namesPick
	for namesTest in "$testDir"/*.test.sh ; do
		namesName="$( basename "$namesTest" .test.sh )"
		if [ $# -gt 0 ] ; then
			namesPick=""
			for namesWant in "$@" ; do
				case "$namesName" in *"$namesWant"*) namesPick=1 ;; esac
			done
			[ -n "$namesPick" ] || continue
		fi
		printf '%s\n' "$namesName"
	done
}
## Asked what has passed, it runs nothing, stands in no line and makes no run folder.
if [ -n "$runPassed" ] ; then
	runPassedNames=()
	while IFS= read -r runName ; do
		[ -z "$runName" ] || runPassedNames[${#runPassedNames[@]}]="$runName"
	done <<< "$( AgentsRunNames "$@" )"
	[ ${#runPassedNames[@]} -gt 0 ] || { echo "⛔ ERROR: AgentsRunTests.sh: no test matches" >&2 ; exit 1 ; }
	runPassedLines="$( AgentsRunPassKey "${runPassedNames[@]}" )"
	## no keeper, no key: nothing is known to have passed
	[ -n "$runPassedLines" ] || runPassedLines="$( printf '%s - -\n' "${runPassedNames[@]}" )"
	printf '%s\n' "$runPassedLines" | LC_ALL=C cut -d' ' -f1,3
	exit 0
fi

AgentsRunRunnerAlive(){ ## pid -- rc 0 while a process of that pid is running this runner
	case "$1" in ''|*[!0123456789]*) return 1 ;; esac
	case "$( ps -p "$1" -ww -o args= 2>/dev/null )" in *AgentsRunTests.sh*) return 0 ;; esac
	return 1
}
AgentsRunHandLockNote(){ ## -- what the hand lock's holder wrote in it, on one line
	local noteText
	noteText="$( cat "$runHandLock"/* 2>/dev/null | LC_ALL=C tr '\n' ' ' | LC_ALL=C cut -c1-240 )"
	noteText="${noteText% }"
	printf '%s' "${noteText:-(no note in it)}"
}
AgentsRunHandLockOwn(){ ## -- rc 0 when the lock was taken by hand by this run's own caller, for this run
	local ownFolder="${MDLT_ORIGIN#"$MMDAPP/.local/temp/"}"
	[ "$ownFolder" != "$MDLT_ORIGIN" ] || return 1
	ownFolder="${ownFolder%%/*}"
	[ -n "$ownFolder" ] || return 1
	! LC_ALL=C grep -q '^runner-pid: ' "$runHandLock"/* 2>/dev/null || return 1
	case " $( cat "$runHandLock"/* 2>/dev/null | LC_ALL=C tr -c 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-' ' ' ) " in
		*" $ownFolder "*) return 0 ;;
	esac
	return 1
}
AgentsRunQueueLeave(){ ## -- out of the line, and the lock given back where this run took it
	[ -z "$runTicket" ] || rm -f "$runQueueDir/$runTicket"
	[ -z "$runLockMine" ] || { rm -f "$runHandLock/holder.txt" ; rmdir "$runHandLock" 2>/dev/null ; }
	runTicket="" ; runLockMine=""
}
AgentsRunQueueTurn(){ ## -- stands in the line and returns at this run's turn; says whom it waits behind, each time that changes
	local turnStamp turnFile turnPid turnWhom turnAhead turnSaid=""
	mkdir -p "$runQueueDir" 2>/dev/null || {
		echo "⛔ ERROR: AgentsRunTests.sh: cannot create the machine's line for full suites: $runQueueDir -- a full suite is not run outside its turn; name the tests to run some without one" >&2 ; exit 1
	}
	turnStamp="$( perl -MTime::HiRes=time -e 'printf "%017.6f", time' 2>/dev/null )" || turnStamp=""
	[ -n "$turnStamp" ] || turnStamp="$( date +%s ).000000"
	runTicket="$turnStamp.$$.ticket"
	trap AgentsRunQueueLeave EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM HUP
	## whole or not at all: a ticket half written would read as one of no runner
	printf 'pid=%s\norigin=%s\nsince=%s\n' "$$" "$MDLT_ORIGIN" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$runQueueDir/.$runTicket" \
		&& mv -f "$runQueueDir/.$runTicket" "$runQueueDir/$runTicket" || {
		echo "⛔ ERROR: AgentsRunTests.sh: cannot stand in the machine's line for full suites: $runQueueDir" >&2 ; exit 1
	}
	while : ; do
		turnWhom="" ; turnAhead=0
		for turnFile in "$runQueueDir"/*.ticket ; do
			[ -f "$turnFile" ] || continue
			[ "${turnFile##*/}" \< "$runTicket" ] || continue
			turnPid="$( LC_ALL=C sed -n 's/^pid=//p' "$turnFile" 2>/dev/null | LC_ALL=C sed -n 1p )"
			if ! AgentsRunRunnerAlive "$turnPid" ; then
				rm -f "$turnFile" ; continue
			fi
			turnAhead=$(( turnAhead + 1 ))
			[ -n "$turnWhom" ] || turnWhom="the run of pid $turnPid from $( LC_ALL=C sed -n 's/^origin=//p' "$turnFile" 2>/dev/null | LC_ALL=C sed -n 1p ), in line since $( LC_ALL=C sed -n 's/^since=//p' "$turnFile" 2>/dev/null | LC_ALL=C sed -n 1p )"
		done
		## Taken by hand by this run's own caller: no turn of its own. With nobody ahead the
		## run's turn has come and it starts under that lock; with anyone ahead it is refused,
		## since each of them waits behind that lock and this run would wait behind them.
		if [ -d "$runHandLock" ] && AgentsRunHandLockOwn ; then
			[ "$turnAhead" != 0 ] || return 0
			echo "⛔ ERROR: AgentsRunTests.sh: not started: this run's caller holds $runHandLock by hand, and its turn in the machine's line has not come: $turnAhead full suite(s) stand ahead of it, the first $turnWhom. A lock taken by hand is no turn. Remove it and run again: the run waits its turn by itself, and takes the lock itself when that comes." >&2
			exit 1
		fi
		if [ -z "$turnWhom" ] ; then
			if mkdir "$runHandLock" 2>/dev/null ; then
				runLockMine=1
				printf 'runner-pid: %s\nagent: AgentsRunTests.sh, a full suite from %s\ntaken: %s\n' "$$" "$MDLT_ORIGIN" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$runHandLock/holder.txt"
				return 0
			fi
			turnPid="$( LC_ALL=C sed -n 's/^runner-pid: //p' "$runHandLock/holder.txt" 2>/dev/null | LC_ALL=C sed -n 1p )"
			if [ -n "$turnPid" ] && ! AgentsRunRunnerAlive "$turnPid" ; then
				rm -f "$runHandLock/holder.txt" ; rmdir "$runHandLock" 2>/dev/null
				continue
			fi
			turnWhom="the lock $runHandLock, taken by hand and held by: $( AgentsRunHandLockNote ) -- where that was done for this very run, remove it: the run takes the turn itself"
		fi
		if [ "$turnWhom" != "$turnSaid" ] ; then
			echo "# AgentsRunTests.sh: one full suite runs on this machine at a time -- this one waits its turn behind $turnWhom" >&2
			turnSaid="$turnWhom"
		fi
		sleep 2
	done
}
## No name given is the whole suite, and that waits its turn.
[ $# -gt 0 ] || AgentsRunQueueTurn

runRoot="$MMDAPP/.local/temp/mdat-tests"
runDir="$runRoot/$( date -u +%Y%m%dT%H%M%SZ )"
## A folder of its own: a run started in the same second as another takes its pid into the name,
## since two runs in one folder would each run the other's list and overwrite its logs.
mkdir -p "$runRoot" 2>/dev/null
mkdir "$runDir" 2>/dev/null || { runDir="$runDir-$$" ; mkdir -p "$runDir" ; } || { echo "⛔ ERROR: AgentsRunTests.sh: cannot create $runDir" >&2 ; exit 1 ; }
ln -sfn "$runDir" "$runRoot/latest" 2>/dev/null || :

runList="$runDir/tests.list"
AgentsRunNames "$@" | while IFS= read -r runName ; do
	printf '%s %s\n' "$runName" "$runTimeout"
done > "$runList"
runCount="$( grep -c . "$runList" )"
[ "$runCount" -gt 0 ] || { echo "⛔ ERROR: AgentsRunTests.sh: no test matches" >&2 ; exit 1 ; }

AgentsRunOneTest(){ ## test name, timeout seconds -- one task line of the run list
	local oneName="$1" oneTimeout="${2:-$runTimeout}" oneStart oneEnd oneRc=0 oneLast onePid oneKey oneAfter oneKept=""
	## the state this test starts on, for the pass it may earn (the pass record, above)
	oneKey="$( AgentsRunPassKey "$oneName" | LC_ALL=C cut -d' ' -f2 )"
	oneStart="$( date +%s )"
	## The test's own process asks for its worker slot, waits for it, and only then becomes
	## the test (the slot keeper, above); fd 8 is this runner's own output, for the one line
	## it says while a test waits, and the test never sees it.
	(
		## nothing of the session this runner was started in reaches the test (the test-only identity, above)
		unset ${!MDAT_SPAWN_@} ${!MDAT_SESSION_@} MDAT_CONVERSATION_THREADS harnessSessionId harnessAgent
		export CLAUDE_CODE_SESSION_ID="rig-run-$oneName-test-only"
		export MDAT_WAIT_REMIND=off
		cd "$testDir" || exit 1
		exec perl -e "$runSlotKeeper" take "$runSlotDir" "$runSlotDefault" 8 "$runDir/slot-wait.said" "$runDir/$oneName.started" "$runTestLock" "$runOwnFolder" "$oneTimeout" bash "$testDir/$oneName.test.sh"
	) 8>&2 > "$runDir/$oneName.log" 2>&1 &
	onePid=$!
	wait "$onePid" || oneRc=$?
	perl -e "$runSlotKeeper" give "$runSlotDir" "$onePid" 2>/dev/null || :
	## its time is counted from when it got its slot, not from when it asked
	[ ! -s "$runDir/$oneName.started" ] || IFS= read -r oneStart < "$runDir/$oneName.started"
	rm -f "$runDir/$oneName.started"
	oneEnd="$( date +%s )"
	oneLast="$( grep . "$runDir/$oneName.log" | tail -n 1 )"
	## kept only where the state is, now that the test has passed, the one it started on; the receipt says which it was
	if [ "$oneRc" = 0 ] ; then
		oneAfter="$( AgentsRunPassKey "$oneName" | LC_ALL=C cut -d' ' -f2 )"
		case "$oneKey:$oneAfter" in
			:*|-:*|*:|*:-) oneKept="not-kept=no key could be made for the state it ran on" ;;
			"$oneAfter:$oneAfter")
				if AgentsRunPassKeep "$oneName" "$oneKey" "$(( oneEnd - oneStart ))" ; then oneKept="kept=$oneKey" ; else oneKept="not-kept=the record could not be written in $runPassDir" ; fi
			;;
			*) oneKept="not-kept=the state it ran on changed while it ran: from $oneKey to $oneAfter" ;;
		esac
	fi
	printf 'rc=%s\nseconds=%s\nlast=%s\n' "$oneRc" "$(( oneEnd - oneStart ))" "$oneLast" > "$runDir/$oneName.receipt"
	[ -z "$oneKept" ] || printf '%s\n' "$oneKept" >> "$runDir/$oneName.receipt"
	if [ "$oneRc" = 0 ] ; then
		printf 'PASS  %-48s %4ss  %s\n' "$oneName" "$(( oneEnd - oneStart ))" "$oneLast"
	else
		printf 'FAIL  %-48s %4ss  rc=%s  %s\n' "$oneName" "$(( oneEnd - oneStart ))" "$oneRc" "$oneLast"
	fi
}

AgentsRunWorker(){ ## worker number -- one task line of the driver: the tests of the run list one after another, each the first no worker has taken, until none is left
	local workerName workerTimeout
	while read -r workerName workerTimeout ; do
		[ -n "$workerName" ] || continue
		## taken by whoever makes its log: made by one worker or not at all, never by two
		( set -C ; printf '' > "$runDir/$workerName.log" ) 2>/dev/null || continue
		AgentsRunOneTest "$workerName" "$workerTimeout" < /dev/null || :
	done < "$runList"
	return 0
}

## The stall keeper: what the run folder holds now, on one line: the time of its newest entry,
## how many entries it has, and how many of them are receipts. The watch compares two of these
## lines and nothing else. (No apostrophe in this program, for the reason the slot keeper gives.)
runStallKeeper="$( cat <<'RUNSTALLKEEPER'
use strict ; use warnings ;
my ( $dir ) = @ARGV ;
opendir( my $list, $dir ) or exit 1 ;
my ( $newest, $entries, $receipts ) = ( 0, 0, 0 ) ;
for my $name ( readdir( $list ) ) {
	next if $name eq "." || $name eq ".." ;
	my @at = stat( "$dir/$name" ) or next ;
	$entries++ ;
	$receipts++ if $name =~ /\.receipt$/ ;
	$newest = $at[ 9 ] if $at[ 9 ] > $newest ;
}
closedir( $list ) ;
print "$newest $entries $receipts\n" ;
RUNSTALLKEEPER
)"
AgentsRunStallEnd(){ ## seconds the run has stood still -- the note of it, for the summary, and the driver ended with what is left under it
	local endSelf endSignal endPid
	## from here the watch is not told to go any more: it ends the run, and then itself
	trap '' TERM
	printf 'stood-still=%s\ntimeout=%s\nmargin=%s\nended=%s\n' "$1" "$runTimeout" "$runStallMargin" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$runDir/stalled.txt" || { rm -f "$runDir/stalled.txt" ; return 1 ; }
	## The driver is the first process of the pipeline, a child of this runner as the watch is,
	## and the tee after it ends by itself once nothing writes to it. The driver is told to end,
	## so it removes what it made; what is under it is ended outright, a stopped process too.
	## The pids are read and signalled in one go: none is kept for later, when its number may
	## be another process's.
	endSelf="$( exec sh -c 'echo "$PPID"' )"
	ps -A -o pid= -o ppid= -o comm= 2>/dev/null | LC_ALL=C awk -v root="$$" -v self="$endSelf" '
		{ ppid[ $1 ] = $2 ; name[ $1 ] = $3 }
		END {
			for ( pid in ppid ) {
				if ( pid == self || pid == root ) continue
				top = pid ; hops = 0
				while ( ( top in ppid ) && ppid[ top ] != root && top != self && hops++ < 64 ) top = ppid[ top ]
				if ( ! ( top in ppid ) || ppid[ top ] != root || top == self || name[ top ] ~ /(^|\/)tee$/ ) continue
				if ( top == pid ) first = first "TERM " pid "\n" ; else rest = rest "KILL " pid "\n"
			}
			printf "%s%s", first, rest
		}' | while read -r endSignal endPid ; do kill "-$endSignal" "$endPid" 2>/dev/null ; done
	return 0
}
AgentsRunStallWatch(){ ## -- beside the run for as long as it lasts: once nothing in the run folder has changed for longer than a test may take and the margin, the run is ended as stalled (A RUN THAT STANDS STILL, above)
	local watchLimit=$(( 10#$runTimeout + 10#$runStallMargin )) watchEvery watchSleep="" watchSeen="" watchNow watchStill=0
	watchEvery=$(( watchLimit / 10 )) ; [ "$watchEvery" -ge 1 ] || watchEvery=1 ; [ "$watchEvery" -le 20 ] || watchEvery=20
	trap '[ -z "$watchSleep" ] || kill "$watchSleep" 2>/dev/null ; exit 0' TERM
	while : ; do
		## its own sleep holds none of the runner's output, and goes with the watch
		sleep "$watchEvery" > /dev/null 2>&1 < /dev/null &
		watchSleep=$! ; wait "$watchSleep" ; watchSleep=""
		## a runner that is gone has nobody to tell
		kill -0 "$$" 2>/dev/null || return 0
		watchNow="$( perl -e "$runStallKeeper" "$runDir" 2>/dev/null )"
		[ -n "$watchNow" ] || continue
		if [ "$watchNow" != "$watchSeen" ] ; then watchSeen="$watchNow" ; watchStill=0 ; continue ; fi
		watchStill=$(( watchStill + watchEvery ))
		[ "$watchStill" -gt "$watchLimit" ] || continue
		AgentsRunStallEnd "$watchStill" || :
		return 0
	done
}

. "${MYXROOT:-/usr/local/share/myx.common}/bin/lib/parallel.Common" || {
	echo "⛔ ERROR: AgentsRunTests.sh: myx.common lib/parallel is not available" >&2 ; exit 1
}
mkdir -p "$runSlotDir" 2>/dev/null && [ -w "$runSlotDir" ] || {
	echo "⛔ ERROR: AgentsRunTests.sh: cannot use the machine's budget of test workers: $runSlotDir -- no test is run outside it" >&2 ; exit 1
}

echo "# AgentsRunTests.sh: $runCount test(s), workers ${runWorkers:-lib/parallel default}, timeout ${runTimeout}s, run folder: $runDir" >&2
runStart="$( date +%s )"
## as many workers as the driver would run at once, and a line of the driver for each, never more lines than tests (THE DRIVER IS HANDED ITS WORKERS, above)
runWorkerCount="${runWorkers:-${ENV_PARALLEL_WORKER_COUNT:-4}}"
runWorkerLines="$runCount"
case "$runWorkerCount" in ''|*[!0123456789]*) ;; *) [ "$runWorkerCount" -ge "$runCount" ] || runWorkerLines="$runWorkerCount" ;; esac
runWorkerList=""
for (( runWorker = 1 ; runWorker <= runWorkerLines ; runWorker++ )) ; do runWorkerList="$runWorkerList${runWorkerList:+$'\n'}$runWorker" ; done
## no time limit for a test, no time to hold a run to; the watch says nothing itself, so it holds none of this runner's output
runStallPid=""
case "$runTimeout" in ''|*[!0123456789]*) ;; *) [ "$(( 10#$runTimeout ))" = 0 ] || { AgentsRunStallWatch > /dev/null 2>&1 & runStallPid=$! ; } ;; esac
Parallel --workers "$runWorkerCount" AgentsRunWorker <<< "$runWorkerList" | tee "$runDir/progress.txt"
## The run has ended: by itself, and the watch is told to go; or by the watch, which hears nothing while it ends
## the run, and is waited for. It is told only while this shell knows it to be running, never by a pid kept for later.
runStalled="" runNever="" runNeverCount=0 runOpen="" runOpenCount=0
if [ -n "$runStallPid" ] ; then
	case " $( jobs -pr | LC_ALL=C tr '\n' ' ' )" in *" $runStallPid "*) kill "$runStallPid" 2>/dev/null ;; esac
	wait "$runStallPid" 2>/dev/null
fi
if [ -f "$runDir/stalled.txt" ] ; then
	runStalled="$( sed -n 's/^stood-still=//p' "$runDir/stalled.txt" | sed -n 1p )" ; runStalled="${runStalled:-?}"
	for runName in $( cut -d' ' -f1 "$runList" ) ; do
		[ ! -f "$runDir/$runName.receipt" ] || continue
		if [ -f "$runDir/$runName.log" ] ; then runOpen="$runOpen $runName" ; runOpenCount=$(( runOpenCount + 1 ))
		else runNever="$runNever $runName" ; runNeverCount=$(( runNeverCount + 1 )) ; fi
	done
	printf 'never-ran=%s\nnever-ended=%s\n' "${runNever# }" "${runOpen# }" >> "$runDir/stalled.txt"
fi

{
	for runName in $( cut -d' ' -f1 "$runList" ) ; do
		runRc="$( sed -n 's/^rc=//p' "$runDir/$runName.receipt" 2>/dev/null )"
		if [ "${runRc:-x}" = 0 ] ; then echo "PASS $runName" ; else echo "FAIL $runName rc=${runRc:-none}" ; fi
	done | sort -k1,1 -k2,2
	runPass="$( grep -l '^rc=0$' "$runDir"/*.receipt 2>/dev/null | wc -l | tr -d ' ' )"
	[ -z "$runStalled" ] || echo "STALLED  never ran $runNeverCount  never ended $runOpenCount"
	echo "TOTAL $runCount  PASS $runPass  FAIL $(( runCount - runPass ))  WALL $(( $( date +%s ) - runStart ))s"
} > "$runDir/summary.txt"
perl -e "$runPassKeeper" prune "$runPassDir" "$runPassAge" 2>/dev/null || :

echo "---" >&2
grep '^FAIL' "$runDir/summary.txt" || :
tail -n 1 "$runDir/summary.txt"
if [ -n "$runStalled" ] ; then
	echo "⛔ ERROR: AgentsRunTests.sh: this run stood still and was ended as stalled: nothing of it started, ended or wrote a line for ${runStalled}s, longer than a test may take (${runTimeout}s) and ${runStallMargin}s more, so no test of it was running and none waited for a worker slot. Never ran, $runNeverCount of $runCount test(s):${runNever:- none}. Started and never ended, $runOpenCount:${runOpen:- none}. What did end is in $runDir/summary.txt, and the note of this in $runDir/stalled.txt" >&2
	exit 124
fi
grep -q '^FAIL' "$runDir/summary.txt" && exit 1
exit 0
