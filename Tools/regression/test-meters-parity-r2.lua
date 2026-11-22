-- test-meters-parity-r2.lua: English number units, a second damage window and reports to chat: defaults keep today's card, each option works switched on, follows its events and restores when off.
local M = dofile("Tools/regression/meters_env.lua")
local G = dofile("Tools/regression/geometry.lua")

local function Party(e)
	e._group = { raid = false, size = 5 }
	e._units.player.guid = "Player-3"
	e.LE_PARTY_CATEGORY_HOME, e.LE_PARTY_CATEGORY_INSTANCE = 1, 2
	e.IsInGroup = function(category)
		if category == 2 then return e._instance == true end
		return e._group.size > 0
	end
end
local env, K, ns = M.New({ width = 1920, height = 1080, game = Party,
	saved = { version = 42, profiles = { Default = { Meters = { enabled = true, followRole = false, damage = { shown = true, mode = "window" } } } }, characters = {} } })
local sources, spells = {}, {}
for i = 1, 5 do
	sources[i] = { name = "Player " .. i, classFilename = "WARRIOR", totalAmount = 62345 - i * 10000, amountPerSecond = 6234.5 - i * 1000,
		sourceGUID = "Player-" .. i, sourceDisplayType = 1, isLocalPlayer = i == 3 }
	spells[i] = { spellID = i, totalAmount = 62345 - i * 10000, amountPerSecond = 6234.5 - i * 1000 }
	env._spells[i] = { name = "Spell " .. i, icon = i }
