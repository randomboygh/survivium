#!/usr/bin/env bash
# Runs the content check, the check that the content reports are fresh and the headless
# tests side by side, each with its own user:// folder (saves, settings.cfg) so they do not
# see each other's files, then prints each log in turn and fails if any of them failed.
# frame_test measures frame times, so it runs by itself after the others; server_test
# listens on a port of its own (7791). Run from the repo root after --import:
#     tests/run_all.sh                     all of them
#     tests/run_all.sh run_tests save_test only these, side by side
# GODOT=path/to/godot if it is not on PATH.
set -u
godot=${GODOT:-godot}
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
declare -A script=(
	[validate]=tools/validate.gd [report]=tools/content_report.gd [run_tests]=tests/run_tests.gd
	[save_test]=tests/save_test.gd [progress_test]=tests/progress_test.gd [frame_test]=tests/frame_test.gd
	[server_test]=tests/server_test.gd)
declare -A args=([report]=--check)
declare -A limit=([validate]=120 [report]=120 [run_tests]=300 [save_test]=300 [progress_test]=600 [frame_test]=600
	[server_test]=300)
failed=()

# Runs the named checks at once and prints their logs.
batch() {
	for n in "$@"; do
		[ -n "${script[$n]:-}" ] || { echo "unknown check $n"; exit 2; }
		mkdir -p "$out/$n.data"
		(
			start=$SECONDS
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
		[ "$code" = 0 ] || failed+=("$n")
	done
}

if [ $# -gt 0 ]; then
	batch "$@"
else
	batch validate report run_tests save_test progress_test server_test
	batch frame_test
fi
if [ ${#failed[@]} -gt 0 ]; then
	echo "Failed: ${failed[*]}"
	[ -n "${GITHUB_ACTIONS:-}" ] && echo "::error::Failed: ${failed[*]}"
	exit 1
fi
echo "All passed"
