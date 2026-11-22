# Medallions effects layer

The effects layer is the part of the Medallions HUD style (KSTY-87 section 6, KSTY-88, M7) that every Medallions effect runs through. It decides how much may move, which effect owns a place on screen, and when a 3D model may play. Every effect is an AnimationGroup, a flipbook or an engine curve: nothing visual runs Lua per frame. Nothing here runs under Frames or Orbs.

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
| Cooldown ready | `OnCooldownDone` on the slot's cooldown, a real cooldown only (IconButton's `WatchCooldown`) | A steel flash (`medReadyFlash`) a third larger than the slot, 0.3 s; Frames and Orbs keep their own flash | 3 | flare |
| Resource cap | `UNIT_POWER_UPDATE`, `UNIT_MAXPOWER` (player); `UnitPowerPercent` through a step curve at 99.5% (secret) | The hub's rune glyphs (`medRuneGlyphs`) and a halo in the class colour, alpha from the curve; it breathes at Full. Rage, energy, focus and the like; a mana user tracks holy power (paladin) or soul shards (warlock) unless the crest jewels' Glow at max lights the ring for them, and anyone else shows nothing | 4 | state; pulse to breathe |
| Hawk perches | `PLAYER_TOTEM_UPDATE` for totem slots 2 and 3, which hold a hunter's Summon Hawk hawks; the slot's own boolean and duration object (secret in combat) | A summon flares its perch, the timer ring drains over the hawk's life, an expiry fades the gilt hawk to steel, a third summon refreshes the oldest perch, and both hawks out light the rune glyphs and a halo under the hub in hunter green ([ActionBars README](../KstyleUI_ActionBars/README.md#hawk-perches)) | none (its own layers) | flare; pulse to breathe |
| Spirit Poles | `PLAYER_TOTEM_UPDATE` for a shaman's four totem slots; the slot's own boolean and duration object (secret in combat) | A drop flares the element's spire and ignites it from the base (a readable expiry plays neither); the spire's lit steel, rune core and halo drain as timer bars over the totem's life; an expiry leaves dark steel ([ActionBars README](../KstyleUI_ActionBars/README.md#spirit-poles)) | none (its own layers) | flare |
| Crest jewels | `UNIT_POWER_FREQUENT` for the jewel power, combo target changes; one-point status bars fed the value now and the value before (secret) | A gained jewel's core flares, a spent one drains, and at the maximum the rune glyphs and a halo under the hub light in the resource's colour, fading in and out ([ActionBars README](../KstyleUI_ActionBars/README.md#resource-jewels)) | none (its own layers) | flare; pulse to breathe |
| Crown | `UNIT_POWER_FREQUENT` for combo points, `COMBO_TARGET_CHANGED` (a target change shows the count still); one-point status bars fed the count now, before and at the maximum (secret) | The crest's class pieces (a rogue's daggers, a cat-form druid's claws): a gained one slides out under a flare, a spent one slashes and cools to ghost steel, at the maximum a glint runs up every piece; at Full and a known maximum the glints return together after a 3.5 s rest ([ActionBars README](../KstyleUI_ActionBars/README.md#crown)). The unit frames' row plays the same fades under Frames and Orbs, which loop nothing | none (its own layers) | flare; pulse to repeat |
| Class crown | The game's aura slots for a warrior's Sunder Armor, a priest's Shadow Weaving, a mage's Arcane Blast, a hunter's Sniper Shot and a bear's Lacerate (application bars, secret) | The crest's fed pieces (banners, candles, shards, arrows, talons): a gained stack lights the piece's glow and sweeps its art up from the base under the bar's `ExponentialEaseOut`, a lost one drains it, the aura going clears them; the maximum lights the rune ring in the class colour, still ([ActionBars README](../KstyleUI_ActionBars/README.md#crown)) | none (its own layers) | flare (Off binds `Immediate`) |
| Cast landed or stopped | The cast bar's own land and finish (`UNIT_SPELLCAST_STOP`, `_INTERRUPTED`, `_FAILED`) | A steel or red wash and a light streak (`medCombatSweep`) run along the bar, clipped to it, 0.25 s | 3 | flare |
| Leave combat | `PLAYER_REGEN_ENABLED`, then 3 s | Target of target, focus, focus target and pet dim to 60% over 0.6 s through Layout's alpha, only where the player left both alphas at 100%; `PLAYER_REGEN_DISABLED` brings them back in 0.24 s | 6 | flare (else at once) |
| Low-health vignette | `UNIT_HEALTH`, `UNIT_MAXHEALTH` (player); `UnitHealthPercent` through a curve, full at 12%, clear from 40% (secret) | `medVignette` stretched over the screen under the whole interface (strata `BACKGROUND`, level 0, on `WorldFrame`), or four soft edges until it lands; hidden while dead | 1 | state; pulse to breathe |
| Medallion burst | `PLAYER_LEVEL_UP` | `medBurst<Class>` behind the player's medallion, 2.2 times its size, growing 0.6 to 1.15 over 1.2 s; the class model at Full | 2 | flare; model |
| Hub proc model | `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` (plain), through M6's `Slab.SetProc` | The class model at the hub, 0.9 s, over M6's 2D pulse | 2 | model |
| Hub level-up model | `PLAYER_LEVEL_UP`, through M6's `Slab.LevelUp` | `levelup.m2` over M6's 2D burst, which always plays | 2 | model |

## The primary test character

Lee plays an undead (Forsaken) warlock, so that case is checked first: `hud_warlock_mac` renders the undead warlock bust and crest with the imp out, and every `RENDER_FX` state above renders there too. The tests pin the warlock's effects: the hub ring follows soul shards rather than mana, a proc runs the fel flipbook (`medProcWarlock`) and the warlock's model (166071) at the hub, the level-up burst is `medBurstWarlock` (the warlock model at Full), and the imp's frame rests after combat while the warlock's own does not (`test-actionbars-medallions-fx`, `test-unitframes-medallions-fx`).

## In-game checks

The render harness cannot draw models or run the client, so five things wait for Lee's single test. Each says what to look for and what happens when it fails; none of them can break the HUD, because every one already has its fallback in code.

1. **PNG filtering at 2:1.** Look at the hub's rune ring and a slot's ready flash at 1920x1080 and 5120x1440. Works: the 1 px edges stay crisp and the glow has no stair steps. Fails (soft or shimmering edges): the textures ship at the size they draw, and M3 redraws the affected ones procedurally (KSTY-87 5.3).
2. **Model file IDs and their frame cost.** Turn Medallions motion to Full, level up or use a spell with a proc (`/run KstyleUI.Effects.Burst("hub", 2, KstyleUI.Effects.playerMedallion, "levelUp", 150, 1.2)` also works). Works: golden level-up rays at the hub and the class model behind the medallion, with `/run print(KstyleUI.Effects.LiveModels())` never above 3 and the frame rate steady. Fails (nothing shows, or a model is huge, tiny or off-centre): the 2D burst plays instead after 0.5 s; tell Capy which class, and the camera distance or the ID changes in one table.
3. **OnCooldownDone in combat.** Use a spell with a cooldown longer than the global cooldown in combat. Works: one steel flash on its slot when it comes back, and none after a plain global cooldown. Fails (no flash in combat): the slot's `readyEffect` stays, and the fix is the cooldown frame's own `SetDrawBling` with `medReadyFlash` as its bling texture.
4. **Curve alpha.** Drop below 40% health, and fill your rage or energy. Works: the red edge grows as health falls (full at 12%) and the hub's ring lights while the resource is full, both with no error. Fails (always on, always off, or a Lua error about a secret): the vignette and ring hide and the effect stays a 2D ring pulse only; tell Capy which.
5. **The Skyborne race file.** Make or log in a Skyborne character of each faction and run `/run print(UnitRace("player"))`. Works: one race file for both (the one-heraldry ruling). Fails (two files): M2 adds the second file's art and `Core/Medallions.lua` maps both to it.
