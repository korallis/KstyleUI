# How to test KstyleUI in game

This guide takes you through the first in-game test of the whole suite: install, first login, a check of each module, the spikes, the restriction and taint settings, and how to hand the results back. Every module was built and tested offline first. This session is the first time the code meets the live Forever client, so expect a few Lua errors. Each one you send back is one the agent can fix.

You need about two hours for the core and modules, plus a dungeon run and, if you can, a battleground for the group checks.

## Before you start

- Quit World of Warcraft. A newly linked addon loads only after a full restart, not after `/reload`.
- Have a level 60 character of a class that pages its action bar (warrior, rogue or druid), a character below level 60 for the XP bar, and a hunter or warlock for the pet bar checks if you have one.
- Install an error catcher such as BugSack and BugGrabber if you do not have one. KstyleUI also logs every error it catches to its devlog.

## Install the addons

The game runs the addons from your clone at `~/KstyleUI`, on the `staging` branch. A script links each addon folder in the clone into the game's AddOns folder, so the game loads whatever the clone holds. Agents work in their own folders and never change your clone. Run each command in **Terminal**.

1. Fetch the latest code:

	```bash
	git -C ~/KstyleUI fetch origin
	```

2. Switch your clone to `staging`. If it is already on `staging`, git prints `Already on 'staging'` and changes nothing.

	```bash
	git -C ~/KstyleUI switch staging
	```

3. Bring the clone up to date:

	```bash
	git -C ~/KstyleUI pull --ff-only
	```

4. Link the addons into the game:

	```bash
	bash ~/KstyleUI/Tools/dev/link-addons.sh --spike
	```

	You see one `link` or `ok` line per addon, each naming `/_forever_/Interface/AddOns/<addon>`. `--spike` also links the spike addon from `Tools/spikes/KstyleUI_Spike`. Leave it out if you only want KstyleUI. To see what the script would do without changing anything, add `--dry-run`.

5. Start World of Warcraft: Forever.

Later, to get new fixes into the game, run `git -C ~/KstyleUI pull --ff-only` and type `/reload`.

## Enable the addons

On the character screen, click **AddOns**. KstyleUI's addons are grouped under **KstyleUI**. Tick all of them:

| Addon | What it is |
| --- | --- |
| KstyleUI | The core: theme, scale, Layout Mode, first-run setup, `/kstyle` |
| KstyleUI Options | The settings window. It loads when you first open it. |
| KstyleUI Unit Frames, Group Frames, Action Bars, Cooldowns, Auras, Nameplates, Combat Text, Minimap, Chat, Bags, Tooltips, Data Bars, Meters, Skins | One addon per module |
| KstyleUI Icons, KstyleUI Colour Icons | The two custom icon sets. They load only when you turn custom icons on. |
| KstyleUI Spike | Only if you linked it with `--spike`. It answers the open questions about the client. |

A module whose addon is not ticked cannot be switched on. Its switch in the setup shows as unavailable.

## Turn on the logs before you log in

Type these in chat once you are in the world. Each setting is saved, so it stays on until you turn it off.

1. Turn on the taint log, so blocked actions are written to a file:

	```text
	/console taintLog 1
	```

2. For the release-candidate pass only, turn on Blizzard's forced restrictions. They make the client treat the open world like a boss fight: health, casts and auras turn secret, and protected calls are refused. Do the first pass without them, then repeat the module checks with them on.

	```text
	/console addonCombatRestrictionsForced 1
	/console addonEncounterRestrictionsForced 1
	/console addonMapRestrictionsForced 1
	/console addonChatRestrictionsForced 1
	```

	To turn them off again, run the same commands with `0`.

## First login: the setup, the settings window and Layout Mode

### Run the first-run setup

About 2 seconds after your first login with KstyleUI, the setup opens: a glass panel that rises in, with four steps across the top.

1. **Welcome.** Click **Next**.
2. **Layout.** Pick **DPS**, **Tank** or **Healer**. The picked card lights in your class colour. Click **Next**.
3. **Modules.** Every module whose addon loaded is switched on, each with a one-line note. Leave them all on for this test. Click **Next**.
4. **Summary.** Click **Apply**, then **Reload**.

