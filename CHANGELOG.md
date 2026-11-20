# KstyleUI changelog

## v0.2.8 (2026-11-20)

The map and bars release: a world map that zooms smoothly, searches and draws you a route, a setup step for your own addons, and action bars you can tune bar by bar, plus the fixes from a long gameplay video.

Highlights:

- The world map zooms smoothly with the wheel and remembers each map's zoom, searches flight masters, dungeons and quests, and draws a straight-line route card with distance and time. Routes are straight lines in this build and the card says so; road-following routes are coming.
- Setup gains a "Your addons" step: choose which of your addons KstyleUI skins, with every skin on by default.
- Action Bars options open on tabs, one per bar, with new per-bar controls: where each bit of text sits, how cooldowns look, item quality borders, a show/hide builder, toggle keys, click-through and reversed button order.
- The consumables bar starts at half size with a backdrop.
- Gameplay-video fixes: the RestedXP guide card fits its steps, Layout Mode labels never overlap, and no stray power percent or bogus frame rate after a loading screen.

### Added

- The world map zooms smoothly with the mouse wheel and remembers your zoom and pan for each map, even after a reload. Wheel out again at the smallest zoom to open the parent map, or in again over a zone to open it; in combat the wheel only zooms the current map. Smooth zoom, Remember zoom and Wheel between maps are each on by default under Window Skins > World map.
- Search the world map for flight masters, dungeon and raid entrances and your quests, then pick a result to set a waypoint and track it. Clicking a native entrance, flight or map-link pin keeps the game's own tracking: the first click draws the route and the second clears it.
- A route card beside the map's quest list shows the yards to your destination and roughly how long it will take, on foot and mounted, with a dotted straight line drawn to it. The line is a straight line in this build and the card says so; road-following routes are coming.
- Dungeon and zone level ranges on the map. Search and routes, Dungeon level ranges, Zone level ranges and Dungeon entrances are each on by default under Window Skins > World map; turning one off removes its additions and gives back the game's own settings.
- A "Your addons" step in the first-run setup lists the supported addons you have installed and lets you choose which ones KstyleUI skins, and which parts step aside for an addon that does the same job. Reopening `/kstyle setup` shows your current choices, and Keep my UI leaves them alone.
- Bar tabs at the top of Action Bars options for Bar 1-6, Pet, Stance and Consumables, so every bar's settings, including its number of buttons, are one click away. The picker stays pinned while you scroll, and you can double-click a bar's mover in Layout Mode to jump to its settings.
- Per-bar text placement: put each bar's keybind, count, macro and cooldown text in a corner, on an edge or in the centre, with horizontal and vertical offsets. Current style with no offsets keeps the positions you know.
- Per-bar cooldown look: fade an icon's colour while it is on a real cooldown (the global cooldown stays coloured) and set how dark the cooldown swipe is.
- Item quality borders on action buttons, on by default per bar: an uncommon or better item, including an item macro, wears its quality colour. Poor and common items keep their normal rim.
- A per-bar show/hide builder: tick the times a bar shows or hides (in combat, out of combat, with a target, mounted, in a group or raid, or while Shift, Control or Alt is held) and KstyleUI writes the visibility rule for you. Writing your own macro condition still works; clear it to get the builder back.
- Toggle keys for every bar under Key Bindings > KstyleUI: bind Toggle Action Bar 1-6, pet, stance or consumables to show or hide that bar, even in combat. The hidden state is saved per character.
- Per-bar Click through, so clicks pass through the bar to the world while its keys still work, and Reverse button order, which swaps where the buttons stand without changing their slots, pages or keybinds. Both are off by default; the connected Medallions slab keeps its fixed order.
- A button-count limit for the consumables bar, which keeps your highest-priority kinds when you lower it.
- Paragon reputation progress, with an optional compact reward marker in the reputation caption.
- An optional KstyleUI card and header for Questie's own tracker, on by default; switch it off and Questie's own art returns at once.

### Changed

- Every skin is on by default. Skins you switched off yourself stay off, a master switch you turned off stays off, and Questie no longer turns the whole Skins module off.
- The consumables bar starts at half the size of the action buttons, with a backdrop behind it and gaps that shrink to match. Under 30 units its text is outlined so counts stay readable, the cooldown timer replaces the count while an item cools down, and keybind text (now off by default) shows only when counts are off; the full binding is in the item's tooltip. Your saved size, backing and keybind choices are kept.

### Fixed

- The frame-rate readout no longer shows a bogus figure such as 240000 FPS just after a loading screen; it shows -- until the first real sample, tooltip included.
- The Medallions player power value sits inside its card and its Layout Mode box, with no second percentage floating underneath.
- RestedXP's guide card fits its active steps (28 units at its shortest), guide and quest cards shrink with shorter content, RestedXP headers keep one height, and the folded guide list no longer leaves a stray gutter tick. **Fit guide to its steps** is on by default; off gives back the shared quest-card height.
- Layout Mode mover labels and readouts clear neighbouring movers, the clock and chat tabs, the toolbar clears Boss Announcements, turning See-through movers off restores the centred solid labels, and thin movers keep their grab area and size and scale details. Dragging and selecting movers no longer repeats the label placement work.
- The durability doll moves to a clear spot beside the minimap at login when you never moved it yourself; a position and size you saved in Edit Mode are kept.
- Options Tasks has destination help and a live preview, and General > Text previews its typography; the help text follows the same colour and spacing as every other row.
- Percentages round the way Blizzard rounds them, including at exact halves.
- KstyleUI steps aside for the Leatrix Plus features you have on and for BetterFriendlist's friends window.
- Finding Questie for the first time keeps its current tracker setting, and the Speedrun Guide and context-menu headers match the rest of KstyleUI.
- Party and raid health bars end without the spark other bars already skipped, and restyled tracked bars use your shared bar height (12 units by default), icon tile and black edge included.
- The Cooldown Manager tip shows once instead of at every login, action-bar overlap notices show once per account for each addon found, and stripped textures stay hidden after a recolour.

