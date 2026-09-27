#!/usr/bin/env bash
# Run agy workers in parallel: tools/agy/run.sh A B C  (task prompts in tools/agy/<name>.txt, logs in tools/agy/logs/)
cd "$(dirname "$0")/../.."
mkdir -p tools/agy/logs
for t in "$@"; do
	agy -p "$(cat tools/agy/common.txt tools/agy/$t.txt)" --dangerously-skip-permissions --model "${AGY_MODEL:-claude-opus-4-6-thinking}" \
		>"tools/agy/logs/$t.log" 2>&1 &
done
wait
echo "all done: $*"
