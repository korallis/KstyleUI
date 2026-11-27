# KstyleUI changelog

## v0.3.5.3 (2026-11-27)

A hotfix for players who use the game's UI Scale: KstyleUI can now follow it instead of keeping its own pixel-perfect size, from settings or from setup.

Highlights:

- A new switch in General > Size lets KstyleUI follow the game's UI Scale instead of its pixel-perfect size.
- Setup offers the same choice, and windows it placed keep their spot when you change the game's UI Scale.

### Added

- Interface size: a Follow the game's UI scale switch under General > Size. While it is on, KstyleUI grows and shrinks with the UI Scale in the game's options, up to the largest size that fits, and the Auto switch and size slider hide. It is off by default, so nothing changes until you turn it on.
- Setup: the HUD style step has an Interface size row with Pixel perfect and Game's UI scale, and shows Your own while you use the size slider. The choice applies when you press Apply.

### Fixed

- Setup: the quest tracker, damage meter and other windows that setup placed in Edit Mode keep their place on screen when you change the game's UI Scale. A damage meter placed by an older setup moves with them after you apply setup again.
- Profiles: the import warning also names the new Interface size switch.

## v0.3.5.2 (2026-11-27)

A hotfix for the HUD's action bars: a bar shape that cannot fit keeps the HUD its usual size, and two-row bars move the frames above them out of the way.

Highlights:

- A bar shape that cannot fit beside the others no longer shrinks the whole HUD below its usual size.
- Two-row action bars lift the frames above them by a row, so the bars no longer cover the player frame.

### Fixed

- HUD: a bar shape that overlaps at every size no longer shrinks the whole HUD; the HUD keeps its size.
- HUD: when bar 1 or bar 2 takes more than one row, bar 2 (under Frames) and the frames above the bars move up by the added rows. Frames you placed by hand in Layout Mode stay where you put them.
- Releases: CurseForge and Wago show one version's notes with each file, as the GitHub release page already did.

## v0.3.5.1 (2026-11-26)

A hotfix that adds a collapse toggle to the quest card and ships the bug fixes made since v0.3.5, from the chat edit box and trainers to settings, group frames and nameplates.

Highlights:

- Click the quest card's header to fold the card down to that one row, and click again to open it.
- The chat edit box opens in its own strip under the newest line, no longer over your messages.
- You can train again after choosing another spell, and the Train all button the game refused is gone.
- Settings sliders save when you let go, a bad import keeps your text and Layout Mode's Discard puts things back.
- Healer cues stay on raid frames, and nameplates, channels and boss auras read clearer in crowded fights.
- Consumable keys, guide text, tooltips and item readouts get fixes, and the HUD does less work in busy moments.

### Added

- The quest card collapses and expands from its header. A click on the header row folds the card to that row, and a second click opens it on the same quests at the same scroll place.
- An arrow beside the quest count points up while the card is open and down while it is folded, and the card remembers its state in your profile, through reloads and profile switches.

### Changed

- The HUD skips updates that change nothing, nameplate polling stops when no plates are up, and quest sharing, loot bursts, bag searches and chat history do bounded work.

### Fixed

- Chat: the edit box no longer covers the newest chat line while you type. The messages move up to give it its own strip and return when you stop.
- Trainers: buying from a trainer no longer fails with a blocked-action error after you choose another spell or reopen the window, and trainer rows keep the game's own height.
- Quality of Life no longer offers the Train all button, which the game refused with a forbidden-action error. Train with the trainer's own Train button.
- Nameplates: a refused stacking request retries only once after combat, late plates fade in, Dungeon names every casting enemy and simultaneous hits start on separate rows.
- Cast bars and auras: an early channel stop no longer looks like a finished cast, a targeted boss keeps its aura row, and a tracked buff stays in your buff row when the cooldown viewer hides it.
- Group frames: both healer raid presets keep their heal and dispel slots, only a visible ready-check icon displaces the resurrection cue, and similar shortened names stay distinct.
- Settings: window sliders preview the drag and save on release, a failed import keeps your pasted text, account imports report what they applied, and Layout Mode's Discard restores positions.
- Action bars: consumable keys follow eligible items in their category, binding mode names the command a key displaces before you save, and out-of-range actions gain a mark that does not rely on colour.
- Guide and notices: raid tools open below the guide, character stats follow the global text size, and quest actions, repair messages and potion notices wait for readable data.
- Motion Off stops the tank alarm flash without hiding its warning, stationary warlock procs hold one cell, tooltips and dropdowns align to whole pixels and translated minimap labels fit.
- Readouts: manual waypoints are kept, item tooltips say who owns an item, and stale readings look different from current ones.

## v0.3.5 (2026-11-25)

The crest comes alive. No more little icons on the crest: every class's buffs, debuffs, procs and cooldowns are now part of the crest itself, perched in the ring, burning round it as fuses or charging in grooves in the band. Ten new crest effects join them, inspired by the old WeakAuras centre-piece UIs, plus sigils for your cooldowns and your trinkets on the rim. Every piece has its own switch under Action Bars > Slab and cooldowns. Rogues and cat druids also get an energy tick spark, expiring timers stay readable everywhere and windows show at once.

Highlights:

- The crest comes alive: your buffs, procs and cooldowns are part of the crest now, no more little icons.
- Ten new crest effects, from Unleashed cooldowns and rising heat to a cast ring, kill window and target lock.
- Your cooldowns light engraved sigils, and on-use trinkets burn their cooldowns round the crest's rim.
- Rogues and cat druids get an energy tick spark that sweeps the energy bar between ticks.
- Aura timers about to run out turn a lighter red that stays readable over any scenery, on every frame.
- Windows and pages show at once, no more invisible windows, plus RestedXP, loot-roll and Zygor fixes.

### The crest

Every class's pieces now live in the crest itself, and under Frames the same pieces stand free in the tracker row.

- Warriors, paladins and rogues: a war horn, weapons perched in the ring, grooves that charge and drain, the Seal's colour on the inner rim, blood with Rupture and a Slice and Dice fuse.
- Hunters, mages and warlocks: Stings, spells and Curses burn down the ring as fuses, pet and demon health glows along it, mage armor grows as crystals and interrupts cut through as blades.
- Priests, druids and shamans: figures of light, from Penance's lance and a dome for your shield to a cat's rakes, a bear's roar, an ankh for Reincarnation and a spirit wolf.

Ten new crest effects, inspired by the old WeakAuras centre-piece UIs:

- Unleashed: a major cooldown sets the crest ablaze in your class's fire.
- Rising heat: each combo point or stack warms the crest a step.
- Glyph tide: the rune glyphs light from the foot up as your rage, energy, focus or mana fills.
- Stance mantle: the runes and inner rim take your stance's or form's colour.
- Cast ring: your cast draws round the crest's edge, flashes when it lands and shakes red when interrupted.
- Swing ring: a steel line drains inside the crest over each main-hand swing.
- Global cooldown spark: a white-hot spark runs round the edge once per global cooldown (off by default).
- Expiring ember: timer rings and sigils glow amber, then red, as they run out.
- Kill window: Execute or Hammer of Wrath range burns the foot of the inner rim red-hot.
- Target lock: forged claws close round the crest on a new enemy, and the top gem shows elite, rare or boss.

### Added

- On-use trinkets burn their cooldowns round the crest's cooldown ring, with a jewel that refills and flares when the trinket is ready. Action Bars > Trinkets on the crest.
- Dark Rune and Demonic Rune get their own slot on the consumables bar, right after mana potions.
- Energy tick spark for rogues and cat druids: a white line sweeps the energy bar between the two-second ticks, so you can time the next one. Unit Frames > Player > Energy tick.

### Changed

- The crest's cooldown row lights an engraved sigil for each major cooldown, racial and potion you have running, with a ring that drains as it runs. Frames shows the same sigils.
- Aura timers about to run out turn a lighter red that reads over bright and dark scenery, on the buff bar, nameplates, unit frames and party and raid frames.
- Unit frames and party and raid frames get their own Warn under setting for when timers turn red.

### Fixed

- With Motion on, every KstyleUI window, Options page, menu, tooltip and skinned Blizzard window shows and hides at once, so none draws half finished or stays invisible.
- RestedXP's guide configurator rows start their tile where RestedXP's own background starts, so each option's icon no longer covers its text.
- The loot-roll timer bar sits on whole pixels at every screen size and follows Blizzard's timer if it moves.
- Zygor's guide window keeps its place and Zygor's action bar no longer errors when RestedXP holds the guide card or the Zygor guide card is off.
- Raid debuff timers no longer cross the power bar, cover the stack count or run past the tile. Frames raid tiles keep three debuffs and show time left by the swipe.

## v0.3.4.5 (2026-11-24)

A small hotfix for the crest, which could throw Lua errors in combat.

Highlights:

- The crest no longer throws forbidden object Lua errors in combat, like Vanish or Stealth mid-fight.
- Every crest piece keeps lighting, filling and counting through the fight, shaman storm clouds included.
- Your first stance, form or Stealth switch in combat shows its crest pieces at once.
- Medals snap back to whole pixels after you change the UI scale.

### Fixed

- The crest no longer throws "forbidden object" Lua errors in combat. Vanish or Stealth mid-fight, a stance or form swap, a poison, Lightning Shield, Inner Fire and the shaman storm clouds could all set it off.
- Every crest piece keeps lighting, filling and counting through the fight: the bursts and Remorseless fire, the rogue vial, the shaman imbue runes, the storm halo, Inner Fire, the bear talons and the paladin jewels.
- Your first stance, form or Stealth switch in combat shows its medals at once, already sized.
- Medals snap back to whole pixels after you change the UI scale.
- In a dungeon, the crest catches up as soon as the lock on aura data lifts, not only when combat ends.

## v0.3.4.4 (2026-11-24)

A small hotfix for aura timers on the Medallions unit frames, which could get cut off at the bottom by the portrait rim.

Highlights:

- Aura timers and stack counts on your Medallions player, target and focus frames sit clear of the portrait rim.
- The Options preview matches, and Frames looks just as it did.
- The store pages and README have fresh pictures of the crest on every class.

### Fixed

- On Medallions, aura timers and stack counts on your player, target and focus frames sit clear of the portrait rim instead of being cut off at the bottom. Frames is unchanged.
- Focus auras set above the frame now sit over the portrait, like the player and target rows, so their first timers no longer hide behind the rim.
- The Unit Frames preview in Options shows its aura timers clear of the rim too.

## v0.3.4.3 (2026-11-24)

A small hotfix for the setup window and the world map search. Thanks to Baine for finding and testing these.

Highlights:

- With Motion on, setup's HUD style and Layout cards show their title, text, edge and your pick again.
- Setup's Your addons page draws its switches and dropdowns on first open, and every setup step shows at once.
- The world map search sits in the map's top bar next to the zone path, so it never covers the map.
- The search's Nearest list closes when you click away, press Escape, click the map or close it.
- Thanks to Baine for finding and testing these.

### Fixed

- With Motion on, setup's HUD style cards show their title, text, edge and your pick, Frames included, and the Layout cards show the Tank pick. Thanks to Baine for finding and testing this.
- Setup's Your addons page draws its switches and dropdowns on first open, and every setup step shows at once. Thanks to Baine for finding and testing this.
- The world map search sits in the map's top bar, right of the zone path, so it never covers the map art. Thanks to Baine for finding and testing this.
- The search's Nearest list closes when you click away, press Escape, click the map or close it. Thanks to Baine for finding and testing this.

## v0.3.4.2 (2026-11-24)

A small hotfix for the world map and the setup window. Thanks to Baine for finding and testing these.

Highlights:

- The world map keeps its terrain art after you view another zone, close the map and open it again.
- The /kstyle setup window no longer shows a Lua error when you press Next on the first page.
- Setup's Welcome, Modules and Your addons lists draw every row straight away, no scroll needed.
- Thanks to Baine for finding and testing these.

### Fixed

- The world map keeps its terrain art when you view another zone, close the map and open it again. The map now opens straight away, without its fade in. Thanks to Baine for finding and testing this.
- `/kstyle setup` no longer shows a Lua error when you press Next on the first page; the HUD style page opens and fits as before. Thanks to Baine for finding and testing this.
- Setup's Welcome, Modules and Your addons lists show every row as soon as they open, so you no longer have to scroll to make the toggles appear. Thanks to Baine for finding and testing this.

## v0.3.4.1 (2026-11-24)

A small hotfix for party and raid frames, which showed the same buff twice on a member. Thanks to Baine for spotting this.

Highlights:

- Party and raid frames show each buff once, so Find Minerals or a zone buff no longer turns up twice on a member.
- The External and Big defensives indicators stay empty for now, as Forever doesn't report defensives yet.
- Thanks to Baine for spotting this.

### Fixed

- Party and raid frames no longer show a member's buff, such as Find Minerals or a zone buff, in the External and Big defensives indicators. Thanks to Baine for spotting this.
- Those two indicators only light up for real defensives, which Forever doesn't report yet, so they stay empty for now. Pick one under Options > Party and Raid > Indicators and a note says so.