end
env._session = { combatSources = sources, maxAmount = 52345, totalAmount = 161725, durationSeconds = 10 }
env._sources["Player-1"] = { combatSpells = spells, maxAmount = 52345, totalAmount = 161725 }
local types = {}
local fromType = env.C_DamageMeter.GetCombatSessionFromType
env.C_DamageMeter.GetCombatSessionFromType = function(session, meter) types[#types + 1] = meter; return fromType(session, meter) end
M.Enable(env, K); env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED"); env.RunTimers()
local list, root = ns.Damage.list, K.Scale.Root()
local function set(key, value) M.Write(env, K, key, value) end
local function Rect(region) return assert(G.Rect(region, root)) end
local function Value(l, i) return M.Last(l.rows[i].value, "SetText")[1] end
local function Errors(label) assert(#env._errors == 0 and K.ErrorCount() == 0, label .. ": " .. tostring(env._errors[1])) end
local function Refresh() env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED"); env.RunTimers() end

-- Defaults: a v0.2.8 profile keeps today's card and builds nothing new.
for key, value in pairs({ ["damage.englishUnits"] = true, ["damage.report"] = false, ["damage.reportTo"] = "auto", ["damage2.shown"] = false,
	["damage2.meter"] = "HealingDone", ["damage2.session"] = "Current" }) do
	assert(ns.Get(key) == value, key .. " keeps its v0.2.8 default")
end
assert(not ns.Damage2.holder and not list.reportButton and not list.resetButton, "the second window and the report button build nothing until switched on")
assert(Value(list, 1) == "52.3K" and list.rest == "3.2K dps", "English units by default: " .. tostring(Value(list, 1)) .. " " .. tostring(list.rest))
assert(list.rows[1].label == nil and ns.Damage.slots[1].label == nil, "with reports off a refresh keeps no report data per row")

-- English number units off uses the game's own units, for rows, the rate and the hover breakdown; on restores.
local game = env.AbbreviateLargeNumbers
local calls = 0
env.AbbreviateLargeNumbers = function(value) calls = calls + 1; return game(value) end
set("damage.englishUnits", false)
assert(Value(list, 1) == "52.34K" and list.rest == "3.23K dps" and calls > 0, "the game's units: " .. tostring(Value(list, 1)) .. " " .. tostring(list.rest))
local added = {}
local split = { AddRow = function(_, _, _, _, text) added[#added + 1] = text end, SetNote = function() end }
assert(list.rowSplit(split, list, 1) and added[1] == "52.34K", "the hover breakdown uses the game's units")
env.SetCombat(true)
sources[1].totalAmount = env.Secret(52345); Refresh()
assert(env.issecretvalue(Value(list, 1)) and env.Reveal(Value(list, 1)) == "52.34K", "a secret amount takes the game's units too")
sources[1].totalAmount = 52345; env.SetCombat(false); env.RunTimers()
set("damage.englishUnits", true)
assert(Value(list, 1) == "52.3K" and list.rest == "3.2K dps", "English units restore")
env.AbbreviateLargeNumbers = nil
set("damage.englishUnits", false)
assert(Value(list, 1) == "52.3K", "without the game's formatter the units stay English")
env.AbbreviateLargeNumbers = game
set("damage.englishUnits", true)
Errors("units")

-- Second damage window: its own meter, fight and drill, the shared style, the group rule, the key and its own place.
types = {}
set("damage2.shown", true)
local second = assert(ns.Damage2.list, "the second window builds when switched on")
assert(ns.Damage2.holder:IsShown() and second.panel:IsShown() and second.count > 0 and second.count == math.min(5, second.capacity), "the second window shows its rows")
local healing = false
for _, meter in ipairs(types) do healing = healing or meter == M.METER.HealingDone end
assert(healing, "the second window measures healing by default")
assert(Value(second, 1) == "52.3K" and second.section == "damage" and second.key == "meters.damage2", "it shares the damage card's look")
set("damage.rowHeight", 24)
assert(math.abs(second.rowHeight - list.rowHeight) < 1e-6 and second.rowHeight >= 24, "style changes reach both windows")
set("damage.rowHeight", 18)
second.panel._scripts.OnMouseUp(second.panel, "LeftButton"); env.RunTimers()
assert(ns.Get("damage2.meter") == "Hps" and ns.Get("damage.meter") == "DamageDone", "clicking the second card changes only its meter")
second.switch._scripts.OnMouseUp(second.switch, "LeftButton"); env.RunTimers()
assert(ns.Get("damage2.session") == "Previous" and ns.Get("damage.session") == "Current", "its fight switch is its own")
set("damage2.session", "Current"); set("damage2.meter", "HealingDone")
second.rows[1].frame._scripts.OnMouseUp(second.rows[1].frame, "LeftButton"); env.RunTimers()
assert(ns.Damage2.drill.active and not ns.Damage.drill.active and M.Last(second.rows[1].name, "SetText")[1] == "SPELL 1", "a drill in the second window leaves the main one")
env.FireEvent("DAMAGE_METER_RESET"); env.RunTimers()
assert(not ns.Damage2.drill.active, "a reset takes the second window back to every source")
local dh, th = list.panel:GetHeight(), ns.Threat.list.panel:GetHeight()
K.Layout.Update("meters.damage2", { height = 60 }); env.RunTimers()
assert(list.panel:GetHeight() == dh and ns.Threat.list.panel:GetHeight() == th and second.panel:GetHeight() <= 60, "resizing the second window leaves the paired cards alone")
K.Layout.Update("meters.damage2", { height = 158 }); env.RunTimers()
set("damage.shown", false)
assert(not list.panel:IsShown() and second.panel:IsShown(), "the second window does not need the main one")
local font
for _, row in ipairs(ns.Schema()) do if row.key == "damage.font" then font = row end end
assert(not font.disableWhen(K.Store.Module("Meters")), "the shared style rows stay open for the second window")
set("damage.shown", true)
set("damage.group", true); env._group.size = 0; env.FireEvent("GROUP_ROSTER_UPDATE"); env.RunTimers()
assert(not second.panel:IsShown(), "only in a group hides the second window alone")
env._group.size = 5; env.FireEvent("GROUP_ROSTER_UPDATE"); env.RunTimers()
assert(second.panel:IsShown(), "joining a group shows it again")
set("damage.group", false)
env.KstyleUI_MetersToggle._scripts.OnClick(env.KstyleUI_MetersToggle); env.RunTimers()
assert(not second.panel:IsShown(), "the show/hide key hides the second window")
env.KstyleUI_MetersToggle._scripts.OnClick(env.KstyleUI_MetersToggle); env.RunTimers()
assert(second.panel:IsShown(), "and shows it again")
local a, b = Rect(ns.Damage.holder), Rect(ns.Damage2.holder)
assert(a.right <= b.left or b.right <= a.left or a.top <= b.bottom or b.top <= a.bottom, "the second window starts clear of the main one")
Errors("second window")

-- Report with Shift-click: anywhere on a window, out of combat, to the right chat, never with a secret; off keeps today's clicks.
local sent = {}
env.C_ChatInfo = { SendChatMessage = function(message, chat) sent[#sent + 1] = { message, chat } end, InChatMessagingLockdown = function() return false end }
env.IsShiftKeyDown = function() return env._shift == true end
K.Layout.Update("meters.damage", { height = 300 }); env.RunTimers()
assert(list.count == 5, "the main card shows every row for the report")
local function Shift(frame, script)
	sent, env._printed, env._shift = {}, {}, true
	frame._scripts[script or "OnMouseUp"](frame, "LeftButton")
	env._shift = false
	env.RunTimers()
end
local function Click() Shift(list.panel) end
Click()
assert(#sent == 0 and ns.Get("damage.meter") == "Dps", "off by default, a Shift-click is today's click")
set("damage.meter", "DamageDone")
set("damage.report", true)
local tip = { lines = {}, AddLine = function(self, text) self.lines[#self.lines + 1] = text end }
list.tooltip(tip)
assert(tip.lines[#tip.lines] == K.L["Shift-click to report these rows to chat."], "the card's tooltip names the Shift-click")
Click()
assert(ns.Get("damage.meter") == "DamageDone", "a Shift-click reports instead of changing the meter")
assert(#sent == 6 and sent[1][1] == "Damage done (Current fight)" and sent[1][2] == "PARTY", "a header to party chat: " .. tostring(sent[1] and sent[1][1]))
assert(sent[2][1] == "1. Player 1 52.3K (32%)" and sent[6][1] == "5. Player 5 12.3K (8%)", "one line a row: " .. sent[2][1])
Shift(list.rows[2].frame)
assert(#sent == 6 and not ns.Damage.drill.active, "a Shift-click on a row reports instead of opening it")
Shift(list.titleHit)
assert(#sent == 6 and ns.Get("damage.meter") == "DamageDone", "and on the title")
local function Refused(label) assert(#sent == 0 and env._printed[#env._printed]:find(K.L["The meter can report after combat."], 1, true), label) end
env.SetCombat(true); Click(); Refused("no report in combat")
env.SetCombat(false); env.RunTimers()
env.C_ChatInfo.InChatMessagingLockdown = function() return true end; Click(); Refused("no report while chat is locked")
env.C_ChatInfo.InChatMessagingLockdown = function() return env.Secret(false) end; Click(); Refused("a secret lockdown answer refuses")
env.C_ChatInfo.InChatMessagingLockdown = function() return false end
sources[2].name = env.Secret("Player 2"); Refresh(); Click(); Refused("a secret name refuses")
sources[2].name = "Player 2"; Refresh()
env._instance = true; Click()
assert(sent[1][2] == "INSTANCE_CHAT", "automatic picks instance chat first")
env._instance, env._group.raid = false, true; Click()
assert(sent[1][2] == "RAID", "then raid chat")
env._group.raid = false
env.IsInGuild = function() return false end
set("damage.reportTo", "GUILD"); Click()
assert(#sent == 0 and env._printed[1] == "KstyleUI: Damage done (Current fight)" and #env._printed == 6, "a chat you are not in shows only you")
env.IsInGuild = function() return true end; Click()
assert(sent[1][2] == "GUILD", "guild chat")
set("damage.reportTo", "auto")
env.C_ChatInfo.SendChatMessage = nil; Click()
assert(#sent == 0 and #env._printed == 6, "without the chat API only you see the report")
env.C_ChatInfo.SendChatMessage = function(message, chat) sent[#sent + 1] = { message, chat } end
list.rows[1].frame._scripts.OnMouseUp(list.rows[1].frame, "LeftButton"); env.RunTimers(); Click()
assert(sent[1][1] == "Player 1: Damage done (Current fight)" and sent[2][1] == "1. Spell 1 52.3K (32%)", "a spell list reports its spells: " .. sent[1][1])
assert(ns.Damage.drill.active, "a Shift-click in a spell list keeps it open")
list.rows[1].frame._scripts.OnMouseUp(list.rows[1].frame, "LeftButton"); env.RunTimers()
Shift(second.panel)
assert(sent[1][1] == "Healing done (Current fight)" and ns.Get("damage2.meter") == "HealingDone", "the second window reports its own meter")
env._sources["Player-3"] = env._sources["Player-1"]
env._group.size = 0; env.FireEvent("GROUP_ROSTER_UPDATE"); env.RunTimers()
Click()
assert(#sent == 0 and #env._printed == 6 and env._printed[2] == "KstyleUI: 1. Spell 1 52.3K (32%)", "alone, only you see the report of your spells")
env._group.size = 5; env.FireEvent("GROUP_ROSTER_UPDATE"); env.RunTimers()
set("damage.report", false)
tip.lines = {}; list.tooltip(tip)
assert(tip.lines[#tip.lines] ~= K.L["Shift-click to report these rows to chat."], "off, the tooltip drops the hint")
Click()
assert(#sent == 0 and ns.Get("damage.meter") == "Dps", "off, a Shift-click is a click again")
set("damage.meter", "DamageDone")
Errors("report")

-- Off restores: the second window hides and stops listening.
set("damage2.shown", false)
assert(not ns.Damage2.holder:IsShown(), "turning the second window off hides it")
types = {}; Refresh()
for _, meter in ipairs(types) do assert(meter ~= M.METER.HealingDone, "a hidden second window does no work") end

-- The live preview shows the second window and the units.
set("damage2.shown", true); set("damage.englishUnits", false)
local parent = env.CreateFrame("Frame", nil, env.UIParent); parent:SetSize(900, 500); parent:SetPoint("CENTER", env.UIParent, "CENTER")
calls = 0
env.AbbreviateLargeNumbers = function(value) calls = calls + 1; return game(value) end
local preview = ns.Preview.Build(parent)
assert(preview.second and preview.second.holder:IsShown() and preview.second.count > 0, "the preview shows the second window")
assert(calls > 0, "the preview uses the game's units when English units are off")
local parts = { preview.damage.holder, preview.second.holder, preview.threat.holder }
for i, part in ipairs(parts) do
	for j = i + 1, #parts do
		local h, o = G.Rect(part, env.UIParent), G.Rect(parts[j], env.UIParent)
		assert(h.right <= o.left + 1e-6 or o.right <= h.left + 1e-6 or h.top <= o.bottom + 1e-6 or o.top <= h.bottom + 1e-6, "preview cards never overlap")
	end
end
set("damage2.shown", false); preview:Refresh()
assert(not preview.second.holder:IsShown(), "and hides it again")
Errors("preview")
-- Review of #621: the reset button, fail-closed checks, secret death times, home chats, room beside threat and the preview.
set("damage2.shown", true); set("damage.englishUnits", true)
set("threat.shown", true); set("threat.group", false); Refresh()
local s2, t2 = Rect(ns.Damage2.holder), Rect(ns.Threat.holder)
assert(not ns.Threat.paired and ns.Threat.list.panel:IsVisible() and second.panel:IsVisible(), "Both keeps threat in its own place while the second window is on")
assert(s2.right <= t2.left or t2.right <= s2.left or s2.top <= t2.bottom or t2.top <= s2.bottom, "the second window starts clear of the threat card")
local function Planned(label)
	local L = K.Setup.Layouts
	for _, size in ipairs(L.PrepareFits("Tank", 1920, 1080, L.Enabled("Tank", K.Store.Profile())).sizes) do
		if size[6] == "meters.threat" then
			assert(size[1] == ns.Threat.holder:GetWidth(), label .. ": the HUD fit plans the threat card " .. size[1] .. " wide, it draws " .. ns.Threat.holder:GetWidth())
		end
	end
end
Planned("second window on")
set("damage2.shown", false)
assert(ns.Threat.paired, "turning the second window off docks threat beside the damage meter again")
Planned("docked")
set("damage2.shown", true)
assert(not ns.Threat.paired, "and on again moves it back to its own place")
set("damage.report", true); set("damage.resetButton", true)
local resets, reset = 0, env.C_DamageMeter.ResetAllCombatSessions
env.C_DamageMeter.ResetAllCombatSessions = function() resets = resets + 1 end
Shift(list.resetButton, "OnClick")
assert(resets == 0 and #sent == 6, "a Shift-click on Reset reports instead of resetting")
list.resetButton._scripts.OnClick(list.resetButton, "LeftButton"); env.RunTimers()
assert(resets == 1, "a plain click on Reset still resets")
env.C_DamageMeter.ResetAllCombatSessions = reset
set("damage.resetButton", false)
local lockdown, combat = env.C_ChatInfo.InChatMessagingLockdown, env.InCombatLockdown
env.C_ChatInfo.InChatMessagingLockdown = nil; Click(); Refused("without the chat lockdown check the report refuses")
env.C_ChatInfo.InChatMessagingLockdown = lockdown
env.InCombatLockdown = function() error("no answer") end; Click(); env.InCombatLockdown = combat
Refused("a combat check that fails refuses")
set("damage.meter", "Deaths"); sources[1].deathTimeSeconds = env.Secret(67); Refresh(); Click()
Refused("a secret death time refuses the report")
sources[1].deathTimeSeconds = 67; Refresh(); Click()
assert(#sent == 6 and sent[2][1] == "1. Player 1 1:07", "a plain death time reports: " .. tostring(sent[2] and sent[2][1]))
set("damage.meter", "DamageDone")
local inGroup, inRaid = env.IsInGroup, env.IsInRaid
env.IsInGroup = function(category) return category ~= 1 end
env.IsInRaid = function(category) return category ~= 1 end
for _, chat in ipairs({ "PARTY", "RAID" }) do
	set("damage.reportTo", chat); Click()
	assert(#sent == 0 and #env._printed == 6, "an instance group alone does not open " .. chat .. " chat")
end
env.IsInGroup, env.IsInRaid = inGroup, inRaid
set("damage.reportTo", "auto"); set("damage.report", false)
set("damage2.session", "Overall"); preview:Refresh()
assert(preview.second.switchSelected == 3 and second.switchSelected == 3, "the preview shows the second window's fight")
set("damage2.meter", "Deaths"); preview:Refresh()
assert(Value(second, 1) == "1:07" and tostring(Value(preview.second, 1)):match("^%d+:%d%d$"), "the preview shows death times: " .. tostring(Value(preview.second, 1)))
set("damage2.session", "Current"); set("damage2.meter", "HealingDone")
set("damage.mode", "skin")
for _, row in ipairs(ns.Schema()) do
	local shown = row.showWhen and row.showWhen(K.Store.Module("Meters"))
	if row.key == "damage.meter" or row.key == "damage.session" then assert(not shown, row.key .. " belongs to the restyled main window") end
	if row.key == "damage.percent" or row.key == "damage2.meter" then assert(shown, row.key .. " still serves the second window") end
end
set("damage.mode", "window"); set("damage2.shown", false)
Errors("review")
print("meters parity round 2 ok")
