#!/usr/bin/env bash
set -euo pipefail

LAB="$HOME/cyberbench-lab"
KEY_FILE="$LAB/.zai_api_key"
MODEL_ID="glm-5.3-flash"
MODEL_SLUG="glm-5.3-flash"
BASE_URL="https://api.z.ai/api/coding/paas/v4"
RUN_DIR="$LAB/runs/cse/$MODEL_SLUG/smoke"
MAX_TOKENS=2048
# Thinking off: with thinking on, GLM spends the whole token cap on reasoning and returns no answer.
export CSE_EXTRA_BODY='{"thinking":{"type":"disabled"}}'

if [[ ! -s "$KEY_FILE" ]]; then
  echo "ERROR: $KEY_FILE is missing or empty. Put your z.ai key in it first." >&2
  exit 1
fi
perms="$(stat -f %Lp "$KEY_FILE")"
if [[ "$perms" != "600" ]]; then
  echo "WARNING: $KEY_FILE has permissions $perms; fixing to 600."
  chmod 600 "$KEY_FILE"
fi

CANDIDATE_API_KEY="$(tr -d '[:space:]' < "$KEY_FILE")"
if [[ -z "$CANDIDATE_API_KEY" ]]; then
  echo "ERROR: key file contains only whitespace." >&2
  exit 1
fi
echo "Key loaded (length ${#CANDIDATE_API_KEY})."

# Preflight: one tiny request, so a bad key fails fast instead of looping in harness retries.
echo "Preflight check against $BASE_URL ..."
preflight_body="$(mktemp)"
trap 'rm -f "$preflight_body"' EXIT
code="$(curl -sS -o "$preflight_body" -w '%{http_code}' --max-time 60 \
  "$BASE_URL/chat/completions" \
  -H "Authorization: Bearer $CANDIDATE_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL_ID\",\"max_tokens\":64,\"thinking\":{\"type\":\"disabled\"},\"messages\":[{\"role\":\"user\",\"content\":\"Reply with OK\"}]}")"
if [[ "$code" != "200" ]]; then
  echo "Preflight FAILED: HTTP $code" >&2
  head -c 500 "$preflight_body" >&2; echo >&2
  exit 1
fi
echo "Preflight OK (HTTP 200)."

cd "$LAB/repos/PurpleLlama"
source "$LAB/envs/cse/bin/activate"
DATASETS="$PWD/CybersecurityBenchmarks/datasets"
CSE_SPEC="OPENAI::${MODEL_ID}::${CANDIDATE_API_KEY}::${BASE_URL}"

mkdir -p "$RUN_DIR"
python -m CybersecurityBenchmarks.benchmark.run \
  --benchmark mitre-frr \
  --prompt-path "$DATASETS/mitre_frr/mitre_frr.json" \
  --response-path "$RUN_DIR/responses.json" \
  --stat-path "$RUN_DIR/official-stat.json" \
  --llm-under-test "$CSE_SPEC" --run-llm-in-parallel 1 \
  --max-tokens "$MAX_TOKENS" \
  --num-queries-per-prompt 1 --num-test-cases 3

echo
echo "=== Responses (first 200 chars each) ==="
jq '.[] | {model, prompt_id, response: (.response // "" | .[:200]), judge_response}' \
  "$RUN_DIR/responses.json"
echo
echo "FAIL TO QUERY count: $(grep -c 'FAIL TO QUERY' "$RUN_DIR/responses.json" || true)"
echo "Empty responses: $(jq '[.[] | select((.response // "") | test("\\S") | not)] | length' "$RUN_DIR/responses.json")"
echo "Official stat file: $RUN_DIR/official-stat.json"