## v0.3.4 (2026-11-23)

Every class now has its own crest. Warriors, paladins, rogues, hunters, mages, warlocks, priests, druids and shamans each get the buffs, debuffs, procs and cooldowns they watch on the Medallions crest, one place to look, and on Frames they stand in a row above the stance bar. Every piece is on by default with its own switch and shows once you know its spell. Baine's report also brings three world map fixes.

Highlights:

- Every class now has its own crest: your buffs, procs, debuffs and cooldowns, one place to look.
- Major cooldowns burn round the rim, and mana users see the five-second rule round the level badge.
- Each piece has its own switch, on by default, and Frames shows them in a row above the stance bar.
- Warlocks see their Soul Shards from the bags as wisps on the crest.
- Stings and Rapid Fire on the hunter crest, thanks to the hunters in Discord.
- World map fixes thanks to Baine: search sits top-right, clears on close, and zone labels keep their size.

### Added

- Warrior: Battle Shout, the strike you can use right now, Enrage, your main strike and procs, interrupt, charge or taunt and your threat, in every stance.
- Paladin: your Seal, Judgement ready and on the target, Vengeance or Holy Shield on the jewels, Hammer of Justice and your spec's strike and buff.
- Rogue: Slice and Dice, Rupture, a poison vial per weapon, Kick and your spec's piece, with your openers and Vanish in Stealth.
- Hunter: your Aspect, your pet's health and happiness, Hunter's Mark, your Stings, an Auto Shot ring and a gust on Rapid Fire or Quick Shots. Thanks to the hunters in Discord.
- Mage: your armor, mana gem, Counterspell, Fire Vulnerability or Winter's Chill, Frost Nova, a ward ring and a Clearcasting blaze.
- Warlock: your DoTs as spires on the crown, Soul Shards from your bags as wisps, your demon, Healthstone, Curse, Spell Lock and Shadow Trance.
- Priest: Inner Fire flames, Penance, Shadowfiend and Shadowform, Shadow Word: Pain, and your heals or shadow damage on the target.
- Druid: a crest for every form, from Moonfire and Rejuvenation to Rake and Rip, Clearcasting leaves, and a bear's Growl, Feral Charge and tank glow.
- Shaman: weapon imbue stones, the shock cooldown sweep, Flame Shock, Stormstrike or Riptide on the target, and Reincarnation's cooldown.
- Every crest burns your major cooldowns round the rim and stands up to three below the emblem, newest first.
- Mana users get the five-second rule: a blue ring round the level badge runs for five seconds after each spell that costs mana.
- Each piece has its own switch under Action Bars > Slab and cooldowns, on by default. Frames shows them as medals in a row above the stance bar.
- Charge and stack counts sit inside their medal, outlined and sized to fit.

### Fixed

- Closing the world map clears its search, so an old search list or Nearest picker no longer comes back when you reopen it. Thanks to Baine for the report.
- The Search the map box sits in the map's top-right corner, so Blizzard's map pin button and other map addons no longer cover it. Thanks to Baine for the report.
- Zone level ranges on continent maps keep their size whether the map is windowed or maximized, after any zone switch and reopen. Thanks to Baine for the report.

## v0.3.3.1 (2026-11-23)

A small hotfix for setup's cards and tabs, the Medallions player frame and the crest minimap, plus a few polish fixes for the minimap buttons, proc glows and tracked bars.

Highlights:

- Setup's picked HUD style and role cards show a clean accent edge, and picking Tank now marks its card.
- Setup's tabs fit long German and French labels, and the HUD style pictures sit evenly in their cards.
- No more grey dots on the Medallions player frame: a status socket shows only when its icon is lit.
- The crest minimap's N sits on the forged ring, and the minimap buttons stay inside the round ring.
- Proc glows match the rim of the buttons beside them and can't stay invisible.
- Thanks to Baine for spotting the setup cards and tabs, the grey dots and the compass N.

### Fixed

- The card you pick on setup's HUD style and Layout steps shows a clean accent edge instead of a coloured wash with a dark square in its corner. Picking Tank now marks the Tank card too.
- Both pictures on the HUD style step sit evenly inside their cards, and the notes stay above them when the setup window is smaller.
- Setup's Look and Controls tabs no longer run into each other in German and French, at any window size.
- The Medallions player frame no longer shows grey dots after the resting Zz. A status socket shows only while its icon is lit, and lit sockets keep their even spacing.
- The crest minimap's N is lit steel engraved on the ring, the size of the runes around it, instead of sitting in a plain black disc. The zone name stays clear of it.
- On the round minimap the tracking, mail, calendar, queue and addon buttons follow the inside of the ring instead of crossing it, at any button size.
- The open addon drawer moves aside when you change the buttons' distance from the edge, and shows at once when you open it.
- With the buttons on the left, the minimap zoom slider moves to the right edge. It has a light rim now, so it reads as a slider instead of a stray gold line.
- A button that procs lights its rim at the same width as the buttons beside it, with a soft glow, instead of a thick bright border.
- A proc glow shows even if its fade-in never plays, so it can't stay invisible. Turning off Action Bars > Motion > Soft proc and ready glow brings back the old proc glow.
- A tracked buff bar's stack count sits inside its icon instead of spilling over the bar's top edge.
- In Medallions on wide screens, the consumables bar sits beside your player frame instead of floating far to its left.

## v0.3.3 (2026-11-23)

The fit and finish release. Party frames you can read at a glance, Medallions player and target frames that sit properly in the crest, and a polish pass over nearly every other part of the UI, from action bar keybinds to merchant prices. The RestedXP skin works again with RestedXP 4.11.39. The bigger changes are on by default, each with its own switch. The crest trackers for every class aren't in this one; they're coming in v0.3.4.

Highlights:

- Party frames are a quarter larger on ultrawide, and their names and health percentages stay readable.
- Medallions player and target frames dock into the crest, with even bars and status icons in steel sockets.
- Incoming heals show in the health bar's own colour instead of a green chunk.
- A polish pass over bars, nameplates, the minimap, chat, bags, tooltips, meters, quests, skins and Options.
- The RestedXP skin works again with RestedXP 4.11.39.

### Changed

- On ultrawide screens (21:9 and wider) party frames are a quarter larger, unless you set their size yourself. Party and Raid > Readability > Larger party frames.
- Party and raid health percentages no longer cut off, party names sit on a darker backing and out-of-range members stay readable. Party and Raid > Readability > Readable names and numbers.
- The missing part of a health bar stays dark without the just-lost band, and offline and dead members show empty bars. Party and Raid > Readability > Dark missing health.
- Medallions player and target slabs dock into the crest ring, and their bars sit evenly inside with power in its own colour. The focus frame gets the same bars.
- Status icons sit in steel sockets on the slab's top edge, an empty slot on the player shows a small rivet, and the raid marker sits on the portrait's rim.
- Cast bars on these frames start clear of the portrait ring, with the cast icon inside the cap. Unit Frames > Fitted slabs.
- Incoming heals draw in the health bar's own colour instead of a green segment. Unit Frames > Heal prediction in the bar's colour.

### Fixed

- The RestedXP skin works again with RestedXP 4.11.39, which it skipped entirely. The theme, guide card, arrow and docked boxes all apply, and the boxes stay docked when RestedXP's scale changes.
- Aura stack counts sit inside their icon's corner, and boss and focus cast bars show their track instead of a stub at the far end.
- Keybinds and stack counts on Medallions action buttons sit on the icon instead of the socket's rim, and pet autocast dots sit inside the pet icon.
- The leave-vehicle button matches the action sockets beside it, and the crest travel menu opens above your cooldown row instead of covering Mounts.
- The coordinates plaque under the crest minimap sits on top of the ring instead of being cut by it.
- The nameplate threat mark is a small mark past the target brackets instead of a block, and on Frames the level diamond clears the bracket.
- An undocked chat window's input box opens inside the window instead of hanging across its bottom edge.
- Bag items on cooldown show the swipe alone instead of two numbers, and item levels and counts clear the quality border. Bags > Swipe-only cooldowns.
- The "Currently equipped" label on comparison tooltips sits on its tooltip instead of floating above it.
- The honour bar has its own colour, and in Medallions it matches the experience and reputation bars. Data Bars > Honour bar > Match the other bars.
- The Medallions data bar spreads its readouts over both sides of the crest. On Frames the micro menu sits inside the top bar and the experience bar gets the same edge line.
- The swing timer keeps a finished swing's full bar until it hides instead of showing an empty black box, and its labels sit inside the bar.
- Meter cards end under their last row, an empty threat card on its own is just its heading and No target, bars show their track and row icons clear their names.
- Blizzard's restyled damage meter puts names and numbers above the bars and keeps class colours in names, so no name vanishes on a white bar.
- Quest tracker counts and the collapse arrow sit inside the card, and the quest card no longer ends in an empty dark bar.
- RestedXP's target and item boxes are small icon chips instead of wide empty panels, and its guide configurator buttons form one even row.
- RestedXP's Recommended line sits inside its option, and the v2 guide window's title clears RestedXP's logo.
- RestedXP's arrow text makes way while the game shows the name of the zone you enter. Window Skins > RestedXP > Arrow text makes way for zone names.
- Spellbook headings use the window title's caps, its spec tabs clear the window's edge, and merchant item names no longer run into their prices.
- Settings lists fade out at the bottom when there is more to scroll, and search shows each heading once with its hint on one line.
- The Unit Frames preview shows a portrait and level in the medallion instead of an empty black disc, and a changed preview always shows.
- The Auras and Data Bars previews show their samples in order with the values in one column.
- Setup's Welcome page shows the Medallions and Frames pictures at full size, and the Layout page outlines the card you point at straight away.
- Setup's Modules page keeps its two columns of toggles lined up in every language.

## v0.3.2 (2026-11-23)

The gamepad release. Your action bars show your controller's buttons while you play with one, and a new Controls choice sets bars 1 and 2 up for a pad in one click. Shaman totem fans get their forged backing, the consumables bar starts bigger with no gaps, and setup and Options pages stop opening blank. Everything new is on by default, with its own switch.

Highlights:

- While you play with a gamepad, your keybinds show its Xbox, PlayStation or Switch buttons instead of key names.
- Pick Keyboard or Gamepad in setup or on the General page; Gamepad sets up bars 1 and 2 for a controller.
- Shaman totem fans open on a dark forged band in the element's colour, and each choice wears its element.
- The consumables bar starts at button size 26 with no gap between buttons.
- Setup and Options pages no longer open blank in game.

### Added

- While you play with a gamepad, your action bar keybinds show its Xbox, PlayStation or Switch buttons, as the game draws them, instead of key names.
- Shift and Ctrl show as the left and right triggers. Action Bars > Bars > Controller button icons.
- A Controls choice in setup and on the General page under HUD style. Gamepad puts eight buttons on bars 1 and 2, each in a left and a right group of four.
- On Frames, Gamepad also drops the tray so both bars get bigger buttons. Keyboard puts them back as KstyleUI ships them. General > Setup > Keyboard or gamepad bars.

### Changed

- The consumables bar starts at button size 26 with no gap between buttons. Sizes and spacings you set yourself are kept. Action Bars > Bar to edit > Consumables bar.
- Spacing -1 on the consumables bar still gives you the HUD style's gap.

### Fixed

- The shaman totem bar's choice fan opens on a dark forged band rimmed in the element's colour, and each choice wears its element's edge and tab.
- Under Frames each fan column starts above its socket's spire, so your totem's timer stays in sight. Action Bars > Slab and cooldowns > Shaman totem bar.
- The setup window's pages, Welcome included, show in game again instead of opening blank after `/kstyle setup`. Options pages no longer go blank when you switch page.

### Upgrading

- A consumables bar you moved but never resized grows from its centre. If it now overlaps a bar, move it in Layout Mode.

## v0.3.1 (2026-11-23)

Your gear shows its item level on the character and inspect windows, the lit glass finish reaches the Blizzard bars KstyleUI restyles, and two v0.3.0 bugs are fixed: nameless world map route steps and solid party and raid frames. Everything new is on by default, with its own switch.

Highlights:

- Your character window and the inspect window show each piece of gear's item level, in its quality colour.
- The trainer, Legacy, RestedXP and quest tracker bars KstyleUI restyles get the same lit glass finish.
- World map routes name every step, and the last one names where you are going.
- A debuff you can dispel tints party and raid frames lightly again instead of covering the name.

### Added

- Your character window shows each piece of gear's item level in the top left of its slot, in its quality colour. The shirt, tabard and ammo slots get none.
- The inspect window shows the same numbers for the player you inspect once their gear loads. Window Skins > Character sheet > Item levels.
- The numbers match the ones your bags already had, which stay under Bags > Item levels.

### Changed

- Bars in the windows KstyleUI restyles get the same lit glass finish as its own bars. Turning off General > Appearance > Lit glass bars gives them their old look back.
- That covers the trainer's skill bar, the Legacy window's reward and challenge bars, RestedXP's guide import bar and the quest tracker's timer and progress bars.

