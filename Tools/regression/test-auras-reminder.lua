-- test-auras-reminder.lua: the missing buff reminder: a v0.2.8 profile builds nothing; switched on, the card names your first known class buff you lack, refreshes on aura, combat, death and spell changes, hides while auras are secret, takes its text rows, shows in the preview and goes away when off.
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
assert(preview.reminder and preview.reminder:IsShown() and preview.reminder.text:GetText() == "Missing: Arcane Intellect", "the preview shows the card")

-- Switched off: the card and element go away and auras no longer refresh it.
write("reminder.enabled", false)
assert(not frame:IsShown() and not K.Layout.Live("auras.reminder"), "off hides the card and its element")
env._mine = {}
aura()
assert(not frame:IsShown(), "and an aura change does not bring it back")
preview:Refresh()
assert(not preview.reminder:IsShown(), "the preview drops the card")

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
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("test-auras-reminder: ok")
