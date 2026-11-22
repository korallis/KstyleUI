-- test-auras-reminder.lua: the reminder card: a v0.2.8 profile builds nothing; switched on, the card names your first known class buff you lack, refreshes on aura, combat, death and spell changes, hides while auras are secret, takes its text rows, shows in the preview and goes away when off; the flask reminder and the ready check mana warning each work alone, switched on, off, in combat, secret and after bag, power and ready check events.
local A = dofile("Tools/regression/auras_env.lua")
local NAMES = { [1459] = "Arcane Intellect", [23028] = "Arcane Brilliance", [168] = "Frost Armor", [7302] = "Ice Armor", [6117] = "Mage Armor", [428741] = "Molten Armor" }
local saved = { version = 4, profiles = { Default = { Auras = { enabled = true } } }, characters = {} }
local env, K = A.New({ saved = saved, setup = function(e)
	e._known, e._mine, e._dead = { [1459] = true, [168] = true }, {}, false
	e.UnitClass = function() return "Mage", "MAGE" end
	e.UnitIsDeadOrGhost = function() return e._dead end
	e.C_SpellBook = { IsSpellKnown = function(id) return e._known[id] == true end }
	e.C_Spell = e.C_Spell or {}
	e.C_Spell.GetSpellName = function(id) return NAMES[id] end
	e.C_Spell.GetSpellTexture = function(id) return 100000 + id end
	e.C_Secrets.ShouldSpellAuraBeSecret = function() return e._aurasSecret == true end
	e.C_UnitAuras = e.C_UnitAuras or {}
	e.C_UnitAuras.GetAuraDataBySpellName = function(unit, name, filter)
		assert(unit == "player" and filter == "HELPFUL", "the reminder reads your own helpful auras")
		return e._mine[name] and { name = name } or nil
	end
	e._flasks, e._bags, e._zone, e._mana, e._manaMax, e._powerReads = {}, {}, "none", 4000, 4000, 0
	e.C_UnitAuras.GetPlayerAuraBySpellID = function(id) return e._flasks[id] and { spellId = id } or nil end
	e.C_Item = { GetItemCount = function(id) return e._bags[id] or 0 end, GetItemIconByID = function(id) return 200000 + id end,
		GetItemNameByID = function(id) return ({ [13510] = "Flask of the Titans", [13512] = "Flask of Supreme Power" })[id] end }
	e.IsInInstance = function() return e._zone ~= "none", e._zone end
	e.Enum.PowerType = { Mana = 0 }
	e.UnitPowerMax = function(_, kind) assert(kind == 0, "mana is read"); return e._manaMax end
	e.UnitPower = function(_, kind) assert(kind == 0, "mana is read"); e._powerReads = e._powerReads + 1; return e._mana end
end })
env.RunTimers()
local function write(key, value) K.Options.Write("Auras", key, value); env.RunTimers() end
local function aura() env.FireEvent("UNIT_AURA", "player"); env.RunTimers() end
local function card() local element = K.Layout.Element("auras.reminder"); return element and element.frame end

-- A v0.2.8 profile: no card, no element.
assert(K.Store.Module("Auras").reminder.enabled == false, "the reminder starts off")
assert(not K.Layout.Element("auras.reminder"), "an off reminder builds no element")

-- Switched on: the card names the first class buff you know and lack, on its own live element.
write("reminder.enabled", true)
local frame = card()
assert(frame and K.Layout.Live("auras.reminder") and frame:IsShown(), "the card shows on its own element")
assert(frame.text:GetText() == "Missing: Arcane Intellect" and frame.icon:GetTexture() == 101459, "it names Arcane Intellect, got " .. tostring(frame.text:GetText()))

-- Arcane Brilliance counts as Arcane Intellect; the armour comes next, and having every buff hides the card.
env._mine["Arcane Brilliance"] = true
aura()
assert(frame:IsShown() and frame.text:GetText() == "Missing: Frost Armor", "the next missing buff is the armour")
env._mine["Mage Armor"] = true
aura()
assert(not frame:IsShown(), "any armour you have counts, so nothing is missing")
env._mine["Mage Armor"] = nil
aura()
assert(frame:IsShown(), "losing the armour brings the card back")