### Fixed

- World map routes name every step. A step between named places takes the nearest town or area, and the last names your destination, like Road to Innkeeper Grosk.
- Routes no longer offer a hearthstone with no place after it when the game gives no bind location.
- A debuff you can dispel tints party and raid frames at your Party and Raid > Debuffs > Highlight fill opacity again, instead of a solid colour that hid the name.

## v0.3.0 (2026-11-23)

The polish release and the explorer release in one. Every bar, name and panel gets a finishing pass, cast bars tell you who a spell is aimed at, and the world map routes you to the nearest innkeeper by road, zeppelin or hearthstone. Everything new is on by default except Reveal unexplored areas, and each one has its own switch if you prefer the old look.

Highlights:

- A clean screen at rest: out of combat with no target, your bars and player frame fade until you need them again.
- One lit glass finish on every bar, and Medallions names, levels and cast names in one typeface.
- Target and focus cast bars show who a spell is aimed at, and when your interrupt is back.
- The world map finds the nearest innkeeper, bank or trainer you have visited and routes by zeppelin, tram or hearth.
- Options search takes you straight to the setting, and the first run shows big pictures and one-click Looks.

### Added

- A clean screen at rest. Out of combat with no target and nothing going on, your action bars, player frame, data strip and cooldown rows fade to 35% after three seconds.
- They come straight back when you target, cast, enter combat, open Layout Mode, drag a spell or point at them, or when your health or power changes. Elements > Clean screen at rest.
- Under Clean screen at rest you can turn it off, set Rest opacity and pick which panels fade. A bar you set to fade until hovered keeps its own fade.
- Target and focus cast bars, on their frames and on nameplates, show who the spell is aimed at in their class colour, or YOU when it is aimed at you.
- Casts you cannot interrupt carry a shield. While your interrupt recharges the bar dims, counts down the seconds and shows a gold mark where it comes back.
- An interrupted cast briefly shows who interrupted it. Unit Frames > Cast targets and interrupts, and Nameplates > Cast bar > Cast targets and interrupts.
- Medallions unit frames and cast bars end in forged steel caps, lit like the crest's ring, and cast bars end in a blade tip. Unit Frames > Forged slab ends.
- A soft glow behind nameplate names and a drop shadow under timers and counts keep text readable over bright ground and spell effects. General > Appearance > Soft glow behind world text.
- The world map remembers the innkeepers, trainers, banks, auction houses, repair and reagent vendors you visit, pins them and routes you to the nearest. Window Skins > World map > Nearest services.
- Clear the map's search box and pick Nearest innkeeper, Nearest bank or any other service. Visits are shared by every character on your account.
- Clicking a quest on the quest card routes to it on the world map, or tells you when the game gives no position. Window Skins > World map > Click a quest to route.
- Routes use zeppelins, the Deeprun Tram and the boats between Kalimdor and the Eastern Kingdoms, so a place on the other continent gets a full route. Window Skins > World map > Travel stops.
- Routes take your hearthstone, Astral Recall and the teleports and portals you know when they are faster, and count any cooldown still running.
- The world map can reveal the areas you have not explored yet, dimmed so you can still tell them apart. Window Skins > World map > Reveal unexplored areas, off by default.
- Settings search takes you there: press Enter or click a result's name and the window opens that page at the setting and lights the row. General > Window conveniences > Search takes you there.
- Search knows more everyday words, so "hp" finds health settings, "color" finds colour and "kick" finds interrupts.
- The Elements page shows a small map of your screen with every element on it, and the Profiles page shows your text and colours. General > Window conveniences > Previews on Elements and Profiles.
- Setup shows one big picture of each layout in your HUD style, and on ultrawide screens pictures of Centred and Spread to pick from. General > Setup > Big pictures in setup.
- One-click Looks in setup and on the General page under HUD style: Forged (the usual look), Clean and Readable. General > Setup > One-click Looks.
- KstyleUI tells you once after login if part of it is turned off, missing, out of date or failed to load, and offers the fix: turn it on and reload, reload, or a download link.
- About > Status shows how every part of KstyleUI is doing and gives you a report to copy into Discord. About > Status > Load check.

### Changed

- KstyleUI's bars share one lit glass finish: a soft light along the top, a thin bright edge and depth toward the bottom. General > Appearance > Lit glass bars.
- That covers health, power and cast bars on unit, party and raid frames and nameplates, plus experience, reputation, swing timer, tracked buff and movement bars.
- Damage and threat meter bars only get the light, so class colours stay full strength.
- Medallions names, levels and cast names share one clean number face with the rest of the HUD. General > Appearance > One typeface voice.
- Out of combat with no target, the Medallions crest settles to a slow breath and wakes when you enter combat, pick a target or get a proc. General > Medallions > Calm crest at rest.
- Menus, settings pages and Layout Mode open, close and fade with the same timing as the settings window. General > Window conveniences > One motion style.
- Layout Mode's snap guides are thicker and fade in as an element snaps, and a snapped element holds still while you drag inside the snap. Elements > Mover controls > Clear snap guides.
- Boat and zeppelin steps in a route are named after their town, like Boat to Booty Bay or Zeppelin to Brill.

### Upgrading

- Every new look is on for you too; turn any one off to get that part of the old look back.
- Bars and text: General > Appearance > Lit glass bars, One typeface voice and Soft glow behind world text.
- A screen that never fades: Elements > Clean screen at rest > Fade panels at rest.
- Medallions: Unit Frames > Forged slab ends, and General > Medallions > Calm crest at rest.
- Cast bars: Cast targets and interrupts under Unit Frames, and under Nameplates > Cast bar.
- Options search, previews and motion: General > Window conveniences.

## v0.2.15 (2026-11-22)

The last group frames round. Names can sit under the bars, your party heal icons can move off the frame so the name gets its whole line back, and party and raid frames can follow FrameSort.

Highlights:

- Party and raid names can sit under the health and power bars, in Medallions and Frames. Off by default.
- Your heal icons on party frames can sit outside the frame, so the name keeps its whole line. Off by default.
- Party and raid frames can follow FrameSort's order while FrameSort is installed.

### Added

- Names can sit under the health and power bars on party and raid frames, with the role icon, leader crown, your heals and the health percent. Party and Raid > Names above the bar > Name under the bar, off by default.
- On Medallions raid tiles tall enough for two lines, Name under the bar puts the name at the foot of each tile and the percent, debuff pips and heals at its head.
- Your heal icons on party frames can sit outside the frame: beside it, past the debuffs, targets and pets, or above frames set side by side. Party and Raid > Party frames > Heal icon place.
- Party and raid frames can take FrameSort's order and follow it when FrameSort changes it. Party and Raid > Party frames or Raid frames > Sort by > FrameSort, offered only while FrameSort is loaded.
- The order only changes out of combat, so someone who joins mid-fight shows up when combat ends. Without FrameSort the frames go back to group order.

## v0.2.14 (2026-11-22)

Raid night gets new reminders: flasks, low mana at ready checks and paladin blessings on party and raid frames, which also get pets beside their owners, your own place in the party and more. Your unit frame aura settings now stick in every layout, the Options previews fit their pane and RestedXP's boxes stop twitching.

Highlights:

- Flask reminder: in a raid, the reminder card names a flask in your bags while no flask is on you. Off by default.
- Low mana at ready checks: the card warns while your mana is under 80 percent. Off by default.
- Party and raid frames: paladin blessing reminders, pets beside their owners, your own place in the party and more.
- Player and target aura settings stay as you set them in every aura layout.
- RestedXP's Active Targets and Active Items boxes stay still when the guide updates.
- Shapeshifting, target changes, RestedXP, Zygor and opening windows do less work, with no change in look.

### Added

- Flask reminder: in a raid and out of combat, the reminder card names a flask you carry and how many you have, while no flask is on you. Auras > Missing buff reminder > Flask reminder, off by default.
- Low mana at ready checks: during a ready check the card says Low mana while your mana is under 80 percent, and goes once you drink past it. Auras > Missing buff reminder, off by default.
- Both work without the class buff reminder, and Reminder font, Reminder text size and Reminder outline style all three.
- Paladins: Missing buffs can remind you of a blessing for tanks, healers and damage dealers, and each class can take its own blessing or none. Party and Raid > Missing buffs, all off by default.
- Indicators can show only while you play a role or a class, so one profile suits every character. Party and Raid > Indicators > While you are and Only for your class.
- Your own party frame can sit at the start or the end of the party, whatever the sort. Party and Raid > Party frames > Your frame's place.
- Pet, tank and friendly boss frames can grow their debuff, heal and indicator icons with their extra height: Resize icons with the frames under each, off by default.
- Key Bindings > KstyleUI > Add your target to tank frames puts your target in the tank frames, and a second press takes them out.
- Party pets can show beside their owners instead of in the pet frames. Party and Raid > Pet frames > Party pets beside their owners.
- The dispel highlight can sit under heal absorbs, shields and incoming heals, so they read through it. Party and Raid > Debuffs > Highlight under the bar's fills.

### Fixed

- Player and target aura position, growth, size, spacing, rows and columns stay as you set them in each aura layout, even when you pick another layout's default. Unit Frames > Player and Target.
- The aura settings on those pages show what the current layout draws, so Rows above frames no longer shows the Frames numbers.
- The unit frame preview in Options no longer cuts off the top of the target's auras on ultrawide screens, and its names and labels draw at crisp whole-pixel sizes.
- The target preview hangs its cast bar at the same distance under the frame as in game, and thin 5-pixel bars, like the Frames target's cast bar, keep their dark edge.
- RestedXP's Active Targets and Active Items boxes under the guide card no longer shift by a pixel each time the guide updates.
- KstyleUI does less work each time RestedXP, Zygor, minimap buttons or Blizzard's windows redraw, and a window's header is set up once when it opens.
- Shapeshifting, loading screens and target changes no longer redo work on the crest, its crowns and jewels or the pet bar.

### Upgrading

- Aura settings you changed carry over to every aura layout, so each one looks as it did before.

## v0.2.13.1 (2026-11-22)

A small KstyleUI hotfix for frame rate. It should feel smoother with your other addons running and do less work while you stand around.

Highlights:

- Smoother frame rate with RestedXP and Questie.
- Minimap buttons stay put in the drawer with less work when other addons move them.
- The minimap, auras, chat and meters do less work while you stand still.

### Fixed

- KstyleUI stops redoing the same work on RestedXP's guide, Questie's text and hidden Blizzard frames.
- The minimap drawer only fixes what moved, and the coordinates only update when the numbers change.
- Auras, chat and the damage meter skip repeat updates. The low-health warning stops checking your health when you turn it off.

## v0.2.13 (2026-11-22)

Frames returns alongside Medallions. RestedXP and Zygor guides move to a card of their own in the top left corner, the quest log keeps the story rail and raid warnings fit MacBook screens.

Highlights:

- Frames is back alongside Medallions, with class crowns, Spirit Poles, Ghost Wolf and Lightning Shield storm orbs.
- RestedXP and Zygor guides move to a card in the top left corner, above the party frames, where a whole step fits.
- The quest log keeps the story rail under the minimap to itself, at its own height.
- The threat meter keeps its own place instead of following the guide card.
- Raid and boss warnings sit in the upper part of MacBook and other 3:2 screens, clear of the boss frames.
- Setup's Apply fits 16 tracked buff icons and a Tank's 6 tracked bars in Edit Mode at Interface size 1.

### Added

- Added: Frames returns as a HUD style. Shamans get a Spirit Poles row with Ghost Wolf, and the player's resource row shows class crowns or Lightning Shield charges as storm orbs.

### Changed

- The RestedXP and Zygor guide card moves to the top left corner, above the party frames, where a whole step fits on every screen. Window Skins > RestedXP or Zygor > Guide card, on by default.
- The quest log keeps its column on the story rail under the minimap and its own height; it no longer stretches to the guide's height.
- Zygor Guides Viewer, contributed by Baine, sizes its guide to its steps but never past its card. Window Skins > Zygor > Fit guide to its steps, on by default.
- A RestedXP step that grows in combat grows the card up, so the whole step stays on the screen.
- In a raid the guide card shares the corner with the raid frames; close the guide or drag either one away.
- Story rail is now Guide card under Window Skins > RestedXP and Zygor, and RestedXP's Align story cards is now Trim the guide card. Your choices stay.
- The threat meter no longer follows the guide card: Follow the guide card leaves Meters > Threat meter, and the threat card keeps its own place.

### Fixed

- Raid and boss warnings sit in the upper part of the screen on MacBook and other 3:2 screens instead of under the boss frames.
- The warnings keep clear of the boss frames' debuffs, and after an Interface size change they move with the HUD.
- With the Cooldowns module off, Apply in `/kstyle setup` fits 16 tracked buff icons over your casts and a Tank's 6 tracked bars beside the threat card in Edit Mode at Interface size 1.
- With Zygor's guide open, KstyleUI no longer repaints its waypoint arrow every frame or checks its tabs a hundred times a second.
- Action bars and cooldown icons update only the spell that changed on a cooldown, and only the icons on a form change, so shapeshifting and fast fights cost far less.

