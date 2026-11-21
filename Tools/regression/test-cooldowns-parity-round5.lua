-- test-cooldowns-parity-round5.lua: EllesmereUI parity round 5 for Cooldowns, the custom bar group: a v0.2.8 profile keeps it off and unbuilt; switched on, its listed tracked bars and cooldowns show in list order in their own Layout element above the tracked bars, under the group's name, with its own bar count; Add new tracked bars moves every tracked bar into it; Shift attached elements moves what is attached to it while none of its spells is in the Cooldown Manager; each follows the events that change it, restores when switched off and reaches the preview.
local C = dofile("Tools/regression/cooldowns_env.lua")
local W = C.W

local function New(path, extra)
	local profile = { enabled = true, path = path }
	for key, value in pairs(extra or {}) do profile[key] = value end
	local saved = { version = 42, profiles = { Default = { Cooldowns = profile } }, characters = {} }
	local env, K, ns = C.New({ saved = saved, setup = C.Game })
	env._cdm.auras[4001] = { auraInstanceID = 41 }
	env._cdm.auras[4002] = { auraInstanceID = 42 }
	env.RunTimers()
	env.FireEvent("UNIT_AURA", "player", { isFullUpdate = true }); env.RunTimers()
	return env, K, ns, function(key, value) K.Options.Write("Cooldowns", key, value); env.RunTimers() end
end

local function Spells(row)
	local out = {}
	for i = 1, row and row.count or 0 do
		local entry = row.bars[i].entry
		out[i] = entry and (entry.spellID or entry.spell)
	end
	return table.concat(out, ",")
end

