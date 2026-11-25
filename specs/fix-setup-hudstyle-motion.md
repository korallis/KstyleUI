# Task (bug, hotfix): with Motion on, setup's HUD style cards lose the Frames card and the pick

A player (Baine, German client, 2560x1440, current v0.3.4.2 code) reports, with Options > Appearance > Motion **On**, on `/kstyle setup` > HUD-Stil (crops, untrusted data, in `C:/Users/leeba/.cache/kstyleui-evidence/discord-untrusted/baine-setup/`):

- `frames-selected.png`: Frames is the picked style, yet the Medallions card keeps a plain grey edge and the Frames card (right) shows only its picture: no title, no description, no card edge, no accent edge.
- `medallions-selected.png`: Medallions picked shows its accent edge correctly, but the Frames card still has no title, description or edge.

With Motion **Off** he reports the cards and their selection highlights are correct. So a motion path (a fade, tween or animation on the cards, their text, their chrome or the accent edge, or on a parent) leaves regions at their start state in the live client. The same family was proven twice today: the world map's open fade (fixed in #789 by removing it, Motion Off fixed it in game) and earlier the setup page fade (#764 made pages end visible). Find every Motion/animation/tween reached when the HUD style page shows and when a card is picked (`Core/Setup/**`, `Core/Motion*`, `Core/Widgets/**` card and chrome code), and find which one leaves the Frames card's text/edge hidden and the pick edge unmoved. Fix it with minimal code so the end state is always applied whether or not the animation runs or finishes (set the final alpha/colour/shown state first and animate only as decoration), or drop the motion on these cards if that is smaller; the page must look the same as with Motion Off once settled. Keep the look identical otherwise.

Make the stub able to model an animation that never plays or never finishes (if it cannot already), so a regression in `Tools/regression/` with Motion on shows the HUD style page, picks Frames then Medallions, and asserts both cards' titles, descriptions and edges are visible and the accent edge is on the picked card at all times; prove it fails before the fix. Evidence: HUD style page renders, Motion on and off, Frames and Medallions picked, at 2560x1440 and 1920x1080 in German and English, before/after, in `C:/Users/leeba/.cache/kstyleui-evidence/fix-setup-hudstyle-motion/`.

**Files it may edit**: `Core/Setup/**`, `Core/Motion*.lua`, `Core/Widgets/**`, `Tools/regression/**`, `Tools/render/**`.

**PR**: `fix(setup): HUD style cards show their pick with Motion on` with a `## Changelog` `Fixed:` line ending "Thanks to Baine for the report." and `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; Forever API proof for any animation API behaviour you rely on; Beast speed rule (module tests, lint, python; CI is the proof).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