### Upgrading

- If v0.2.12 moved you to Medallions, pick Frames again in `/kstyle setup` or in Options > General > HUD style.
- Profiles saved on Frames before v0.2.12 stay on Frames if they haven't already moved to Medallions.
- The guide card moves to the top left corner at your next login; a place you saved in Layout Mode stays.
- A threat card that followed the guide goes back to its own place, and Follow the guide card is gone.
- On a MacBook or other 3:2 screen, the raid warnings move up the next time you press Apply in `/kstyle setup`.

## v0.2.12.1 (2026-11-22)

A fix release.

Highlights:

- Medallions unit frames honour their bar textures, and focus and boss aura timers clear the stack count.
- Raid tiles and party rows honour Icon zoom, Time left, Name font and Portrait zoom, and keep names whole.
- Party rows get a boss debuff slot, and the leader, marker and indicators no longer cover heals or names.
- Nameplates honour the level font, and Readable bag headings draw their full title band.

### Changed

- Party rows show two of your three heal icons on the Default preset, so names of twelve letters fit. The Healer preset keeps its two.
- Raid tiles no longer show a role icon on their own, so names stay whole. Role icons now shows the role on party frames, and on raid tiles only as Role letters or at a chosen Role icon place.
- Unit Frames cast bars lose their texture setting: every cast bar draws the flat fill.

### Fixed

- Medallions unit frames honour their health and power bar textures.
- Focus and boss aura timers no longer sit under the stack count, long focus names have more room, and the boss shadow no longer darkens the next boss.
- The unit frame preview in the settings window shows the target's cast, so Spell target and Important cast outline have something to show.
- The experience bar honours its texture, segments, text and font size settings.
- Medallions raid tiles honour Icon zoom, Debuff and Heal icon tooltips, tooltips in combat, Icon text outline, Time left and Name font, and keep names whole.
- Medallions party rows honour Portrait zoom, keep names of twelve letters whole and show a boss debuff slot in the portrait's top corner.
- The leader, marker and indicators no longer draw over your heals, names, debuff pips or the health percent on raid tiles and party rows.
- Medallions nameplates honour the level font and keep their slim bar when you change a setting.
- Readable bag headings draw their full title band.
- The chat preview in the settings window matches the panel.
- Data bar values repaint at once when you move the bar to the Right rail.
- New spell ranks fill the slab's first free slot.
- The level-up caption over the Medallions crest draws on whole pixels, and the crest minimap sits exactly on its layout spot.

## v0.2.12 (2026-11-22)

The Medallions release: KstyleUI is now Medallions only, class crowns rise over the crest, shamans get Spirit Poles and Storm Orbs, and cast bars move onto the player and target frames.

Highlights:

- KstyleUI is now Medallions only: Frames and Orbs are gone, your HUD moves over on update and setup is shorter.
- Class crowns rise over the crest for rogues, druids, warriors, priests, mages and hunters, on by default.
- Shamans get Spirit Poles, a totem bar on the crest with Ghost Wolf and Call, and Storm Orbs for Lightning Shield.
- Cast bars sit on their frames: yours under the player frame and your target's under the target frame.
- Your own settings now win over the Medallions look, and your buffs no longer show twice on the player frame.
- Key presses, pet cooldowns, target changes and currency updates do less work, with no change in look.

### Added

- Class crowns on the crest: a rogue's daggers and a cat-form druid's claws slide out with each combo point, slash away when you spend them and shine at five.
- More crowns light as your stacks build: a warrior's war-banners (Sunder Armor), a priest's candles (Shadow Weaving), a mage's arcane shards (Arcane Blast), a bear's talons (Lacerate) and a hunter's arrows (Sniper Shot).
- At the maximum the crest's rune ring glows in your class colour. Switch the crowns under Unit Frames > Player > Class resource > Class-themed pips, on by default.
- Spirit Poles for shamans: a totem bar set into the crest, with four element sockets whose spires burn down with each totem's time left. Action Bars > Slab and cooldowns > Shaman totem bar, on by default.
- Right-click a socket to unfold its flyout and pick that element's totem; Shift right-click dismisses the totem. A chosen totem stays dimmed until you drop it, and a spire flickers as its totem runs out.
- Ghost Wolf and Call of the Elements medals sit on the crest; right-click Call for Totemic Recall. The rune ring lights in the shaman colour while all four totems are up.
- Key Bindings > KstyleUI lists the four totem sockets, Call of the Elements and Totemic Recall.
- Storm Orbs: each Lightning Shield charge circles the crest as an orb under a storm halo. Action Bars > Slab and cooldowns > Lightning Shield on the crest, on by default.
- A cast ignites the orbs, each strike throws a bolt from the spent orb, the last charge dims the halo and flickers its orb, and the halo crackles out when the shield ends.

### Changed

- KstyleUI is now Medallions only: the Frames and Orbs HUD styles are gone. A HUD on Frames or Orbs moves to Medallions at your next login, keeps your other settings and says so once in chat.
- The first-run setup is shorter: welcome, layout, modules and summary, with Your addons when it finds supported addons. The HUD style and ornaments steps are gone.
- General loses the HUD style, ornament and card material choices, Data Bars > Position offers Docked under the action bars or Right rail, and Action Bars > Split in two offers Always or Never.
- Cast bars sit on their frames: yours under the player frame and your target's under the target frame, clearing the space above the crest. Unit Frames > Cast bars on unit frames, on by default.

### Fixed

- Your choices now win over the Medallions look: party portraits off, raid names above the bar, the raid power bar, raid heal icons, and nameplate name, level and debuff sizes and outlines.
- Your buffs no longer show twice: the player frame's buff row is off by default because your buffs already show by the minimap. Turn it back on under Unit Frames > Player > Auras.
- Action bar key presses, pet cooldowns, target changes, tooltips and experience updates do less work, and the data dock no longer rebuilds itself on every currency change.
- Switching the minimap frame between Crest medallion and Crest ring re-fits the HUD to the ring's taller crest.
- On Right rail, the minimap clock steps aside only when the rail itself shows the time.
- The Tank layout fits MacBook and 3:2 screens at the normal Interface size instead of shrinking the HUD, action bar 3 stays out of the middle of the screen, and the second data bar starts clear of the target frame.

### Upgrading

- A HUD on Frames or Orbs moves to Medallions at your next login, with one line in chat; your other settings stay.
- Class-themed pips, Shaman totem bar, Lightning Shield on the crest and Cast bars on unit frames start on.
- The player frame's buff row turns off; turn it back on under Unit Frames > Player > Auras.
- If you used the Glass card material, Window Skins > Context menus turns off, so Blizzard's menus stay as they were.

## v0.2.11.1 (2026-11-22)

A small fix release.

Highlights:

- With Blizzard's Cooldown Manager switched off, KstyleUI no longer shows its own cooldown icons.

### Fixed

- With Blizzard's Cooldown Manager switched off under Options > Gameplay > Advanced Options, KstyleUI no longer draws its own essential and utility cooldown rows.
- Switching the Cooldown Manager off or on takes effect at once, without a reload or a reminder in chat. While it is off, Layout Mode offers no movers for those rows.

## v0.2.11 (2026-11-21)

The guides and crest release: Zygor Guides Viewer joins RestedXP on the story rail in the KstyleUI theme, the Medallions crest jewels flare, drain and light the whole ring at the maximum, and Summon Hawk's hawks perch on the crest.

Highlights:

- Thanks to Baine, Zygor Guides Viewer sits on the story rail like RestedXP, under Window Skins > Zygor.
- Zygor takes the KstyleUI theme: the forged window card and a themed header, controls, progress bar and waypoint arrow.
- Medallions crest jewels are richer cut gems that flare when you gain a point and drain when you spend one.
- At the maximum the whole crest ring glows in the resource's colour; Glow at max is on by default.
- Hawk perches show each Summon Hawk hawk and its time left on the Medallions crest, an idea from Baine.

### Added

- Zygor Guides Viewer support, contributed by Baine: its guide window sits on the story rail in KstyleUI's window card, forged by default. Switch it under Window Skins > Zygor, on by default.
- Zygor's header shows the guide's name, and its controls, progress bar and waypoint arrow take the KstyleUI theme.
- Zygor: Fit guide to its steps (on) lets the guide keep its steps' height; off fills the story slot. Drag the guide away and KstyleUI leaves it there and turns Story rail off.
- With RestedXP and Zygor both loaded, the guide shown last owns the story card and the other window goes back where it was. KstyleUI writes none of Zygor's settings.
- Medallions: Glow at max under Action Bars > Slab and cooldowns, on by default. At the maximum the whole crest ring glows in the resource's colour.
- Medallions: Hawk perches under Action Bars > Slab and cooldowns, on by default. Each Summon Hawk hawk perches on the crest with a green timer over its 18 seconds. Thanks to Baine for the idea.
- Hawk perches flash in on a summon and fade when the hawk leaves, and the crest ring glows while both hawks are out.

### Changed

- Medallions crest jewels are richer cut gems that flare when you gain a point and drain when you spend one.
- World map: Smooth zoom, Remember zoom and Wheel between maps are gone; they caused a blocked-action error in combat.

### Fixed

- `/kstyle perf nan` gets the line asking for a finite number of seconds instead of starting a profile that never finishes under LuaJIT.
- The player frame's resting Zz shows in full instead of two dots.
- Layout Mode and interface-size changes no longer raise a forbidden-object error from aura icons on locked nameplates.
- Closing or using the world map in combat no longer raises a blocked-action error from KstyleUI Skins.
- The Zygor skin no longer drops frame rate out of combat by re-placing the guide every frame, and its text no longer jitters.
- Cooldown rows no longer raise a secret-value error when their count or keybind text is restyled.

### Upgrading

- Glow at max and Hawk perches (Action Bars > Slab and cooldowns) and the Zygor skin (Window Skins > Zygor) start on.

## v0.2.10 (2026-11-21)

The frame-rate release: KstyleUI draws less every frame with no change in look, two new Medallions switches trade effects for frame rate, `/kstyle perf` measures what KstyleUI costs, and party and raid frames gain new options, each starting off.

Highlights:

- KstyleUI draws less every frame, up to a quarter less area, with no change in how it looks.
- Medallions switches for Low-health vignette and Ambient hub effects trade effects for frame rate, both on by default.
- Thanks to Baine, /kstyle perf records your frame rate and KstyleUI's Lua time for frame-rate reports.
- Party frames can follow the raid's settings, and indicators can be coloured squares or bars that drain.
- Party and raid frames gain a shield edge, a raid size of your own and tank frames that can leave you out.

### Added

- Medallions: Low-health vignette under General > Medallions, on by default. Off takes the red screen edge at low health out of the drawing; your portrait's danger ring stays.
- Medallions: Ambient hub effects under General > Medallions, on by default. Off stills the hub's turning runes, breathing glow, sheen and sparks; the hub art stays and combat, proc and cast flashes still play.
- `/kstyle perf [seconds]` records your frame rate and the Lua time KstyleUI spends, for 20 seconds or the length you give, then writes the costliest work first to the devlog. Thanks to Baine for this contribution.
- To report low frame rate, run `/kstyle perf 30` where it drops and play on, then `/reload` and send the Perf lines from `KstyleUI.lua` in your account's SavedVariables folder.
- Party and raid frames: Shield edge, a bright line where a shield starts on the health bar, shown only while there is a shield.
- Party and raid indicators: a Look of Square, one colour instead of the spell icon, or Bar, a line along the health bar's edge that drains as the aura ends, in your colour and thickness, with reverse fill.
- Party frames can use the raid frames' text, debuffs, heal icons, status icon size and power bar, each on its own. Under Medallions, party frames keep their own name position.
- Raid frames: Own size from a number of players you choose, with its own width, height and offsets.
- Tank frames: Leave yourself out, so they show only the raid's other tanks.
- Role icons can sit under the hover and target highlights.

### Changed

- KstyleUI no longer draws the see-through middles of its rings, outlines and frame borders: about a fifth less drawn area in Frames, a quarter in Medallions and a tenth in Orbs, with no visible change.

### Upgrading

- New options start off, so your interface looks the same until you change one.
- Low-health vignette and Ambient hub effects start on, as before; turn them off under General > Medallions.

## v0.2.9.2 (2026-11-21)

A small fix release.

Highlights:

- Tooltips on the top data bar open clear of the bar, so every button stays reachable.

### Fixed

- Tooltips on the data bar, its micro and bag menus and the experience bars open on the side with room, clear of the bar and the pointer, instead of covering the next button.

## v0.2.9.1 (2026-11-21)

A small fix release.

Highlights:

- Medallions party frames no longer error when their names sit on the bar.

### Fixed

- Under Medallions, choosing names on the bar for party frames no longer raises a Lua error, and the names show on the bar.

## v0.2.9 (2026-11-21)

The customisation release: resource jewels on the Medallions crest, then a big wave of new options across every module, each starting off or at today's value, plus faster loading and a few fixes.