-- Combat hides it as it starts, and it returns when combat ends.
env.SetCombat(true); env.RunTimers()
assert(not frame:IsShown(), "the card hides as combat starts")
aura()
assert(not frame:IsShown(), "and stays hidden in combat")
env.SetCombat(false); env.FireEvent("PLAYER_REGEN_ENABLED"); env.RunTimers()
assert(frame:IsShown(), "it returns when combat ends")

-- Secret auras, death and unlearned spells hide it.
env._aurasSecret = true
aura()
assert(not frame:IsShown(), "a secret aura answer shows nothing")
env._aurasSecret = false
env._dead = true
env.FireEvent("PLAYER_DEAD"); env.RunTimers()
assert(not frame:IsShown(), "a dead player is not reminded")
env._dead = false
env.FireEvent("PLAYER_ALIVE"); env.RunTimers()
assert(frame:IsShown(), "and is again once alive")
env._known = {}
env.FireEvent("SPELLS_CHANGED"); env.RunTimers()
assert(not frame:IsShown(), "no known buff, no reminder")
env._known = { [1459] = true, [168] = true }
env.FireEvent("SPELLS_CHANGED"); env.RunTimers()
assert(frame:IsShown(), "a learned buff counts again")

-- The text rows apply.
write("reminder.size", 20)
local _, size = frame.text:GetFont()
assert(math.abs(size - 20) < 1, "the text size applies, got " .. tostring(size))
write("reminder.outline", "THICKOUTLINE")
assert(select(3, frame.text:GetFont()) == "THICKOUTLINE", "the outline applies")

-- The preview shows the card while the reminder is on.
local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
parent:SetSize(320, 240)
local preview = K.Options.Preview("Auras")(parent)
preview:Refresh()
assert(preview.reminders[1] and preview.reminders[1]:IsShown() and preview.reminders[1].text:GetText() == "Missing: Arcane Intellect", "the preview shows the card")

-- Switched off: the card and element go away and auras no longer refresh it.
write("reminder.enabled", false)
assert(not frame:IsShown() and not K.Layout.Live("auras.reminder"), "off hides the card and its element")
env._mine = {}
aura()
assert(not frame:IsShown(), "and an aura change does not bring it back")
preview:Refresh()
assert(not preview.reminders[1]:IsShown(), "the preview drops the card")

-- The PR #657 review's probes. Unchanged aura events repaint nothing.
write("reminder.enabled", true)
frame = card()
assert(frame:IsShown() and frame.text:GetText() == "Missing: Arcane Intellect", "on again, the card names Arcane Intellect")
local setText, writes = frame.text.SetText, 0
frame.text.SetText = function(self, ...) writes = writes + 1; return setText(self, ...) end
for _ = 1, 10 do aura() end
frame.text.SetText = nil
assert(writes == 0, "ten unchanged aura events repaint nothing, got " .. writes)

-- A restriction change alone hides and restores the card.
env._aurasSecret = true
env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED"); env.RunTimers()
assert(not frame:IsShown(), "a restriction alone hides the card")
env._aurasSecret = false
env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED"); env.RunTimers()
assert(frame:IsShown(), "lifting it brings the card back")

-- Spells unlearned while the reminder is off are not remembered when it comes back on.
write("reminder.enabled", false)
env._known = {}
env.FireEvent("SPELLS_CHANGED"); env.RunTimers()
write("reminder.enabled", true)
assert(not frame:IsShown(), "no known buff after switching back on, no reminder")
env._known = { [1459] = true, [168] = true }
env.FireEvent("SPELLS_CHANGED"); env.RunTimers()
assert(frame:IsShown(), "learned again, it shows")

-- An equivalent buff whose name cannot be read never reports the buff missing.
NAMES[23028] = nil
env._mine = { ["Arcane Brilliance"] = true, ["Frost Armor"] = true }
env.FireEvent("SPELLS_CHANGED"); env.RunTimers()
assert(not frame:IsShown(), "Arcane Brilliance unreadable: Arcane Intellect is not called missing, got " .. tostring(frame.text:GetText()))
NAMES[23028] = "Arcane Brilliance"
env._mine = {}

