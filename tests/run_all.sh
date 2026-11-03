#!/usr/bin/env bash
# Runs the checks that need Godot side by side, each with its own user:// folder (saves,
# settings.cfg) so they do not see each other's files, then prints each log in turn with
# its time and fails if any of them failed. frame_test measures frame times, so it runs by
# itself after the others; server_test listens on a port of its own (7791). Run from the
# repo root after --import:
#     tests/run_all.sh                       all of them
#     tests/run_all.sh run_tests save_test   only these, side by side
# The checks: parse (every script compiles), validate (the mods' data), report (the content
# reports in docs/generated are fresh), run_tests, save_test, progress_hunting and
# progress_other (the two halves of progress_test, see its --part), progress_test (the whole
# way in one run), server_test, frame_test.
# GODOT=path/to/godot if it is not on PATH; LOGS=dir keeps each check's log there (CI
# uploads them); in GitHub Actions the times and results also go to the job's summary.
set -u
godot=${GODOT:-godot}
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
declare -A script=(
	[parse]=tools/parse_check.gd [validate]=tools/validate.gd [report]=tools/content_report.gd
	[run_tests]=tests/run_tests.gd [save_test]=tests/save_test.gd [progress_test]=tests/progress_test.gd
	[progress_hunting]=tests/progress_test.gd [progress_other]=tests/progress_test.gd
	[frame_test]=tests/frame_test.gd [server_test]=tests/server_test.gd)
declare -A args=([report]=--check [progress_hunting]="--part hunting" [progress_other]="--part other")
declare -A limit=([parse]=120 [validate]=120 [report]=120 [run_tests]=300 [save_test]=300 [progress_test]=1500
	[progress_hunting]=1200 [progress_other]=1200 [frame_test]=600 [server_test]=300)
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
		cat "$out/$n.log"
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
		counts=$(grep -E '[0-9]+ checks, [0-9]+ fail|^content OK|content problems|scripts, [0-9]+ do not|^content reports|stale' "$out/$n.log" | tail -1)
		summary+=("| $n | $secs | $result | ${counts//|/\\|} |")
		if [ "$result" != passed ]; then
			[ -n "${GITHUB_ACTIONS:-}" ] && echo "::error title=$n $result::$(grep -m1 -E '^FAIL|^content:|ERROR' "$out/$n.log" | head -c 300)"
			grep -E '^FAIL' "$out/$n.log" | head -10 | sed 's/^/    /' >>"$out/fails.txt"
		fi
		if [ -n "${LOGS:-}" ]; then
			mkdir -p "$LOGS" && cp "$out/$n.log" "$LOGS/$n.log"
		fi
	done
}

if [ $# -gt 0 ]; then
	batch "$@"
else
	batch parse validate report run_tests save_test progress_hunting progress_other server_test
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
	echo "Failed: ${failed[*]}"
	[ -n "${GITHUB_ACTIONS:-}" ] && echo "::error::Failed: ${failed[*]}"
	exit 1
fi
echo "All passed"