### Upgrading

- Skins are on by default now: if you never touched them, your supported addons start skinned. Switch any off in Options or in the setup's "Your addons" step; skins you switched off stay off.
- The consumables bar shrinks to half size with a backdrop unless you set its size or backing yourself; both are under Options > Action Bars > Consumables.

The optional icon pack still applies: download `KstyleUI-Icons-<version>.zip` from this project's GitHub releases page, quit the game, copy its Interface folder into your Forever folder so the files land in Interface/Icons, then start the game again.

## v0.2.7 (2026-11-20)

The big customisation release: a data bar you fill with the readouts you want, a consumables bar that fills itself, a reworked Medallions centre with crest clicks and a crest minimap, and layout tools that keep everything apart at every screen size.

Highlights:

- A data bar across the top in Frames and Orbs, and a dock under the slab in Medallions, with your choice of readouts and a toggleable micro menu.
- An automatic consumables bar that keeps your best food, potions and other consumables to hand.
- Medallions: cooldowns centred above the crest, aura rows above the unit frames, click the crest to hearth, right-click it for travel, frame the minimap like the crest, and pick an extra-bar layout.
- Text formats for health and power, one aura filter set, one bar options set, and a layout for each of your specs.
- Attach any element to another and match its width, lock drags to one direction in Layout Mode, and cycle stacked frames.
- Hover a quest to see your party's progress on it.
- Fixes for the alt-tab stutter and the frame-rate drop from minimap pins, and HUD parts that overlapped or left the screen.

### Added

- A data bar across the top of the screen in Frames and Orbs, in the shared card chrome: your specialization, Hearthstone and a toggleable micro menu on the left, the clock in the centre, and guild, friends, durability, bag space, frame rate, latency, gold and tracked currencies on the right. It is 14 units tall by default, so Frames and Orbs keep their v0.2.6 size and place at every screen size. In Options > Data Bars pick Top, Docked under the action bars or Right rail, the height (12 to 32), opacity, Forged or Plain artwork, and which readouts show and in what order. Right rail puts the readout back where v0.2.6 had it, even after you run setup again. While the bar shows the time, the minimap clock steps aside and comes back when the bar clock is off.
- New readouts: specialization (switch dual specialization out of combat, or open talents), Hearthstone location and cooldown, guild and friends online, bag space and up to three tracked currencies.
- In Medallions, a data dock under the action slab shows the original five readouts (frame rate, latency, gold, durability and clock) and the micro menu; turn the others on in Options. When the dock runs out of room it drops whole readouts from its ends and lists them in the last readout's tooltip.
- An automatic consumables bar with twelve item kinds, in the action bars' shared sockets, with grid controls, fading, a preview and `/kb` bindings. It fills itself with your best consumables and stays clear of your auras and side bars.
- In Medallions, left-click the central crest to use your Hearthstone and right-click it for your travel spells, items and mounts. Turn Crest travel clicks on or off in Action Bars options.
- In Medallions, frame the minimap like the central crest: pick Crest medallion, Crest ring or Classic under Minimap frame in Options.
- Two quick layouts for extra action bars in Medallions: two rows on the slab, or small bars beside it. Pick one under Extra bars layout in Options; everything stays movable.
- Every action bar can be sized and arranged in Options, in every HUD style, including the Medallions slab bars.
- Text options for unit frames and nameplates: font, size, outline, colour, and formats such as `[hp:abr]` and `[hp:pct]`, with tags for name, health, power, level, absorbs, target and group.
- Shared aura controls for player auras, nameplates and group frames, with spell-ID allow and block lists on nameplates.
- Give each spec its own layout of frames and bars while keeping one profile's look, show any element only in a party, in a raid or when solo, and let the meter follow your role: threat when you tank, damage otherwise.
- As a damage dealer you can show the threat meter next to the damage meter (Options > Meters).
- In Layout Mode, Shift locks a drag to one direction, you can cycle through stacked frames, and every frame can show its coordinates. Attach any element to another one (above, below or beside it) and match its width; it follows wherever you move the other.
- Hover a quest in the quest card to see each party member's progress on it. Party members with KstyleUI or Questie show their objectives.

### Changed