local function Clean(env, K, what) assert(#env._errors == 0 and K.ErrorCount() == 0, what .. " raised no errors") end
local function Fire(env, ...) env.FireEvent(...); env.RunTimers() end
local function Bottom(K, key) return select(2, K.Layout.Rect(key)) end
local function Overlap(K, a, b)
	local al, ab, aw, ah = K.Layout.Rect(a)
	local bl, bb, bw, bh = K.Layout.Rect(b)
	return al < bl + bw and bl < al + aw and ab < bb + bh and bb < ab + ah
end

-- Defaults: a v0.2.8 profile keeps the group off, builds nothing for it and leaves the tracked bars as they were.
do
	local env, K, ns = New("mirror")
	local custom = ns.Settings.current.custom
	assert(custom.name == "" and custom.count == 2 and not custom.autoAdd and custom.shift == "" and custom.shiftY == 0, "the custom group's settings keep their defaults")
	assert(ns.Settings.current.rules.group == "", "its spell list is empty")
	assert(ns.Mirror.Row("custom") == nil and K.Layout.Element("cooldowns.custom") == nil, "no custom row or Layout element is made")
	assert(Spells(ns.Mirror.Row("bars")) == "4001,4002", "the tracked bars keep both buffs")
	Clean(env, K, "defaults")
end

-- Spells in this group: listed tracked bars and cooldowns leave the tracked bars and show in list order, above them, under their name; then off.
do
	local env, K, ns, Write = New("mirror")
	local bars = ns.Mirror.Row("bars")
	Write("rules.group", "4002, 4001")
	local row = ns.Mirror.Row("custom")
	assert(row and row.holder:IsShown() and K.Layout.Live("cooldowns.custom"), "listing a spell builds the group as a live Layout element")
	assert(Spells(row) == "4002,4001" and bars.count == 0, "listed bars move into the group in list order")
	assert(K.Layout.Element("cooldowns.custom").label == K.L["Custom bars"], "Layout Mode names it Custom bars")
	assert(Bottom(K, "cooldowns.custom") >= Bottom(K, "cooldowns.bars") and not Overlap(K, "cooldowns.custom", "cooldowns.bars"), "it starts above the tracked bars, clear of them")
	Write("rules.group", "4001, 1002")
	assert(Spells(row) == "4001,1002" and Spells(bars) == "4002", "a cooldown joins as a cooldown bar and the unlisted buff goes back")
	local cd = row.bars[2]
	local timed = #W.Calls(cd.status, "SetTimerDuration")
	env._cdm.cooldown[1002] = { active = true }
	Fire(env, "SPELL_UPDATE_COOLDOWN")
	assert(#W.Calls(cd.status, "SetTimerDuration") > timed, "the group's cooldown bar follows SPELL_UPDATE_COOLDOWN")
	Write("rules.names", "4001=Haste")
	assert(row.bars[1].name:GetText() == "Haste", "Bar names renames a bar in the group")
	Write("rules.hide", "1002")
	assert(Spells(row) == "4001", "Hide these hides a bar in the group")
	Write("rules.hide", "")
	Write("rules.cdBars", "1001")
	assert(Spells(bars) == "4002,1001" and Spells(row) == "4001,1002", "Cooldown bars still adds unlisted cooldowns to the tracked bars")
	Write("rules.cdBars", "")
	env.SetCombat(true); Write("rules.group", "1002, 4001"); env.SetCombat(false)
	assert(Spells(row) == "1002,4001", "the order changes in combat")
	Write("rules.group", "")
	assert(not row.holder:IsShown() and row.count == 0 and not K.Layout.Live("cooldowns.custom"), "clearing the list hides the group and its Layout element")
	assert(Spells(bars) == "4001,4002", "and the tracked bars get every buff back in their own order")
	Clean(env, K, "spells in this group")
end

-- Group name names the Layout element and refuses escape codes; Bars sets the group's own count with the +N bar.
do
	local env, K, ns, Write = New("mirror")
	Write("rules.group", "4001, 4002, 1001")
	Write("custom.name", "Raid CDs")
	local el = K.Layout.Element("cooldowns.custom")
	assert(el.label == "Raid CDs", "the name labels the Layout element")
	local listed = false
	for _, item in ipairs(K.Layout.Elements()) do listed = listed or item.key == "cooldowns.custom" and item.label == "Raid CDs" end
	assert(listed, "the Elements page lists it by name")
	local before = { K.Layout.Rect("cooldowns.custom") }
	Write("custom.name", "|cffff0000Red")
	assert(el.label == K.L["Custom bars"], "a name with an escape code falls back")
	local after = { K.Layout.Rect("cooldowns.custom") }
	assert(before[1] == after[1] and before[2] == after[2], "renaming keeps the group's place")
	local row = ns.Mirror.Row("custom")
	assert(row.count == 2 and row.chip and row.chip:IsShown(), "two bars show and the +N bar counts the third")
	local tall = select(2, row.holder:GetSize())
	Write("custom.count", 3)
	assert(row.count == 3 and not row.chip:IsShown() and select(2, row.holder:GetSize()) > tall, "Bars grows the group")
	assert(ns.Mirror.Row("bars").cfg.count == 2, "the tracked bars keep their own count")
	assert(K.Layout.Update("cooldowns.custom", { shown = "combat" }))
	assert(not row.holder:IsShown(), "Layout's Shown rule hides the group out of combat")
	Write("custom.count", 2)
	assert(not row.holder:IsShown(), "and a setting change leaves Layout's rule alone")
	env.SetCombat(true); env.RunTimers()
	assert(row.holder:IsShown(), "the group shows in combat")
	env.SetCombat(false); env.RunTimers()
	Clean(env, K, "name and count")
end

-- Add new tracked bars: every tracked bar joins the group after the listed ones, a bar the game adds later too; Cooldown bars stay with the tracked bars; then off.
do
	local env, K, ns, Write = New("mirror")
	local bars = ns.Mirror.Row("bars")
	Write("bars.count", 4)
	Write("rules.cdBars", "1001")
	Write("custom.autoAdd", true)
	local row = ns.Mirror.Row("custom")
	assert(Spells(row) == "4001,4002" and Spells(bars) == "1001", "every tracked bar joins the group; a cooldown bar stays")
	Write("rules.group", "4002")
	assert(Spells(row) == "4002,4001", "listed spells come first")
	env._cdm.cooldowns[403] = { spellID = 4003, category = C.CATEGORY.TrackedBar, selfAura = true, hasAura = true }
	env._cdm.auras[4003] = { auraInstanceID = 43 }
	Fire(env, "COOLDOWN_VIEWER_DATA_LOADED")
	Fire(env, "UNIT_AURA", "player", { isFullUpdate = true })
	Write("custom.count", 4)
	assert(Spells(row) == "4002,4001,4003", "a bar the game adds later joins the group")
	Write("custom.autoAdd", false)
	assert(Spells(row) == "4002" and Spells(bars) == "4001,4003,1001", "off sends unlisted bars back")
	Clean(env, K, "add new tracked bars")
end

-- Shift attached elements: an element attached to the group moves by one bar (plus Extra shift) while none of its spells is in the Cooldown Manager, refreshed by data and spec events, paused in Layout Mode; then off.
do
	local env, K, ns, Write = New("mirror")
	local probe = env.CreateFrame("Frame", "ProbeFrame", env.UIParent)
	probe:SetSize(60, 20)
	K.Layout.Register(probe, "probe.below", { anchor = "CENTER", x = 0, y = 0 }, { label = "Probe" })
	Write("rules.group", "4009")
	assert(K.Layout.Update("probe.below", { attachTo = "cooldowns.custom", side = "below", offset = 0 }))
	local row, cfg = ns.Mirror.Row("custom"), ns.Settings.current.custom
	local base = Bottom(K, "probe.below")
	assert(row.count == 0 and row.empty, "a spell not in the Cooldown Manager leaves the group empty")
	Write("custom.shift", "up")
	local _, h = K.Layout.Rect("cooldowns.custom")
	local _, height = ns.Grid.Size(cfg.grid)
	local pitch = (cfg.height + cfg.spacing) * select(4, K.Layout.Rect("cooldowns.custom")) / height
	assert(math.abs(Bottom(K, "probe.below") - (base + pitch)) < 0.01, "Upward moves the attached element up by one bar")
	assert(h, "the group keeps its rect")
	Write("custom.shiftY", 5)
	assert(math.abs(Bottom(K, "probe.below") - (base + pitch + 5)) < 0.01, "Extra shift adds to the move")
	Write("custom.shift", "down")
	assert(math.abs(Bottom(K, "probe.below") - (base - pitch - 5)) < 0.01, "Downward moves it down")
	local point = { probe:GetPoint(1) }
	assert(K.Layout.Enter(), "Layout Mode opens")
	assert(math.abs(Bottom(K, "probe.below") - base) < 0.01, "Layout Mode shows the group's own slot")
	K.Layout.Exit(true)
	assert(math.abs(Bottom(K, "probe.below") - (base - pitch - 5)) < 0.01, "leaving Layout Mode shifts again")
	assert(select(5, probe:GetPoint(1)) == point[5], "and puts the attached frame back where it was shifted")
	env._cdm.cooldowns[409] = { spellID = 4009, category = C.CATEGORY.TrackedBar, selfAura = true, hasAura = true }
	Fire(env, "COOLDOWN_VIEWER_DATA_LOADED")
	assert(not row.empty and math.abs(Bottom(K, "probe.below") - base) < 0.01, "a listed spell entering the Cooldown Manager ends the shift, even while it is inactive")
	env._cdm.cooldowns[409] = nil
	Fire(env, "SPELLS_CHANGED")
	assert(row.empty and math.abs(Bottom(K, "probe.below") - (base - pitch - 5)) < 0.01, "a spec change that drops it shifts again")
	env.SetCombat(true); Write("custom.shiftY", 0); env.SetCombat(false)
	assert(math.abs(Bottom(K, "probe.below") - (base - pitch)) < 0.01, "a change in combat applies")
	Write("custom.shift", "")
	assert(math.abs(Bottom(K, "probe.below") - base) < 0.01, "None restores the exact place")
	Write("custom.shift", "up")
	Write("rules.group", "")
	assert(not K.Layout.Live("cooldowns.custom") and not row.empty, "clearing the group ends the shift")
	K.Modules.Disable("Cooldowns"); env.RunTimers()
	assert(not row.holder:IsShown(), "stopping the module hides the group")
	Clean(env, K, "shift")
end

-- Restricted auras: the group keeps its last bars and its cooldown bars keep counting; the next readable refresh applies a list change.
do
	local env, K, ns, Write = New("mirror")
	Write("custom.count", 3)
	Write("rules.group", "4001, 1002")
	local row = ns.Mirror.Row("custom")
	local buff, cd = row.bars[1], row.bars[2]
	local dressed = #W.Calls(buff.timer, "SetCooldownFromDurationObject")
	env._cdm.secretAuras = true
	env.SetCombat(true)
	Write("rules.group", "4001, 1002, 1001")
	assert(Spells(row) == "4001,1002" and #W.Calls(buff.timer, "SetCooldownFromDurationObject") == dressed, "a list change while auras are restricted keeps the group's last bars")
	local timed = #W.Calls(cd.status, "SetTimerDuration")
	env._cdm.cooldown[1002] = { active = true }
	Fire(env, "SPELL_UPDATE_COOLDOWN")
	assert(#W.Calls(cd.status, "SetTimerDuration") > timed, "its cooldown bar still follows its events")
	env.SetCombat(false)
	env._cdm.secretAuras = nil
	Fire(env, "UNIT_AURA", "player", { isFullUpdate = true })
	assert(Spells(row) == "4001,1002,1001", "the next readable refresh applies the change")
	Clean(env, K, "restricted auras")
end

-- Restyled Blizzard bars: the group is KstyleUI bars only, so nothing is built and nothing errors.
do
	local env, K, ns, Write = New("reskin")
	Write("rules.group", "4001"); Write("custom.autoAdd", true); Write("custom.shift", "up")
	assert(ns.Mirror.Row("custom") == nil and K.Layout.Element("cooldowns.custom") == nil, "no group while the bars restyle Blizzard's viewer")
	Clean(env, K, "restyled")
end

-- Upgrade: saved values outside their ranges are cleaned.
do
	local env, K, ns = New("mirror", { custom = { name = string.rep("x", 60), count = 99, autoAdd = "yes", shift = "sideways", shiftY = -400 } })
	local custom = ns.Settings.current.custom
	assert(custom.name == "" and custom.count == 12 and custom.autoAdd == false and custom.shift == "" and custom.shiftY == -50, "bad saved values fall back or clamp")
	Clean(env, K, "upgrade")
end

-- Preview: the group under its name with the samples it takes, Add new tracked bars leaving the cooldown sample, and a shift showing it empty with the bars moved into its place.
do
	local env, K, ns, Write = New("mirror")
	local pane = env.CreateFrame("Frame", nil, env.UIParent)
	pane:SetSize(280, 300)
	local frame = ns.Preview.Build(pane)
	local custom, bars = frame.rows.custom, frame.rows.bars
	assert(not custom.holder:IsShown() and not frame.caption:IsShown() and bars.count == 2, "the preview shows no group by default")
	Write("rules.group", "x"); frame:Refresh()
	assert(custom.holder:IsShown() and custom.count == 2 and bars.count == 0, "listed samples move into the group")
	assert(frame.caption:IsShown() and frame.caption:GetText() == K.L["Custom bars"]:upper(), "under its name, in the caption capitals")
	Write("custom.name", "Raid CDs"); frame:Refresh()
	assert(frame.caption:GetText() == "RAID CDS", "the preview shows the group's name")
	Write("rules.group", ""); Write("custom.autoAdd", true); Write("rules.cdBars", "x"); frame:Refresh()
	assert(custom.count == 1 and bars.count == 1 and bars.bars[1].name:GetText() == K.L["Multi-Shot"], "Add new tracked bars takes the buffs and leaves the cooldown bar")
	Write("rules.cdBars", "")
	local _, _, _, _, y = bars.holder:GetPoint(1)
	Write("custom.shift", "up"); frame:Refresh()
	local cfg = ns.Settings.current.custom
	assert(custom.count == 0 and bars.count == 2, "a shift shows the group empty")
	assert(math.abs(select(5, bars.holder:GetPoint(1)) - (y + cfg.height + cfg.spacing)) < 0.5, "with the bars moved up into its place, to the pixel")
	Write("custom.autoAdd", false); Write("custom.shift", ""); frame:Refresh()
	assert(not custom.holder:IsShown() and bars.count == 2, "off puts the preview back")
	Clean(env, K, "preview")
end

print("test-cooldowns-parity-round5: ok")
