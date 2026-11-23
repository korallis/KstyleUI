# Task: add gallery images 09-11 on CurseForge and Wago

v0.3.1 is live and its store descriptions are already pasted. The galleries still have only 01-08. Add the three new ones, in order, with the exact title and caption from the Gallery tables in `docs/store/curseforge.md` and `docs/store/wago.md` on tag `v0.3.1`:
- `docs/store/gallery/09-rest.gif` "Clean screen at rest"
- `docs/store/gallery/10-casts.gif` "Who a cast is aimed at"
- `docs/store/gallery/11-map.gif` "Routes and nearest services"

Use Orca's browser (`orca tab list`; tab 0 is the CurseForge authors console, project 1812141, Images tab; tab 1 is Wago's project settings for `kstyleui`). The owner is already logged in on both. Never log in with credentials, never touch Discord (tab 2) and never change anything else on either page. Check the result by reloading each gallery page and listing the images in order (11 on each). This is how #722 (`specs/store-gallery-swap.md`) swapped the gallery last time; read its approach first.

No PR. **Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the final gallery order on both sites.