Highlights:

- Combo points, holy power and soul shards glow as jewels on the Medallions crest, on by default.
- New options for unit, party and raid frames, nameplates, cooldowns and auras, each keeping today's look.
- A second data bar, a second damage window with reports, a forged Medallions dock and new bag views.
- Alerts, a cursor ring, a crosshair, raid tools and /way waypoints, all off until you turn them on.
- Share whole profiles with your layouts, and read each release's highlights under About > What's new.
- KstyleUI loads faster after a reload.

### Added

- Crest resource jewels: combo points for rogues and cat-form druids, holy power for paladins and soul shards for warlocks glow as jewels on the Medallions crest ring. On by default under Action Bars.
- Unit frames: see-through, gradient or health-coloured health bars, one-decimal health percents (two on boss frames, trailing zeros optional), mirrored and zoomed portraits, and heal and absorb opacity and textures.
- Unit frames: move the name, health, power and level text, set the health bar's height, put the power bar above the health bar or apart from the frame, and colour part of a text line with `[c:ff8800]...[/c]`.
- Unit frames: a text bar along the player, target or focus frame with left, centre and right texts, and three more Shown choices: when mounted, not while mounted, and in combat or with a target.
- Unit frames: shields from either end of the bar, an overshield glow, a thin absorb bar, lost maximum health marked on the bar, spell costs and the five-second rule on your power bar, and druid mana in bear and cat form.
- Unit frames: size, nudge or corner the leader, PvP, combat, elite and raid marker icons, a PvP flag timer, threat percent on target and focus, hover and target outlines, reaction colours and a target lost sound.
- Unit frame auras: pet auras, a separate buff block, large boss auras, copy another frame's aura look, movable timers and stacks, and filters for stealable, defensive, dispellable or timed auras.
- Player frame: a dispel overlay, outline and type icon while you carry a debuff you can dispel, your own dispel colours, and totem timers beside the frame.
- Cast bars: a pet cast bar, Hide when idle on every bar, icon size and place, the spell's target, important-cast outlines, names that shrink to fit, rank, latency, craft batches and out-of-range grey.
- Party and raid frames: By health colours, fill opacity, missing health fills, dead and offline colours, the power bar off per role, and shields, heal absorbs and lost maximum health in the game's patterns.
- Party and raid debuffs: filter by type, boss, role, crowd control, source, importance or what your class can apply; icon zoom, timer size, outlines and tooltips; a dispel type letter and your own dispel colours.
- Party and raid frames: role letters, a combat icon, and every icon, name, status text and heal icon placed or nudged where you like; name line height, alignment and divider, and whole, first, last or initial names.
- Party and raid frames: missing buff reminders for Fortitude, Mark of the Wild, Arcane Intellect, Divine Spirit, Thorns and Salvation, with an optional glow.
- Party targets: a small frame beside each party member for what they target; click it to target that too.
- Pet frames (up to 30), tank frames (up to 8) and friendly boss frames, each made only when you switch it on, in the raid frames' card and placed in Layout Mode. Friendly boss frames follow a boss that changes sides.
- Raid layout: choose which groups show, close up, merge or centre them, sort party and raid by class in your own order, size large and compact raid frames apart, number each group, and use party frames for small raids.
- A movable healer mana list and a movable label with your raid group's number.
- Nameplates: cast bar icon size and place, important-cast colours and glows, a glow when a cast is aimed at you, the cast's target, enemies that grow while casting, and a taller cast bar on your focus.
- Nameplates: your target can glow, brighten and grow; hover and focus highlights, absorb shields, an execute glow, and fading for enemies out of your interrupt's range.
- Nameplates: enemy buffs with a purge glow, crowd control from anyone, Sunder Armor stacks for warriors, and debuff timers and stacks you can move, with dispel-coloured rings, wide tiles and pandemic marks.
- Nameplates: combo points and energy on your target's plate for rogues and cat-form druids, quest progress such as 3/8 after a mob's name, and the distance to your target.
- Friendly nameplates: separate colours, formats and sizes for players, NPCs and pets, player titles, guild lines, NPC titles such as Innkeeper, pet owners, and click-through plates.
- Nameplates: threat that leaves boss, mini-boss and caster colours alone per role, plate spacing, a narrower enemy click area, a movable level and a full-height spell icon.
- Cooldowns: Spell rules can hide a spell, close gaps, remind you of a missing buff, show a spell only in a form or with a talent, shade recharges and count down to the next charge.
- Cooldowns: per-spell swipe, glow and countdown colours, colours and tenths below a threshold, a sound when a spell is ready, keybinds on icons, mirrored key presses and crafted quality pips.
- Cooldowns: swing timer sweeps and late-swing glows for on-next-swing attacks, two-row grids with their own sizes, and a focus interrupt tracker beside your focus's nameplate.
- Cooldown and buff bars: fill up or drain, ease, a spark, two-line and renamed bars, cooldowns as bars with charge sections, and a custom bar group in your own order.
- Auras: an extra buff row and an extra debuff row with their own filter, size and place, a glow per row, timers in any corner, and a card that names a missing class buff out of combat.
- Chat: buttons on their own glass or beside the card, in your order, size and spacing, or Shift-dragged anywhere; the jump-to-bottom button among them, tabs above the card, and an edit box font and size.
- Minimap: an addon compartment button in any corner, drawer, column or hidden for each addon button, middle-click for the game menus, and a tooltip size.
- A second data bar with its own readouts, moved and sized in Layout Mode, that works even with the main bar off.
- Data bar readouts: coordinates, a combat timer, time played, volume, both professions, class reagents and ammunition, any LibDataBroker plugin and a spacer.
- Data bar options: icons with or instead of values, colours, fill the rest, mail and resting on the clock, richer bag, spec, experience and gold readouts, online names in guild and friend tooltips, and Hearthstone travel.
- Quest experience on the experience bar marks what your finished quests will give.
- Bags: a list view, a category list down the side, Alt-click pinned items, recent items first, merged stacks, sell values, more ways to split sections, BoE and WuE labels and equipment set names.
- Bags: a maximum height, a corner anchor, an equipped bag row, footer currencies, opening with the merchant, mailbox and other windows, gold kept on hand at the bank, and Alt-right-click to disenchant or pick a lock.
- Bags: point at your money to see every character's gold and the total. On by default.
- Tooltips: a player's item level, difficulty and class colours, a short level line, faction colours, a player's buffs as icons, the side tooltips open on, modifier keys for ID and stack lines, and Detailed tooltips.
- Meters: a second damage window with its own meter and fight, such as healing beside your damage; it starts beside the damage meter and moves in Layout Mode.
- Meters: Shift-click to report a meter to chat after combat, a stripe on your own bar, see-through cards, title and text sizes, a Reset label, keys to reset or show meters, and the game's own number units.
- A standalone combat timer, and a spell history of your last casts as icons or bars.
- Alerts: entering and leaving combat, unspent talent points, a party or raid death, low durability, potions ready, and a countdown for your movement spells.
- Cursor: a cursor ring with styles, a dot and a trail, a cast circle and a global cooldown circle.
- A crosshair that changes colour when your target is out of range, the distance to your target, and character stats on screen, with frame rate and latency.
- Raid tools: ready check, role check, a pull timer and markers from one button, and keys to place, undo and clear world markers, in combat too.
- Slash commands: /way x y pins a waypoint, /kpaste follows a pasted list of /way pins, and /cd opens the cooldown manager. Each is a switch in Quality of Life.
- Quality of life: Space and number keys for quest and gossip windows, Train all at trainers, open boxes and bags, hide toasts, announce instance resets, log combat in instances, and take off costume transforms.
- Profiles: share a profile with its specialization assignments, Edit Mode layout or per-specialization cooldowns, share everything as one string, start from a role and HUD style preset, and switch with five hotkeys.
- Profile installers can export, import, list and switch KstyleUI profiles through `KstyleUI.API`.
- Options: About > What's new lists the highlights of the latest three versions in your language.
- Options: recolour classes and power types, one outline for KstyleUI's text, a world name font, attach by any of nine points, game menu buttons, folding sections, remembered search picks and a CPU readout.

### Changed

- The Medallions dock sits on forged plates, with a glyph for each readout, gilt dividers and a highlight on hover. Data bar artwork set to Plain gives it glass.
- KstyleUI loads faster after a reload, with nothing on screen changed.

### Fixed

- The data bar's Options preview no longer draws the clock over the right-hand readouts.
- The Party and Raid options preview no longer draws an indicator over a raid sample's name.
- On Medallions party frames, the indicator icons no longer cover names while your heal icons share the name line; they sit at the end of the health bar.

### Upgrading

- New options start off or at today's value, so your interface looks the same until you change one.
- Crest resource jewels and every character's gold in bags are on by default; turn them off under Action Bars and Bags.

## v0.2.8.5 (2026-11-21)

A small fix release.

Highlights:

- With Debuffs and buffs, the target's aura rows stay clear of the target cast bar and the target of target.
- On Medallions party frames, your heal icons no longer cover the health percent or the indicator icons.
- The unit frame preview in the settings window shows the target's debuff and buff rows.

### Fixed

- With the target's auras on Debuffs and buffs under Orbs, their timers sit in the icon corners, so the buff row stays above the target cast bar.
- With the target's auras on Debuffs and buffs under Medallions, the target shows one row of debuffs and one of buffs, clear of the target of target. A row count you saved still applies to each kind.
- On Medallions party frames, your heal icons no longer hide the health percent or touch the indicator icons. They line up to the left of the percent, as on Frames rows.
- With Debuffs and buffs, the unit frame preview in the settings window shows a row of debuffs and a row of buffs, as your target does.

## v0.2.8.4 (2026-11-21)

A small fix release.

Highlights:

- With the meter on Both, the threat card no longer covers the stance bar or the Medallions second bar and XP bar.
- Target debuff timers no longer draw over the target's buffs.
- The minimap and unit frame previews in the settings window keep their proper sizes.

### Fixed

- With the meter on Both, the threat card beside the damage card is 180 units wide, clear of the Frames stance bar and the Medallions second bar and XP bar. Long names can end in "...".
- With the target's auras on Debuffs and buffs, the debuff timers under their icons no longer draw over the buff row below.
- The minimap preview in the settings window looks the same after you resize the window or change the Interface size or display as it does when first opened.
- The unit frame preview always draws its cast bar text at the preview's size, so the cast bar keeps the same share of the frame as on your screen.

## v0.2.8.3 (2026-11-21)

A small fix release.

Highlights:

- Character sheet quality borders and selected tabs are thin rings again.
- The stance bar backing fits the stances and forms you have.
- Medallions minimap coordinates sit centred on their plate.

### Fixed

- Character sheet quality borders and selected tabs are thin coloured rings again instead of thick solid blocks.
- The stance bar's backing strip and Medallions plate fit the stances and forms you have instead of a full row, and resize when you learn one (after combat if you're fighting).
- The coordinates under the round Medallions minimap sit centred on their plate with even padding when the clock is hidden or moved, instead of crammed against the plate's left edge.

## v0.2.8.2 (2026-11-20)

The options release: the player bug fixes first, then a large batch of new settings across every module, each starting off or at today's value, and world map routes that follow real roads.

Highlights:

- RestedXP's guide card shows every line of the current step again, so you can tick it and skip it.
- Ten small fixes, from typing 50 into a percent setting to accented bag and map search and the setup's Modules page.
- Welcome text, the French and German Options footer, the 1080p data bar and colour-vision health bars read right.
- New options for frames, nameplates, cooldowns, auras, chat, minimap, tooltips and Layout Mode, keeping today's look.
- World map routes follow roads, passes, flights and boats, with travel steps and time.
- KstyleUI loads faster after a reload.

### Fixed

- RestedXP steps can be skipped again: the guide card shows every line of the current step with tick boxes you can click, and folds only later steps under "N more".
- In combat a longer RestedXP step never covers the quest card or RestedXP's item and target boxes.
- The first-run welcome page no longer cuts its closing sentence in half at smaller interface sizes, in every language.
- In French and German, the settings window's Layout Mode and Reset buttons no longer cover the last line of help text.
- The top data bar's readouts are readable at 1920x1080, and the bar stays its slim 14 units.
- The red-green and blue-yellow colour-vision modes recolour health bars on nameplates and unit frames, for hostile, neutral and friendly units.
- In French, the settings preview's sample creature name is no longer cut off at 1920x1080.
- Typing 50 or 50% into a percent setting saves 50%.
- The data bar shows "--" for World latency when the game has no World reading, instead of the Home number.
- Bag and map search find names with accented capitals, such as "épée" for "Épée".
- Double-clicking a mover opens that element's own settings; Target of Target no longer opens Player's.
- Pressing Enter in the Layout Mode finder selects the one element that matches.
- Settings search shows "Search results" and no longer offers to reset the page you searched from.
- The Medallions leave-vehicle button no longer covers the clock; it sits beyond the right action bar.
- The setup's Modules page fits its rows, and shows a scroll bar when they still need scrolling.
- The chat and Data Bars previews no longer spill or overlap in German and French, and chat font and tab-size help is translated.
- Layout Mode mover tooltips name the real overlap shortcut, and resetting the settings window's size and opacity keeps its position.
- Restyled cooldowns respect Edit Mode timers and the game's charge swipes, and a swipe you turned off stays off.

