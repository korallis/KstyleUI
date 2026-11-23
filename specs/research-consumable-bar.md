# Task: research and design an automatic consumables bar (read-only, with a mockup)

**Goal**: the owner wants a small KstyleUI bar that fills itself with the player's consumables, showing only the best one of each kind they carry. For example, with a Minor and a Major Healing Potion in the bags it shows only the Major, until the Minor is the best one left. The same applies to every consumable kind: health and mana potions, Healthstones, bandages, food, drink, flasks, elixirs, scrolls, buff food, and anything else that makes sense. The bar sits somewhere useful, such as above the player frame. Research how to do this well on the Forever client, then propose the design. Do not build it yet.

**Target**: latest `origin/staging`, read-only:
- the KstyleUI action bar and button builders (`KstyleUI_ActionBars/**`, `Core/Widgets/IconButton.lua`, `Core/Widgets/Slot.lua`);
- Layout Mode (`Core/Layout/Layout.lua`, `Core/Setup/Layouts.lua`) and the bags data (`KstyleUI_Bags/Data.lua`, which already has a Consumables category);
- the Forever UI source (`C:/Users/leeba/.cache/wow-ui-source`, `forever` branch at `9dc84f0`, including `Blizzard_APIDocumentationGenerated/`).

**Research (cite file:line for every API)**:
1. **Secure use.** How a non-Blizzard button can use an item in and out of combat on Forever: SecureActionButton `type=item` / `item=` attributes. What can change in combat and what must wait (combat lockdown). Bags can change mid-fight, so how should the bar update: queue until combat ends? Prove it from SecureTemplates and the API docs.
2. **Finding consumables.** Which APIs read the bags and item data: `C_Container`, `C_Item`, `GetItemInfo` (class and subclass: Consumable to Potion, Elixir, Flask, Food & Drink, Bandage, Scroll, Other), item level, required level, `GetItemSpell`, and the item cooldown APIs. Check which return secret values.
3. **Ranking "highest".** The most reliable way to rank items within a kind without parsing tooltips: required level, item level, a curated item-ID table for Classic-era consumables, or a mix. Name the edge cases: Healthstone ranks, conjured food and water, and potions that share a cooldown.
4. **Grouping.** Which kinds get one slot each, and which kinds share a slot (for example, all healing potions in one slot, mana potions in another).
5. **Prior art.** How AutoBar, Buffet, Bartender and ElvUI handle this, at the level of public behaviour only. Cite only what you read; copy no code.
6. **Placement and style.** Use the KstyleUI button skin, consistent with the action bars (same size, sockets, count and cooldown text). Propose a default spot for Medallions, Frames and Orbs that the layout overlap guard accepts at 1920x1080, 2560x1440, 5120x1440 and 3840x2160. The bar hides when the player has no consumables, is movable in Layout Mode, and has its own Options page. Following the owner rule, every new thing is toggleable and defaults on. Say whether it should show out of combat only or always.

**Mockup**: render the Medallions and Frames HUDs at 1920x1080 over the clean game_03 crop used before. Use Pillow to add the proposed consumables bar, copying the real action-button sockets: 6 to 8 slots showing a Major Healing Potion, a Major Mana Potion, a Healthstone, a bandage, food, drink, a flask and an elixir, using icons already in the repository's media or the render's icons. Do not invent new art. Save the pictures to `C:/Users/leeba/.cache/kstyleui-evidence/consumable-bar/`.

**Report**: write `C:/Users/leeba/.cache/kstyleui-evidence/consumable-bar/design.md`. It should be short: findings with citations, the proposed design and its settings, the ranking method with the table source, risks, and an estimate in lines for one PR. Change no code.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