After the reload, KstyleUI's frames replace Blizzard's and sit where the layout puts them. The setup does not open again. `/kstyle setup` reopens it.

Check:

- [ ] **Back**, **Next** and the step strip move between steps, and steps you have not reached cannot be clicked.
- [ ] **Reload** reloads with no "Interface action blocked" message.
- [ ] If you are in combat when you press **Apply**, **Reload** stays disabled until combat ends.

### Open the settings window

Type `/kstyle`. The window opens with a short fade and rise. You can also open it from Esc > Options > AddOns > **KstyleUI**, or from the minimap's addon compartment.

- [ ] The rail on the left lists General, Elements, one page per module, Profiles and About. The selected entry has an accent bar and wash in your class colour.
- [ ] Each module page shows a live preview on the right, and changing a setting changes the preview and the real frames at once.
- [ ] Type `opacity` in the search field: rows from several pages are listed, and changing one there works. The clear button returns to the page.
- [ ] General > Appearance: change the accent to a custom colour, the font, the interface size (it applies when you let go of the slider), the text size and Motion. The window follows each change.
- [ ] Profiles: create a profile, switch to it, copy, rename and delete one. Export a profile (the string is selected, so Ctrl+C copies it) and import it back. Importing `hello` shows a clear reason.
- [ ] Escape and `/kstyle` both close the window. In combat it stays usable and your movement keys still work.

### Move and resize everything in Layout Mode

Click **Layout Mode** in the settings window, or type `/kstyle layout`.

- [ ] Every element you can see has a mover plate with its name. A frame you switched off has none.
- [ ] Drag a plate: accent guides show near the screen centre and other elements, and the element snaps.
- [ ] Turn on **Grid** in the toolbar: lines every 16 units, and drags snap to them.
- [ ] Click a plate and press the arrow keys: it moves one physical pixel at a time, ten with Shift. Your character does not turn.
- [ ] Drag the corner and edge handles of a resizable element (a unit frame, the minimap, the chat): size limits hold and the borders stay crisp.
- [ ] Scroll over the plate of a scalable element (an action bar, a dialog): it grows and shrinks, and its borders stay crisp.
- [ ] **Undo**, **Redo** and **Reset** work, and so do Ctrl+Z and Ctrl+Y. Right-click a plate to reset that element.
- [ ] Move something, then pull a mob: Layout Mode closes, the element goes back to its saved place, chat says why, and no "action blocked" message appears.
- [ ] **Done** closes Layout Mode. After `/reload`, everything stays where you put it.
- [ ] On the Elements page, set an element to **In combat only**: it hides out of combat and shows in combat. Set one to **On mouseover**: it fades in under the pointer.
- [ ] The Elements page shows no **Shown** row for the settings window, the dialogs, the Layout Mode toolbar or the setup window, and their opacity stops at 25%.
- [ ] If you have a second screen at another resolution, move the game window there: elements keep their places and their borders stay crisp.

## Check each module

Work through the modules in any order. Every module has the same three checks at the end, so they are listed once here:

- Its settings page changes the live frames and the preview at once.
- Layout Mode moves and resizes or scales each of its elements.
- Turning it off in its settings page gives Blizzard's frames back. A module that restyles Blizzard's windows (Skins, Chat, Minimap, Tooltips, Cooldowns in reskin mode) asks for a reload instead.

### Unit Frames

- [ ] Blizzard's player, target, focus, pet and boss frames and the player cast bar are gone. KstyleUI's frames sit in the HUD band, as in the v3 mockups.
- [ ] Target a mob and a player: health bar, percent text, name in capitals, level badge, reaction or class colour, round portrait. Switch the portrait to the class icon and to off.
- [ ] Left-click targets, right-click opens the unit menu, and hovering shows the unit tooltip, on every frame including boss frames.
- [ ] Target another player in restricted content (or with the forced restrictions on): their health bar keeps its class colour, not grey.
- [ ] Get healed: the incoming heal shows past the health fill.
- [ ] Pull a mob: the target frame glows neutral yellow, then orange, then hostile red as you take aggro. The player frame glows with your own threat.
- [ ] A raid marker, the leader crown, role icons, the PvP badge, crossed swords in combat and Zz while resting show and hide correctly.
- [ ] As a rogue, combo pips fill and follow your target. As a druid, mana shows in bear and cat form and pips in cat form. As a hunter or warrior, there is no class resource and no mover for it.
- [ ] Cast, channel, get interrupted and fail a cast. Check the target, focus and boss cast bars too, including a grey non-interruptible cast. A failed second spell during a cast does not end the running cast bar.
- [ ] Debuff a focus target and a boss: your debuffs show right of their frames with swipe, timer, stacks and dispel border.
- [ ] Switch the focus frame off: it disappears, and Layout Mode and the Elements page have nothing for it.

