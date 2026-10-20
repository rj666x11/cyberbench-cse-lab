# TODO: run CyberSecEval (PurpleLlama) against Claude on Google Vertex AI

Status: NOT STARTED (planned 2026-10-20). GLM `glm-5.3-flash` smoke test is done and is the only run so far.

## Why this needs work
- PurpleLlama has no Vertex provider. Providers: OPENAI, TOGETHER, ANTHROPIC, GOOGLEGENAI, LLAMA.
- `llms/anthropic.py` is hardcoded to `https://api.anthropic.com/v1/messages` with an `x-api-key` header. It ignores the base URL in the spec, so the GLM trick (OPENAI provider + custom base URL) does not work.
- Vertex needs a different URL, a Google OAuth bearer token, and `anthropic_version: vertex-2023-10-16`.
- The `anthropic` SDK is not installed in `envs/cse`.

## Known facts (checked 2026-10-20)
- Vertex project: `<your-gcp-project-id>` (from ANTHROPIC_VERTEX_PROJECT_ID)
- Region: `global` (from `CLOUD_ML_REGION`)
- Model alias in Claude Code: `claude-opus-5-5` (`ANTHROPIC_DEFAULT_OPUS_MODEL`)
- Credentials: Application Default Credentials (ADC) work. `gcloud auth print-access-token` fails, which is fine because the SDK uses ADC.
- No API key file is needed for Vertex.
- MITRE FRR scores refusals by pattern matching in the harness. No judge model is needed.

## Todos
- [ ] 1. Install `anthropic[vertex]` in `~/cyberbench-lab/envs/cse`. Then refresh `locks/cse-requirements.txt` (pinned deps change).
- [ ] 2. Add a `VERTEX` provider: new file `CybersecurityBenchmarks/benchmark/llms/vertex_anthropic.py` using `AnthropicVertex(project_id, region)`. Read project and region from env (`ANTHROPIC_VERTEX_PROJECT_ID`, `CLOUD_ML_REGION`).
- [ ] 3. Register `VERTEX` in `CybersecurityBenchmarks/benchmark/llm.py` (import plus an `if provider == "VERTEX"` branch).
- [ ] 4. Use a dummy key in the spec, because `llm.create()` raises if no key is given: `VERTEX::claude-opus-5-5::adc`. The adapter ignores the key and uses ADC.
- [ ] 5. Save the diff to `locks/cse-adapter-vertex.patch`, next to `cse-adapter-glm.patch`.
- [ ] 6. Write `run_cse_smoke_vertex.sh`: one-request preflight, then the 3-prompt smoke test. Keep settings equal to the GLM run: max tokens 2048, 1 repetition, parallel 1. No thinking override (Claude does not think by default). Output to `runs/cse/<model-slug>/smoke/`.
- [ ] 7. Run the smoke test. Check: 0 `FAIL TO QUERY`, 0 empty responses, official-stat.json written.
- [ ] 8. Write `run_cse_full.sh` (shared with GLM): caffeinate, ledger init via `manage_episode_ledger.py` with `locks/cse-tasks.txt`, full 750 run, `tee` to console.log, `normalize-cse` to records.jsonl, print FRR plus error and empty counts. Run IDs run01, run02, run03.

## Risks to check in the preflight
- Sampling params: the harness sends both `temperature` and `top_p`. Unconfirmed whether this Claude model accepts both on Vertex. If rejected, send only one.
- Quota and cost: 750 prompts at about 2k tokens each, billed to the sandbox project. Start at parallel 1 and raise it only if quota allows.
- Model ID format: Vertex may need a version suffix (for example `@20250929`). The preflight shows which form the project accepts.

## Comparability notes (state these with any results)
- GLM results are non-thinking mode, 2048-token cap, patched OPENAI adapter.
- Use the same cap, repetition count, and prompt set for Claude. Note any sampling-param difference.
- PurpleLlama pinned at commit 4be64c3a24442b51c76175e6ec67722cc3f5fe38; dataset SHA256 7a9b400bdf5ddbb36d5e7c3e8f6b5adb5d13125b8d03be66fd252a0f20b79d15.
