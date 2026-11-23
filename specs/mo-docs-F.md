# Task: Medallions-only docs and README pictures (list F, PR #695)

The owner removed the Frames and Orbs HUD styles; KstyleUI is Medallions only. PR #695 (branch `korallis/medallions-only-remove-frames`, lead worker ctx_190cacbd9d74) has the addon, tests (helpers in progress) and media tools done. You own the docs. Setup: `git fetch origin && git checkout -B mo-helper-f origin/korallis/medallions-only-remove-frames`; commit small, then `git pull --rebase origin korallis/medallions-only-remove-frames && git push origin HEAD:korallis/medallions-only-remove-frames` (others push too; touch only your files). Ask the lead for anything outside them.

**Do:**
- `README.md`: drop the Frames and Orbs sections and pictures; retake the hud/healer/meter/rail pictures in Medallions with `python3 Tools/render/readme.py`, retuning its crops; drop `RENDER_HUD_STYLE` there.
- `docs/store/description.md` then `python3 Tools/media/marketing.py --pages`: replace the "Three HUD styles" card and `header-three-huds` with Medallions-only copy and pictures.
- `docs/medallions.md`, module READMEs, `docs/feature-map.md`, `Tools/render/README.md`: no Frames/Orbs mentions or variables.
- `docs/statecharts/`: delete the HUD style chart; update the setup chart to five steps (welcome, layout, modules, ornaments, summary).
- `docs/core-visuals.md` (minimapMask row), `KstyleUI_Minimap/README.md` (square mask lines), `Tools/render/guard_allow.tsv` (the Brannoc line that mentions Orbs).

**Rules**: real game backdrops only (`~/.cache/kstyleui-backdrops`, never the mockup plate); ultrawide README pictures use Spread; `--strict`; branded and readable like the existing pictures; never name EllesmereUI, CaithUI or any other UI pack. **Run at most ONE render at a time** (the lead's pixel proof is rendering on this machine). Python suite and lint must pass for your files (`Tools/tests/test_marketing.py` included).

**Done when** no doc, README or store page mentions Frames, Orbs or a HUD style choice, and the pictures are retaken. Report to the lead and to me: files changed, pictures retaken.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md` (no PR of your own).

**Files it may edit**: `README.md`, `docs/**`, `KstyleUI_*/README.md`, `Core/**/README.md`, `Tools/render/README.md`, `Tools/render/readme.py`, `Tools/render/guard_allow.tsv`, `docs/media/**`.
