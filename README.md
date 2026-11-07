# KstyleUI

A complete UI overhaul for **World of Warcraft: Forever** (TOC `16001`, game type `camelot`).
It aims for the polish of Narcissus, WaypointUI and DialogueUI: modern, elegant and animated,
with one art direction across every window.

KstyleUI targets the Forever client only.

## Status

KstyleUI is in early development. It has no release yet.

| Folder | What it holds |
| --- | --- |
| `docs/` | The design spec, the implementation plans and the mockups |
| `Tools/` | Checks, tests and developer scripts. They never ship. |
| `research_notes/` | Notes on Forever's API, its addon restrictions, existing UI suites, visual techniques and tooling |
| `reports/` | The combined research report |

## Install

1. Download the latest zip from the [Releases page](https://github.com/korallis/KstyleUI/releases).
2. Unzip it into `World of Warcraft/_forever_/Interface/AddOns`. Each folder in the zip becomes one addon folder there.
3. Restart the game, then enable KstyleUI in the AddOns list.

## Develop

Read [`AGENTS.md`](AGENTS.md) for the branch flow, the commands to run before every push and the repository rules.

## Licence

All rights reserved. See [`LICENSE.md`](LICENSE.md).
