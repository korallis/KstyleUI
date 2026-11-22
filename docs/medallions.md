# Medallions art pipeline

The unit and party rims are original procedural art, generated with `python Tools/media/medallions_kit.py chrome --only Ring128`. The shared `medRing` registration keeps the legacy `Ring128.png` filename; the image is now 256x256 so the 86-unit player and target rims have enough texels at 5120x1440 and on Retina. Twenty angular invented glyphs have dark engraved cuts and a lit lower lip inside the existing eight-unit steel band. The same asset scales down for pets and party badges, without extra texture layers or animation. The separate `medRuneRing` remains the crest hub's turning rune band. Target-of-target and focus-target remain the existing mini slabs without medallions.

`Tools/regression/test-medallions-rune-rim.lua` checks every procedural chrome file against the texture registry, opens the registered PNGs, checks the rim's resolution and exercises unit and party draws. A generated chrome file without a registration fails with the instruction to register it in `Core/Tokens.lua`.

`Tools/medallions/` makes the Medallions HUD's painted art: a bust and a badge for each of the 104 race, class and sex combinations, and a crest for each of the 52 race and class combinations (KSTY-87 section 5, KSTY-88 section 2). It is modelled on `Tools/icons/iconset.py`: a committed prompts table, generation with the Higgsfield CLI, a scripted judge, a by-eye review on contact sheets, and provenance for every file.

| File | What it holds |
| --- | --- |
| `tables.py` | The prompts table: the race and class matrix, the fixed text blocks, the race, class and sex lines, and the prompt builders |
| `imaging.py` | The judge's measurements, the clean and bake steps and the contact sheets, in Pillow only |
| `medallions.py` | The command line: plan, anchors, generate, judge, accept, reject, adopt, bake, sheets, status, verify |
| `anchors.json`, `anchors/` | The locked references: job ids, the originals' SHA-256 and prompts, and a 512 px copy of each |
| `manifest.json` | One entry per shipped file: its prompt, settings, references, job, judge measurements and SHA-256 |

## Keys and files

Keys are the game's own tokens, lowercased: the race file UnitRace returns, the class file UnitClass returns, and `male` or `female`. A portrait key is `<race>_<class>_<sex>` (`nightelf_priest_female`), a crest key `<race>_<class>` (`troll_shaman`). The undead race file is `scourge`. Prompts describe each people in plain fantasy words (a mountain dwarf, a bull-headed minotaur) and never use the setting's own names: `tables.BANNED_WORDS` lists the words a test and `verify` keep out of every prompt. A locked anchor sent before the table was reworded lists the words it carried in `historicalWords` (the Skyborne master); it is never sent again.

| Kind | Shipped file | Size |
| --- | --- | --- |
| Bust | `Media/Textures/Medallions/Busts/<key>.png` | 128x128, pre-circled |
| Badge | `Media/Textures/Medallions/Badges/<key>.png` | 64x64, pre-circled |
| Crest | `Media/Textures/Medallions/Crests/<key>.png`, `<key>_glow.png`, `<key>_metal.png` | 256x256 |

`bake` writes `Core/MedallionAssets.lua`, which sets `KstyleUI.MedallionAssets`:

```lua
MedallionAssets.portraits[raceFile][classFile][sex] = { bust = path, badge = path }
MedallionAssets.crests[raceFile][classFile] = { crest = path, glow = path, metal = path }
```

`raceFile` and `classFile` are what UnitRace and UnitClass return as their second value (`NightElf`, `WARRIOR`), and `sex` is UnitSex's number (2 or 3). A combination without art is absent. The glow and metal masks are white with the mask in alpha, for the crest's bloom and sheen.

## The recipe