- In Medallions your cooldowns sit centred above the crest and cast bars, your buffs stand in rows above your own frame, and your target debuffs stand in a row above the target frame. Prefer the old crest fan? Pick Crest fan under Unit Frames > Aura layout.
- The damage and threat meters use matching nameplate-style rows by default; turn off Nameplate-style meter rows in Options > Meters for the previous rows. The damage and threat cards are 250 units wide, so two fit side by side.
- Nameplate bars, levels and cast names use the same bar and fonts as the rest of the interface: cast names are in capitals and the default plate health bar is 12 units high. Medallions' Minimal preset keeps its slim bar, and Dungeon and saved Custom plates keep theirs.
- Quest, tracker and guide cards use the same header and spacing as every other card.
- Every bar's texture, colour and height options use the same shared controls across unit frames, nameplates, group frames, cooldowns, meters and data bars.
- Bars across the interface share one texture and height, party health uses class colours, and short numbers read the same everywhere (12.4K). Saved profiles with an explicitly chosen texture keep it.
- The bag window keeps its size and your items stay put; compact bags are an option.
- Logging in, reloading and changing screen size do less work, with no visible change.

### Fixed

- Alt-tabbing out of the game and back no longer causes a stutter, and frame rate no longer drops while other addons draw pins or gathering nodes on the minimap. The addon drawer no longer takes map pins in.
- HUD parts, captions and mouse targets stay on screen and apart in all three HUD styles, at every screen size. Your saved positions are kept; anything you saved within 17 units of a screen edge is drawn just inside it.
- Minimap and map icons are no longer shrunk (compact icons are an option), the minimap no longer runs off the edge of wide screens, and its zone name no longer covers the map.
- The Medallions damage meter is back on the lower right rail, clear of the nameplates, and long spell names in the damage meter stay whole; saved positions are kept.
- The Medallions quest card shows whole lines with every minimap frame, in the taller column beside the guide card.
- With Questie installed, its quest tracker and the KstyleUI quest card no longer draw over each other, RestedXP's Active Items and Active Targets boxes dock under the guide card instead of floating mid-screen, and the RestedXP guide window no longer flickers.
- KstyleUI restyles other addons' text inside skinned windows without making it overflow their frames, and item tooltips no longer blink when you hover items in the auction house and other lists.
- Moving a spell on your action bars no longer casts it, the class trainer's skill rows no longer spill over each other or the Train button, and opening the travel menu no longer slows later refreshes.
- Saved Frames health-text settings no longer blank the health orb, and custom text tags paint once per update.
- The experience bar shows your real rested share past one level of rested experience, experience, reputation and honour percents no longer read one percent low at exact values, the swing timer stops a hand with no weapon, and the threat meter reads the same figure on a boss as on other enemies.
- When another addon does the same job, KstyleUI steps aside only for that part: DataBars yields its micro menu and bag bar to Bartender4 or Dominos, Meters yields only damage to Details, and each part can be turned back on. Turning nameplate management or the Nameplates module off gives your own game settings back across reloads.
- Running setup again with Right rail chosen keeps the data readout in its old spot.
- The data bar's clock no longer sits on the bar's centre gem.
- The Medallions data dock separates its readouts from the XP caption.
- In Medallions, the quest card and guide card line up.
- Right rail shows the classic readout and keeps it inside its frame.

### Upgrading

- Your Frames and Orbs data readout moves into the new top bar; if you had moved it, a chat message says so once. Pick Right rail in Options > Data Bars for the old readout.
- In Medallions your readouts move into the dock under the slab; a saved readout position is not used while the dock is on.
- If you had moved the Medallions crest fan, you keep the fan; everyone else gets the new aura rows (Unit Frames > Aura layout switches back).
- RestedXP's Active Items and Active Targets boxes dock under the guide card again once, even if you had undocked them; drag either box to undock it.
- Role-following meters stay off for existing profiles until you turn them on.

An optional icon pack repaints ability and item icons everywhere, including buffs. The addon repaints the frames; **KstyleUI Icons** repaints the icons inside them, in one style everywhere the game draws them. The icons were made with AI image tools. The pack is not an addon and is not part of this download: download `KstyleUI-Icons-<version>.zip` from this project's GitHub releases page, quit the game, copy its Interface folder into your Forever folder so the files land in Interface/Icons, then start the game again.

## v0.2.6 (2026-11-18)

Clearer combat and finished HUD styles: tooltips that follow your mouse out of combat, readable casts and their outcomes, one danger signal at the screen edge, colour-vision and readability choices, Orbs and Frames finished with their own switches, Options that opens on common tasks, a branded welcome page, and a long list of alignment and readability fixes.

### Added

- Tooltips can follow the mouse out of combat and sit at their usual place in combat. This is the new default; pick another anchor in Options if you prefer.
- Under Medallions, your debuffs on your target fan out in a metal-rimmed row above the crest, with their timers, cooldown sweeps and overflow, a switch in Options and a mover in Layout Mode.
- Four readability switches in Options > General > Appearance, on by default, with the original look available when you switch one off.
- Enemy cast names on target and focus nameplates, a shield mark for casts you cannot interrupt, and a Dungeon nameplate preset.
- Orbs and Frames finish with switches, all on by default. Under Options > Unit Frames > Orbs: Sharp orb glass, Ledge under bar 2 and Room for long spell names. Under Frames: Spell name inside the bar (Options > Unit Frames > Player and Target) and Tray on the centre column (Options > Action Bars).
- When you learn a new spell, KstyleUI offers to add it to your action bars, beside the offer to update a spell to its new rank.
- A setting to wait until you stop resizing the game window before the HUD resizes with it, on by default.
- Colour vision choices, role and threat shapes, interrupt shields, and debuff letters classified by the game, so important signals do not rely on colour alone.
- Readable and Healer presets, target range cues, tank threat alarms, and resurrection, summon and AFK indicators.
- Bind keys buttons in Options, typed slider values, diamonds on settings you have changed, quick resets, and searchable elements in Layout Mode.
- Scoped profile sharing with an import review, plus recovery backups you can restore in one click.
- Separate options to restore the previous low-health screen glow and the smoky portrait pulses.
- Options opens on common tasks, with search in player words and ornament samples you can see before you choose.

