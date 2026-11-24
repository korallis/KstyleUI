# Medallions effects layer

The effects layer is the part of the Medallions HUD style (KSTY-87 section 6, KSTY-88, M7) that every Medallions effect runs through. It decides how much may move, which effect owns a place on screen, and when a 3D model may play. Every effect is an AnimationGroup, a flipbook or an engine curve: nothing visual runs Lua per frame. Nothing here runs under Frames.

| File | What it holds |
| --- | --- |
| `Core/Effects.lua` | The motion level, `Allows`, the arbiter, the `Medallions` settings section |
| `Core/EffectModels.lua` | The 3D model pool, `Model`, `Burst`, the candidate file IDs |
| `Core/EffectBursts.lua` | The player medallion's level-up burst and the target bracket glows' motion |
| `Core/Vignette.lua` | The screen-edge low-health vignette |
| `Core/Layout/Rest.lua` | The leave-combat rest of the secondary frames |
| `KstyleUI_ActionBars/SlabEffects.lua` | The slot ready flash, the hub's resource-cap ring, the hub's 3D proc and level-up models |
| `KstyleUI_UnitFrames/CastEffects.lua` | The cast bar's landed and stopped flash |
| `Core/Widgets/Medallion.lua` (M5) | The sheen as ambient motion, the flip-in's claim, `Medallion:Burst` |
| `KstyleUI_ActionBars/Slab.lua` (M6) | The hub's ambient sheen and particles yield while an effect holds the hub |

## Motion level

General > Medallions > Medallions motion is Full (the default), Calm or Off, saved per profile as `Medallions.motion` through `Store.RegisterDefaults`. The level in force is the lower of that setting and Appearance > Motion: Reduced caps it at Calm and Off makes it Off, so the existing reduced-motion setting still wins.

| Kind | Full | Calm | Off | What it covers |
| --- | --- | --- | --- | --- |
| `ambient` | yes | yes | no | The hub's rune turn, breathing glow and sheen; the portrait sheen |
| `flare` | yes | yes | no | One-shot 2D effects: flip-in, combat sweep, proc start, hub pulse, level-up burst, ready flash, cast flash, bracket glow fade-in |
| `pulse` | yes | no | no | Repeating event loops: the slot's proc flipbook, the low-health ring, the vignette's and cap ring's breathing, the bracket glow's breathing |
| `particle` | yes | no | no | The hub's class particles |
| `model` | yes | no | no | 3D models |

At Off an effect's end state is applied at once (the secondary frames dim), and a state such as the low-health ring, the vignette or the cap ring still shows, still.

Two switches on the same page, both on by default, let a player drop an effect's drawing cost without touching the rest (`Medallions.vignette`, `Medallions.ambient`):

- **Low-health vignette** off hides the vignette's 16 edge slices, so they leave the draw (health is secret, so Lua cannot hide them by health). The portrait's low-health ring still shows and keeps breathing: it breathes on the vignette's group, so that one group runs on while the ring uses it and stops otherwise.
- **Ambient hub effects** off stills the hub as Calm does: the rune turn, glow and bloom breaths, sheen and particles stop, and the sheen and particles are hidden. The static hub art stays, and flares (combat, proc, level-up, ready and cast flashes) still play by the motion level.

**Calm crest at rest** (`Medallions.restingCrest`, on by default) settles the hub while the player is out of combat with no target, no proc and no effect holding it: the rune ring pauses where it stands, the sheen finishes its pass, the particles go, and only the glow and bloom breathe, at half speed (8.4 s a breath). Combat, a target or a proc wakes it to full at once, the runes turning on from their angle, and a wake during the sheen's last pass restarts the sheen. A target or proc repaints the hub only when ambient motion is on and its rest actually changes. It only stops loops, so the idle hub runs 2 loops instead of 9 (`test-perf-medallions-switches`). Off keeps the full idle motion.

| Function | Behaviour |
| --- | --- |
| `Effects.Level() -> "full" \| "calm" \| "off"` | The level in force |
| `Effects.Allows(kind) -> boolean` | Whether that kind of motion may play now |
| `Effects.Active() -> boolean` | Whether the HUD style is Medallions |
| `EffectsLevelChanged(level, old)` | A callback, fired once when the level in force changes from either setting |

## Priority and arbitration

A place is any key: `"hub"`, a slot button, a medallion, a cast bar. One effect holds a place at a time. The priorities are KSTY-87's table (`Effects.PRIORITY`, lower wins): low health 1; proc, level-up and medallion burst 2; ready flash and cast flash 3; resource cap and target change 4; entering combat 5; leaving combat 6; ambient 9.