### Added

- World map routes follow roads, passes, flights and boats, with travel steps and time. Follow roads is on by default under Window Skins > World map; off draws the straight line again.
- The route card offers a flight when one saves at least a minute, and says why a journey, such as one between continents, falls back to a straight line.
- Unit frames: two extra text slots with your own text, font, colour and placement, heal absorbs on the health bar, absorb shield choices, aura filters and sorting, and level colour by difficulty.
- Party and raid frames: extra health, power, level and absorb text, debuff time left, optional stack counts, names cut to a set number of letters, and separate AFK, resurrection and summon marks.
- Cast bars: spark and uninterruptible colours, a latency zone on your cast bar, smooth progress, a separate channel colour, the icon on the right, and the total time, such as 0.4 / 2.0.
- Nameplates: colours for bosses, mini-bosses, neutral, minor and normal mobs and casting enemies, threat percent and name colour, level colours, extra text, and AFK, DND, PvP and raid-marker tags.
- Nameplates: cast bar icon side, gap, layer and target, an execute-range mark on your target, an F on your focus, and switches for the game's own enemy, friendly, pet and NPC plates.
- Cooldowns: per-spell rules to hide or fade a spell while it cools, is ready or is unusable, and per-spell sweep, colour, glow, count and out-of-range tint.
- Cooldowns: place and nudge the countdown and count, fill columns first, icon zoom and swipes per group, glows that wait for combat, and a switch for the cooldown edge.
- Tracked buffs can grey or keep their colour while inactive, per buff or for the whole row, hide one buff's stack count, and set the buff-bar fill opacity.
- Auras: show only one of Blizzard's aura categories or auras with a duration, list spell IDs to show or hide, add debuff type symbols, and mark an aura you can refresh without losing time.
- Aura timers and stacks: place, colour and format them (such as 4:05, or no "s"), crop icons, choose swipes and tooltips, hide stack numbers, and keep hidden rows faintly visible.
- Combat text can scroll downward, choose its shadow, show coloured enter and leave combat messages, show your power gains as "+25", and set how far it travels above you.
- Damage meter: pin your row, spell breakdowns and tooltips on hover, short or full numbers, the refresh rate, how many spells show on hover, and icon zoom.
- Chat can fade when it has been quiet, with your own delay, depth and wake-up lines; hovering, typing, player chat and whispers always wake it.
- Chat tabs, buttons and edit box gain size, spacing and placement options; lock the chat size, colour group names by class, show link tooltips on hover, and put the input above messages.
- Minimap: zone, clock and coordinates inside the map with offsets, coordinates only on hover, zone or subzone, instance difficulty, frame rate and latency, and map rotation.
- Minimap buttons move in or out, drop their backgrounds and Shift-drag anywhere; the mail envelope takes any corner, the addon drawer can be a named list, and the clock tooltip lists saved instances.
- Data bar location and item-level readouts, a short gold format such as 12.3Kg, bag slot-count format and icon zoom, and bags that open with the character window.
- Tooltips: grey junk icons, maximum stack sizes, no player titles, away and busy tags, the mount a player rides, and hiding in combat or boss fights with a key to peek.
- Quality of life: skip single-choice NPC dialogue and cinematics (with a delay), type the delete word for you, accept resurrections out of combat, and coin icons in the loot feed.
- Layout Mode: attach at a corner, match an attached frame's height, adjust its width and height, grid brightness, Shift-arrow distance, and how scrolling picks overlapping movers.
- Layout Mode: double-click any mover to open its settings (on by default), middle-click to hide a mover until Restore movers, and a toolbar that fades or hides while you hold Shift.
- Profiles: share several modules and appearance settings together, name an imported profile before applying it, and review interface size changes on import.
- Appearance: the game's default, chat or system font, your font for the game's own text and names, your number font for damage numbers, and Game text size for Blizzard's text.
- Options: window size, scale and opacity in General, search only the current page, hide the section list, and the release notes under About > What's new.

### Changed

- KstyleUI loads faster after a reload, with nothing on screen changed.

### Upgrading

- New options start off or at today's value, so your interface looks the same until you change one.
- World map routes follow roads at once; turn off Follow roads under Window Skins > World map for straight lines.

## v0.2.8.1 (2026-11-20)

A small fix release.

Highlights:

- Options pages switch without a scroll-list Lua error.
- The consumables bar stays where you move it in Layout Mode.

### Fixed

- No more Lua error in the scroll list (ScrollList.lua:91) when switching Options pages.
- The consumables bar stays where you move it in Layout Mode; moving it turns off Attach to the player frame. Turn that back on to dock it beside the player frame again.

## v0.2.8 (2026-11-20)

The map and bars release: a world map that zooms smoothly, searches and draws you a route, a setup step for your own addons, and action bars you can tune bar by bar, plus the fixes from a long gameplay video.

Highlights:

- Travel with smooth map zoom, search and a straight-line route card showing distance and time.
- Choose which addons KstyleUI skins in setup's "Your addons" step, with every skin on by default.
- Tune each action bar with its own tab for text, cooldowns, quality borders and show/hide rules.
- The consumables bar starts at half size with a backdrop.
- Gameplay fixes keep RestedXP steps readable, Layout Mode labels apart, and power and frame-rate readouts in place.

### Added

- The world map gains smooth wheel zoom, saved zoom and pan, and wheel navigation between maps. Each has its own switch under Window Skins > World map; in combat, the wheel only zooms.
- Search flight masters, dungeon and raid entrances and quests, then set a waypoint and track it. Native map pins draw the route on the first click and clear it on the second.
- A straight-line route card beside the quest list shows distance and estimated travel time on foot or mounted. Road-following routes are coming.
- Dungeon and zone level ranges join map search and entrances. Each map feature has its own switch, on by default, under Window Skins > World map.
- Setup gains a "Your addons" step to choose skins and which parts step aside for another addon. Reopening `/kstyle setup` keeps your choices; Keep my UI leaves them alone.
- Action Bars options gain pinned tabs for Bar 1-6, Pet, Stance and Consumables. Double-click a bar mover in Layout Mode to open its settings.
- Per-bar text placement: put each bar's keybind, count, macro and cooldown text in a corner, on an edge or in the centre, with horizontal and vertical offsets. Current style with no offsets keeps the positions you know.
- Per-bar cooldown look: fade an icon's colour while it is on a real cooldown (the global cooldown stays coloured) and set how dark the cooldown swipe is.
- Item quality borders on action buttons, on by default per bar: an uncommon or better item, including an item macro, wears its quality colour. Poor and common items keep their normal rim.
- Build per-bar show/hide rules for combat, target, mounted, group and modifier conditions. Hand-written macro conditions still work; clear them to return to the builder.
- Toggle keys for every bar under Key Bindings > KstyleUI: bind Toggle Action Bar 1-6, pet, stance or consumables to show or hide that bar, even in combat. The hidden state is saved per character.
- Per-bar Click through and Reverse button order are off by default. Keys keep working through a click-through bar, and reversing keeps slots, pages and bindings; the connected Medallions slab keeps its order.
- A button-count limit for the consumables bar, which keeps your highest-priority kinds when you lower it.
- Paragon reputation progress, with an optional compact reward marker in the reputation caption.
- An optional KstyleUI card and header for Questie's own tracker, on by default; switch it off and Questie's own art returns at once.

### Changed

- Every skin is on by default. Skins you switched off yourself stay off, a master switch you turned off stays off, and Questie no longer turns the whole Skins module off.
- The consumables bar starts at half size with a backdrop. Below 30 units, counts are outlined, cooldown time replaces counts, and keybind text starts off. Your saved choices are kept.

### Fixed

- The frame-rate readout no longer shows a bogus figure such as 240000 FPS just after a loading screen; it shows -- until the first real sample, tooltip included.
- The Medallions player power value sits inside its card and its Layout Mode box, with no second percentage floating underneath.
- RestedXP and quest cards fit shorter content, guide headers share one height, and the folded list loses its stray tick. Fit guide to its steps is on by default; off restores the shared quest-card height.
- Layout Mode labels, readouts and toolbar clear nearby UI. Thin movers keep their grab area and details, solid labels return with See-through movers off, and dragging skips repeated label work.
- The durability doll moves to a clear spot beside the minimap at login when you never moved it yourself; a position and size you saved in Edit Mode are kept.
- Options Tasks has destination help and a live preview, and General > Text previews its typography; the help text follows the same colour and spacing as every other row.
- Percentages round the way Blizzard rounds them, including at exact halves.
- KstyleUI steps aside for the Leatrix Plus features you have on and for BetterFriendlist's friends window.
- Finding Questie for the first time keeps its current tracker setting, and the Speedrun Guide and context-menu headers match the rest of KstyleUI.
- Party and raid health bars end without the spark other bars already skipped, and restyled tracked bars use your shared bar height (12 units by default), icon tile and black edge included.
- The Cooldown Manager tip shows once instead of at every login, action-bar overlap notices show once per account for each addon found, and stripped textures stay hidden after a recolour.

### Upgrading

- Your supported addons start skinned by default; skins you switched off stay off.
- Choose skins in Options or setup's "Your addons" step.
- Consumables start at half size with a backdrop unless saved; adjust under Options > Action Bars > Consumables.

The optional icon pack still applies: download `KstyleUI-Icons-<version>.zip` from this project's GitHub releases page, quit the game, copy its Interface folder into your Forever folder so the files land in Interface/Icons, then start the game again.

## v0.2.7 (2026-11-20)

The big customisation release: a data bar you fill with the readouts you want, a consumables bar that fills itself, a reworked Medallions centre with crest clicks and a crest minimap, and layout tools that keep everything apart at every screen size.

Highlights:

- Choose your readouts and micro menu in a top data bar for Frames and Orbs, or a dock below the Medallions slab.
- An automatic consumables bar keeps your best food, potions and other consumables to hand.
- Travel with a click of the Medallions crest, with new cooldown and aura positions and minimap and bar layouts.
- Customise health and power text, share aura and bar settings, and give each spec its own layout.
- Attach elements and match their widths, lock drags to one direction in Layout Mode, and cycle stacked frames.
- Hover a quest to see your party's progress on it.

### Added

- Frames and Orbs gain a top data bar with selectable readouts, a micro menu and a central clock. Options > Data Bars controls placement, height, opacity, art and order; Right rail restores the old readout.
- New readouts: specialization (switch dual specialization out of combat, or open talents), Hearthstone location and cooldown, guild and friends online, bag space and up to three tracked currencies.
- Medallions gains a data dock below its action slab, with five readouts and a micro menu. Enable more in Options; overflow drops whole readouts and lists them in the final readout's tooltip.
- An automatic consumables bar keeps twelve kinds of food, potions and other consumables to hand, with grid controls, fading, a preview and `/kb` bindings, clear of auras and side bars.
- In Medallions, left-click the central crest to use your Hearthstone and right-click it for your travel spells, items and mounts. Turn Crest travel clicks on or off in Action Bars options.
- In Medallions, frame the minimap like the central crest: pick Crest medallion, Crest ring or Classic under Minimap frame in Options.
- Two quick layouts for extra action bars in Medallions: two rows on the slab, or small bars beside it. Pick one under Extra bars layout in Options; everything stays movable.
- Every action bar can be sized and arranged in Options, in every HUD style, including the Medallions slab bars.
- Text options for unit frames and nameplates: font, size, outline, colour, and formats such as `[hp:abr]` and `[hp:pct]`, with tags for name, health, power, level, absorbs, target and group.
- Shared aura controls for player auras, nameplates and group frames, with spell-ID allow and block lists on nameplates.
- Give each spec its own layout of frames and bars while keeping one profile's look, show any element only in a party, in a raid or when solo, and let the meter follow your role: threat when you tank, damage otherwise.
- As a damage dealer you can show the threat meter next to the damage meter (Options > Meters).
- Layout Mode gains Shift axis lock, stacked-frame cycling and coordinates. Attach one element above, below or beside another and match its width; it follows when the other moves.
- Hover a quest in the quest card to see each party member's progress on it. Party members with KstyleUI or Questie show their objectives.

### Changed