- **Anchors.** The portrait finish is KSTY-87's dwarf shaman bust and the badge style its undead paladin badge; the crest style is KSTY-88's dwarf shaman crest, and each race has one race master (KSTY-88's Latin square: each race and each class once). Lee approved them on 2026-11-15. `medallions.py anchors` downloads each original, checks it against its SHA-256 and writes the 512 px copy; nothing is generated.
- **Busts** use the anchor's style block, a reference line and one character sentence from the race, sex and class lines, with the portrait anchor as the reference (high quality, 1k, 1.5 credits).
- **Badges** reference their own accepted bust and the badge style anchor, with one fixed prompt (1.5 credits).
- **Crests.** The other 43 crests are edits of their race master: keep the frame, replace the centre emblem (xhigh quality, 1k, transparent background, 2.5 credits). A locked master is never regenerated.

## The judge

Each image is measured at 256 px: a bust against the committed portrait anchor copy, a badge against its own accepted bust, a crest edit against its race master's copy. A rejected image is rerolled with the same prompt. An asset is exhausted after three images, or after two jobs that ended without an image (`MAX_IMAGES`, `MAX_FAILURES`); `reject` opens a new window of three. A rate limit that lasts through 40 waits, or the run's credit cap, records nothing and leaves the asset for the next run. If the judge itself fails on a paid image, the image is kept and not rerolled: fix the cause and run `judge`, or decide by eye. Every threshold was set so that the art Lee approved passes; `imaging.py` holds the values.

| Check | Rule | Calibration |
| --- | --- | --- |
| Centring | The subject's centre within 8 % of the image centre across, and of the anchor's height down | Approved busts and badges: within 4.7 % |
| Background | The ring above the head darker than luma 60 | Approved: 12 to 56. The KSTY-87 sky-elf probe reads 83 and is rejected |
| Drift (bust) | Disc luminance and saturation within 25 % of the portrait anchor | KSTY-87 proposed 15 %, which rejects the approved bull-folk druid (saturation 22 %). The sky-elf probe drifts 62 % |
| Drift (badge) | Luminance within 25 % and saturation within 50 % of its own bust | Approved badges: 2 to 5 % and 13 to 26 %. M1's first four badges drifted 37 to 48 % in saturation and looked right on the contact sheet: the flat cut is bolder in colour by design |
| Readable at 24 px (badge) | Luma spread in the disc at least 40, and the face at least 15 brighter than its ring | Approved badges: 63 to 76 and 23 to 90; busts at 24 px: 49 to 51 and -7 to 4 |
| Crest placement | Transparent corners, the crest centred within 8 %, filling 60 to 100 % of the canvas | All nine race masters pass |
| Crest edit | Silhouette IoU with its master at least 0.93, the frame band's mean difference at most 0.12 and its luminance within 20 %, the emblem changing at least 5 % of the field, and its glow within 40 degrees of the class hue (a white glow for priest) | KSTY-88's two edits: IoU 0.99, frame 0.06 and 0.09, hues 20 and 214. An edit compared with another race's master: IoU 0.85 and 0.86, frame 0.24 and 0.34 |

A race master's emblem colour is checked by eye on the contact sheet, since only an edit has a master to tell the emblem from the frame. `sheets --out DIR` bakes every image at the sizes it is shown at (busts 128 to 32 px, badges 64 to 18 px, crests 256 to 64 px) with its verdict; `accept` and `reject` record what the reviewer decided, and the provenance row says so.

## Bake

Portraits are reduced in linear light with premultiplied alpha and Lanczos, given a light unsharp, cut to a disc drawn at 8x and box-filtered, and given a 1 px dark rim on the disc's edge. Crests have alpha below 14 cut to nothing, are trimmed and refitted so the longest side is 900/1024 of the canvas, reduced the same way, and given a 1 px dark outline just outside the silhouette. Every edge is drawn at the shipped size rather than kept from the generated art (KSTY-87's lesson).

The hub draws the original 256 px crest canvas at up to 150 units, over a 118-unit socket inside its 150-unit ring. A circular OrbMask, fixed to the hub at the 118-unit opening, clips the crest and bloom before they reach the ring. The sheen and combat-entry flash use that opening too, each clipped independently of animation. The crest keeps full colour and alpha through rest and combat repaints. The draw size caps the crest (including its pulse) and bloom below 256 physical pixels, leaving one pixel for snapping. On 4K the crest is slightly smaller within the opening so its texture stays at its native resolution. The shipped PNGs are staging's original bakes, byte-for-byte. `test-actionbars-medallions-opening.lua` checks both axes, centring, masks, effects, caps and brightness; `test_medallions_hub_clip.py` reads all 52 crest and glow PNGs and proves their masked alpha stays inside the opening, including the crest pulse.

## Where the shipped prompts came from

M2 (KSTY-92) generated the bulk set before `tables.py` landed, from its own prompt table built on KSTY-87 and KSTY-88's text: the 100 busts it painted and the 39 crest edits outside M1's proof set use those prompts, and the badges use `tables.BADGE_PROMPT`. The manifest records the exact prompt, references and job of every shipped file, so it, not `prompt_for()`, is the provenance of the shipped art. A reroll runs `generate`, which uses `tables.py`'s prompts; the judge then holds the new image to the same anchors.

## Running it

```sh
PY=~/.local/share/wow-dev/venv/bin/python
$PY Tools/medallions/medallions.py anchors
$PY Tools/medallions/medallions.py plan --kind bust
$PY Tools/medallions/medallions.py generate --kind bust --all --max-credits 200
$PY Tools/medallions/medallions.py generate --kind badge --all --max-credits 200
$PY Tools/medallions/medallions.py generate --kind crest --all --max-credits 150
$PY Tools/medallions/medallions.py sheets --out ~/.capy/work/<code>/sheets
$PY Tools/medallions/medallions.py bake
$PY Tools/medallions/medallions.py verify --complete
```

`generate` needs the Higgsfield CLI signed in and the anchor copies in place: it builds every asset's judge before it spends anything. It never spends more than `--max-credits` in one run and prints the balance before and after. Raw images and records live in `~/.local/share/wow-dev/medallions/raw` (`MEDALLIONS_RAW` overrides it), so a rerun picks up where it stopped. `adopt` records an image another thread generated, with its job id, prompt and references, and judges it like any other. `Tools/tests/test_medallions.py` runs `verify` on the repository.
