# Task: make the Medallions crest useful: left click hearths, right click opens travel

**Goal**: in the Medallions HUD style, the central crest artwork between the action bars (the hub in `KstyleUI_ActionBars/Slab.lua`) has no clicks today. The owner wants it to be useful:
- **Left click** uses the Hearthstone.
- **Right click** opens a small travel menu with the player's portals, teleports, mounts and other transport.

**Behaviour**:
- **Secure button.** Use a secure action button over the crest, placed with `K.Widgets.Cover(overlay, visual)`, so both clicks work in combat where the game allows. The Hearthstone uses `type1="item"` and `item1="item:6948"`, never a bag slot. If the player carries no Hearthstone, the left click does nothing and the tooltip says so.
- **Hover tooltip**, in the KstyleUI tooltip style:
  - the bind location;
  - the Hearthstone cooldown, shown as "--" when secret (`issecretvalue` before any comparison);
  - "Left click: Hearthstone · Right click: travel".
- **The right-click menu**: a flyout of KstyleUI buttons with the same `Widgets.Slot` skin and sockets as the action bars, so it is one consistent style. It opens above the crest and closes on a second right click, on Escape or after use. Show only what the player actually has:
  - class travel spells the character knows: Mage teleports and portals, Druid Teleport: Moonglade, Shaman Astral Recall, and any other class travel Forever has;
  - transport items in the bags, such as engineering teleporters and trinkets and other teleport items, from a small curated item-ID list in `Tools/data/`;
  - mounts the character can use, read the way Forever exposes them (prove whether that is a mount journal, the companion API or spell or item mounts; `Blizzard_Collections` does not load on camelot);
  - grouped as Hearth and class, Portals and teleports, Mounts, in priority order. An empty group hides.
- **Combat.** Opening a secure flyout in combat needs a secure handler (for example `SecureHandlerClickTemplate` with `_onclick` showing the flyout, the way Blizzard's spell flyouts do). If the client blocks that, the menu opens out of combat only and says so in the tooltip. Changes to the menu's contents wait for `Core/Combat.lua`'s queue.
- **Option.** Following the owner rule, add "Crest travel clicks" on the Action Bars Medallions settings, ON by default. Off restores today's click-through crest.
- **Shared source.** Put the travel list (Hearthstone, class travel, transport items, mounts) in one small source that the planned data bar's Hearthstone module can reuse later. Do not build the data bar.

**Target**: latest `origin/staging`. `KstyleUI_ActionBars/Slab.lua` (the hub), `Core/Widgets/Slot.lua`, `Core/Combat.lua`, `KstyleUI_Bags/Data.lua` (secret-safe bag reads), and the Forever UI source (`C:/Users/leeba/.cache/wow-ui-source`, `forever` at `9dc84f0`). Cite file:line for every API, template and secure attribute, including the flyout and secure handler pattern.

**Tests**:
- left click sets the Hearthstone item attribute;
- the menu lists only known spells and carried items;
- groups hide when empty;
- the setting off removes the clicks;
- no attribute or show change in combat outside the secure handler;
- no comparison of secret values;
- the menu stays on screen and clear of the unit frames at 1920x1080, 2560x1440, 5120x1440 and 3840x2160.

Renders of the open menu at the four sizes, for a Mage (many portals) and for a class with only a Hearthstone and a mount.

**Constraints**: minimal code; AGENTS.md rules (one event handler per owner, CRLF/ASCII, `K.Widgets.FontString`, `Widgets.Cover`); evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/crest-travel/`). Open a **draft** PR against `staging` titled `feat(actionbars): the Medallions crest hearths and opens your travel` with `## Changelog` (`Added: In Medallions, left click the central crest to use your Hearthstone, and right click it for your portals, teleports and mounts. Turn it off with Crest travel clicks in Options.`), `## Options`, `## In-game checks` and `## Before and after`. Do not merge.

**Files it may edit**: `KstyleUI_ActionBars/**`, `KstyleUI_Options/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/data/**`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`, the module README, `.luacheckrc` (only the module's own globals).

**Gate**: lint, python and the touched modules' tests locally; green Mac CI is the full proof.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL, run id and render paths.