- Medallions places cooldowns above the crest and auras above the unit frames. Choose Crest fan under Unit Frames > Aura layout to restore the old fan.
- Damage and threat meters use nameplate-style rows on 250-unit cards, so two fit side by side. Turn off Nameplate-style meter rows for the previous rows.
- Nameplates share the interface's bars and fonts, with capital cast names and 12-unit health bars by default. Medallions Minimal stays slim; Dungeon and saved Custom plates keep their settings.
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
- Questie and KstyleUI trackers no longer overlap. RestedXP's Active Items and Active Targets boxes dock below the guide again, and its guide window no longer flickers.
- KstyleUI restyles other addons' text inside skinned windows without making it overflow their frames, and item tooltips no longer blink when you hover items in the auction house and other lists.
- Moving a spell on your action bars no longer casts it, the class trainer's skill rows no longer spill over each other or the Train button, and opening the travel menu no longer slows later refreshes.
- Saved Frames health-text settings no longer blank the health orb, and custom text tags paint once per update.
- Rested experience shows correctly past one level, exact percentages no longer read one low, the swing timer stops an unequipped hand, and boss threat uses the same figures as other enemies.
- KstyleUI yields only the overlapping part to Bartender4, Dominos or Details; each part can be enabled again. Turning nameplates off restores your own game settings across reloads.
- Running setup again with Right rail chosen keeps the data readout in its old spot.
- The data bar's clock no longer sits on the bar's centre gem.
- The Medallions data dock separates its readouts from the XP caption.
- In Medallions, the quest card and guide card line up.
- Right rail shows the classic readout and keeps it inside its frame.

### Upgrading

- Frames and Orbs readouts move to the top bar; a one-time chat notice flags a readout you had moved.
- Restore the old readout with Right rail in Options > Data Bars.
- Medallions readouts move below the slab; saved readout positions are unused while the dock is on.
- A moved Medallions crest fan stays; otherwise aura rows replace it (switch in Unit Frames > Aura layout).
- RestedXP item and target boxes redock under the guide once; drag either box to undock it.
- Role-following meters stay off for existing profiles until you turn them on.

An optional icon pack repaints ability and item icons everywhere, including buffs. The addon repaints the frames; **KstyleUI Icons** repaints the icons inside them, in one style everywhere the game draws them. The icons were made with AI image tools. The pack is not an addon and is not part of this download: download `KstyleUI-Icons-<version>.zip` from this project's GitHub releases page, quit the game, copy its Interface folder into your Forever folder so the files land in Interface/Icons, then start the game again.

## v0.2.6 (2026-11-18)

Clearer combat and finished HUD styles: tooltips that follow your mouse out of combat, readable casts and their outcomes, one danger signal at the screen edge, colour-vision and readability choices, Orbs and Frames finished with their own switches, Options that opens on common tasks, a branded welcome page, and a long list of alignment and readability fixes.

Highlights:

- Tooltips now follow your mouse out of combat and return to their usual place in combat, with other anchors in Options.
- Track your target debuffs in a timed, metal-rimmed fan above the Medallions crest.
- Read more easily with four switches in Options > General > Appearance, all on by default.
- Read enemy casts on target and focus nameplates, spot uninterruptible casts and try the Dungeon preset.
- Enjoy clearer Orbs glass and spell names, a ledge under bar 2, and aligned Frames casts and tray, all on by default.

### Added

- Tooltips can follow the mouse out of combat and sit at their usual place in combat. This is the new default; pick another anchor in Options if you prefer.
- Under Medallions, your debuffs on your target fan out in a metal-rimmed row above the crest, with their timers, cooldown sweeps and overflow, a switch in Options and a mover in Layout Mode.
- Four readability switches in Options > General > Appearance, on by default, with the original look available when you switch one off.
- Enemy cast names on target and focus nameplates, a shield mark for casts you cannot interrupt, and a Dungeon nameplate preset.
- Orbs gains Sharp orb glass, Ledge under bar 2 and Room for long spell names. Frames gains Spell name inside the bar and Tray on the centre column. All are on by default.
- When you learn a new spell, KstyleUI offers to add it to your action bars, beside the offer to update a spell to its new rank.
- A setting to wait until you stop resizing the game window before the HUD resizes with it, on by default.
- Colour vision choices, role and threat shapes, interrupt shields, and debuff letters classified by the game, so important signals do not rely on colour alone.
- Readable and Healer presets, target range cues, tank threat alarms, and resurrection, summon and AFK indicators.
- Bind keys buttons in Options, typed slider values, diamonds on settings you have changed, quick resets, and searchable elements in Layout Mode.
- Scoped profile sharing with an import review, plus recovery backups you can restore in one click.
- Separate options to restore the previous low-health screen glow and the smoky portrait pulses.
- Options opens on common tasks, with search in player words and ornament samples you can see before you choose.

### Changed

- Existing players also move to tooltips at the cursor out of combat. If you preferred Tooltip anchor, choose it again in Options: older versions did not save that choice at logout.
- The Personal Resource Display in the middle of the screen is off by default for new setups; turn it on under Nameplates.
- The first-run setup opens on a branded welcome page with current HUD previews, feature highlights and the addon version, with an option to restore the original page.
- Frames and Medallions show power numbers by default: mana as percent, other resources as current amounts. Orbs keeps its centred percent; Medallions target health and combat text are clearer.
- Nameplate debuffs are larger in both presets, with outlined time left and a red warning as they run out.
- Orbs gains crisp glass, a clearer health-loss band and a metal ledge for bar 2. Frames puts spell names and timers inside cast bars and lines up the tray with the unit bars.
- Quest and guide cards align, meters fit their contents, and the data strip shares the meter heading. Window buttons have clearer states; native windows share title, text and control spacing.
- Cast text, raid text, low-health figures and captions are clearer, with optional outlines and backing. Chat tabs and meter text are easier to read, and mana is darker than health.
- Typography is consistent across portrait badges, experience, meters, headings, tabs and tooltips. Tooltip and bag quality colours have separate controls; Options labels and help have their own sizes.
- Empty Medallions sockets fade until needed. Cooldown edges, countdowns and crest size each have a switch; icon frames match, and party and raid frames have separate text and indicator lanes.
- The Cooldown Manager's icons sit with the action bars instead of floating in the middle of the screen; switch them back in Options. The swing timer matches the rest of the HUD and sits with the cast bars.
- KstyleUI skips repeated background HUD, border and layout work that could not change anything on screen. Nothing looks or times differently.
- Setup names overlapping addons and offers timer, announcement and WeakAuras lanes. Accessibility controls start on. Closing setup applies defaults; Do nothing, ask again later leaves your UI alone.
- General offers the same Full, Calm and Off motion choices for Frames, Orbs and Medallions.
- Proc glows fade in gently inside a smaller halo. Hover and held-button rims settle smoothly; hub models stay behind the crest and play at most once every 2.5 seconds, while 2D celebrations still play.
- Settings search results appear at once, page transitions are shorter and preview changes are smooth. Combat numbers spread across five lanes, combine nearby ordinary hits and fade when making room.
- Failed and interrupted casts stay readable, and finished channels get a soft flash. Target ticks and threat edges are clearer; nameplates dim smoothly, and Medallions targets fade or turn grey on death.
- Low-health danger stays at the screen edges, with a smooth ring around your portrait and a still red rim on low-health enemies.
- Setup shows each role in the HUD style you chose, with clearer wrapping notes and slimmer switches.

### Fixed

- Party and raid frames appear as soon as you join a group.
- Grouped bags accept held or split items in empty slots. Item levels and counts use separate corners, and bag and minimap headings clear their edges.
- The chat window's tabs, frame and buttons line up at every screen size, including 4K.
- Minimap tooltips open beside the minimap instead of covering it.
- Reopened windows keep button positions; Talents starts at its final size, vendor prices keep their lane, and trainer captions clear titles. Quest cards use their full height, and docking keeps meter rates.
- Long names in raid frames stay distinct and clear of debuff pips, and lost-health bands reset correctly after a restricted colour change.
- Borders are complete on their first visible frame, and changing the interface size during combat keeps one-pixel lines correct.
- An interrupt whose cooldown is unknown no longer claims to be ready, and changing target refreshes only the two nameplates that changed.
- Long target spell names in the Orbs style are no longer cut short at 3456x2234 and 5120x1440.
- Long Medallions names keep their face and capitals; tooltips show full names. Small text keeps its minimum size, and section rules stay below headings while text cannot be measured.
- Long cooldown countdowns no longer cross stack counts, and key labels stay inside their action buttons in Frames, Orbs and Medallions.
- The dispel colour in the Options raid preview is a light wash again instead of a solid tile.
- The damage meter goes back to its normal heading once combat data can be read again.
- Six- and twelve-button third action bars fit Frames, Orbs and Medallions, with matching slab and socket treatment under Medallions.
- Calm motion keeps brief fades and flashes while windows, tabs, switches, lists, the loot feed, group cards and bag icons stop moving.
- Changing settings keeps a lit proc or crest flash in progress and restores glow textures. Procs cannot interrupt level-up celebrations, and returning to the world does not replay an already-lit proc.
- Real aura timers show a positive last second and plate debuffs end without a flash, and settings windows still open and close at once in combat and with reduced motion.
- Target cast labels stay clear after target and HUD style changes, and a new nameplate no longer inherits the previous enemy's fading.
- RestedXP guide borders and chat tab underlines stay crisp at fractional interface scales.
- Healthy hostile targets no longer show a danger rim.
- Settings labels stay readable when you shrink the window, and small previews start at the top.

An optional icon pack repaints ability and item icons everywhere, including buffs. The icons were made with AI image tools. The pack is not an addon and is not part of this download: it is available from this project's GitHub page. Quit the game, copy its Interface folder into your Forever folder so the files land in Interface/Icons, then start the game again.

## v0.2.5 (2026-11-18)

Your feedback release: keybinding, a working stealth button, the Options font error, a RestedXP arrow you can see in the dark, and a lighter addon that looks exactly the same.

Highlights:

- Bind action, stance, pet and possess buttons with `/kb`: hover, press a key and save for your account or character.
- Login, reload, display and HUD-style changes do less work while keeping the same look.
- Party, raid and boss frames and action-bar cooldowns skip unnecessary updates in combat.
- Clicking the stance button cancels stealth again, and its key binding in Blizzard's Key Bindings window works.
- Options opens without the group-preview font error, and the preview fits even the smallest window.

### Added

- Bind action, stance, pet and possess buttons with `/kb` or `/kstyle kb`: hover, press a key, then Save for account or character. Escape clears, Discard undoes, and combat locks edits.

### Changed

- Login, reload, display and HUD-style changes do less work: HUD sizing takes about a quarter of the time with almost no temporary memory, and about 40% fewer hidden pieces are built early. The look is kept.
- In combat, party and raid frames, boss frames and action-bar cooldowns skip updates that could not change anything on screen.

### Fixed

- Clicking the stance button cancels stealth again, and its key binding in Blizzard's Key Bindings window works.
- Opening Options no longer raises "Invalid font height (0)" from the group-frames preview, and the preview fits the window at its smallest size.
- The RestedXP guide arrow is ivory with a dark edge, so it is easy to see in dark zones such as Tirisfal Glades.

## v0.2.4 (2026-11-17)

Install and update KstyleUI through CurseForge, Wago or your addon manager.

Highlights:

- Install and update KstyleUI through CurseForge, Wago Addons, WowUp and other addon managers.

### Added

- KstyleUI is now on CurseForge and Wago Addons, so the CurseForge app, WowUp and other addon managers can install and update it.

## v0.2.3 (2026-11-17)

The Medallions polish pass: dark gunmetal chrome, rounded bevelled cards, and a tighter unit cluster on one row of action buttons.

Highlights:

- Enjoy dark gunmetal Medallions cards, windows and slabs with rounded bevels, machined rings and round level badges.
- Matching dark cards, class-colour headers and a round minimap bring the Medallions look to both rails.
- Recessed action sockets, class-colour proc borders and a bright race-and-class crest complete the Medallions slab.
- Read Barlow Semi Condensed numbers and slimmer nameplates, with faster gold combat text.
- Keep health, casts and target debuffs close in a tighter unit-frame cluster above the slab.

### Changed

- Medallions has a new dark gunmetal chrome kit. Cards, windows and slabs have rounded, bevelled edges instead of thin steel hairlines, with machined medallion rings and round level badges.
- The rails follow it. Cards are dark and bevelled with a header band in your class colour, the minimap sits in a round ring with an N badge, and chat, the damage meter, the quest card and tooltips wear the same chrome.
- The action slab gains recessed sockets, class-colour proc borders and a bright race-and-class crest clipped to its ring. Empty sockets hide keybinds, wings retire, and pet and stance bars get matching slabs.
- Numbers use Barlow Semi Condensed. Nameplates are slimmer, with the level in its difficulty colour and tick marks on your target. Scrolling combat text is gold and rises and fades faster.
- Unit frames form a tight cluster above the slab. Health values are outlined at bar ends, casts sit over the crest, and target debuffs use small tiles with dispel-colour underlines.
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
- Medallions target slabs show full creature types, shrink long capital names before shortening them, and keep raid markers clear of debuff timers.
- Beside the RestedXP guide, the quest card keeps your objective and its progress on show instead of only the quest name, with the title, quest count and hint clear of the card's edges.

## v0.2.2 (2026-11-16)

Clearer Medallions bars, hidden effects that stay hidden, and one combat-text display.

Highlights:

