-- test-tooltips-parity-r1.lua: the EllesmereUI parity round 1 tooltip options keep today's defaults, apply when switched on, refresh on their events and restore when switched off.
local T = dofile("Tools/regression/tooltips_env.lua")
local W = T.W

local s = { player = true, me = false, combat = false, now = 100, ilvl = 71.6, asks = {}, auras = {}, secretAuras = false, open = false }

local function saved(settings)
	return { version = 42, profiles = { Default = { Tooltips = settings } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

local env, K, ns = T.New({ saved = saved({ enabled = true, iconSize = 28, anchor = "fixed", itemID = true }), setup = function(e)
	e.UnitTokenFromGUID = function() return "mouseover" end
	e.UnitIsPlayer = function() return s.player end
	e.UnitIsUnit = function(a, b) return a == b or (b == "player" and s.me) end
	e.UnitGUID = function() return "Player-1-2" end
	e.UnitLevel = function() return 60 end
	e.UnitClass = function() return "Hunter", "HUNTER" end
	e.UnitFactionGroup = function() return "Horde", "Horde" end
	e.GetFactionColor = function() return { GetRGB = function() return 0.9, 0.05, 0.07 end } end
	e.GetCreatureDifficultyColor = function() return { r = 1, g = 0.5, b = 0.25 } end
	e.TOOLTIP_UNIT_LEVEL, e.PLAYER = "Level %s", "Player"
	e.GetTime = function() return s.now end
	e.InCombatLockdown = function() return s.combat end
	e.CanInspect = function() return true end
	e.NotifyInspect = function(unit) s.asks[#s.asks + 1] = unit end
	e.InspectFrame = { IsShown = function() return s.open end }
	e.C_PaperDollInfo = { GetInspectItemLevel = function() return s.ilvl end }
	e.GetAverageItemLevel = function() return 70.4, 66.6 end
	e.C_Secrets = { ShouldAurasBeSecret = function() return s.secretAuras end }
	e.C_UnitAuras = { GetAuraDataByIndex = function(_, i) return s.auras[i] end }
	e.C_Item.GetItemMaxStackSizeByID = function() return 20 end
	e._cvars = { UberTooltips = "1" }
	e.C_CVar = {
		GetCVar = function(name) return e._cvars[name] end,
		GetCVarInfo = function(name) if e._cvars[name] then return e._cvars[name], "1", false, false, false, false, false end end,
		SetCVar = function(name, value) e._cvars[name] = value; return true end,
	}
end })
assert(K.Modules.Enable("Tooltips"), tostring(env._errors[1]))
env.FireEvent("VARIABLES_LOADED")
env.RunTimers()
local tip, Get = env.GameTooltip, ns.Settings.Get

local function write(key, value)
	assert(K.Options.Write("Tooltips", key, value) ~= false, key .. " must write")
	env.RunTimers()
end

local function hover(lines)
	tip:ClearLines()
	tip:SetOwner(env.UIParent, "ANCHOR_NONE")
	for _, text in ipairs(lines or { "Valerin", "Level 60 Hunter (Player)", "Horde" }) do
		tip:AddLine(text)
	end
	T.PostCall(env, tip, { type = env.Enum.TooltipDataType.Unit, guid = "Player-1-2" })
	T.BlizzardShow(tip, true)
	return T.Lines(tip)
end

local function find(lines, label)
	for _, line in ipairs(lines) do
		if line[1] == label then return line[2] end
	end
end

local function item()
	env._items[19019] = { quality = 3, icon = 135499 }
	tip:ClearLines()
	tip:SetOwner(env.UIParent, "ANCHOR_NONE")
	tip:AddLine("Thunderfury")
	T.PostCall(env, tip, { type = env.Enum.TooltipDataType.Item, id = 19019 })
	return T.Lines(tip)
end

local function red(region)
	local r, g, b = region:GetTextColor()
	return W.Near(r, 0.9) and W.Near(g, 0.05) and W.Near(b, 0.07)
end

local function buffs()
	local out = {}
	for _, frame in ipairs({ env.UIParent:GetChildren() }) do
		for _, child in ipairs({ frame:GetChildren() }) do
			if child.texture and child.glow and child:IsShown() then out[#out + 1] = child end
		end
	end
	return out
end

-- Defaults: every new option keeps today's tooltip, and the v0.2.8-shaped profile keeps its choices.
local store = K.Store.Module("Tooltips")
assert(store.iconSize == 28 and Get("anchor") == "fixed" and Get("itemID"), "the old profile's choices survive")
for key, value in pairs({ cursorSide = "ANCHOR_CURSOR_RIGHT", growth = "auto", itemLevel = false, levelColor = false, classLine = false,
	compactLevel = false, factionColor = false, ["buffs.shown"] = false, extraKey = "none", detailed = "game" }) do
	assert(Get(key) == value, key .. " defaults to " .. tostring(value))
end
s.auras = { { icon = 136076 }, { icon = 132212 }, { icon = 132328 } }
local snap = T.Snapshot(env)
local lines = hover()
assert(lines[2][1] == "Level 60 Hunter (Player)" and not find(lines, K.L["Item level"]) and #s.asks == 0, "the default unit tooltip is unchanged and inspects no one")
assert(#buffs() == 0 and env._cvars.UberTooltips == "1", "no buff icons and the game's Detailed tooltips are left alone")
assert(not red(tip._left[3]), "the faction line keeps its colour")
assert(find(item(), K.L["Item ID"]) == "19019", "an ID line shows without a key by default")

-- Item level: the player's own level at once, others from a throttled inspect out of combat, then cached.
write("itemLevel", true)
s.me = true
assert(find(hover(), K.L["Item level"]) == "66" and #s.asks == 0, "your own equipped level, with no inspect")
s.me = false
assert(not find(hover(), K.L["Item level"]) and #s.asks == 1 and s.asks[1] == "mouseover", "another player is inspected")
hover()
assert(#s.asks == 1, "a second hover within the gap asks no more")
env.FireEvent("INSPECT_READY", "Player-9-9")
assert(not find(T.Lines(tip), K.L["Item level"]), "another player's answer adds nothing")
env.FireEvent("INSPECT_READY", "Player-1-2")
assert(find(T.Lines(tip), K.L["Item level"]) == "71", "the answer reaches the open tooltip")
env.FireEvent("INSPECT_READY", "Player-1-2")
lines = hover()
assert(find(lines, K.L["Item level"]) == "71" and #s.asks == 1, "the cached level shows without asking again")
local count = 0
for _, line in ipairs(lines) do count = count + (line[1] == K.L["Item level"] and 1 or 0) end
assert(count == 1, "the level shows once")
s.now = s.now + 400
s.combat = true
hover()
assert(#s.asks == 1, "combat never inspects")
s.combat, s.open = false, true
hover()
assert(#s.asks == 1, "an open inspect window is never disturbed")
s.open = false
s.ilvl = env.Secret(80)
hover()
assert(#s.asks == 2, "a stale level is asked again out of combat")
env.FireEvent("INSPECT_READY", "Player-1-2")
assert(find(T.Lines(tip), K.L["Item level"]) == "71", "a secret answer keeps the last readable level")
s.player = false
assert(not find(hover(), K.L["Item level"]), "creatures get no item level")
s.player = true
write("itemLevel", false)
assert(not find(hover(), K.L["Item level"]), "off removes the line")

-- The level line: each option on its own, then all together, never on a secret or coloured line.
write("compactLevel", true)
assert(hover()[2][1] == "60 Hunter", "compact drops the level word and the player tag")
write("compactLevel", false)
write("levelColor", true)
assert(hover()[2][1] == "Level |cffff8040" .. "60|r Hunter (Player)", "the level reads in its difficulty colour")
write("levelColor", false)
write("classLine", true)
local r, g, b = K.Theme.ClassColor("HUNTER")
local hex = string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
assert(hover()[2][1] == "Level 60 " .. hex .. "Hunter|r (Player)", "the class reads in its class colour")
s.player = false
assert(hover()[2][1] == "Level 60 Hunter (Player)", "a creature's type is never class-coloured")
s.player = true
write("compactLevel", true)
write("levelColor", true)
assert(hover()[2][1] == "|cffff8040" .. "60|r " .. hex .. "Hunter|r", "all three combine")
assert(ns.Logic.LevelLine(env.Secret("Level 60 Hunter (Player)"), "Level ", true) == nil, "a secret level line is left alone")
assert(ns.Logic.LevelLine("Level |cffffffff60|r", "Level ", true) == nil, "so is one Blizzard already coloured")
for _, key in ipairs({ "compactLevel", "levelColor", "classLine" }) do write(key, false) end
assert(hover()[2][1] == "Level 60 Hunter (Player)", "off restores Blizzard's line")

-- Faction colour.
write("factionColor", true)
hover()
assert(red(tip._left[3]), "the Horde line takes its faction colour")
write("factionColor", false)
hover()
assert(not red(tip._left[3]), "off leaves the faction line alone")

-- Unit buffs: icons beside the tooltip, refreshed on aura and combat events, placed once per change.
write("buffs.shown", true)
hover()
local shown = buffs()
assert(#shown == 3, "three buffs, three icons")
assert(W.LastCall(shown[1].texture, "SetTexture")[1] == 136076, "the first buff's icon")
local p1 = { shown[1]:GetPoint(1) }
assert(p1[1] == "TOPLEFT" and p1[3] == "BOTTOMLEFT" and p1[5] < 0, "the default row sits under the tooltip")
local places = #W.Calls(shown[1], "SetPoint")
s.auras = { { icon = 136076 }, { icon = 132212 } }
env.FireEvent("UNIT_AURA", "mouseover")
assert(#buffs() == 2, "a lost buff leaves the row")
assert(#W.Calls(shown[1], "SetPoint") == places, "an aura change does not place the icons again")
env.FireEvent("UNIT_AURA", "party1")
assert(#buffs() == 2, "another unit's auras change nothing")
s.secretAuras = true
env.FireEvent("PLAYER_REGEN_DISABLED")
assert(#buffs() == 0, "secret auras in combat show no icons")
s.secretAuras = false
env.FireEvent("PLAYER_REGEN_ENABLED")
assert(#buffs() == 2, "and they return after combat")
write("buffs.position", "RIGHT")
write("buffs.perRow", 1)
write("buffs.size", 30)
shown = buffs()
local p2 = { shown[2]:GetPoint(1) }
assert(p2[1] == "TOPLEFT" and p2[3] == "TOPRIGHT" and p2[4] > 0 and p2[5] < 0, "one per row on the right: the second sits under the first")
assert(W.Near(shown[1]:GetWidth(), 30, 0.5), "the size applies")
write("buffs.position", "LEFT")
assert(select(1, buffs()[1]:GetPoint(1)) == "TOPRIGHT", "the left side grows away from the tooltip")
write("buffs.position", "TOP")
assert(select(1, buffs()[1]:GetPoint(1)) == "BOTTOMLEFT", "the top side sits above it")
tip:ClearLines()
assert(#buffs() == 0, "a cleared tooltip hides its icons")
env.C_Secrets = nil
s.combat = true
hover()
assert(#buffs() == 0, "without the secrecy predicate combat reads no auras")
s.combat = false
hover()
assert(#buffs() == 2, "and out of combat it does")
write("buffs.shown", false)
assert(#buffs() == 0, "off hides the icons at once")
env.FireEvent("UNIT_AURA", "mouseover")
assert(#buffs() == 0, "and stops following auras")

-- Extra lines key: ID and stack lines only while the key is held.
write("maxStack", true)
write("extraKey", "SHIFT")
lines = item()
assert(not find(lines, K.L["Item ID"]) and not find(lines, K.L["Maximum stack"]), "without Shift the extra lines stay hidden")
env._modifiers.shift = true
lines = item()
assert(find(lines, K.L["Item ID"]) == "19019" and find(lines, K.L["Maximum stack"]) == "20", "holding Shift shows them")
env._modifiers.shift = false
write("extraKey", "none")
assert(find(item(), K.L["Item ID"]) == "19019", "no key shows them always")

-- Position: the cursor side and the anchor's growth.
write("anchor", "cursor")
env.GameTooltip_SetDefaultAnchor(tip, env.UIParent)
assert(tip._anchor[1] == "ANCHOR_CURSOR_RIGHT", "the default cursor side")
write("cursorSide", "ANCHOR_CURSOR_LEFT")
env.GameTooltip_SetDefaultAnchor(tip, env.UIParent)
assert(tip._anchor[1] == "ANCHOR_CURSOR_LEFT", "the chosen cursor side")
write("anchor", "fixed")
env.GameTooltip_SetDefaultAnchor(tip, env.UIParent)
assert(tip:GetPoint(1) == "BOTTOMRIGHT", "the anchor grows up and left by default")
write("growth", "down")
env.GameTooltip_SetDefaultAnchor(tip, env.UIParent)
assert(tip:GetPoint(1) == "TOPRIGHT", "Down hangs the tooltip from the anchor")
write("growth", "auto")
env.GameTooltip_SetDefaultAnchor(tip, env.UIParent)
assert(tip:GetPoint(1) == "BOTTOMRIGHT", "Automatic restores it")

-- Detailed tooltips: written on choice, restored to the player's value on Game setting and on Disable.
write("detailed", "off")
assert(env._cvars.UberTooltips == "0" and K.Store.Account().tooltipsDetailed.original == "1", "Off writes the CVar and remembers the player's value")
write("detailed", "game")
assert(env._cvars.UberTooltips == "1" and K.Store.Account().tooltipsDetailed == nil, "Game setting puts it back")
write("detailed", "off")
env._cvars.UberTooltips = "1"
write("detailed", "game")
assert(env._cvars.UberTooltips == "1", "a value the player set since stays")
write("detailed", "off")

-- The preview reflects each new option.
local preview = K.Options.Preview("Tooltips")(env.CreateFrame("Frame", nil, K.Scale.Root()))
write("compactLevel", true)
write("factionColor", true)
write("itemLevel", true)
write("buffs.shown", true)
preview:Refresh()
local rows = preview.unit.rows
assert(rows[3].left:GetText() == "60 Hunter" and rows[4].left:IsShown() and rows[7].left:IsShown(), "compact level, faction and item level in the preview")
assert(red(rows[4].left), "the sample faction line takes the faction colour")
assert(#preview.buffs == 5 and preview.buffs[1]:IsShown(), "the sample buffs show")
for _, key in ipairs({ "compactLevel", "factionColor", "itemLevel", "buffs.shown" }) do write(key, false) end
preview:Refresh()
assert(rows[3].left:GetText() == "Level 60 Hunter (Player)" and not rows[4].left:IsShown() and not rows[7].left:IsShown() and not preview.buffs[1]:IsShown(), "off restores the sample")

T.Check(env, snap)
K.Modules.Disable("Tooltips")
assert(env._cvars.UberTooltips == "1", "turning the module off puts the player's Detailed tooltips back")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("test-tooltips-parity-r1: ok")