-- Every hunter aspect in the installed client's tables counts, Aspect of the Falcon (469145) included.
local ASPECTS = { [13165] = "Aspect of the Hawk", [13163] = "Aspect of the Monkey", [5118] = "Aspect of the Cheetah", [13159] = "Aspect of the Pack",
	[20043] = "Aspect of the Wild", [13161] = "Aspect of the Beast", [415423] = "Aspect of the Viper", [469145] = "Aspect of the Falcon" }
for id, name in pairs(ASPECTS) do NAMES[id] = name end
env.UnitClass = function() return "Hunter", "HUNTER" end
env._known = { [13165] = true, [469145] = true }
env._mine = { ["Aspect of the Falcon"] = true }
env.FireEvent("SPELLS_CHANGED"); env.RunTimers()
assert(not frame:IsShown(), "a hunter in Aspect of the Falcon is not told to cast Hawk")
env._mine = {}
aura()
assert(frame:IsShown() and frame.text:GetText() == "Missing: Aspect of the Hawk", "without an aspect the card names Hawk")

-- The card's icon takes the Medallions socket rim with Match Medallions sockets, as its sibling aura tiles do.
assert(A.W.SameColor(frame.tile.chrome.rim[5], K.Tokens.Color("medSocketRim")), "Medallions: the dark metal rim")
K.Options.Write("Auras", "medallionsIcons", false); env.RunTimers()
assert(A.W.SameColor(frame.tile.chrome.rim[5], K.Tokens.Color("edgeInner")), "the setting off restores the plain rim")
K.Options.Write("Auras", "medallionsIcons", true)
K.Options.Write("HudStyle", "style", "frames"); env.RunTimers()
assert(A.W.SameColor(frame.tile.chrome.rim[5], K.Tokens.Color("edgeInner")), "Frames keeps the plain rim")
K.Options.Write("HudStyle", "style", "medallions"); env.RunTimers()

-- Round 3 defaults: the flask reminder and the mana warning start off.
local s = K.Store.Module("Auras").reminder
assert(s.flasks == false and s.mana == false, "the flask reminder and the mana warning start off")

-- The flask reminder on its own: the class buffs off, the card still builds, and only in a raid.
env.UnitClass = function() return "Mage", "MAGE" end
env._known, env._mine = { [1459] = true }, {}
write("reminder.enabled", false)
assert(not K.Layout.Live("auras.reminder"), "every reminder off: no live element")
write("reminder.flasks", true)
assert(K.Layout.Live("auras.reminder") and not frame:IsShown(), "flasks alone keep the element; outside a raid nothing shows")
env._bags = { [13510] = 3, [13512] = 1 }
env._zone = "party"
env.FireEvent("PLAYER_ENTERING_WORLD"); env.RunTimers()
assert(not frame:IsShown(), "a dungeon is not a raid")
env._zone = "raid"
env.FireEvent("PLAYER_ENTERING_WORLD"); env.RunTimers()
assert(frame:IsShown() and frame.text:GetText() == "Missing: Flask of the Titans (3)" and frame.icon:GetTexture() == 213510, "in a raid the card names the flask you carry, got " .. tostring(frame.text:GetText()))
env._bags[13510] = 2
env.FireEvent("BAG_UPDATE_DELAYED"); env.RunTimers()
assert(frame.text:GetText() == "Missing: Flask of the Titans (2)", "a bag change updates the count")
env._bags[13510] = nil
env.FireEvent("BAG_UPDATE_DELAYED"); env.RunTimers()
assert(frame.text:GetText() == "Missing: Flask of Supreme Power (1)", "the next flask you carry is named")
env._flasks[17627] = true
aura()
assert(not frame:IsShown(), "any flask on you counts, Distilled Wisdom included")
env._flasks = {}
aura()
assert(frame:IsShown(), "the flask fading brings the card back")
setText, writes = frame.text.SetText, 0
frame.text.SetText = function(self, ...) writes = writes + 1; return setText(self, ...) end
for _ = 1, 10 do aura(); env.FireEvent("BAG_UPDATE_DELAYED"); env.RunTimers() end
frame.text.SetText = nil
assert(writes == 0, "unchanged aura and bag events repaint nothing, got " .. writes)
env._aurasSecret = true
aura()
assert(not frame:IsShown(), "a secret flask aura shows nothing")
env._aurasSecret = false
env.SetCombat(true); env.FireEvent("PLAYER_REGEN_DISABLED"); env.RunTimers()
assert(not frame:IsShown(), "combat hides the flask card")
env.SetCombat(false); env.FireEvent("PLAYER_REGEN_ENABLED"); env.RunTimers()
assert(frame:IsShown(), "and it returns after combat")
write("reminder.enabled", true)
assert(frame.text:GetText() == "Missing: Arcane Intellect", "a missing class buff comes before a flask")
write("reminder.enabled", false)
env._bags = {}
env.FireEvent("BAG_UPDATE_DELAYED"); env.RunTimers()
assert(not frame:IsShown(), "no flask in your bags, no card")
env._bags = { [13510] = 3 }
write("reminder.flasks", false)
assert(not frame:IsShown() and not K.Layout.Live("auras.reminder"), "the flask reminder off hides the card and its element")

