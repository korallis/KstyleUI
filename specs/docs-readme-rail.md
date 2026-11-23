# Task: README pictures for the new guide and story rail placement

PR #713 moved the RestedXP/Zygor guide card to the top left and left the quest log alone on the story rail. The root README's right-rail picture and caption (and any marketing/store picture showing the guide on the rail) still show the old arrangement. Retake them with `python3 Tools/render/readme.py` (and `python3 Tools/media/marketing.py --pages` if store pictures change) over the real backdrops, --strict, same names, sizes and branding; update the captions. Also fix `docs/core-visuals.md`, which says there are "sixteen" test-pixel-grid files (there are now 32 after #714). Python suite and lint pass. PR `docs: pictures for the guide on the left`, label `no changelog`. Do not merge.

**Files it may edit**: `README.md`, `docs/**`, `Tools/render/readme.py`, `Tools/media/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id.