### Changed

- Existing players move to the new default of tooltips at the cursor out of combat. If you had chosen Tooltip anchor, older versions did not keep that choice at logout, so choose Tooltip anchor again in Options to restore it.
- The Personal Resource Display in the middle of the screen is off by default for new setups; turn it on under Nameplates.
- The first-run setup opens on a branded welcome page with current HUD previews, feature highlights and the addon version, with an option to restore the original page.
- Frames and Medallions show power numbers by default: your mana as a percent, or the current amount of rage, energy and the like. Orbs keeps its own centred percent. Under Medallions, your target's health percent stands out and combat text keeps clear of casts and debuffs.
- Nameplate debuffs are larger in both presets, with outlined time left and a red warning as they run out.
- Orbs glass is crisper, with a hard glint and a clearer band for health just lost, and the split second action bar sits on a metal ledge. Under Frames, cast bars show the spell name and timer inside the bar, and the tray's buttons line up with the unit bars above them.
- Quest and guide cards line up, meters fit their contents, and the data strip shares the meter heading. Window buttons have a steel surface with clearer pressed and disabled states, and native windows share one spacing for their titles, text and controls.
- Readability pass: clearer cast and raid text, low-health figures and captions, outlines and backing for bare text where you want them, readable chat tabs, mana a darker step below health, and meter row text with a one-pixel shadow. Bar and threat pill colours are unchanged.
- Type pass: portrait levels show once, with a larger number badge on the hub; experience captions and meter row names use instrument faces, card-header figures use PT Serif Bold, and section headings and tabs share gold capitals. Tooltips use clearer title, body and caption sizes, bright stat lines and readable reaction names, with separate controls for tooltip and bag quality colours. Options labels and help have their own sizes.
- Empty Medallions action sockets fade until you drag a spell, bind keys or edit the layout. Cooldown edges are quieter, countdowns are clearer and the seated crest is smaller, each with its own switch, and Medallions icon frames match, with separate text and indicator lanes on party and raid frames.
- The Cooldown Manager's icons sit with the action bars instead of floating in the middle of the screen; switch them back in Options. The swing timer matches the rest of the HUD and sits with the cast bars.
- KstyleUI skips repeated background HUD, border and layout work that could not change anything on screen. Nothing looks or times differently.
- Setup names addons that overlap with KstyleUI and offers timer and announcement lanes and named WeakAuras anchors; raid tools remain available. Every new accessibility feature has an Options control and is on by default, and Standard and Compact remain the named preset defaults. Closing setup now applies the default setup; "Do nothing, ask again later" leaves your interface unchanged.
- General offers the same Full, Calm and Off motion choices for Frames, Orbs and Medallions.
- Proc glows fade in gently, stay inside a smaller halo and hold still when their loop is off. Hover highlights finish rising before they fade, held buttons keep a small lit rim, and hub models sit behind the crest, fade when replaced and play at most once every 2.5 seconds while the 2D celebration still plays.
- Settings search results appear at once, page transitions are shorter and preview changes are smooth. Combat numbers spread across five lanes, combine nearby ordinary hits and fade when making room.
- Failed and interrupted casts stay readable, and a completed channel gets a soft acknowledgement. Target ticks are clearer, threat reads as a coloured edge, nameplates dim smoothly, and a Medallions target fades when lost or replaced and turns grey on death.
- Low-health danger stays at the screen edges, with a smooth ring around your portrait and a still red rim on low-health enemies.
- Setup shows each role in the HUD style you chose, with clearer wrapping notes and slimmer switches.

### Fixed

- Party and raid frames appear as soon as you join a group.
- With your bags grouped by category, you can drop a held or split item onto the empty slots to put it away. Bag item levels and stack counts now sit in separate corners, and bag and minimap headings keep clear of their edges.
- The chat window's tabs, frame and buttons line up at every screen size, including 4K.
- Minimap tooltips open beside the minimap instead of covering it.
- Reopening a window keeps its native button chains in place, Talents controls use their final size on the first open, vendor prices paid in currency keep their lane after updates, and trainer skill captions stay clear of the window title. Quest cards use their full height, and docking keeps the meter rate without refreshing the data strip when nothing changed.
- Long names in raid frames stay distinct and clear of debuff pips, and lost-health bands reset correctly after a restricted colour change.
- Borders are complete on their first visible frame, and changing the interface size during combat keeps one-pixel lines correct.
- An interrupt whose cooldown is unknown no longer claims to be ready, and changing target refreshes only the two nameplates that changed.
- Long target spell names in the Orbs style are no longer cut short at 3456x2234 and 5120x1440.
- Long Medallions names keep their face and capitals at every resolution; the unit tooltip carries the full name. Small text keeps its previous minimum size at 1080p and 1440p, and section rules stay under their headings while text cannot be measured.
- Long cooldown countdowns no longer cross stack counts, and key labels stay inside their action buttons in Frames, Orbs and Medallions.
- The dispel colour in the Options raid preview is a light wash again instead of a solid tile.
- The damage meter goes back to its normal heading once combat data can be read again.
- Six- and twelve-button third action bars fit Frames, Orbs and Medallions, with matching slab and socket treatment under Medallions.
- Calm motion keeps brief fades and flashes while windows, tabs, switches, lists, the loot feed, group cards and bag icons stop moving.
- Changing a setting no longer restarts a lit proc's entrance or crest flash, and the previous glow restores its full texture. A proc cannot interrupt a level-up celebration, and returning to the world does not replay a proc that was already lit.
- Real aura timers show a positive last second and plate debuffs end without a flash, and settings windows still open and close at once in combat and with reduced motion.
- Target cast labels stay clear after target and HUD style changes, and a new nameplate no longer inherits the previous enemy's fading.
- RestedXP guide borders and chat tab underlines stay crisp at fractional interface scales.
- Healthy hostile targets no longer show a danger rim.
- Settings labels stay readable when you shrink the window, and small previews start at the top.