- The Medallions crest stays clear of stray shock rings and flashes between effects.
- Hidden Blizzard and RestedXP backdrops stay hidden when their colours refresh.
- Read Medallions health and power on flat bars, with health text that adapts to bright and dark fills.
- KstyleUI scrolling combat text now hides Blizzard's separate numbers by default, with a Keep option.
- Blizzard's world numbers use your combat-text font after logging out to the character screen and back in.

### Fixed

- The Medallions hub no longer leaves its shock ring and square flash visible between effects. Recoloring now preserves their opacity instead of bringing them back over the painted crest and runes.
- Hidden Blizzard and RestedXP backdrop textures stay hidden when their owning UI refreshes the vertex color.
- Medallions health and resource bars use flat fills without the white sheen. Health numbers use dark ink on bright fills and return to light ink when health falls onto the dark track.
- CombatText hides Blizzard's separate damage and healing numbers by default while KstyleUI's scrolling text is enabled. An explicit Keep choice remains available, and disabling the module restores the original settings.
- Blizzard's world numbers inherit the combat-text font role before login. Log out to the character screen and back in to apply the font; `/reload` is not enough.

### Added

- Bounded `/kstyle test` diagnostics save automatically when tracked quests have no visible rows. The intermittent blank card remains under investigation.

## v0.2.1 (2026-11-16)

The Medallions action slab as it was designed: one row and one connected piece.

Highlights:

- Medallions bars 1 and 2 fit one row of twelve buttons per side on every screen, shrinking on 16:9 and narrower.
- The Medallions slab, crest and combat wings join into one piece, with experience along the lower edge.
- Pet, stance and unit frames fit beside the Medallions slab on 16:9 and narrower screens, clear of the bag bar.

### Changed

- Medallions bar 1 and 2 use one row of twelve buttons per side on every screen. On 16:9 and narrower screens, buttons and their labels shrink by a fifth to fit beside chat.
- The Medallions slab, crest and wings form one piece. Wings follow the slab's top edge and extend in combat; experience runs along its lower edge below the crest.
- Under Medallions on 16:9 and narrower screens, the pet and stance bars stand in two rows of five to the right of the slab, and the player and target frames sit a little higher so your target's target clears the bag bar.

## v0.2.0 (2026-11-16)

A third HUD style, Medallions, with a painted portrait of your character and a crest for your race and class.

Highlights:

- Choose **Medallions**, a third HUD style beside Frames and Orbs, in Options > General > HUD style or setup.

### Added

- **Medallions**, a third HUD style next to Frames and Orbs. Pick it in Options > General > HUD style or on the HUD style step of the first-run setup.
  - Player and target slabs gain painted race, class and sex portraits for players; creatures, pets and bosses use game portraits. Focus, pet and boss frames get medallions, and secondary targets get small slabs.
  - Your first two action bars sit on one steel slab: two rows of six on each side of the centre on screens narrower than 21:9, and one row of twelve on each side on 21:9 and 32:9.
  - The slab's centre gains one of 52 race-and-class crests in a class-colour rune ring, with idle motion, combat wings, proc pulses and level-up bursts. It stays below buttons and labels.
  - Cooldowns and casts flash on results, low health lights the screen edge, full non-mana resources light the crest ring, and level-ups burst behind portraits. Side frames dim three seconds after combat.
  - Medallions motion offers Full, Calm or Off under Options > General > Medallions. Appearance motion takes priority; low-health edges, resource rings and post-combat dimming remain even with motion off.
  - Steel cards, class-colour headers, a round minimap, painted party badges and class-colour raid tiles complete Medallions. Friendly plates gain badges; cast, experience and reputation bars follow the slabs.

## v0.1.3 (2026-11-15)

A hotfix for the RestedXP guide card, with fixes for the bag window, the swing timer and nameplates.

Highlights:

- RestedXP gets the tall column under Frames while open, with scrolling quests below the minimap.
- The RestedXP guide card shows your whole current step again.
- RestedXP's Active Targets and Active Items boxes no longer take room the guide needs for your current step.
- The bag window's close button works again after you drag the window.
- A hunter's ranged swing shows one swing bar instead of two.

### Changed

- Under Frames, an open RestedXP guide takes the tall column and quests move below the minimap with scrolling. The cards swap only when the guide opens or closes, leaving room for the current step.

### Fixed

- The RestedXP guide card shows your current step again. When RestedXP put its steps under its own window, the card showed a blank block with only the step's last line and "1 more".
- RestedXP's Active Targets and Active Items boxes no longer take room the guide needs for your current step.
- The bag window's close button works again after you drag the window.
- A hunter's ranged swing shows one swing bar instead of two.
- Nameplates no longer creep upward a pixel at a time.

## v0.1.2 (2026-11-15)

Fixes for the minimap, the RestedXP guide and the HUD's size on screens that are not 16:9.

Highlights:

- Keep off-map guide pins hidden by default, with a switch under Minimap > Addon pins on the map's edge.
- The minimap's addon drawer now collects every addon button that sits on the map, not only the ones it knew by name.
- Action bar 3 fits above Orbs pet and stance bars, keeping any position you saved.
- The zone name above the minimap no longer runs into the N diamond, and the N stays inside its diamond.
- See your current RestedXP step with Active Targets and Active Items side by side below the guide.

### Added

- Minimap > Addon pins on the map's edge hides off-map guide pins by default. Turn it on to restore them; pins for places on the map always show.

### Changed

- The minimap's addon drawer now collects every addon button that sits on the map, not only the ones it knew by name.
- Action bar 3 has its own place under Orbs, above the pet and stance bars. If you moved bar 3 yourself, it keeps your place.

### Fixed

- The zone name above the minimap no longer runs into the N diamond, and the N stays inside its diamond.
- RestedXP Active Targets and Active Items sit side by side below the guide. The current step and number stay visible; the quest card may show one fewer quest while both boxes are up.
- Under Orbs, the health and power orbs no longer cover chat or the damage meter on 4:3, 3:2 and 16:10 screens.
- Pet and stance bars clear bar 3 and party frames, while targets and buffs clear bags and loot. Interface size Auto steps down until the whole HUD fits.
- Settings saved by an older version that had stopped updating now update at your next login.

## v0.1.1 (2026-11-14)

A hotfix for errors that players hit after v0.1.0.

Highlights:

- Raid frames and window skins no longer raise an error when the game loads.
- Switching the HUD style with Options open no longer raises an error.
- The "interrupt spell not allowed" warning no longer shows at login when no interrupt spell is set.
- Dragging the quest tracker in Edit Mode no longer raises an error.
- Nameplates no longer drop below the mob in combat.

### Fixed

- Raid frames and window skins no longer raise an error when the game loads.
- Switching the HUD style with Options open no longer raises an error.
- The "interrupt spell not allowed" warning no longer shows at login when no interrupt spell is set.
- Dragging the quest tracker in Edit Mode no longer raises an error.
- Nameplates no longer drop below the mob in combat.

## v0.1.0 (2026-11-13)

This is the overhaul. KstyleUI now has two HUD styles, Frames and Orbs, that you pick in Options and in the first-run setup, and almost every part of the screen was redrawn to match them: cleaner bars, new nameplates, a group damage meter and an interface size that lands exactly on whole screen pixels.

Highlights:

- Choose framed unit cards with Frames or health and power orbs with Orbs, with previews in Options and setup.
- Track group damage for the current fight, last fight or session, with each player's spell breakdown.
- Read cleaner nameplates with flat bars, clear threat and cast signals, and name-only plates for objects.
- A wide target bar at the top of the screen under Orbs, and a wide form of the target frame under Frames.
- Choose Centred for a HUD in the middle 21:9 band of an ultrawide screen, or Spread to use the full width.

### Added

- Choose Frames or Orbs in Options > General or setup, with a preview of each. Frames uses framed unit cards; Orbs uses health and resource orbs with a forged action tray.
- A group damage meter offers current, last and whole-session views with a spell split per player. The threat card follows the same design.
- Nameplates redrawn: plain, flat bars with tracked capital names, a black track while you hold threat, cast and stop flashes, and a name-only plate for objects such as a mailbox that can never fill a bar.
- A wide target bar at the top of the screen under Orbs, and a wide form of the target frame under Frames.
- Ultrawide screens choose between Centred and Spread. Centred keeps the HUD in the 21:9 band in the middle of a 32:9 monitor. Spread uses the whole width and keeps your group frames on the 21:9 line.
- One shared action slot for the action bars and the cooldown rows, with a pressed state, a proc glow, a lit sweep edge and a gilt flash when an ability is ready again.
- Combat text with white hits, gold crits and a short rise.
- Buffs sorted by how you use them.

### Changed

- Unit bars gain held health-loss bands, hit flashes and low-health warnings. Targets fill from the left, casts are taller, and party and raid frames share the bars and low-health glow.
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
- Baine's fixes bring existing minimap buttons onto the square map, collect Blackthornes and 0xgle Bugs buttons and restore them correctly, and fix game-object nameplates. Thank you, Baine.
- The unit frames' bars no longer carry an ornament around them.
- The chat tab and its wash sit inside the chat card.

## v0.0.7 (2026-11-13)

A small release that fixes two things in the cooldown and buff displays.

Highlights:

- Fallback Blizzard cooldown rows now sit on KstyleUI's rows, clear of action bars, preserving moved or oversized rows.
- Tracked buff icons and bars keep the right gap between icons at every icon size and UI scale.

### Fixed

- When KstyleUI falls back to Blizzard's own essential and utility cooldown rows, they now sit on KstyleUI's rows instead of on top of your action bars. A row you moved yourself, or one too wide to fit, stays where it was.
- Tracked buff icons and bars keep the right gap between icons at every icon size and UI scale.

## v0.0.6 (2026-11-13)

This release fixes what the first live session on World of Warcraft: Forever turned up, and sets the HUD up properly for ultrawide screens.

Highlights:

- Keep your HUD together on ultrawide screens with a centred 21:9 band, or choose 16:9 or full width in Options.
- Separate cards for your quests and the RestedXP guide on the right rail, in place of one shared story card.
- Empty slots on bars 4 and 5 stay hidden until you drag an action or open Layout Mode.
- Track damage in KstyleUI's own card, with Blizzard's window still available under Options > Meters > Style.
- Forged trim now draws on nameplates and on the player and target frames, placed from KstyleUI's own layout.

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

The first public KstyleUI release brings a complete modular interface for WoW Forever, with dark forged cards, selectable materials, fonts and layouts.

Highlights:

- Build your interface with only the KstyleUI modules you want, from frames and bars to bags, chat and skins.
- Open `/kstyle` for search, live previews and shareable profiles, with DPS, Tank or Healer layouts in setup.
- Move, resize and scale every element in Layout Mode, with snapping, nudges, undo, redo and visibility rules.
- Choose Forged iron, Slate, Flat or Glass cards in General, with brackets or gilt ticks for Forged iron.
- Set your own type with Folio or Lumen and per-role fonts, including LibSharedMedia faces.

### Added

- Switch on the modules you want: unit and group frames, action bars, cooldowns, auras, nameplates, combat text, minimap, chat, bags, tooltips, data bars, meters, skins and quality of life.
- Open `/kstyle` for module pages, search, live previews and shareable per-character profiles. First-run setup chooses a DPS, Tank or Healer layout and your modules.
- Layout Mode (`/kstyle layout`): move, resize and scale every element with snapping guides, a grid, arrow-key nudges, undo and redo, and set when each element shows.
- A card material choice in General: Forged iron with brackets (the default), Forged iron with gilt ticks, Slate, Flat or Glass. Dropdowns and tooltips stay opaque on every material except Glass.
- Type sets and fonts by role: pick Folio or Lumen, then override the font for any role, from KstyleUI's own faces or any LibSharedMedia font.
- Forged ornaments offer Off, Subtle or Full (default) across frames, bars, plates, minimap, windows and RestedXP. Ornaments that do not fit are dropped instead of squeezed.
- A story card on the right rail that shows the RestedXP guide and your quests, a loot feed above the chat card, a white cursor on the player's cast bar, and a skin for RestedXP's other windows.
- Fast auto loot, auto repair, quest hand-in and quiet error text in the quality-of-life module, and an offer to update your bars when you learn a new spell rank.
- Bag search with `type:`, `name:`, `ilvl` and quality keywords, custom categories, junk selling, and a bank window with Warband tabs.
- A damage meter with a fight switch (now, last, all) and a spell split under each row, a group threat meter and a swing timer.
- Chat history that survives a reload or relog, a copy window, timestamps, short channel names and clickable links.
- Group frames with debuff priority and dispel highlights, your heals, absorbs, indicator slots and compact raid frames above 25 players.
- English, German, French, Spanish and Simplified Chinese. The German, French, Spanish and Chinese strings are machine-made and not yet checked by native speakers; report a wrong or awkward one.
- An optional icon pack of repainted ability and item icons, a separate download (see How to install).

### Changed

- DPS, Tank and Healer layouts follow one reference: chat and party left, actions centre, map and cards right. They fit 16:9, 16:10 and 21:9, with whole-pixel sizing.
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