### Group Frames

- [ ] With no group, nothing shows. Turn on **Show when solo** and your own frame appears at the top left.
- [ ] In a party, five frames stack downward with your own first: portrait with a class ring and level badge, class-coloured bar, name and percent health. Blizzard's party frames are gone.
- [ ] Walk away from a member: their frame fades to 40% and comes back when you return. A dead member shows "Dead"; an offline member shows "Offline".
- [ ] Left-click targets the member (accent outline), right-click opens the unit menu, hovering shows the tooltip. The hover outline eases in rather than snapping.
- [ ] In a raid, the party frames hide and eight group columns appear. Switch **Sort by** between Group, Role and Class out of combat: the raid reorders.
- [ ] Have people join and leave quickly: the frames end up with the right names, classes and health.
- [ ] Change width, height, spacing and growth in combat: the change applies when combat ends, with no "Interface action blocked" message.
- [ ] Role icons, the leader crown, raid markers and ready-check marks show. Pull aggro onto a member: a yellow, orange or red border, in the same colours as the unit frames and nameplates.
- [ ] A heal with a cast time shows a lighter segment on the member's bar; Power Word: Shield shows a pale one.
- [ ] A debuff shows its icon with a swipe; clicking through it targets the member. A debuff you can dispel outlines the frame in the debuff type's colour.
- [ ] Switch to the gamepad interface (Options, Controls) out of combat: Blizzard's party frames return and gamepad targeting works. Switch back: KstyleUI's return.

### Action Bars

- [ ] Bars 1 and 2 show as two rows of 12 under the HUD band. Blizzard's main, multi, pet and stance bars are gone.
- [ ] Your keybinds (1 to =, Shift keys, mouse buttons) cast from KstyleUI's buttons and show short keybind text such as `S1` or `M4`.
- [ ] Warrior: change stance in and out of combat; bar 1 pages. Rogue: stealth pages bar 1. Druid: cat, bear and moonkin forms page bar 1, and prowl follows the Stealth switch.
- [ ] Mind Control or another possess: bar 1 shows the possessed unit's actions and the pet bar shows its abilities.
- [ ] Hunter or warlock: the pet bar shows only with a pet. Right-click toggles autocast (accent dot).
- [ ] Cooldown sweeps and numbers run, including the global cooldown. A spell with charges shows its count and a recharge edge.
- [ ] A proc such as Overpower or Clearcasting glows. Out of range tints the icon red, lacking power tints it blue, and an unusable action greys out.
- [ ] Shift-drag a spell off a bar and drop another on. Nothing moves in combat.
- [ ] A flyout such as mage portals opens above its button, casts the spell you click and closes.
- [ ] In a vehicle or on a flight path, the leave button beside bar 1 gets you out or lands early. Scale bar 1 in Layout Mode: the leave button scales with it.
- [ ] Switch bar 3 on and off: its mover comes and goes in Layout Mode.
- [ ] Switch to the gamepad interface and back, once out of combat and once in combat: KstyleUI's bars hide and the gamepad bars work, then everything comes back, with no Lua error and no "action blocked" message.

### Cooldowns

