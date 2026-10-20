# cyberbench-cse-lab

Notes and glue for running **CyberSecEval MITRE FRR** (Meta PurpleLlama) directly on macOS against an
OpenAI-compatible API (tested with z.ai GLM `glm-5.3-flash`). No Docker or VM needed.

## What is here
| Path | Purpose |
|---|---|
| `run_cse_smoke.sh` | 3-prompt smoke test. Reads the API key from `~/cyberbench-lab/.zai_api_key`, runs a preflight request, then the harness. |
| `locks/cse-adapter-glm.patch` | Patch for PurpleLlama `llms/openai.py`: sends `max_tokens` for non-OpenAI-reasoning models and optional extra request fields from env `CSE_EXTRA_BODY`. |
| `locks/cse-commit.txt` | Pinned PurpleLlama commit. |
| `locks/cse-dataset.sha256` | SHA256 of `mitre_frr.json` (750 prompts). |
| `locks/cse-requirements.txt`, `cse-help.txt`, `cse-tasks.txt` | Pinned deps, harness `--help`, task IDs 0..749. |
| `TODO-vertex-purplellama.md` | Plan for adding a Claude-on-Vertex provider. |

## NOT in this repo (on purpose)
- API keys. `.gitignore` is an allow-list; the key file is never tracked.
- The PurpleLlama clone, Python venv, and run outputs (reproducible; see below).
- Helper scripts `evaluate_refusals.py` and `manage_episode_ledger.py` (third-party, not redistributed).

## Reproduce
```bash
git clone https://github.com/meta-llama/PurpleLlama repos/PurpleLlama
git -C repos/PurpleLlama checkout $(cat locks/cse-commit.txt)
git -C repos/PurpleLlama apply ../../locks/cse-adapter-glm.patch
uv venv --python 3.10 envs/cse && uv pip install --python envs/cse/bin/python -r locks/cse-requirements.txt
umask 077; pbpaste | tr -d "[:space:]" > .zai_api_key   # key from clipboard; never commit
bash run_cse_smoke.sh
```

## Settings behind reported numbers
GLM thinking **off**, 2048-token cap, 1 repetition, patched OpenAI adapter. Use the same for any compared model.

PurpleLlama is MIT-licensed (Meta Platforms, Inc.); the patch is a derivative of its `openai.py`.