| Function | Behaviour |
| --- | --- |
| `Claim(place, priority, stop) -> token \| nil` | Takes the place when it is free or held at an equal or lower priority (the holder's `stop` runs); refuses a lower priority |
| `ClaimFor(place, priority, seconds, stop)` | A claim the layer releases after `seconds` (`C_Timer.After`) |
| `Release(place, token)`, `Stop(place)` | Frees the place; a replaced claim's token frees nothing |
| `Holder(place) -> priority \| nil` | Who holds the place |
| `Ambient(place, start, stop)` | Ambient motion for a place: it runs while the place is free and `Allows("ambient")`, and `stop` pauses it while any effect holds the place |

Who claims what: a proc holds its slot (a ready flash on it yields, and the proc ends a running flash); a ready flash holds its slot for 0.3 s; a cast flash holds its cast bar; a flip-in holds its medallion for 0.18 s and a burst for 1.2 s, pausing the portrait sheen; a proc model and the level-up model hold the hub, pausing the hub's sheen and particles (the rune ring and breathing keep turning, so nothing snaps). Every claim is allocation-free on its combat path (`Tools/regression/perf/`).

## 3D models

`Effects.Model(anchor, key, size, seconds, priority, fallback, place)` plays a model from a pool of at most three ModelScenes. A scene is `MARGIN` (1.6) times the effect's size, so the model never clips, takes its anchor's strata and level + 2 (the hub's `LOW`, so slots stay above it), fades in over 0.1 s and out over 0.3 s, and is then paused (`SetPaused`), cleared and hidden. A full pool evicts its oldest model of the lowest priority when the newcomer's priority is equal or higher, and refuses otherwise. The pool is built on first use, so a reload builds it again. A model plays only at Full; otherwise, when the pool refuses, when `SetModelByFileID` returns false, or when the actor has not loaded 0.5 s later, the caller's 2D twin plays instead. A file that is refused, or misses its load twice, is not tried again this session.

`Effects.Burst(place, priority, anchor, key, size, seconds, play2D, stop2D)` claims the place for `seconds` and plays the model or the 2D twin; it returns `"model"`, `"2d"` or false.

The candidates are referenced by file ID and ship nothing. Each ID was checked against the community listfile (wowdev/wow-listfile, 2026-11-15); the 70862 UI source holds no models, so whether Forever's data has each one is an in-game check.

| Key | File ID | Path in the listfile | Used for |
| --- | --- | --- | --- |
| `levelUp` | 166464 | spells/levelup/levelup.m2 | Level-up rays at the hub |
| `levelUpBlue` | 340883 | spells/levelup_blue.m2 | Spare |
| `SHAMAN` | 534877 | spells/lightning_ring_nova_state.m2 | Shaman proc and burst |
| `HUNTER` | 166027 | spells/enchantments/sparkle_a.m2 | Hunter |
| `MAGE` | 166014 | spells/enchantments/rune_intellect.m2 | Mage |
| `PALADIN` | 166334 | spells/holy_precast_high_base.m2 | Paladin |
| `PRIEST` | 166338 | spells/holy_precast_uber_base.m2 | Priest |
| `WARLOCK` | 166071 | spells/fel_fire_precast_hand.m2 | Warlock |
| `WARRIOR` | 166120 | spells/fire_precast_hand.m2 | Warrior |
| `ROGUE` | 166808 | spells/shadow_precast_med_base.m2 | Rogue |
| `DRUID` | 166604 | spells/nature_precast_chest.m2 | Druid |
| `frost` | 5855149 | spells/11fx_frostswirl01.m2 | Spare |

The APIs, proved in the 70862 source (`Blizzard_APIDocumentationGenerated/`): `ModelScene` `CreateActor`, `SetCameraPosition`, `SetCameraOrientationByYawPitchRoll`, `SetPaused` (FrameAPIModelSceneFrameDocumentation.lua); actor `SetModelByFileID` returning `success`, `IsLoaded`, `ClearModel`, `SetPosition`, `SetUseCenterForOrigin`, `SetAlpha` (FrameAPIModelSceneFrameActorBaseDocumentation.lua). The camera sits 4 yards back on the scene's x axis looking forward, the default orbit camera's frame (Blizzard_SharedXML/Shared/ModelSceneCameras/OrbitCameraMixin.lua).

## The effects M7 owns

| Effect | Trigger (secret status) | What it does | Priority | Level |
| --- | --- | --- | --- | --- |
| Cooldown ready | `OnCooldownDone` on the slot's cooldown, a real cooldown only (IconButton's `WatchCooldown`) | A steel flash (`medReadyFlash`) a third larger than the slot, 0.3 s; Frames keeps its own flash | 3 | flare |
| Resource cap | `UNIT_POWER_UPDATE`, `UNIT_MAXPOWER` (player); `UnitPowerPercent` through a step curve at 99.5% (secret) | The hub's rune glyphs (`medRuneGlyphs`) and a halo in the class colour, alpha from the curve; it breathes at Full. Rage, energy, focus and the like; a mana user tracks holy power (paladin) unless the crest jewels' Glow at max lights the ring for them, and anyone else shows nothing | 4 | state; pulse to breathe |
| Hawk perches | `PLAYER_TOTEM_UPDATE` for totem slots 2 and 3, which hold a hunter's Summon Hawk hawks; the slot's own boolean and duration object (secret in combat) | A summon flares its perch, the timer ring drains over the hawk's life, an expiry fades the gilt hawk to steel, a third summon refreshes the oldest perch, and both hawks out light the rune glyphs and a halo under the hub in hunter green ([ActionBars README](../KstyleUI_ActionBars/README.md#hawk-perches)) | none (its own layers) | flare; pulse to breathe |
| Spirit Poles | `PLAYER_TOTEM_UPDATE` for a shaman's four totem slots; the slot's own boolean and duration object (secret in combat) | A drop flares the element's spire and ignites it from the base (a readable expiry plays neither); the spire's lit steel, rune core and halo drain as timer bars over the totem's life and flicker through the last fifth while readable; an expiry leaves dark steel; a fan unfolds from its socket over 0.12 s; all four up light the rune glyphs and a halo in the class colour, breathing in the cap ring's timing ([ActionBars README](../KstyleUI_ActionBars/README.md#spirit-poles)) Under Frames the spires stand upright in a row beside the tray, with no rune ring. | none (its own layers) | flare (drop, fan); pulse (last-fifth flicker, ring breath) |
| Storm orbs | Blizzard's aura slots on the player, filtered to Lightning Shield's ranks (the charge count, secret in combat); the player's own `UNIT_SPELLCAST_SUCCEEDED` (readable) | Three orbs, one per charge, circle the emblem over steel studs with a storm halo; a cast bursts the crest and ignites them, a strike drains the spent orb and throws a bolt from it, one charge left dims the halo and flickers the last orb, and the halo crackles out when the shield ends ([ActionBars README](../KstyleUI_ActionBars/README.md#storm-orbs)) | none (its own layers) | flare (Off binds `Immediate`); ambient to circle, crackle and flicker |
| Crest trackers | Blizzard's aura slots (player and enemy target) and weapon enchants (durations and presence, secret in combat); `IsSpellUsable` and `GetSpellCooldown`'s never-secret flags; `GetSpellCooldownDuration` duration objects | A warrior's, paladin's or rogue's medals, rim and vials light from their feeds and drain from the engine's durations; a piece flares in its class burst when it lights or a different aura takes its slot (`AddAuraAssignedAnimation`), Enrage's fire burns round the rim ([ActionBars README](../KstyleUI_ActionBars/README.md#melee-crest-trackers)) | none (their own layers) | ambient (flares and fire at Full only; Calm crest at rest holds the fire still) |
| Healer trackers | Blizzard's aura slots on the player and the target (charges and durations, secret in combat), weapon enchant frames, `C_Spell.GetSpellCooldownDuration` objects; the player's own casts, `GetTemporaryEnchantmentInfo`, `GetSpellCooldown().isActive` and `C_Item.GetItemCount` (never secret) | A priest's Inner Fire halo and flames, cooldown medals and Pain gem; a druid's seed medals, Clearcasting leaves and ready gem; a shaman's rune stones, emblem sweep and Reincarnation medal ([ActionBars README](../KstyleUI_ActionBars/README.md#healer-trackers)) | none (its own layers) | flare for bursts; pulse for the last flame's flicker, the stones' gutter and pulse; ambient for the rims' flipbooks and the leaves' unfurl; Calm crest at rest holds them still |
| Crest jewels | `UNIT_POWER_FREQUENT` for the jewel power, combo target changes; one-point status bars fed the value now and the value before (secret) | A gained jewel's core flares, a spent one drains, and at the maximum the rune glyphs and a halo under the hub light in the resource's colour, fading in and out ([ActionBars README](../KstyleUI_ActionBars/README.md#resource-jewels)) | none (its own layers) | flare; pulse to breathe |
| Crown | `UNIT_POWER_FREQUENT` for combo points, `COMBO_TARGET_CHANGED` (a target change shows the count still); one-point status bars fed the count now, before and at the maximum (secret) | The crest's class pieces (a rogue's daggers, a cat-form druid's claws): a gained one slides out under a flare, a spent one slashes and cools to ghost steel, at the maximum a glint runs up every piece; at Full and a known maximum the glints return together after a 3.5 s rest ([ActionBars README](../KstyleUI_ActionBars/README.md#crown)). The unit frames' pip row plays the same fades under Frames and loops nothing | none (its own layers) | flare; pulse to repeat |
| Class crown | The game's aura slots for a warrior's Sunder Armor, a priest's Shadow Weaving, a mage's Arcane Blast, a hunter's Sniper Shot and a bear's Lacerate (application bars, secret) | The crest's fed pieces (banners, candles, shards, arrows, talons): a gained stack lights the piece's glow and sweeps its art up from the base under the bar's `ExponentialEaseOut`, a lost one drains it, the aura going clears them; the maximum lights the rune ring in the class colour, still ([ActionBars README](../KstyleUI_ActionBars/README.md#crown)) Under Frames the player's resource row plays the same fills upright with no ring, a shaman's storm orbs among them, and the full row glows; Off binds `Immediate` there too. | none (its own layers) | flare (Off binds `Immediate`) |
| Cast landed or stopped | The cast bar's own land and finish (`UNIT_SPELLCAST_STOP`, `_INTERRUPTED`, `_FAILED`) | A steel or red wash and a light streak (`medCombatSweep`) run along the bar, clipped to it, 0.25 s | 3 | flare |
| Leave combat | `PLAYER_REGEN_ENABLED`, then 3 s | Target of target, focus, focus target and pet dim to 60% over 0.6 s through Layout's alpha, only where the player left both alphas at 100%; `PLAYER_REGEN_DISABLED` brings them back in 0.24 s | 6 | flare (else at once) |
| Low-health vignette | `UNIT_HEALTH`, `UNIT_MAXHEALTH` (player); `UnitHealthPercent` through a curve, full at 12%, clear from 40% (secret) | `medVignette` stretched over the screen under the whole interface (strata `BACKGROUND`, level 0, on `WorldFrame`), or four soft edges until it lands; hidden while dead | 1 | state; pulse to breathe |
| Medallion burst | `PLAYER_LEVEL_UP` | `medBurst<Class>` behind the player's medallion, 2.2 times its size, growing 0.6 to 1.15 over 1.2 s; the class model at Full | 2 | flare; model |
| Hub proc model | `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` (plain), through M6's `Slab.SetProc` | The class model at the hub, 0.9 s, over M6's 2D pulse | 2 | model |
| Hub level-up model | `PLAYER_LEVEL_UP`, through M6's `Slab.LevelUp` | `levelup.m2` over M6's 2D burst, which always plays | 2 | model |

## Crest medals and sockets

`KstyleUI_ActionBars/SlabMedals.lua` (`ns.SlabMedals`, loaded before the hawks, storm orbs and totems) holds the crest pieces the class trackers share. Positions and sizes are in hub units (the 150-unit ring); `Place` snaps them and makes every part an even number of pixels. A piece's `lits` are its engine-driven layers; Lua never reads or compares what they show.

| Call | What it does |
| --- | --- |
| `Known(spells)` | The first spell in the list the player knows, or nil |
| `Restricted()`, `Locked()` | `Restricted()` is true while auras are secret: call `Engine` only when it is false. `Locked()` adds combat lockdown: build pieces only when it is false (wait for `PLAYER_REGEN_ENABLED`); prepared choices still swap in combat |
| `Round(frame)`, `Texture(parent, layer, sublevel, token, color, units, blend)`, `Layer(holder, level)`, `Even(region)`, `Steps(target, steps, looping)`, `Cloud(parent, token, cell)`, `Flip(texture, token, stretch)` | The parts the hawk perches and storm orbs were built from |
| `Dress(m, cover)` | The Ghost Wolf and Call medals' dressing: shade, round masked `m.icon`, enamel and ring (on `cover` when given) |
| `Seat(name)` | `x, y` of a named seat: `left` and `right` (the shoulders, 75.9 at 24.8 degrees: the study's 65 px out and 30 up at 1080), `top` (96 above, the reliquary), `topGem` (60 above, on the band; not with jewels), `lowerLeft` and `lowerRight` (the band 125 degrees from the top; a hip on the same side overlaps), `leftHip` and `rightHip` (76 at 218 and 322 degrees), `footLeft` and `footRight` (67.5 at 247 and 293 degrees, on the band beside the level plaque; `Medals.FOOT` = 15 is their size, and a medal smaller than `Medals.SIZE` draws its timer ring 2 units out, so a timed foot clears the cooldown band and stays inside the rim). Seat medals draw above the rings |
| `Feed(parent, spec, level)` | The lit layer: an aura slot (`spec.feed = "aura"`, `unit`, `filter`, `spells`; `target`, `focus` and `pet` slots refresh themselves on `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED` and `UNIT_PET`) or a weapon enchant (`"enchant"`, `slot` = `MainHand` or `OffHand`) in its own container, else a plain frame (`"cooldown"`, `"usable"`) |
| `Medal(parent, spec, level)` | A round medal (`spec.size`, default 26) whose steel icon is `spec.texture`; an aura lights it with its own icon, an enchant or cooldown with `spec.texture`; `spec.color` adds a timer ring the engine drains; `"cooldown"` (`spec.spell`) sweeps a dark swipe and flares when ready; `"usable"` (`spec.candidates`, in priority order) lights the first usable spell not on a real cooldown; `spec.newest` shows the most recent matching aura rather than the first; `spec.count` writes the aura's stacks in the corner (`SetApplicationCount`); `spec.pips = n` adds `n` small pips under the medal, one aura slot and application bar each; `"item"` (`spec.items`, in priority order) shows the first item in the bags, greyed under a draining `spec.color` ring (default gilt) while it cools, and an empty setting with no steel icon when the bags hold none (`C_Item.GetItemCount`, `GetItemCooldown`, never secret); with `spec.slot` it shows the item equipped in that inventory slot instead, its cooldown from `GetInventoryItemCooldown` (`Camelot/PaperDollFrame.lua:2196`), ignoring the global cooldown (its fourth return, `CooldownViewer.lua:1017`), a disabled cooldown and secret values; `spec.feeds = { {...}, {...} }` builds one aura layer per entry, each with its own icon and ring, under one shade, steel and cover |
| `Rim(parent, spec, level)` | An aura shown round the inner rim: with `spec.ambient`, a cell of that flipbook that burns at Full and holds still at rest; with `spec.color`, a thin ring 112 across that drains with the aura in the dark between the emblem and the rune band; `spec.burst` flares when it appears |
| `CooldownRim(parent, spec, level)` | Major cooldowns: `spec.families = { { spells = {...}, known = {...}?, unit = "pet"? }, ... }` (buff aura IDs, `HELPFUL`). One container per unit (player first, a pet's refreshed on `UNIT_PET`): its newest aura burns a thin `spec.color` ring 118 across, just outside a rim's ring and flares in `spec.burst`, and a row of up to `spec.max` (default 3) small round icons, newest first, each draining, sits 30 units below the centre (an aura group sorted by `AuraInstanceIDOnly`, `Reverse`). A permanent aura shows steady with no burn. The engine draws each aura's own icon |
| `Beside(piece, anchor, rim, left)` | Anchors a piece, centred on the icon row, at the left or right end of a shown `CooldownRim`'s icon row (to its first or last container, 4 units out), or 4 units either side of the row's place 30 below `anchor`'s centre without one; the containers size themselves, so the piece follows the row with no measurement |
| `Socket(parent, spec, level)` | A jewel setting on the ring whose `spec.color` liquid drains with an aura or enchant, or refills with `"cooldown"` (`spec.spell`) or `"item"` (an item cooldown turned into a duration object with `C_DurationUtil.CreateDuration` and `SetTimeFromStart`, `DurationUtilDocumentation.lua:11`, `LuaDurationObjectAPIDocumentation.lua:445`) and flares when ready |
| `Threat(parent, spec, level)` | A gem whose `spec.color` fill is your threat on the target (`UnitDetailedThreatSituation`'s `scaledPercentage` into `SetValue`) and whose glow lights while you tank it (`isTanking` into `SetAlphaFromBoolean` while secret); `feed = "threat"`, repainted by `Refresh` |
| `Plaque(parent, spec, level)` | A `spec.color` ring round the hub's level plaque; the trackers start it for 5 s on the player's own spell that costs mana (the five-second rule) |
| `Emblem(parent, spec, level)` | A `spec.color` glow over the crest, lit while you tank the target (`feed = "threat"`) |
| `Piece(parent, level, units)`, `Flare(piece, lit, level, token, units)` | The factory every piece is built on (`piece.add(part, units)` registers a part for `Place`) and the flare a lit layer plays when shown |
| `Place(piece, anchor, x, y)` | Seats a piece and sizes its parts |
| `Engine(pieces, on, full)` | Enables or disables every feed and gives the engine the flares (and a rim's fire) while `full`; returns false and changes nothing while auras are secret |
| `Refresh(piece)` | Repaints a `"cooldown"` or `"usable"` piece; call it on `SPELL_UPDATE_COOLDOWN` and `SPELL_UPDATE_USABLE` |
| `Fire(piece)` | Plays a piece's flare at Full |
| `Rest()`, `OnRest(fn)` | `Slab.Resting()` is true while Calm crest at rest settles the hub; when it changes (and on a motion change) `Rest()` holds every rim's fire still or lets it burn and calls each `OnRest` function with `still` |
| `Still(piece, still)` | Holds one rim's fire still or lets it burn |

## Crest trackers

`KstyleUI_ActionBars/SlabTrackers.lua` (`ns.SlabTrackers`) is the one tracker lifecycle for every class. A class file loaded after it registers its rows:

```lua
ns.SlabTrackers.Register("PRIEST", rows, hooks)
```

Each row is one seat, built only while its switch (`key`, a saved ActionBars setting that defaults on) is on and its class knows a spell, on the crest under Medallions and as a medal in a row above the stance bar under Frames.

| Row field | Meaning |
| --- | --- |
| `key` | The Options switch; several rows may share one |
| `seat` | A `Medals.Seat` name, `"rim"` (a `Rim`), `"cooldowns"` (a `CooldownRim`) or `{ x, y }` in hub units |
| `feed`, `unit`, `filter`, `spells`, `slot`, `color`, `ambient`, `size`, `texture` | Passed to the default builder: `Medal`, or on the crest `Rim`, `CooldownRim` or, for `feed = "enchant"`, `Socket` |
| `known` | Spells any one of which the player must know (default `spells`), or `function(row) -> id or nil` for items, talents, a spec or pet state |
| `size` | The piece's size in hub units (17 for the feet) |
| `crestOnly` | No Frames medal for this row |
| `groups` | For `feed = "usable"`: lists of ranks in priority order; the first known rank of each becomes a candidate |
| `families` | For `seat = "cooldowns"`: `{ spells, known?, unit? }` entries; under Frames the player's families feed one medal showing the newest |
| `choices` | Alternatives for the seat, each a partial row inheriting the rest; every known choice is built and fed out of combat, and the first known choice whose `forms` holds `GetShapeshiftFormID()` (any form when `forms` is nil; no form counts as 0) shows while the others hide, on `UPDATE_SHAPESHIFT_FORM`, in combat too; a secret form keeps the last |
| `active(choice)` | On a choice: whether it shows now (a pet out, a buff up); it is built and fed whenever it is known, and `Trackers.Swap()` (call it from a `paint` hook) re-picks the shown choices with no rebuild; while auras are secret a wanted choice not yet built gives way to the row's first built one |
| `build(parent, spec, level, form)` | A custom builder returning a piece with `.parts` (for `Medals.Place`) and `.lit` or `.lits` (for `Medals.Engine`); `form` is `"crest"` or `"row"` |
| `place(piece, anchor, form, x, n)` | Custom placement: `anchor` is the hub on the crest and the row frame under Frames, where `n` is the next free cell and `x` its left offset; return the next free cell (a piece spanning four medals returns `n + 4`; one laid over the whole grid returns `n`). `Medals.Cell(n)` gives a cell's `x, y`: the row is `Medals.LINE` (5) medals of `Medals.SIZE` a line with `Medals.GAP` (4) between, growing upward |

| Hook | Meaning |
| --- | --- |
| `burst` | The class's flare texture token, such as `medBurstWarrior` |
| `events` | Events (or `{ event, unit }`) that call `paint` while a tracker shows |
| `update` | Events that rebuild the seats (`Trackers.Update`), such as `PLAYER_EQUIPMENT_CHANGED` |
| `paint(form, event, ...)` | Repaints class-owned parts; `form.pieces` holds the pieces by `"<row>:<choice>"` |
| `motion(form, full, still)` | Called on each update and when Calm crest at rest or the effects level changes |
| `fiveSecondForms` | `GetShapeshiftFormID` values in which the five-second rule shows (any form when absent) |

Every class's `seat = "cooldowns"` row also gets the shared families: the racial buffs (Blood Fury 20572, Berserking 20554, Stoneform 20594, Perception 20600, Will of the Forsaken 7744 and Forever's 1299026, 1259799, 1259812, 1260270) and the potion buffs (17528, 6615, 3169, 17540, 2379, 11359, 16323). Registering a `seat = "cooldowns"` row also adds two `crestTrinkets` rows (Trinkets on the crest), one per trinket slot (13 and 14), and `PLAYER_EQUIPMENT_CHANGED` to the class's `update` events: a trinket shows only while `C_Item.GetItemSpell` gives its equipped item a use spell (`ItemDocumentation.lua:970-985`, no secret return), as a forged jewel (`Socket`, never an icon: the crest carries effects, not icons) the first slot left of the cooldown icons and the second right (`Beside`), full and lit while ready, emptied and refilling in the class's cooldown colour while it cools and flaring when ready again, and under Frames as an `"item"` medal in the row, greyed under its draining ring while it cools (`BAG_UPDATE_COOLDOWN`, which repaints the character sheet's slots too, `Camelot/PaperDollFrame.lua:2073`). The trinket's buff is not read. Dark Rune and Demonic Rune apply no aura (their spells 27869 and 16666 are mana and damage effects only), so they join the consumables bar rather than these families. Registering a mana class (paladin, priest, druid, shaman, mage, warlock, hunter) adds the `crestFiveSecond` row first: a `Plaque` ring on the crest, a medal under Frames, started on the player's own mana spell (`C_Spell.GetSpellPowerCost`, plain values only). A Lua-fed piece repaints only while it shows and only on its own kind's events. `Trackers.Joined(...)` joins spell lists. Lua-fed pieces repaint on their kind's events: `"cooldown"` on `SPELL_UPDATE_COOLDOWN`; `"usable"` also on `SPELL_UPDATE_USABLE` and `PLAYER_TARGET_CHANGED`; `"item"` on `BAG_UPDATE_DELAYED` and `BAG_UPDATE_COOLDOWN`; `"threat"` on `UNIT_THREAT_LIST_UPDATE`, `UNIT_THREAT_SITUATION_UPDATE` and `PLAYER_TARGET_CHANGED`. `Trackers.Has(key)` tells an Options row whether the player's class registered that switch. Builds wait while `Medals.Locked()` and run on `PLAYER_REGEN_ENABLED`; Lua-fed pieces (`"cooldown"`, `"usable"`) repaint on `SPELL_UPDATE_COOLDOWN`, `SPELL_UPDATE_USABLE` and `PLAYER_TARGET_CHANGED`.

## Ranged crest trackers

`KstyleUI_ActionBars/SlabRanged.lua` registers a hunter's, mage's and warlock's rows with the [tracker lifecycle](#crest-trackers) and holds the builders SlabMedals has none for. Every seat has a choice for each build, pet state and level band; the first known choice shows, every known choice is built out of combat, and a warlock's shoulders and right foot switch on `UNIT_PET` through `active`: the demon medal and Spell Lock are built once a summon is known, so a demon summoned in combat shows at once. None of these classes has a form, stance or tank or healer spec on Forever (their kits for those are runes), so their crests change by talent, pet and level. The file returns at once for any other class, so nothing of it loads there. Every seat is a `Medals.Seat` name, and the foot perches are `Medals.FOOT` across.

| Class | Seat (switch) | Choices, first that applies | Fed by |
| --- | --- | --- | --- |
| Hunter | Top gem (Shot medal) | Counterattack or Mongoose Bite while usable, else Aimed Shot or Multi-Shot when ready (Mongoose Bite 16, Multi-Shot 18) | `C_Spell.IsSpellUsable` and the cooldown's never-secret flags (`Medals.Refresh`) |
| Hunter | Left hip (Aspect medal) | The Aspect up, steel with none (4); before that Raptor Strike's cooldown | Aura slot; the cooldown's duration object |
| Hunter | Right hip (Pet medal) | The pet's portrait, darkening red from the top by its missing health, a happiness rim (none while secret) and a green ring pulsing under Mend Pet, steel with no living pet (10); before that Arcane Shot's cooldown (6) | `UNIT_PET`, `SetPortraitTexture`, `UnitHealthMax` and `UnitHealthMissing` into a status bar, `C_PetInfo.GetPetHappiness`, an aura slot on `"pet"` |
| Hunter | Left foot (Hunter's Mark perch) | Hunter's Mark on the target with its red ring (6) | Aura slot `HARMFUL` on the target |
| Hunter | Right foot (Sting perch) | The newest of your Serpent, Viper, Scorpid or Wyvern Sting, Lacerate or Black Arrow on the target, with its own icon; rests on Serpent Sting (4) | Aura slot `HARMFUL|PLAYER`, newest first |
| Hunter | Inner rim (Auto Shot ring) | A thin ring drained over each Auto Shot or melee swing, amber below 200 shots, red with none | `PLAYER_SWING` into a duration object; `GetInventoryItemCount` on the ammo slot |
| Hunter | Rim (Cooldowns on the crest) | Rapid Fire, Deterrence and the pet's Bestial Wrath | `CooldownRim`, the last on a `"pet"` family |
| Hunter | Ring (Quick Shots gust) | The hunter burst, glyphs and halo and a feathered gust (`trackerGust`) every 1.2 s at Full while Rapid Fire (26), or Quick Shots or Quick Strikes (Deadly Aspects), lasts; the streaks rest at the centre when the gust does not run | Aura slot |
| Mage | Left shoulder (Armor medal) | Frost, Ice or Mage Armor and its time; steel with none | Aura slot |
| Mage | Right shoulder (Mana gem medal) | The best gem, glowing ready, swept while it cools, an empty setting with none (28), a blue glow under 30% mana while it is ready; before that Arcane Intellect or Brilliance and its time | `C_Item.GetItemCount` and `GetItemCooldown`; `UnitPowerPercent` through a step curve into the glow's alpha |
| Mage | Left hip (Counterspell medal) | Counterspell's cooldown, flaring when ready (24); before that Fire Blast's | The cooldown's duration object |
| Mage | Right hip (School medal) | Your Fire Vulnerability on the target (Improved Scorch), else your Winter's Chill (the talent), with their stacks; else Arcane Wrath's cooldown (25); else Frost Nova's | Aura slot `HARMFUL|PLAYER` on the target; cooldowns |
| Mage | Left foot (Frozen perch) | Your Frost Nova or Frostbite on the target (10); before that your Frostbolt's chill | Aura slot `HARMFUL|PLAYER` |
| Mage | Right foot (Spell perch) | Your newest fire damage on the target (Ignite, Pyroblast, Fireball) with Ignite known, else your chill (Frostbolt, Cone of Cold) with Winter's Chill, else your Polymorph | Aura slot `HARMFUL|PLAYER`, newest first |
| Mage | Rim (Cooldowns on the crest) | Arcane Power, Presence of Mind, Combustion, Evocation, Ice Block | `CooldownRim` |
| Mage | Inner rim (Ward ring) | A thin pale frost band (the shared rim ring) drained over Ice Barrier, Mana Shield or a ward (20) | Aura slot |
| Mage | Ring (Clearcasting blaze) | The burst, glyphs and an arcane halo with the frost fire round the rim until the free spell (Arcane Concentration) | Aura slot |
| Warlock | Crown (Torment spires) | Corruption, Bane (Agony from rank 1, Doom, Havoc), Immolate and Siphon Life: sockets 82 units out at 126, 102, 78 and 54 degrees, each with a 34-unit spire burning down in its colour; each stands once known | One container of aura slots `HARMFUL|PLAYER` on the target: three `SetDurationBar` bars and a `SetIcon` per spire, refreshed on a new target |
| Warlock | Left shoulder (Demon medal) | A demon out (or Demonic Sacrifice known): its portrait and missing health, and after a sacrifice the buff's icon with a violet ring; no demon: Demon Skin or Demon Armor and its time | As the pet medal; aura slots |
| Warlock | Right shoulder (Healthstone medal) | The Healthstone, ready, cooling or empty (10); before that, while a demon holds the left, Demon Skin | Bag counts and item cooldowns; aura slot |
| Warlock | Lower left (Weapon stone jewel) | The Spellstone or Firestone on the weapon, draining with it; dark when missing (28) | `AddItemEnchantment(MainHand)` with `SetDurationBar` |
| Warlock | Lower right (Conflagrate jewel) | A jewel refilling over Conflagrate's cooldown, flaring when ready (25) | The cooldown's duration object |
| Warlock | Left foot (Curse perch) | Your Curse on the target: Weakness, Recklessness, Tongues, the Elements or Exhaustion (4) | Aura slot `HARMFUL|PLAYER` |
| Warlock | Right foot (Spell Lock medal) | Your Felhunter's Spell Lock cooldown while one is out; else Death Coil's (42) | `C_SpellBook.IsSpellKnown(id, Pet)`; the cooldown's duration object |
| Warlock | Inner rim (Soul wisps) | One violet wisp (`trackerWisp`) per Soul Shard in the bags, up to five, with the exact count as a number above five, each on a dark shade, flying in and bursting and circling once every 12 s at Full off rest; with five or more the rim keeps a faint violet light. Soul Shards are bag items on Forever, not a power, so no jewel or cap ring reads them | `C_Item.GetItemCount(6265)`, the total across every bag, on `BAG_UPDATE_DELAYED` only |
| Warlock | Rim (Cooldowns on the crest) | Amplify Curse, Fel Domination, Shadow Ward, the Voidwalker's Sacrifice | `CooldownRim` |
| Warlock | Ring (Shadow Trance blaze) | A violet burst and dark-flame halo until the instant Shadow Bolt (Nightfall) | Aura slot |

Under Frames each seat stands in the tracker row above the stance bar: medals and perches as medals, the spires upright over their sockets, the wisps as five pips, the Auto Shot ring as a medal with a sweep, a moment as a faint glow behind the row and the ward as a thin frost bar along its top. Motion: Full plays the flares, the gust, the rim fire, the Mend Pet pulse and the wisp orbit; Calm and Calm crest at rest hold them still, and a shard gained or spent at rest appears or goes without flying; Off shows end states.

Switching every ranged tracker off restores today's crest except for the warlock's five shard jewels, which are gone. They read the `SoulShards` power, which a Forever warlock does not have: Forever's own UI leaves its shard bar out for this client (`Blizzard_UnitFrame.toc:77-78`, `[ExcludeLoadGameType camelot]`), so in the game `UnitPowerMax` gave no jewels, or five that never lit when it was secret. The render harness fakes a shard power, so the base render draws them; with the base's `crestJewels` off, the warlock's all-off crest matches the base at every size. Nothing runs OnUpdate. Tested by `test-actionbars-crest-ranged`; rendered with `RENDER_TRACKERS` and `RENDER_TRACKERS_BUILD` ([render README](../Tools/render/README.md)).

## The primary test character

Lee plays an undead (Forsaken) warlock, so that case is checked first: `hud_warlock_mac` under `RENDER_HUD_STYLE=Medallions` renders the undead warlock bust and crest with the imp out, and every `RENDER_FX` state above renders there too. The tests pin the warlock's effects: Soul Shards are bag items (the soul wisps count them) so the cap ring reads no shard power, a proc runs the fel flipbook (`medProcWarlock`) and the warlock's model (166071) at the hub, the level-up burst is `medBurstWarlock` (the warlock model at Full), and the imp's frame rests after combat while the warlock's own does not (`test-actionbars-medallions-fx`, `test-unitframes-medallions-fx`).

## In-game checks

The render harness cannot draw models or run the client, so five things wait for Lee's single test. Each says what to look for and what happens when it fails; none of them can break the HUD, because every one already has its fallback in code.

1. **PNG filtering at 2:1.** Look at the hub's rune ring and a slot's ready flash at 1920x1080 and 5120x1440. Works: the 1 px edges stay crisp and the glow has no stair steps. Fails (soft or shimmering edges): the textures ship at the size they draw, and M3 redraws the affected ones procedurally (KSTY-87 5.3).
2. **Model file IDs and their frame cost.** Turn Medallions motion to Full, level up or use a spell with a proc (`/run KstyleUI.Effects.Burst("hub", 2, KstyleUI.Effects.playerMedallion, "levelUp", 150, 1.2)` also works). Works: golden level-up rays at the hub and the class model behind the medallion, with `/run print(KstyleUI.Effects.LiveModels())` never above 3 and the frame rate steady. Fails (nothing shows, or a model is huge, tiny or off-centre): the 2D burst plays instead after 0.5 s; tell Capy which class, and the camera distance or the ID changes in one table.
3. **OnCooldownDone in combat.** Use a spell with a cooldown longer than the global cooldown in combat. Works: one steel flash on its slot when it comes back, and none after a plain global cooldown. Fails (no flash in combat): the slot's `readyEffect` stays, and the fix is the cooldown frame's own `SetDrawBling` with `medReadyFlash` as its bling texture.
4. **Curve alpha.** Drop below 40% health, and fill your rage or energy. Works: the red edge grows as health falls (full at 12%) and the hub's ring lights while the resource is full, both with no error. Fails (always on, always off, or a Lua error about a secret): the vignette and ring hide and the effect stays a 2D ring pulse only; tell Capy which.
5. **The Skyborne race file.** Make or log in a Skyborne character of each faction and run `/run print(UnitRace("player"))`. Works: one race file for both (the one-heraldry ruling). Fails (two files): M2 adds the second file's art and `Core/Medallions.lua` maps both to it.