An optional icon pack repaints ability and item icons everywhere, including buffs. The icons were made with AI image tools. The pack is not an addon and is not part of this download: it is available from this project's GitHub page. Quit the game, copy its Interface folder into your Forever folder so the files land in Interface/Icons, then start the game again.

## v0.2.5 (2026-11-18)

Your feedback release: keybinding, a working stealth button, the Options font error, a RestedXP arrow you can see in the dark, and a lighter addon that looks exactly the same.

### Added

- Bind your action buttons with `/kb` or `/kstyle kb`: hover a button, press a key (with Shift, Ctrl, Alt, mouse buttons or the wheel), then Save for your account or this character. Escape clears a binding, Discard undoes your changes, and it refuses to change bindings in combat. It also binds your stance, pet and possess buttons. `/kb` is left to another addon such as Bartender4 if it already owns it; `/kstyle kb` always works.

### Changed

- KstyleUI does much less work at login, `/reload`, display changes and HUD-style changes: working out the HUD size takes about a quarter of the time and almost no temporary memory, and about 40% fewer hidden pieces are created until they are needed. Nothing looks different.
- In combat, party and raid frames, boss frames and action-bar cooldowns skip updates that could not change anything on screen.

### Fixed

- Clicking the stance button cancels stealth again, and its key binding in Blizzard's Key Bindings window works.
- Opening Options no longer raises "Invalid font height (0)" from the group-frames preview, and the preview fits the window at its smallest size.
- The RestedXP guide arrow is ivory with a dark edge, so it is easy to see in dark zones such as Tirisfal Glades.

## v0.2.4 (2026-11-17)

### Added

- KstyleUI is now on CurseForge and Wago Addons, so the CurseForge app, WowUp and other addon managers can install and update it.

## v0.2.3 (2026-11-17)

The Medallions polish pass: dark gunmetal chrome, rounded bevelled cards, and a tighter unit cluster on one row of action buttons.

### Changed

- Medallions has a new dark gunmetal chrome kit. Cards, windows and slabs have rounded, bevelled edges instead of thin steel hairlines, with machined medallion rings and round level badges.
- The rails follow it. Cards are dark and bevelled with a header band in your class colour, the minimap sits in a round ring with an N badge, and chat, the damage meter, the quest card and tooltips wear the same chrome.
- The action slab has recessed, rounded sockets. An empty socket shows no keybind, an ability that lights up gets a border in your class colour inside its socket, and your race-and-class crest fills the hub at full brightness, clipped to its dark gunmetal ring so even wide crests stay inside it. The crest's wings are retired, and your pet and stance bars get small matching slabs.
- Numbers use Barlow Semi Condensed. Nameplates are slimmer, with the level in its difficulty colour and tick marks on your target. Scrolling combat text is gold and rises and fades faster.
- Your unit frames sit in one tight cluster just above the action slab, with the pet and target of target beside the medallions. Health numbers are outlined and sit at the end of the bar, cast bars sit over the crest, and target debuffs are small tiles with a dispel-colour underline. Bars and cast bars are cleaner.
- Medallion rims carry an engraved band of runes.
- Smaller download: unused Medallions art has been removed.

### Fixed

- The Medallions action bars are one row of twelve buttons a side on every screen again, including 16:9 and the MacBook.
- Switching HUD style now rebuilds your aura tiles in the new style, so a dispel colour can no longer cover their icons.
- The quest card keeps a quest whose details have not loaded yet while other quests update around it, and it retries the load, including after combat.
- RestedXP's Active Items box lines up with its Active Targets box.
- In Options, slider labels stay clear of their descriptions, and live previews keep translated names and portraits inside the space they are given.
- The leave-vehicle button sits clear of the hub, appears at once in combat, and stays fully visible even when your first action bar is faded out or shown only on mouseover.
- Crisper edges on the quest card, the minimap face, the data bars and the loot feed at the HUD sizes Interface size Auto picks.
- On the Medallions target slab, creature types such as Elemental and Mechanical show in full, long names stay in capitals by shrinking a little before they shorten, and the raid marker sits clear of your target's debuff timers.
- Beside the RestedXP guide, the quest card keeps your objective and its progress on show instead of only the quest name, with the title, quest count and hint clear of the card's edges.

## v0.2.2 (2026-11-16)

### Fixed

