#!/usr/bin/env bash
# Runs the checks that need Godot side by side, each with its own user:// folder (saves,
# settings.cfg) so they do not see each other's files, then prints each log in turn with
# its time and fails if any of them failed. frame_test measures frame times, so it runs by
# itself after the others; server_test listens on a port of its own (7791). Run from the
# repo root after --import:
#     tests/run_all.sh                       all of them
#     tests/run_all.sh run_tests save_test   only these, side by side
# The checks: parse (every script compiles), validate (the mods' data), report (the content
# reports in docs/generated are fresh), balance (the balance tables in docs/balance are fresh), run_tests, save_test, progress_hunting and
# progress_other (the two halves of progress_test, see its --part), progress_test (the whole
# way in one run), server_test, frame_test.
# GODOT=path/to/godot if it is not on PATH; LOGS=dir keeps each check's log there (CI
# uploads them); in GitHub Actions the times and results also go to the job's summary.
# Quiet by default outside GitHub Actions: one line per check (time, exit code, counts), the
# FAIL / SCRIPT ERROR lines of a check that did not pass, and the full logs in LOGS (default
# logs/, which git ignores). VERBOSE=1, or GITHUB_ACTIONS, prints every full log as before,
# and after them the failing checks' FAIL / SCRIPT ERROR lines again (`What failed:`).
set -u
verbose=
if [ -n "${VERBOSE:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then verbose=1; fi
if [ -z "$verbose" ]; then LOGS=${LOGS:-logs}; fi
godot=${GODOT:-godot}
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
declare -A script=(
	[parse]=tools/parse_check.gd [validate]=tools/validate.gd [report]=tools/content_report.gd [balance]=tools/balance_report.gd
	[run_tests]=tests/run_tests.gd [save_test]=tests/save_test.gd [progress_test]=tests/progress_test.gd
	[progress_hunting]=tests/progress_test.gd [progress_other]=tests/progress_test.gd
	[frame_test]=tests/frame_test.gd [server_test]=tests/server_test.gd)
declare -A args=([report]=--check [balance]=--check [progress_hunting]="--part hunting" [progress_other]="--part other")
declare -A limit=([parse]=120 [validate]=120 [report]=120 [balance]=120 [run_tests]=300 [save_test]=300 [progress_test]=2400
	[progress_hunting]=1500 [progress_other]=1500 [frame_test]=600 [server_test]=300)
failed=()
summary=()

# Runs the named checks at once and prints their logs.
batch() {
	for n in "$@"; do
		[ -n "${script[$n]:-}" ] || { echo "unknown check $n (one of: ${!script[*]})"; exit 2; }
		mkdir -p "$out/$n.data"
		(
			start=$SECONDS
			# shellcheck disable=SC2086 # the arguments are words
			XDG_DATA_HOME="$out/$n.data" timeout "${limit[$n]}" "$godot" --headless --path . \
				--script "res://${script[$n]}" ${args[$n]:+-- ${args[$n]}} >"$out/$n.log" 2>&1
			echo "$? $((SECONDS - start))" >"$out/$n.code"
		) &
	done
	wait
	for n in "$@"; do
		read -r code secs <"$out/$n.code"
		if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::group::$n: $secs s, exit $code"; else echo "=== $n: $secs s, exit $code"; fi
		[ -n "$verbose" ] && cat "$out/$n.log"
		[ -n "${GITHUB_ACTIONS:-}" ] && echo "::endgroup::"
		local result=passed
		if [ "$code" = 124 ]; then
			echo "$n: timed out after ${limit[$n]} s"
			result="timed out after ${limit[$n]} s"
			failed+=("$n")
		elif [ "$code" != 0 ]; then
			result="failed (exit $code)"
			failed+=("$n")
		elif grep -q 'SCRIPT ERROR' "$out/$n.log"; then
			# A runtime error aborts the function it is in, and the test goes on without
			# the checks after it: the exit code alone does not show it.
			echo "$n: script errors in the log:"
			grep -A2 'SCRIPT ERROR' "$out/$n.log" | head -20
			result="script errors"
			failed+=("$n")
		fi
		# The line of counts each check ends with ("3211 checks, 0 failed", "content OK: …").
		local counts
		counts=$(grep -E '[0-9]+ checks, [0-9]+ fail|^content OK|content problems|scripts, [0-9]+ do not|^content reports|stale|^fresh' "$out/$n.log" | tail -1)
		summary+=("| $n | $secs | $result | ${counts//|/\\|} |")
		[ -z "$verbose" ] && [ -n "$counts" ] && echo "    $counts"
		if [ "$result" != passed ]; then
			[ -n "${GITHUB_ACTIONS:-}" ] && echo "::error title=$n $result::$(grep -m1 -E '^FAIL|^content:|ERROR' "$out/$n.log" | head -c 300)"
			{
				echo "$n: $result"
				grep -E '^FAIL' "$out/$n.log" | head -10
				grep -A2 'SCRIPT ERROR' "$out/$n.log" | head -12
				[ "$code" = 124 ] && tail -5 "$out/$n.log"
			} | sed 's/^/    /' >>"$out/fails.txt"
			if [ -z "$verbose" ]; then
				grep -E -A2 '^FAIL|SCRIPT ERROR|^content:|^ERROR' "$out/$n.log" | head -30
				echo "    full log: ${LOGS}/$n.log"
			fi
		fi
		if [ -n "${LOGS:-}" ]; then
			mkdir -p "$LOGS" && cp "$out/$n.log" "$LOGS/$n.log"
		fi
	done
}

if [ $# -gt 0 ]; then
	batch "$@"
else
	batch parse validate report balance run_tests save_test progress_hunting progress_other server_test
	batch frame_test
fi
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
	{
		echo "| check | s | result | counts |"
		echo "|---|---|---|---|"
		printf '%s\n' "${summary[@]}"
		if [ -s "$out/fails.txt" ]; then
			echo
			echo '```'
			cat "$out/fails.txt"
			echo '```'
		fi
	} >>"$GITHUB_STEP_SUMMARY"
fi
if [ ${#failed[@]} -gt 0 ]; then
	# Again at the very end: printed whole, the logs after a failing check's (server_test's is
	# ~13k lines) push its FAIL lines out of the last 5000 lines a job's log is read by.
	if [ -n "$verbose" ] && [ -s "$out/fails.txt" ]; then
		echo "What failed:"
		cat "$out/fails.txt"
	fi
	echo "Failed: ${failed[*]}"
	[ -n "${GITHUB_ACTIONS:-}" ] && echo "::error::Failed: ${failed[*]}"
	exit 1
fi
echo "All passed"