-- The mana warning on its own: only during a ready check, only under 80 percent, following your mana.
write("reminder.mana", true)
env._mana = 1000
aura()
assert(K.Layout.Live("auras.reminder") and not frame:IsShown(), "no ready check, no warning")
env.FireEvent("READY_CHECK", "Leader", 35); env.RunTimers()
assert(frame:IsShown() and frame.text:GetText() == "Low mana" and frame.icon:GetTexture() == 132794, "a ready check at 25 percent mana warns, got " .. tostring(frame.text:GetText()))
env._mana = 3300
env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA"); env.RunTimers()
assert(not frame:IsShown(), "drinking past 80 percent hides it")
env._mana = 3100
env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA"); env.RunTimers()
assert(frame:IsShown(), "and dropping under 80 percent brings it back")
env._mana = env.Secret(1000)
env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA"); env.RunTimers()
assert(not frame:IsShown(), "secret mana shows nothing")
env._mana = 1000
write("reminder.enabled", true)
assert(frame:IsShown() and frame.text:GetText() == "Low mana", "the mana warning comes before a missing class buff")
write("reminder.enabled", false)
env.FireEvent("READY_CHECK_FINISHED", false); env.RunTimers()
assert(not frame:IsShown(), "the warning ends with the ready check")
local reads = env._powerReads
env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA"); env.RunTimers()
assert(env._powerReads == reads, "after the ready check, power changes do no work")
env._manaMax = 0
env.FireEvent("READY_CHECK", "Leader", 35); env.RunTimers()
assert(not frame:IsShown(), "a class without mana is never warned")
env._manaMax = 4000
env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA"); env.RunTimers()
assert(frame:IsShown(), "and the warning follows the ready check that is still running")
env.SetCombat(true); env.FireEvent("PLAYER_REGEN_DISABLED"); env.RunTimers()
assert(not frame:IsShown(), "combat hides the warning")
env.SetCombat(false); env.FireEvent("PLAYER_REGEN_ENABLED"); env.RunTimers()
write("reminder.mana", false)
assert(not frame:IsShown() and not K.Layout.Live("auras.reminder"), "the warning off hides the card and its element")
reads = env._powerReads
env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA"); env.FireEvent("READY_CHECK", "Leader", 35); env.RunTimers()
assert(env._powerReads == reads and not frame:IsShown(), "off, a ready check reads no mana")
env.FireEvent("READY_CHECK_FINISHED", false); env.RunTimers()

-- The preview shows one sample card for each reminder switched on, and drops each one switched off.
for key, value in pairs({ ["reminder.enabled"] = true, ["reminder.flasks"] = true, ["reminder.mana"] = true }) do write(key, value) end
preview:Refresh()
local texts = {}
for i, each in ipairs(preview.reminders) do texts[i] = each:IsShown() and each.text:GetText() or "-" end
assert(table.concat(texts, "|") == "Low mana|Missing: Arcane Intellect|Missing: Flask of the Titans (3)", "the preview shows all three, got " .. table.concat(texts, "|"))
write("reminder.mana", false); write("reminder.enabled", false)
preview:Refresh()
assert(preview.reminders[1].text:GetText() == "Missing: Flask of the Titans (3)" and not preview.reminders[2]:IsShown() and not preview.reminders[3]:IsShown(), "the preview keeps only the flask card")
write("reminder.flasks", false)
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("test-auras-reminder: ok")