- The Medallions hub no longer leaves its shock ring and square flash visible between effects. Recoloring now preserves their opacity instead of bringing them back over the painted crest and runes.
- Hidden Blizzard and RestedXP backdrop textures stay hidden when their owning UI refreshes the vertex color.
- Medallions health and resource bars use flat fills without the white sheen. Health numbers use dark ink on bright fills and return to light ink when health falls onto the dark track.
- CombatText hides Blizzard's separate damage and healing numbers by default while KstyleUI's scrolling text is enabled. An explicit Keep choice remains available, and disabling the module restores the original settings.
- Blizzard's world numbers inherit the combat-text font role before login. Log out to the character screen and back in to apply the font; `/reload` is not enough.

### Added

- Bounded quest-card diagnostics in `/kstyle test`, plus automatic saved diagnostics when tracked quests have no visible rows. The intermittent blank card is still under investigation; this release does not claim to fix it.

## v0.2.1 (2026-11-16)

The Medallions action slab as it was designed: one row and one connected piece.

### Changed

- Under Medallions, your first two action bars stand in a single row on every screen: twelve buttons left of the crest and twelve right of it. On 16:9 and narrower screens, such as a MacBook, the buttons are a fifth smaller so the row fits beside your chat, and their keybinds and cooldown numbers shrink with them so they never overlap.
- The slab, the crest and its wings are now one piece. The crest sits in the slab, the wings grow out of the crest along the slab's top edge and slide further along it when you enter combat, and your experience runs along the slab's lower edge, under the crest.
- Under Medallions on 16:9 and narrower screens, the pet and stance bars stand in two rows of five to the right of the slab, and the player and target frames sit a little higher so your target's target clears the bag bar.

## v0.2.0 (2026-11-16)

A third HUD style, Medallions, with a painted portrait of your character and a crest for your race and class.

### Added

- **Medallions**, a third HUD style next to Frames and Orbs. Pick it in Options > General > HUD style or on the HUD style step of the first-run setup.
  - Your player and target frames are dark steel slabs with clean bars and a round medallion on the outer end. Your medallion shows a painted portrait of your race, class and sex, and so does any other player you target. Creatures, pets and bosses show the game's own portrait. Your focus, pet and boss frames get medallions too, and your target's target and your focus's target are small slabs.
  - Your first two action bars sit on one steel slab: two rows of six on each side of the centre on screens narrower than 21:9, and one row of twelve on each side on 21:9 and 32:9.
  - At the centre of the slab is a crest painted for your race and class, 52 in all, in a ring of runes in your class colour. At rest it breathes, its runes turn and your class's particles drift round it. When you enter combat its wings spread. It pulses when an ability beside it lights up, and it bursts when you level up. The crest always sits under your action buttons, so it never hides a spell, a cooldown or a keybind.
  - Every effect answers something that happened. A slot flashes steel when its cooldown comes back. Your cast bar flashes when a cast lands, and flashes red when a cast is stopped, interrupted or fails. A red edge grows round the screen when your health runs low. The crest's ring lights up while your rage, energy or focus is full; a paladin's follows holy power and a warlock's soul shards, and mana never lights it. A burst blooms behind your portrait when you level up. Three seconds after combat, your pet, focus, focus target and target-of-target frames dim to 60%, and they come back when the next fight starts.
  - **Medallions motion** in Options > General > Medallions sets how much moves: Full (the default) adds the game's own 3D spell effects for procs and level-ups, Calm keeps the slow motion and short flashes, and Off stops the motion, though the low-health edge and the crest's ring still show and the frames still dim after combat. Options > General > Appearance > Motion still wins: Reduced caps Medallions motion at Calm, and Off turns it off.
  - The rest of the screen follows. Cards, windows, tooltips and menus turn to steel, with your class colour on their headers. The minimap turns round in a steel ring. Party members get painted badges, raid frames become class-coloured tiles, and friendly players' nameplates carry a small badge. Your cast bars hang under their slabs, and your experience and reputation show as thin strips under the action slab.

## v0.1.3 (2026-11-15)

A hotfix for the RestedXP guide card, with fixes for the bag window, the swing timer and nameplates.

### Changed

- Under Frames, while the RestedXP guide is shown, the guide card takes the tall column beside the minimap and the quest card moves into the space under the minimap, where it shows at least one quest and scrolls for the rest. That gives the guide room to show your whole current step. The two cards swap only when the guide opens or closes, never from one step to the next. Without RestedXP, or with its guide closed, the quest card stays where it was.

### Fixed

- The RestedXP guide card shows your current step again. When RestedXP put its steps under its own window, the card showed a blank block with only the step's last line and "1 more".
- RestedXP's Active Targets and Active Items boxes no longer take room the guide needs for your current step.
- The bag window's close button works again after you drag the window.
- A hunter's ranged swing shows one swing bar instead of two.
- Nameplates no longer creep upward a pixel at a time.

## v0.1.2 (2026-11-15)

Fixes for the minimap, the RestedXP guide and the HUD's size on screens that are not 16:9.

### Added

- A Minimap setting, **Addon pins on the map's edge**, under the addon drawer. Guides such as RestedXP park pins on the edge of the map for places off the map, which lined the map like a row of buttons. KstyleUI now hides those edge pins unless you turn the setting on. Pins for places on the map always show.

### Changed

- The minimap's addon drawer now collects every addon button that sits on the map, not only the ones it knew by name.
- Action bar 3 has its own place under Orbs, above the pet and stance bars. If you moved bar 3 yourself, it keeps your place.

