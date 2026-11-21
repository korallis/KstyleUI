-- test-cooldowns-parity-round2.lua: EllesmereUI parity round 2 for Cooldowns: every new option keeps today's defaults on a v0.2.8 profile, applies when switched on (per-spell hide, gaps, forms, missing buffs, counts, colours, tenths, active glows, numbers only, buffs kept in place, bar names, fill, smoothing, spark, wrap, the rotation helper), follows the events that change it, restores when switched off, and reaches the restyled viewers and the preview.
local C = dofile("Tools/regression/cooldowns_env.lua")
local W = C.W

local function Game(e)
	C.Game(e)
	e.AssistedCombatManager = {}
	e._cdm.auras[3001] = { auraInstanceID = 71 }
	e._cdm.auras[4001] = { auraInstanceID = 81 }
	for name, viewer in pairs(e._viewers) do
		for i, item in ipairs(viewer._items) do
			item.GetSpellID = function() return name == "BuffIconCooldownViewer" and 3000 + i or 1000 + i end
		end
	end
end

local function New(path)
	local saved = { version = 42, profiles = { Default = { Cooldowns = { enabled = true, path = path } } }, characters = {} }
	local env, K, ns = C.New({ saved = saved, setup = Game })
	env.RunTimers()
	return env, K, ns, function(key, value) K.Options.Write("Cooldowns", key, value); env.RunTimers() end
end

local function IconOf(ns, group, spell)
	local row = ns.Mirror.Row(group)
	for i = 1, row.count do
		if row.icons[i].entry and row.icons[i].entry.spellID == spell then return row.icons[i] end
	end
end