- [ ] Turn on Blizzard's Cooldown Manager (Options > Gameplay > Combat). The essential row appears above the action bars with the utility row under it, and Blizzard's essential and utility viewers disappear.
- [ ] Cast spells with cooldowns in the open world and in a dungeon boss fight: icons sweep and count down, grey while cooling, glow when ready, show charges and pulse on procs.
- [ ] Reorder cooldowns in Blizzard's Cooldown Manager settings: the KstyleUI rows follow within about a second.
- [ ] Hover a KstyleUI icon: its spell tooltip shows. Hovering where Blizzard's viewer used to be shows nothing.
- [ ] Blizzard's tracked buff icons and bars show restyled. Set **Display** to **KstyleUI icons**: KstyleUI buff icons and bars appear and follow your buffs. In a boss fight, note whether they keep updating.
- [ ] `/kstyle test` lists `cooldowns` with `essential=mirror(n) utility=mirror(n)`. If any group says `reskin` with "the mirror failed" in the devlog, send that line.

### Auras

- [ ] Blizzard's buff and debuff frames disappear and KstyleUI's panels show under the minimap, with timers under each icon.
- [ ] A weapon oil, poison or imbue shows first in the buff row; right-click removes it.
- [ ] Right-click a buff, in and out of combat: it is cancelled. Hovering shows the aura tooltip.
- [ ] A magic, curse, poison or disease debuff takes its type's border colour.
- [ ] Pull a dungeon boss: the panels keep updating with no Lua error, and private boss debuffs appear.
- [ ] Set Buffs to **On mouseover** on the Elements page: the panel fades in when the pointer moves straight onto an icon, also in combat.
- [ ] In the gamepad interface, Blizzard's buff frames come back.

### Nameplates

- [ ] Enemy plates show the KstyleUI plate and no Blizzard plate under it, also after `/reload`. Friendly plates inside a dungeon stay Blizzard's.
- [ ] Health and percent update in combat; enemy names show in a dungeon even when they are secret.
- [ ] A player whose class is hidden still gets their class colour on the bar and name.
- [ ] The target's plate has the accent glow; the focus's plate has a blue edge. Other plates dim only while you have a target, if you set their opacity below 100%.
- [ ] Raid markers show. Elites show a gold diamond; rares a blue one.
- [ ] In a group: as damage, a mob on you glows red; as the tank, mobs you hold glow green.
- [ ] Casters' plates show cast bars with name, icon and time left. Interrupt one: red, "Interrupted", fade. A stun or root during a cast does not restart the cast bar.
- [ ] Your debuffs show above the name with swipe, time and stacks. Clicking through them targets the mob.
- [ ] Under Game nameplate settings: if **Distance** and **Height difference** show, run `/dump C_CVar.GetCVarInfo("nameplateMaxDistance")` and `/dump C_CVar.GetCVarInfo("nameplateMaxVerticalDistance")` and send the output. If either dump prints nothing, that row must be hidden.
- [ ] With a gamepad, the interact prompt icon still shows above an NPC's plate.

### Combat Text

- [ ] Log out to the character screen and back in (a `/reload` is not enough), then hit a target dummy: the game's own damage numbers use Source Sans 3.
- [ ] Take damage: numbers rise through the field above your character, coloured by school; critical hits are larger and gold. Heals show as green `+` numbers; dodges and parries in grey.
- [ ] With Unit Frames on, numbers rise from the target frame. Set **Your numbers** to the player frame: they move there, and the field's mover disappears from Layout Mode.
- [ ] In a party with Group Frames, numbers rise from members' frames. With Nameplates, numbers rise from plates if the game sends them. The `combat text` devlog line says how many came from nameplate units.

### Minimap

- [ ] The square map sits top right. Blizzard's round border, header, zoom buttons, day and night orb and coordinates are gone.
- [ ] Scroll over the map, including its corners: it zooms. Clicks still ping and blips still show tooltips.
- [ ] The zone and the clock show on the strip inside the bottom edge, and the clock rolls over at the minute. Coordinates change as you walk and hide in instances.
- [ ] The button column shows tracking and calendar; mail and the queue eye appear when they apply. Each opens what Blizzard's does.
- [ ] With addons that add minimap buttons (BigWigs, Details), the four-squares button opens a drawer with every addon button, and each still works.

### Chat