### Fixed

- The zone name above the minimap no longer runs into the N diamond, and the N stays inside its diamond.
- RestedXP's Active Targets and Active Items boxes now sit side by side under the guide card instead of over it, and the guide keeps showing your current step and its step number. To make room for the step, the quest card may show one quest fewer while both boxes are up.
- Under Orbs, the health and power orbs no longer cover chat or the damage meter on 4:3, 3:2 and 16:10 screens.
- The pet and stance bars no longer overlap action bar 3 or the party frames, and the target frame and your buffs no longer overlap the bags bar or the loot feed. Interface size Auto now steps down until the whole HUD fits.
- Settings saved by an older version that had stopped updating now update at your next login.

## v0.1.1 (2026-11-14)

A hotfix for errors that players hit after v0.1.0.

### Fixed

- Raid frames and window skins no longer raise an error when the game loads.
- Switching the HUD style with Options open no longer raises an error.
- The "interrupt spell not allowed" warning no longer shows at login when no interrupt spell is set.
- Dragging the quest tracker in Edit Mode no longer raises an error.
- Nameplates no longer drop below the mob in combat.

## v0.1.0 (2026-11-13)

This is the overhaul. KstyleUI now has two HUD styles, Frames and Orbs, that you pick in Options and in the first-run setup, and almost every part of the screen was redrawn to match them: cleaner bars, new nameplates, a group damage meter and an interface size that lands exactly on whole screen pixels.

### Added

- Two HUD styles to choose from. Frames keeps the framed player and target cards. Orbs puts health and resource in two orbs with a forged tray round your first action bar. Options > General shows a picture of each style and the first-run setup has a HUD style step, so you see what you are picking.
- A group damage meter in the style of Details: one card with a bar per player, a switch between this fight, the last fight and the whole session, and the spell split under each row. The threat card follows the same design.
- Nameplates redrawn: plain, flat bars with tracked capital names, a black track while you hold threat, cast and stop flashes, and a name-only plate for objects such as a mailbox that can never fill a bar.
- A wide target bar at the top of the screen under Orbs, and a wide form of the target frame under Frames.
- Ultrawide screens choose between Centred and Spread. Centred keeps the HUD in the 21:9 band in the middle of a 32:9 monitor. Spread uses the whole width and keeps your group frames on the 21:9 line.
- One shared action slot for the action bars and the cooldown rows, with a pressed state, a proc glow, a lit sweep edge and a gilt flash when an ability is ready again.
- Combat text with white hits, gold crits and a short rise.
- Buffs sorted by how you use them.

### Changed

- The unit bars are clean: health and resource fill with a held loss band, a flash on a hit and a warning curve at low health. The target fills from the left, cast bars are taller, and party and raid frames use the same bars with a low-health glow.
- Interface size Auto now picks the size that fits your screen exactly and keeps every frame, bar, slot, aura and combat text on whole screen pixels. Under Orbs it reaches the same size as under Frames.
- The experience strip is clean, the readout sits on the world, and the micro menu shows only when you need it.
- Party frames sit at mid-left, and the right rail leaves room for four quests with the threat card off the centre.
- Tooltips, windows and the quest card share one card design. Tooltip headings, window headings, dropdown chevrons, bag and chat headings and in-tile aura counts were redrawn to match.
- Class colours on names are easier to read, and spell and cast labels no longer use Cinzel.
- Text is never drawn below 11 pixels at 1080 lines, and the Meters sample fits the settings pane.
- Options names only Frames and Orbs as HUD styles.

### Fixed

- The RestedXP guide step arrow is set in the number face and the steps are pitched like the quest card, and RestedXP's steps frame is sized so it enables under the rail.
- The damage card shows short whole numbers in and out of combat.
- Nameplates no longer dart about: the plate scale settings are held at 1 while plates ignore that scale.
- Baine fixed two things and we ported them: minimap buttons now move onto the square map's shape even when they were made before KstyleUI loaded, and the drawer collects the buttons Blackthornes and 0xgle Bugs draw themselves, and hands them back as they were. Baine also fixed nameplates for game objects. Thank you, Baine.
- The unit frames' bars no longer carry an ornament around them.
- The chat tab and its wash sit inside the chat card.

## v0.0.7 (2026-11-13)

A small release that fixes two things in the cooldown and buff displays.

### Fixed

- When KstyleUI falls back to Blizzard's own essential and utility cooldown rows, they now sit on KstyleUI's rows instead of on top of your action bars. A row you moved yourself, or one too wide to fit, stays where it was.
- Tracked buff icons and bars keep the right gap between icons at every icon size and UI scale.

## v0.0.6 (2026-11-13)

This release fixes what the first live session on World of Warcraft: Forever turned up, and sets the HUD up properly for ultrawide screens.

### Added

- A centred HUD width for ultrawide screens. The HUD sits in a 21:9 band by default, with 16:9 and full width as choices in Options, so nothing is stranded at the far edges of a 32:9 monitor.
- Separate cards for your quests and the RestedXP guide on the right rail, in place of one shared story card.

### Changed

- Empty slots on action bars 4 and 5 are hidden at rest. They still show while you drag an action onto a bar and while Layout Mode is open, and filled slots are always drawn.
- The damage meter shows KstyleUI's own card instead of Blizzard's restyled window. Blizzard's window is still there under Options > Meters > Style.