local function X(region) return W.LastCall(region, "SetPoint")[4] end
local function Near(a, b) return math.abs(a - b) < 0.01 end
local function Clean(env, K, what) assert(#env._errors == 0 and K.ErrorCount() == 0, what .. " raised no errors") end
local function Aura(env) env.FireEvent("UNIT_AURA", "player", { isFullUpdate = true }); env.RunTimers() end

-- Defaults: a v0.2.8 profile keeps every new option off and writes nothing new.
do
	local env, K, ns = New("mirror")
	local current = ns.Settings.current
	assert(not current.assist and current.decimalBelow == 3 and current.timerSource == "class", "new module options default off")
	for _, group in ipairs({ "essential", "utility", "buffs" }) do assert(not current[group].numbersOnly and not current[group].keepPlace, group .. " keeps its sockets") end
	local bars = current.bars
	assert(not bars.fillUp and not bars.smooth and not bars.spark and not bars.nameWrap and not bars.decimals and bars.decimalBelow == 3, "bar options default off")
	local a = IconOf(ns, "essential", 1001)
	assert(not a.assistGlow and a.icon:GetAlpha() == 1 and Near(W.LastCall(a.countdown, "SetTextColor")[1], K.Widgets.Rgba("slotNumber")), "icons stay as before")
	local bar = ns.Mirror.Row("bars").bars[1]
	assert(not bar.status.spark:IsShown() and #W.Calls(bar.name, "SetMaxLines") == 0, "no spark and no wrap")
	local timer = W.LastCall(bar.status, "SetTimerDuration")
	assert(timer[2] == 0 and timer[3] == env.Enum.StatusBarTimerDirection.RemainingTime, "bars still snap and drain")
	assert(#W.Calls(ns.Mirror.Row("buffs").icons[1], "SetAlpha") == 0, "buff icons write no alpha")
	Clean(env, K, "defaults")
end

-- Spell rules on KstyleUI cooldown icons, each switched on, driven by its events, then switched off.
do
	local env, K, ns, Write = New("mirror")
	local cdm = env._cdm
	local a, b, c = IconOf(ns, "essential", 1001), IconOf(ns, "essential", 1002), IconOf(ns, "essential", 1003)
	Write("essential.growth", "right")
	local slotA, slotB, slotC = X(a), X(b), X(c)

	Write("rules.hide", "1001")
	assert(a:GetAlpha() == 0 and a.ruleHidden and not a:IsMouseEnabled() and X(b) == slotB, "Hide these hides a spell and keeps its slot")
	Write("rules.shift", "1001")
	assert(X(b) == slotA and X(c) == slotB, "Close gaps for these closes that spell's gap with Close gaps off")
	Write("rules.hide", "1001, 1002")
	assert(X(c) == slotB, "an unlisted hidden spell keeps its slot")
	Write("rules.hide", ""); Write("rules.shift", "")
	assert(a:GetAlpha() == 1 and a:IsMouseEnabled() and X(a) == slotA and X(b) == slotB and X(c) == slotC, "clearing the lists restores every icon and slot")

	Write("essential.usable", false); Write("rules.form", "1001")
	cdm.usable[1001] = { usable = false, noMana = false }; env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(a:GetAlpha() == 0, "outside its form the spell hides on the form event")
	cdm.cooldown[1001] = { active = true }; cdm.usable[1001] = nil; env.FireEvent("SPELL_UPDATE_USABLE"); env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(a:GetAlpha() == 1 and a.onCooldown, "in its form it shows, even while cooling")
	cdm.usable[1001] = { usable = false, noMana = true }; env.FireEvent("SPELL_UPDATE_USABLE")
	assert(a:GetAlpha() == 1, "low resources do not hide it")
	cdm.cooldown[1001], cdm.usable[1001] = nil, nil; env.FireEvent("SPELL_UPDATE_COOLDOWN"); env.FireEvent("SPELL_UPDATE_USABLE")
	Write("rules.form", ""); Write("essential.usable", true)

	Write("essential.showCount", false)
	assert(a.count:GetAlpha() == 0, "the group switch hides counts")
	Write("rules.count", "1001")
	assert(a.count:GetAlpha() == 1 and b.count:GetAlpha() == 0, "Show counts shows that spell's count over the group switch")
	Write("rules.noCount", "1001")
	assert(a.count:GetAlpha() == 0, "Hide counts still wins")
	Write("rules.noCount", ""); Write("rules.count", ""); Write("essential.showCount", true)

	Write("rules.timerColour", "1001 #FF8000, 1002")
	local colour = W.LastCall(a.countdown, "SetTextColor")
	assert(Near(colour[1], 1) and Near(colour[2], 128 / 255) and Near(colour[3], 0), "a colour after a spell is its own countdown colour")
	K.Callbacks.Fire("LayoutChanged", "cooldowns.essential"); env.RunTimers()
	assert(Near(W.LastCall(a.countdown, "SetTextColor")[2], 128 / 255), "a layout restyle keeps the colour")
	Write("timerSource", "custom"); Write("timerColor", { r = 0.2, g = 0.4, b = 0.6 })
	assert(Near(W.LastCall(b.countdown, "SetTextColor")[1], 0.2), "an unmarked spell takes the countdown colour")
	Write("rules.timerColour", "")
	local slot = { K.Widgets.Rgba("slotNumber") }
	assert(Near(W.LastCall(a.countdown, "SetTextColor")[1], slot[1]) and Near(W.LastCall(b.countdown, "SetTextColor")[3], slot[3]), "clearing it restores the socket's number colour")
	Write("timerSource", "class")

	Write("rules.tint", "1001 #00FF00, 1002 #0000FF")
	a.onCooldown, b.onCooldown = true, true; a:Paint(); b:Paint()
	local tintA, tintB = W.LastCall(a.cooldown, "SetSwipeColor"), W.LastCall(b.cooldown, "SetSwipeColor")
	assert(tintA[2] == 1 and tintA[3] == 0 and tintB[3] == 1 and tintB[2] == 0, "each spell has its own swipe colour")
	a.onCooldown, b.onCooldown = nil, nil
	Write("rules.tint", "")
	Write("rules.glow", "1001 #FF0000")
	assert(a.readyGlow.colorRGB[1] == 1 and a.readyGlow.colorRGB[2] == 0, "Glow colour takes a spell's own colour")
	Write("rules.glow", "")

	Write("rules.decimals", "1001"); Write("decimalBelow", 5)
	local formatter = W.LastCall(a.cooldown, "SetCountdownFormatter")[1]
	assert(formatter and formatter.breakpoints[1].format == "%.1f" and formatter.breakpoints[2].threshold == 5, "listed countdowns show tenths below the threshold")
	assert(W.LastCall(b.cooldown, "SetCountdownFormatter")[1].breakpoints[1].format == "%d", "other spells keep whole seconds")
	Write("essential.timerSize", 16); Write("readableCountdown", false)
	local seconds = W.LastCall(a.cooldown, "SetCountdownFormatter")[1]
	local found = false
	for _, call in ipairs(seconds.calls) do found = found or call.method == "SetMillisecondsThreshold" and call.args[1] == 5 end
	assert(found, "the seconds formatter also takes the threshold")
	Write("readableCountdown", true); Write("rules.decimals", "")
	assert(W.LastCall(a.cooldown, "SetCountdownFormatter")[1].breakpoints[1].format == "%d", "clearing the list restores whole seconds")

	Write("essential.numbersOnly", true)
	assert(a.icon:GetAlpha() == 0 and W.LastCall(a.cooldown, "SetDrawSwipe")[1] == false and W.LastCall(a.cooldown, "SetHideCountdownNumbers")[1] == false, "Numbers only leaves the socket and its countdown")
	Write("essential.numbersOnly", false)
	assert(a.icon:GetAlpha() == 1 and W.LastCall(a.cooldown, "SetDrawSwipe")[1] == true, "and restores the icon and its swipe")

	env.SetCombat(true)
	Write("rules.hide", "1002")
	assert(b:GetAlpha() == 0, "rules apply in combat")
	env.SetCombat(false)
	Write("rules.hide", "")
	Clean(env, K, "cooldown rules")
end

-- The rotation helper follows Blizzard's Assisted Highlight announcements, never polling.
do
	local env, K, ns, Write = New("mirror")
	local a, b = IconOf(ns, "essential", 1001), IconOf(ns, "essential", 1002)
	local manager = env.AssistedCombatManager
	manager.lastNextCastSpellID = 1001
	C.Trigger(env, "AssistedCombatManager.OnAssistedHighlightSpellChange")
	assert(not a.assistGlow, "the helper is off by default")
	Write("assist", true)
	assert(a.assistGlow.playing and not b.assistGlow, "switched on, the recommended spell glows")
	manager.lastNextCastSpellID = 1002
	C.Trigger(env, "AssistedCombatManager.OnAssistedHighlightSpellChange")
	assert(not a.assistGlow.playing and b.assistGlow.playing, "the glow follows the next recommendation")
	Write("assistSource", "custom"); Write("assistColor", { r = 0.1, g = 0.9, b = 0.3 })
	assert(b.assistGlow.colorRGB[2] == 0.9, "the custom highlight colour applies at once")
	manager.lastNextCastSpellID = env.Secret(1002)
	C.Trigger(env, "AssistedCombatManager.OnAssistedHighlightSpellChange")
	assert(not b.assistGlow.playing, "a secret recommendation lights nothing")
	manager.lastNextCastSpellID = 1002
	C.Trigger(env, "AssistedCombatManager.OnAssistedHighlightSpellChange")
	manager.lastNextCastSpellID = nil
	C.Trigger(env, "AssistedCombatManager.OnSetUseAssistedHighlight", false)
	assert(not b.assistGlow.playing, "turning off Assisted Highlight clears it")
	manager.lastNextCastSpellID = 1001
	C.Trigger(env, "AssistedCombatManager.OnAssistedHighlightSpellChange")
	Write("assist", false)
	assert(not a.assistGlow.playing, "switching the helper off stops the glow")
	ns.definition.Disable()
	assert(not next(env._cdm.callbacks["AssistedCombatManager.OnAssistedHighlightSpellChange"]), "stopping the module stops listening")
	Clean(env, K, "rotation helper")
end

-- KstyleUI tracked buffs: hidden, missing, active glows, counts, swipe colours and buffs kept in place, on the aura events.
do
	local env, K, ns, Write = New("mirror")
	local cdm, row = env._cdm, ns.Mirror.Row("buffs")
	assert(row.count == 1 and row.icons[1].entry.spellID == 3001, "one active buff shows")
	Write("rules.hide", "3001")
	assert(row.count == 0, "Hide these drops a tracked buff")
	Write("rules.hide", "")
	Write("rules.missing", "3002")
	assert(row.count == 2 and row.icons[2].entry.spellID == 3002, "a missing reminder shows while the buff is off you")
	cdm.auras[3002] = { auraInstanceID = 72 }; Aura(env)
	assert(row.count == 1 and row.icons[1].entry.spellID == 3001, "it hides once the buff is on you")
	cdm.auras[3002] = nil; Aura(env)
	Write("rules.missing", "")

	Write("glowSource", "custom"); Write("glowColor", { r = 0.3, g = 0.2, b = 0.1 }); Write("rules.activeGlow", "3001")
	local icon = row.icons[1]
	assert(icon.ready and icon.readyGlow.colorRGB[1] == 0.3, "Glow while active lights an active buff in the glow tint")
	cdm.auras[3001] = nil; Write("buffs.inactive", true); Aura(env)
	assert(not IconOf(ns, "buffs", 3001).ready, "it stops when the buff falls off")
	cdm.auras[3001] = { auraInstanceID = 71 }; Aura(env)
	Write("rules.activeGlow", "")
	assert(not row.icons[1].ready and not row.icons[1].readyGlow.colorRGB, "clearing it stops the glow and its tint")

	Write("buffs.showCount", false); Write("rules.count", "3001")
	assert(row.icons[1].count:GetAlpha() == 1, "Show counts shows a buff's stacks over the group switch")
	Write("rules.count", ""); Write("buffs.showCount", true)
	Write("rules.tint", "3001 #FF0000")
	row.icons[1]:Paint()
	assert(W.LastCall(row.icons[1].cooldown, "SetSwipeColor")[1] == 1, "a tracked buff's swipe takes its own colour")
	Write("rules.tint", "")

	Write("buffs.inactive", false); Write("buffs.keepPlace", true)
	cdm.auras[3001], cdm.auras[3002] = nil, { auraInstanceID = 72 }; Aura(env)
	assert(row.count == 2 and row.icons[1].blank and row.icons[1]:GetAlpha() == 0 and not row.icons[1]:IsMouseEnabled(), "an inactive buff keeps an empty slot")
	assert(row.icons[2].entry.spellID == 3002 and row.icons[2]:GetAlpha() == 1, "the active buff stays in its own place")
	Write("buffs.keepPlace", false)
	assert(row.count == 1 and row.icons[1].entry.spellID == 3002 and row.icons[1]:GetAlpha() == 1 and row.icons[1]:IsMouseEnabled(), "switching off packs the row and restores the icon")
	Clean(env, K, "tracked buffs")
end

-- KstyleUI tracked buff bars: names, fill, smoothing, spark, wrap and tenths.
do
	local env, K, ns, Write = New("mirror")
	local bar = ns.Mirror.Row("bars").bars[1]
	Write("rules.names", "4001=Haste, 4002 = Shield")
	assert(bar.name:GetText() == "Haste", "a bar takes its new name")
	Write("rules.names", "")
	assert(bar.name:GetText() == "Spell 4001", "and returns to the spell's name")
	Write("bars.fillUp", true); Write("bars.smooth", true)
	local timer = W.LastCall(bar.status, "SetTimerDuration")
	assert(timer[2] == env.Enum.StatusBarInterpolation.ExponentialEaseOut and timer[3] == env.Enum.StatusBarTimerDirection.ElapsedTime, "Fill up and Smooth bars reach the timer")
	Write("bars.fillUp", false); Write("bars.smooth", false)
	timer = W.LastCall(bar.status, "SetTimerDuration")
	assert(timer[2] == 0 and timer[3] == env.Enum.StatusBarTimerDirection.RemainingTime, "and restore it")
	Write("bars.spark", true)
	local point = W.LastCall(bar.status.spark, "SetPoint")
	assert(bar.status.spark:IsShown() and point[3] == "RIGHT", "the spark rides the fill's end")
	Write("bars.orientation", "VERTICAL"); Write("bars.reverse", true)
	assert(W.LastCall(bar.status.spark, "SetPoint")[3] == "BOTTOM", "and follows the fill's direction")
	Write("bars.orientation", "HORIZONTAL"); Write("bars.reverse", false); Write("bars.spark", false)
	assert(not bar.status.spark:IsShown(), "off hides it")
	Write("bars.height", 28); Write("bars.nameWrap", true)
	assert(W.LastCall(bar.name, "SetWordWrap")[1] == true and W.LastCall(bar.name, "SetMaxLines")[1] == 2, "a tall bar wraps its name over two lines")
	Write("bars.height", 12)
	assert(W.LastCall(bar.name, "SetMaxLines")[1] == 1, "a short bar keeps one line")
	Write("bars.nameWrap", false)
	assert(W.LastCall(bar.name, "SetWordWrap")[1] == false and W.LastCall(bar.name, "SetMaxLines")[1] == 0, "off restores the single line")
	Write("bars.decimals", true); Write("bars.decimalBelow", 4)
	local seconds = W.LastCall(bar.timer, "SetCountdownFormatter")[1]
	local found = false
	for _, call in ipairs(seconds.calls) do found = found or call.method == "SetMillisecondsThreshold" and call.args[1] == 4 end
	assert(found, "the bar timer shows tenths below its threshold")
	Write("bars.decimals", false)
	assert(W.LastCall(bar.timer, "SetCountdownFormatter")[1] ~= seconds, "off restores the plain formatter")
	Write("bars.showCount", false); Write("rules.count", "4001")
	assert(bar.count:GetAlpha() == 1, "Show counts reaches a bar")
	Write("rules.count", ""); Write("bars.showCount", true)
	Clean(env, K, "tracked bars")
end

-- Restyled Blizzard viewers: counts, countdown colours and the active glow follow each item's spell and state.
do
	local env, K, ns, Write = New("reskin")
	local buffs = env._viewers.BuffIconCooldownViewer._items
	local item = env._viewers.EssentialCooldownViewer._items[1]
	Write("buffs.showCount", false); Write("rules.count", "3001")
	assert(buffs[1].Applications.Applications:GetAlpha() == 1 and buffs[2].Applications.Applications:GetAlpha() == 0, "Show counts reaches Blizzard's buff by its spell")
	Write("rules.count", ""); Write("buffs.showCount", true)
	Write("essential.showCount", false); Write("rules.count", "1001")
	assert(item.ChargeCount.Current:GetAlpha() == 1, "and Blizzard's charges")
	Write("rules.count", ""); Write("essential.showCount", true)

	local countdown = item.Cooldown:GetCountdownFontString()
	Write("rules.timerColour", "1001 #00FF00")
	assert(W.LastCall(countdown, "SetTextColor")[2] == 1, "a restyled countdown takes its spell's colour")
	Write("rules.timerColour", "")
	assert(Near(W.LastCall(countdown, "SetTextColor")[2], K.Widgets.Rgba("textEmphasis") and select(2, K.Widgets.Rgba("textEmphasis"))), "and returns to the restyle's colour")

	buffs[2]._active = false
	Write("rules.activeGlow", "3001, 3002")
	local glow = K.Safe.Side(buffs[1]).glow
	assert(glow and glow.playing and not K.Safe.Side(buffs[2]).glow, "an active restyled buff glows, an inactive one does not")
	buffs[1]._active = false; buffs[1]:UpdateShownState(); env.RunTimers()
	assert(not glow.playing, "the glow stops when the buff turns inactive")
	buffs[1]._active = true; buffs[1]:UpdateShownState(); env.RunTimers()
	assert(glow.playing, "and returns with it")
	ns.definition.Disable()
	assert(not glow.playing, "stopping the module stops the glow")
	Clean(env, K, "restyled viewers")
end

-- The preview follows the new options.
do
	local env, K, ns, Write = New("mirror")
	local parent = env.CreateFrame("Frame", nil, env.UIParent)
	parent:SetSize(280, 300)
	local frame = ns.Preview.Build(parent)
	Write("assist", true); Write("essential.numbersOnly", true); Write("rules.activeGlow", "x"); Write("bars.fillUp", true); Write("bars.spark", true)
	frame:Refresh()
	local essential, buffs, bar = frame.rows.essential, frame.rows.buffs, frame.rows.bars.bars[1]
	assert(essential.icons[2].assistGlow.playing and not essential.icons[1].assistGlow, "the preview shows the helper on one sample")
	assert(essential.icons[1].icon:GetAlpha() == 0, "the preview shows numbers only")
	assert(buffs.icons[1].ready and not buffs.icons[3].ready, "the preview glows the active buff samples")
	assert(math.abs(W.LastCall(bar.status, "SetValue")[1] - 0.4) < 0.01 and bar.status.spark:IsShown(), "the preview bars fill up with a spark")
	Write("rules.hide", "x")
	frame:Refresh()
	assert(buffs.icons[1]:GetAlpha() == 0 and essential.icons[1]:GetAlpha() == 0, "the preview hides listed samples")
	Clean(env, K, "preview")
end

print("cooldowns parity round 2 ok")