- [ ] The chat sits bottom left in a glass panel: tabs in capitals with an accent underline, messages, and the edit box at the bottom.
- [ ] Guild, party and `/1` lines show `[14:31] [G] Name: text`, with names in class colours.
- [ ] Post `https://www.wowhead.com` in `/s`: it becomes a link; clicking it opens a dialog with the address selected.
- [ ] Chat lines show one timestamp, in brackets and in the timestamp colour. Loot, XP and system lines have none: the game adds the timestamp, and it stamps only chat messages.
- [ ] On the Chat settings page, change **Timestamp format** and **Timestamp colour**: the next chat line uses them. Pick **None**: new lines have no timestamp.
- [ ] Open Esc > Options > Social and change **Chat Timestamps**: KstyleUI's **Timestamp format** follows, and new lines keep KstyleUI's brackets and colour.
- [ ] Note your timestamp choice in Options > Social before the first login with KstyleUI. Turn the Chat module off: that choice comes back.
- [ ] If chat lines show `|cff` text or no timestamp at all, send the devlog. It says whether the game refused KstyleUI's format.
- [ ] **Copy** at the end of the tab strip opens the copy window with the chat as plain text.
- [ ] Open and close Blizzard's Edit Mode: the chat returns to its panel.
- [ ] `/cast` and `/use` typed in chat still work in combat.

### Bags

- [ ] Press B: the KstyleUI bag window opens bottom right and Blizzard's bags stay closed. Press B again: it closes. Escape closes it too.
- [ ] Right-click a potion, in and out of combat: it is used. Drag items between slots and shift-click a stack to split it.
- [ ] Item levels, stack counts, quality borders, a gold dot on grey items and a glow on new items show. The search field dims other items. **Sort** sorts.
- [ ] At a merchant, right-click a grey item to sell it, and **Sell junk** sells every grey.
- [ ] At a banker, the KstyleUI bank window opens with your bags beside it. Deposit, withdraw, sort, and buy a tab if one is free.
- [ ] Switch to the gamepad interface: Blizzard's bags and bank come back and the D-pad works. Switch back: B opens KstyleUI's window.

### Tooltips

- [ ] Hover a bag item, an action button and a creature: dark chamfered glass with no Blizzard border. Green, blue and purple items glow in their quality colour.
- [ ] Players show their class colour and `<Guild>`; a unit targeting you shows `Target  You`. A health bar sits under unit tooltips and works in combat.
- [ ] Turn on Item ID, Spell ID and Icon ID: they show.
- [ ] Set the position to the mouse cursor: world tooltips follow it. Back on the anchor, drag the Tooltip anchor in Layout Mode: tooltips follow it. The anchor's rows on the Elements page are only position and scale.

### Data Bars

- [ ] On a character below level 60, the XP bar sits under the action bars with ten ticks and a rested overlay. Kill a mob: the fill eases to the new value. At level 60 the XP bar is hidden, as it should be.
- [ ] A watched faction shows in its standing's colour. In a battleground, the honour bar shows rank progress.
- [ ] The data strip shows frame rate, latency, gold, durability and time. Frame rate, latency and the clock update every second; gold and durability change when you loot, spend, take damage or repair.
- [ ] Click gold (bags), durability (character pane) and the clock (calendar) out of combat. In combat, nothing opens and nothing is blocked.
- [ ] KstyleUI's micro menu and bag bar sit bottom right on glass. Every micro button opens its window; bag buttons open your bags, also in combat.

### Meters

- [ ] The damage meter sits at the right above the data strip, with the threat meter above it. Turn on Blizzard's Damage Meter (Options, Advanced): while KstyleUI's shows, Blizzard's is gone.
- [ ] Hit a dummy: the damage meter lists you. Click its title to change the meter type; right-click switches between current and overall.
- [ ] In a group fight, say whether the damage meter keeps updating in combat. If it shows "Hidden in combat", report what happens after combat.
- [ ] In a party in combat, the threat meter lists the group highest first. Near aggro as damage, the edge turns yellow at 80% and red with a pulse at 95%.
- [ ] With Blizzard's swing timer on (Options, Combat), melee: KstyleUI's bar fills once per swing. Dual-wield shows two bars; a hunter shows a ranged bar.
- [ ] Switch the threat meter or swing timer off: its mover disappears from Layout Mode.