### Fixed

- Forged trim now draws on nameplates and on the player and target frames, placed from KstyleUI's own layout.
- Nameplates and the unit tooltip no longer raise "Can't measure restricted regions", so nameplates are no longer left half built.
- The chat text area fills the chat card, with no gap under the last line.

## v0.0.5 (2026-11-12)

KstyleUI is a full interface for World of Warcraft: Forever, drawn in one dark, Diablo IV-style forged look. Cards and windows are forged iron with corner brackets by default, and you can switch the card material in Options. You choose the type set (Folio, a classic serif, is the default; Lumen is still there) and a font for each kind of text, and forged ornaments on frames, bars, plates, the minimap and windows run at Off, Subtle or Full. This is the first public release.

### Added

- Every part of the interface as a module you switch on when you want it: unit frames, group frames, action bars, cooldowns, buffs and debuffs, nameplates, combat text, minimap, chat, bags and bank, tooltips, data bars, meters, window skins and a quality-of-life module.
- A settings window (`/kstyle`) with a page per module, search across every setting and a live preview, per-character profiles you can export and import as a string, and a first-run setup that picks a DPS, Tank or Healer layout and your modules.
- Layout Mode (`/kstyle layout`): move, resize and scale every element with snapping guides, a grid, arrow-key nudges, undo and redo, and set when each element shows.
- A card material choice in General: Forged iron with brackets (the default), Forged iron with gilt ticks, Slate, Flat or Glass. Dropdowns and tooltips stay opaque on every material except Glass.
- Type sets and fonts by role: pick Folio or Lumen, then override the font for any role, from KstyleUI's own faces or any LibSharedMedia font.
- Forged ornaments at Off, Subtle or Full (Full by default), on unit frames and cast bars, the action bar tray, nameplates, the minimap, the experience, reputation and honour bars, windows, tooltips and the RestedXP windows. They are dropped where they do not fit, never squeezed.
- A story card on the right rail that shows the RestedXP guide and your quests, a loot feed above the chat card, a white cursor on the player's cast bar, and a skin for RestedXP's other windows.
- Fast auto loot, auto repair, quest hand-in and quiet error text in the quality-of-life module, and an offer to update your bars when you learn a new spell rank.
- Bag search with `type:`, `name:`, `ilvl` and quality keywords, custom categories, junk selling, and a bank window with Warband tabs.
- A damage meter with a fight switch (now, last, all) and a spell split under each row, a group threat meter and a swing timer.
- Chat history that survives a reload or relog, a copy window, timestamps, short channel names and clickable links.
- Group frames with debuff priority and dispel highlights, your heals, absorbs, indicator slots and compact raid frames above 25 players.
- English, German, French, Spanish and Simplified Chinese. The German, French, Spanish and Chinese strings are machine-made and not yet checked by native speakers; report a wrong or awkward one.
- An optional icon pack of repainted ability and item icons, a separate download (see How to install).

### Changed

- Layouts follow one reference picture: chat and your party on the left, your hands at the centre, and the map, buffs, bars, readout and story card on the right. DPS, Tank and Healer layouts do not overlap at 16:9, 16:10 or 21:9, and everything sits on whole screen pixels at every size.
- The minimap is a square map inside a thin rim, with its controls shown while the pointer is over it. Buffs and debuffs are plain icon rows beside it.
- Unit frames, cast bars, the experience bar, nameplates and the chat card follow the picture's sizes, ramps and edges. Nameplates are flat bars with tracked capital names, and they are larger when you pull.
- Section captions and names use letter-spaced capitals. Under Folio, tooltip titles, chat and the boss cast names follow the type set.
- Player-facing German wording for the action bar, meter, minimap and font options was polished.

### Fixed

- Nothing raises "Font not set", "Cannot anchor protected frames to regions" or a secret-value error on the minimap, aura frames or nameplate casts, and capitals no longer show boxes between letters.
- Bags, group frames, auras and action bars hand back to Blizzard's own when you switch to the gamepad interface.
- The data strip, clock, chat, group frames and nameplates do less repeated work, so busy groups and big pulls stay smooth. Nameplate cast bars no longer restart or stick.
- Pet bar icons and right-click autocast work, item cooldowns use the right timers, and tracked buffs and group frames no longer hide dispellable debuffs.
- Chat shows whole lines at every size, the threat card keeps its rows at 1366x768, the quest card keeps all four quests, and forged trim no longer disappears on bars at the screen's edge.
- Players whose class is hidden in restricted content keep their class colour.

## How to install

1. Download the addon zip (`KstyleUI-v0.1.1-forever.zip`) from the [GitHub release](https://github.com/korallis/KstyleUI/releases) and unzip it into `World of Warcraft/_forever_/Interface/AddOns`. You get `KstyleUI` and a `KstyleUI_<Module>` folder for each module. Fully quit the game and start it again (a `/reload` is not enough) so the addon's fonts load, then type `/kstyle` and switch on the modules you want.
2. Optional: the icon pack, the `KstyleUI-Icons` zip from the same release, repaints ability and item icons everywhere, buff tiles included. It is not an addon and does not go into `AddOns`: quit the game, copy its `Interface` folder into `_forever_`, and start the game again. The steps, and how to remove it, are in [the icon pack guide](https://github.com/korallis/KstyleUI/blob/main/docs/icons.md).
