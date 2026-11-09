# KstyleUI_QoL

Small quality-of-life helpers: faster auto loot, auto repair, quest hand-ins, the farthest camera and quiet error text.

| Field | Value |
| --- | --- |
| Module name | `QoL`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Behaviour only; it draws nothing |
| Loads | With the core addon, switched off until the player turns it on. The first-run setup turns it on, and migration 5 turns it on for profiles that finished the setup before the module existed |
| Files | `KstyleUI_QoL.toc` lists `QoL.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Why

The owner asked for the everyday helpers Leatrix Plus is known for, built the KstyleUI way: one switch each, help text in every language, and nothing that fights the game. Leatrix Plus is inspiration only. No code was copied, ported or paraphrased; each helper comes from what the feature does and from Blizzard's own UI source for the Forever build.

## Helpers

| Setting | Default | What it does | API and evidence |
| --- | --- | --- | --- |
| Faster auto loot | On | When the game auto loots, takes every unlocked slot at once, last first, on `LOOT_READY` | `LOOT_READY(autoloot)` in `LootDocumentation.lua`. When the payload is missing or secret, the game's `autoLootDefault` CVar and the `AUTOLOOTTOGGLE` modified click decide, as `Blizzard_HUDInventoryButton.lua` reads them. A locked slot (an open roll) is left alone, and a bind-on-pickup item still shows the game's own confirm. |
| Repair by itself | On | Repairs everything at a repair merchant and prints the cost | `CanMerchantRepair`, `GetRepairAllCost`, `RepairAllItems` as `MerchantFrame.lua` and `.xml` (Mainline, which Forever loads) use them |
| Guild funds first | Off | Pays from the guild bank when the rank can repair and the guild covers the whole bill, else from the player | `CanGuildBankRepair`, `GetGuildBankWithdrawMoney` (`-1` means no limit), `GetGuildBankMoney`, as the guild repair button's tooltip reads them |
| Accept and turn in quests | Off | Accepts quest offers, hands in finished quests, and picks a finished or new quest from a greeting or gossip window | `QuestFrame.lua` (Mainline): `AcceptQuest`, `AcknowledgeAutoAcceptQuest`, `CompleteQuest`, `GetQuestReward`; `C_GossipInfo` in `GossipInfoDocumentation.lua`. It leaves PvP quests (`QuestFlagsPVP`), a choice of rewards, turn-ins that cost money, item-started and area-trigger quests (Blizzard's own pop-ups), adventure map quests, and grey or ignored quests to the player |
| Pause key | Shift | Holding it while a quest window opens does nothing for that window | `IsShiftKeyDown`, `IsControlKeyDown`, `IsAltKeyDown` |
| Max camera distance | On | Sets `cameraDistanceMaxZoomFactor` to 2, out of combat | Forever's own slider for this CVar runs from 1.0 to 2.0 (`Blizzard_SettingsDefinitions_Frame/Camelot/ControlsOverrides.lua`), so 2 is the game's maximum, not a value past it |
| Quiet error text | Off | Hides the red cooldown, range and out-of-resource errors | Retail's `UIErrorsFrame.lua` never shows these types. Forever's `UIErrorsFrameOverrides.lua` replaces that list with one type, so Forever shows them all. The helper hides the Retail list through `UIErrorsFrame:SetMessageTypeEnabled`, Blizzard's own switch, and shows again only the types it hid. Quest progress and other yellow messages are not touched. |

Selling junk is one feature, in Bags: **Sell junk by itself** on the Bags page, on by default since 2026-11-09. The QoL page carries a note that points there instead of a second switch.

## Rules

- Never loot, repair, accept or turn in anything the game asks the player to confirm: a PvP quest, a reward choice, a turn-in that costs money, a bind-on-pickup item.
- Never compare a secret. Every value the helpers test goes through `ns.True` or `ns.Number`, which treat a secret as "no".
- The camera CVar is written only out of combat, through `KstyleUI.Combat.Queue`, and only once the character's CVars have loaded (`VARIABLES_LOADED`, or `KstyleUI.CVars.Loaded()` when the module starts later). Before that the CVar can read a stand-in value, and taking it as the player's would lose their own. The player's value is kept per character in the account table `qolCamera`, as `{ original, written }`. Turning the helper or the module off puts it back when the CVar still holds what KstyleUI wrote; `Core/CVars.lua` does the same at login on a character whose QoL module is off.
- At load the module only registers itself. It registers events only in `Enable`, and installs no hooks and no frames.

## Not built

- **Hiding the talking head.** `TalkingHeadFrame` loads on Forever, but it is an Edit Mode system frame, and closing it from addon code would write its fields. That needs a taint check in the client first.
- **Hiding the level-up banner and zone text.** They are rare, carry information, and are not the screen-filling spam the owner described.

## Files

`QoL.xml` loads them in this order.

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table, the log, and the secret-safe reads `ns.True` and `ns.Number` |
| `Settings.lua` | The defaults, the settings schema and checked setting reads (`ns.Get`) |
| `Loot.lua` | Faster auto loot |
| `Repair.lua` | Auto repair |
| `Quests.lua` | Quest accept and turn-in |
| `Camera.lua` | Max camera distance and its per-character memory |
| `Alerts.lua` | Quiet error text |
| `Module.lua` | The module's registration, `Enable` and `Disable`, and the event routing the parts share |

## Tests

`test-qol.lua` (settings, setup, settings window, migration 5), `test-qol-loot.lua`, `test-qol-repair.lua`, `test-qol-quests.lua`, `test-qol-camera.lua` and `test-qol-alerts.lua`, on the stand-ins in `Tools/regression/qol_env.lua`.
