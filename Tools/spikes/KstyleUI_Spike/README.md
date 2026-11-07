# KstyleUI Spike

KstyleUI Spike is a throwaway addon that answers the open questions in the [design spec's Spikes section](../../../docs/superpowers/specs/2026-11-07-kstyleui-design.md#spikes) inside the live Forever client. It never ships: nothing under `Tools/` is packaged.

Each spike writes what it found to the SavedVariables table `KstyleUISpikeDB`. Panels that need your eyes take their own screenshot.

## Install the spike

Do this once on the Mac. Run each command in **Terminal**.

1. Fetch the latest code:

	```bash
	git -C ~/KstyleUI fetch origin
	```

2. If the folder `~/KstyleUI.worktrees/staging-live` does not exist yet, create it:

	```bash
	git -C ~/KstyleUI worktree add ~/KstyleUI.worktrees/staging-live staging
	```

	If git answers `invalid reference: staging`, run this instead:

	```bash
	git -C ~/KstyleUI worktree add --track -b staging ~/KstyleUI.worktrees/staging-live origin/staging
	```

3. Bring that folder up to date:

	```bash
	git -C ~/KstyleUI.worktrees/staging-live merge --ff-only origin/staging
	```

4. Link the addons into the game:

	```bash
	bash ~/KstyleUI.worktrees/staging-live/Tools/dev/link-addons.sh --spike
	```

	You see one `link` line (or `ok` line) per addon, including `.../Interface/AddOns/KstyleUI_Spike`.

5. Quit World of Warcraft completely and start it again. A `/reload` does not load a newly linked addon.
6. On the character screen, click **AddOns** and check that **KstyleUI Spike** is ticked.
7. Log in. Chat shows `KstyleUI Spike: loaded on build 1.60.1.70840. Type /kspike for help.`

## Run the basic spikes on each screen

Run these anywhere out of combat: a city is fine.

1. Type `/kspike basic` in chat.
2. Wait 20 seconds. The spike opens the fonts panel, the scale card and the textures panel one after another, 4 seconds apart, and takes a screenshot of each. It also checks profile encoding and records the experience preset. Chat says when each one is done.
3. During the first minute, open and close the character window (`C`), the spellbook (`P`) and the world map (`M`). The scale spike counts any action the game blocks.
4. Type `/kspike hide` to close the panels.
5. If you have another screen (1080p, 1440p or 4K), move the game window to it and repeat steps 1 to 4 there.
6. Type `/reload` to save the results.

Optional: `/kspike scale 1.25` and `/kspike scale 0.75` redraw the scale card at the largest and smallest user scale. Each takes a screenshot.

## Compare the Classic and Enhanced presets

1. Type `/kspike presets`. Chat names the current experience preset.
2. Press **Esc**, open **Options**, find the experience preset setting, and switch to the other preset. Log out and back in if the game asks.
3. Type `/kspike presets` again.
4. Switch back to the preset you play with.

## Test action bar paging

Use a character that pages its action bar: a warrior (stances), a druid (forms) or a rogue (stealth). Start out of combat.

1. Type `/kspike paging`. A button appears below the centre of the screen, labelled `Spike page 1, action 1`.
2. Change stance or form, or stealth. The label and icon change with the page.
3. Click the button a few times. It uses the first action on the current page.
4. If you can, take control of a creature (possess) or enter a vehicle.
5. Start a fight, and type `/reload` while you are in combat. After the reload, chat says `paging started.` The button was rebuilt at login, in combat.
6. Leave combat, then type `/kspike stop`. The spike stops rebuilding the button at each login.

## Test group headers and unit watch

Start out of combat.

1. Type `/kspike header`. Two bars appear at the left of the screen: `Target watch` and `Header child 1` (you).
2. Target something, then clear the target with **Esc**. `Target watch` shows only while you have a target.
3. Invite someone to a party, or join one. The header adds a bar per member.
4. Type `/kspike stop`.

## Run the combat spikes at a boss

The auras spike needs a boss pull: aura data turns secret around `ENCOUNTER_START`. Any dungeon boss works.

1. Stand next to the boss, out of combat, and type `/kspike pull`. Chat says `combat started.`, `auras started.`, `meters started.` and `cdm started.`
2. Pull the boss within 15 minutes. Fight as usual.
3. In combat, a row of cooldown icons labelled `KstyleUI Spike mirror of the essential cooldowns` appears above the action bars. Type `/kspike shot` once while both it and Blizzard's essential cooldowns are on screen.
4. After the fight, type `/reload`.

The pull spikes stop on their own after 15 minutes. `/kspike stop` ends them sooner.

## Hand back the results

After a `/reload` or a logout, the game has written two things:

| What | Where |
| --- | --- |
| The run log | `/Applications/World of Warcraft/_forever_/WTF/Account/<ACCOUNT>/SavedVariables/KstyleUI_Spike.lua` |
| Screenshots | `/Applications/World of Warcraft/_forever_/Screenshots/` |

Tell the agent the spikes are done. The agent reads both and writes the answers into `docs/superpowers/spikes/2026-11-spike-results.md`. You only pick the font from the fonts screenshots.

## Commands

| Command | What it does |
| --- | --- |
| `/kspike` | Prints help. |
| `/kspike list` | Names every spike, its group, and what it does. |
| `/kspike basic` | Runs the basic group: `fonts`, `scale`, `encoding`, `textures` and `presets`, 4 seconds apart. |
| `/kspike pull` | Starts the pull group at once: `combat`, `auras`, `meters` and `cdm`. |
| `/kspike <name>` | Runs one spike, for example `/kspike fonts`. |
| `/kspike scale <n>` | Runs the scale spike at user scale `n`, from 0.75 to 1.5. |
| `/kspike shot` | Takes a screenshot now. |
| `/kspike status` | Prints how many runs are logged and which spikes are still running. |
| `/kspike stop` | Ends every running spike, marks it finished, and stops `paging` from rebuilding at login. |
| `/kspike hide` | Closes every spike panel. |

Running a spike again starts a new run. Old runs stay in the log.

## What each spike records

Each run is a row in `KstyleUISpikeDB.runs` with `spike`, `time` (server time), `build`, `origin` and `results`. A spike never stores a secret value: it stores the string `<secret>` instead.

| Spike | Spec question | `results` holds |
| --- | --- | --- |
| `fonts` | Do Source Sans 3 and Inter render cleanly at 9, 11, 16 and 24 units, with and without `SLUG`? | `samples`: one row per font, size and variant, with what `GetFont()` reported. `screenshots`. |
| `scale` | Does setting the scale of a frame parented to `UIParent` cause taint, and do the pixel maths hold? | The physical screen size, `UIParent` and root scales, the root's size in units, the pixel size, the border width in pixels, `blocked` and `forbidden` counts, and `events`. `screenshots`. |
| `encoding` | Do `C_EncodingUtil.SerializeCBOR`, `CompressString` and `EncodeBase64` exist on Forever? | `exists` per function, each `stages` step, `roundTrip`, `mismatch`, and `rejectsGarbage`: what each decoder does with a hostile string. |
| `textures` | Do masks read a PNG's alpha channel, and does a 2048x2048 texture load? | `textures`: for each tile, the `SetTexture` return, `GetTexture()`, the file path, the file ID and `IsObjectLoaded()`. `screenshots`. |
| `presets` | How do the Classic and Enhanced experience presets change the default frames KstyleUI hides? | `preset`, `editMode` (the active layout and whether it is a preset), `frames` (exists, shown and visible for each default frame a module replaces), and `cvars`. |
| `paging` | Do `RegisterStateDriver` and `WrapScript` work on live, including stance, stealth, form and possess paging? | `driver`, `createdAt` (`command` or `PLAYER_LOGIN`), `inCombatAtCreate`, `changes` (each page with the bonus bar offset, form, stealth and every macro condition), `clicks`, `blocked` and `triggers`. |
| `header` | Does `SecureGroupHeaderTemplate` work on live? | `children` and `units` from the party header, `counts` over time, `watch` (each show and hide of the `RegisterUnitWatch` button), and `blocked`. |
| `combat` | Which units fire `UNIT_COMBAT`, and which arguments are secret in and out of restriction? | `units`: per unit token, the event count and a secret count per argument, in and out of combat. `nameplateFired`, `kinds` and `instanceType`. |
| `auras` | When does `C_Secrets.ShouldAurasBeSecret()` turn true relative to `ENCOUNTER_START` and `InCombatLockdown()`? Are combo points secret outside restriction? | `flips` (each change of `ShouldAurasBeSecret()` with the combat and encounter state), `events` (encounter, regen and restriction changes), `initial`, and `comboPoints` secret and plain counts in and out of combat. |
| `meters` | Do `C_DamageMeter` values go secret in combat? Which power types are never secret? | `powerTypes` (each type's `GetPowerTypeSecrecy` level), `available`, and `samples` of the current session: which fields are secret, in and out of combat. |
| `cdm` | Can `C_CooldownViewer` data and duration objects drive KstyleUI's own cooldown icons in combat? | `categories` and `cooldowns` (the Cooldown Manager's data and its secret fields), `icons`, `builtInCombat`, `calls` (duration objects, secret durations and `SetCooldownFromDurationObject` errors), `setCooldownProbe` (whether plain `SetCooldown` accepts the values), and `samples` comparing the mirror with `EssentialCooldownViewer`. |

### Read the panels

- **Fonts.** Rows are font and size. Columns are `SetFont` with no flags, `SetFont` with the `SLUG` flag, and a font object from `Spike.xml` with `slug="true"`. If the second and third columns look the same, the `SLUG` flag works from Lua.
- **Scale.** The card's border is the width KstyleUI will use on this screen. Each comb is lines one physical pixel wide, one pixel apart. On a sharp result every line is separate and even. Blurred or doubled lines mean the pixel maths are off.
- **Textures.** Tile 3 is a solid colour masked by `alpha_test.png`, whose alpha fades left to right while its colour fades top to bottom. A left-to-right fade means masks read alpha. Tile 4 shows the chamfered diamond only if the 2048x2048 PNG loaded.

## Remove the spike

The spike folder in `AddOns` is a symbolic link. Removing the link leaves the repository alone:

```bash
rm "/Applications/World of Warcraft/_forever_/Interface/AddOns/KstyleUI_Spike"
```

## Redraw the test textures

`make_media.py` draws `Media/mask_2048.png` and `Media/alpha_test.png` with the Python standard library. From the repository root:

```bash
python3 Tools/spikes/KstyleUI_Spike/make_media.py
```

`Tools/tests/test_spike_media.py` checks that the committed PNGs match the script.

## Fonts and licences

All three fonts are under the SIL Open Font License 1.1. They were downloaded from each project's GitHub release on 2026-11-07.

| File | Source | Licence file | SHA-256 |
| --- | --- | --- | --- |
| `Media/SourceSans3-Semibold.ttf` | [`adobe-fonts/source-sans` 3.052R](https://github.com/adobe-fonts/source-sans/releases/tag/3.052R), `TTF-source-sans-3.052R.zip` | `Media/OFL-SourceSans3.txt`, from `LICENSE.md` at tag 3.052R | `a3f4f8dcf343a8f24dc61951de93f3ba1558b15cd250ba24af8a40e957081b7d` |
| `Media/SourceSans3-Regular.ttf` | Same zip | Same | `4644c81b86ec9caaa76b634889968ed3c4f4f52f054855933acc7c2b21e53b0f` |
| `Media/Inter-SemiBold.ttf` | [`rsms/inter` v4.1](https://github.com/rsms/inter/releases/tag/v4.1), `Inter-4.1.zip`, `extras/ttf/` | `Media/OFL-Inter.txt`, from `LICENSE.txt` in the zip | `78a843fade9d4612a5567302fb595b56976eb5fcebf4fea5a5912d638bafcde3` |

## Why

- **One root canvas.** Every panel sits on `KstyleUISpike_Root`, scaled with the spec's `ApplyRootScale`, so the fonts and pixel combs render at the size KstyleUI will use.
- **No dependency on the core.** The spike tests the client, not KstyleUI. It does not register with `KstyleUI.Layout` or `KstyleUI.Options`, and it logs to its own `KstyleUISpikeDB`.
- **Automatic screenshots.** A Mac keyboard has no Print Screen key, so panels call `Screenshot()` one second after they open.
- **Spaced-out groups.** `/kspike basic` opens one panel at a time so each screenshot shows one panel.
- **Pull spikes run 15 minutes.** The window starts when you type the command, so it covers the walk to the boss and a long fight. Aggregates are counts, so a long window does not grow the log much.
- **Secure frames stay on `UIParent`.** The paging and header frames are not children of the scaled spike root: a protected child would block rescaling the root in combat.
- **The cooldown mirror waits for lockdown.** `PLAYER_REGEN_DISABLED` fires before `InCombatLockdown()` turns true, so `cdm` builds its icons on its first tick in lockdown. That is the case the question asks about.
- **Offline tests.** `Tools/regression/test-spike.lua` and `Tools/regression/test-spike-probes.lua` load the addon into the stub game and run every spike, including with secret values and with the probed APIs missing, so a typo fails CI instead of the game session.