### Skins

- [ ] Each window below wears the glass panel with no Blizzard frame art, and still works: character sheet (C), spellbook (P) and talents (N), world map and quest log (M), objective tracker, game menu (Escape), group finder, mail, merchant, class and profession trainers, professions, friends (O), guild (J), Legacy, loot and loot rolls, popups, ready check and the AddOns list.
- [ ] Equipment slots and loot show quality rims; reputation and profession bars are flat on a dark track.
- [ ] Open the spellbook or the map in combat, then leave combat: the skin applies after combat, with no "action blocked" message.
- [ ] Press Escape several times: the game menu buttons keep their hover glow every time.
- [ ] `/kstyle test`: each window you opened logs `applied`. Note any `is missing on this client` lines.

### Custom icons

- [ ] General > Icons: turn on **Custom icons**. Action buttons, cooldown icons, cast bar icons and tooltip icons show the light art (set A), tinted in your class colour.
- [ ] The art shows as glowing light art, not as blank, black or green squares. If it does not render, say so: set A's PNGs are 8-bit greyscale and can be repackaged as RGB.
- [ ] Switch the tint between class colour, spell school and white. Fireball turns fire-coloured under spell school.
- [ ] Switch to **Full colour** (set B): the painted art shows untinted, with no reload and no visible hitch.
- [ ] Turn custom icons off: Blizzard's icons come back.

## Run the smoke checks

Type `/kstyle test`. Chat prints `Test finished: N passed, N failed, N warnings.` The test checks that each module you switched on is running, that no Lua error was caught since login, that the APIs KstyleUI needs exist, that a profile export round-trips, and each module's own check.

- `PASS` is fine.
- `WARN` names an optional API that is missing and the fallback KstyleUI uses. Send it.
- `FAIL` is a bug. Send it.

Type `/reload` afterwards so the results are written to disk.

## Run the spikes

The spike addon answers the questions the code had to guess about in build mode. Its full guide is [`Tools/spikes/KstyleUI_Spike/README.md`](../Tools/spikes/KstyleUI_Spike/README.md). In short:

1. Out of combat in a city, type `/kspike basic` and wait 20 seconds. It shows the fonts panel, the scale card and the textures panel one after another and takes a screenshot of each.
2. Type `/kspike presets`, switch the experience preset in Options, and type `/kspike presets` again.
3. On a warrior, druid or rogue, type `/kspike paging`, change stance or form, and click the test button. Then `/kspike stop`.
4. Type `/kspike header`, target something and clear it, and join a party. Then `/kspike stop`.
5. Before the boss, switch the Cooldowns module off in `/kstyle`, so Blizzard's essential cooldowns show again. KstyleUI's mirror hides them.
6. Next to the dungeon boss, out of combat, type `/kspike pull`, then pull the boss. Type `/kspike shot` once in combat while the spike's cooldown row and Blizzard's are both on screen.
7. Type `/reload`, then switch the Cooldowns module on again.

`/kspike status` shows what is still running, and `/kspike list` names every spike.

## Send the results back

Type `/reload` (or log out) after your last check, so the game writes everything to disk. Then tell the agent the session is done. The agent reads these files:

| What | Where |
| --- | --- |
| KstyleUI's saved data and devlog: every caught error, every fallback taken, the `/kstyle test` results | `/Applications/World of Warcraft/_forever_/WTF/Account/<ACCOUNT>/SavedVariables/KstyleUI.lua` |
| The spike results | `/Applications/World of Warcraft/_forever_/WTF/Account/<ACCOUNT>/SavedVariables/KstyleUI_Spike.lua` |
| The taint log | `/Applications/World of Warcraft/_forever_/Logs/taint.log` |
| Screenshots | `/Applications/World of Warcraft/_forever_/Screenshots/` |

`<ACCOUNT>` is the folder named after your account, in capitals. With them, send:

- Each checklist item that failed, with what you saw instead.
- BugSack's text for any Lua error, if you use it.
- Which screens and resolutions you tested.
- Your font choice from the fonts screenshots.

When every module passes, including the pass with the forced restrictions on, `staging` can move to `main` and be tagged for the first release.
