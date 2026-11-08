-- test-cooldowns-mirror.lua: the Cooldowns mirror draws the essential and utility cooldowns as KstyleUI icons driven by duration objects, fades Blizzard's viewers, and falls back when the mirror fails.
local C = dofile("Tools/regression/cooldowns_env.lua")
local W = C.W

local function New(opts)
	opts = opts or {}
	local setup = opts.setup
	opts.setup = function(env)
		C.Game(env)
		if setup then
			setup(env)
		end
	end
	return C.New(opts)
end

local function LastArg(frame, method)
	local call = W.LastCall(frame, method)
	return call and call[1]
end

local function Row(ns, group)
	return ns.Mirror.Row(group)
end

local function Spells(row)
	local out = {}
	for i = 1, row.count do
		out[i] = row.icons[i].entry.spell
	end
	return table.concat(out, ",")
end

-- Off by default, and nothing runs until Enable.
do
	local env, K, ns = New()
	assert(K.Modules.IsEnabled("Cooldowns") == false, "the module is off by default")
	assert(ns.Mirror.Row("essential") == nil, "no row exists before Enable")
	assert(env._viewers.EssentialCooldownViewer:GetAlpha() == 1, "Blizzard's viewer is untouched before Enable")
end

-- Enable builds both rows from the Cooldown Manager's data, in the HUD band.
local env, K, ns = New()
C.Enable(env, K)
local essential, utility = Row(ns, "essential"), Row(ns, "utility")
assert(essential and utility, "Enable builds the essential and utility rows")
assert(essential.count == 3 and Spells(essential) == "1001,1002,1033", "essential icons: " .. Spells(essential))
assert(utility.count == 2 and Spells(utility) == "2001,2002", "utility icons: " .. Spells(utility))
assert(ns.Path.Get("essential") == "mirror" and ns.Path.Get("utility") == "mirror", "both rows take the mirror path")

-- Layout places both rows under their element keys at the setup's default positions, scalable.
local function Registered(key)
	for _, element in ipairs(K.Layout.Elements()) do
		if element.key == key then
			return element
		end
	end
end
for _, key in ipairs({ "cooldowns.essential", "cooldowns.utility" }) do
	local element = Registered(key)
	assert(element, key .. " must register with Layout")
	assert(element.module == "Cooldowns", key .. " belongs to the Cooldowns module")
	assert(element.opts.scalable == true, key .. " is scalable")
	assert(element.label == K.Setup.Layouts.Element(key).label, key .. " uses the setup's label")
end
local ew, eh = essential.holder:GetSize()
assert(ew == 376 and eh == 56, "the essential holder is its 376 by 56 footprint, got " .. tostring(ew) .. " by " .. tostring(eh))
local uw, uh = utility.holder:GetSize()
assert(uw == 238 and uh == 52, "the utility holder is its 238 by 52 footprint")
assert(essential.icons[1].opts.size == 56 and utility.icons[1].opts.size == 52, "icons are 56 and 52 units")

-- The cooldown rows' countdowns read "4s" and "2m", as the mockup's centre cluster does: a one-letter seconds
-- formatter from C_StringUtil goes on each Cooldown; the tracked buff icons keep the engine's numbers.
do
	local formatter = LastArg(essential.icons[1].cooldown, "SetCountdownFormatter")
	assert(type(formatter) == "table" and formatter:Format(4) == "4s" and formatter:Format(120) == "2m", "an essential icon's countdown has the one-letter formatter")
	assert(LastArg(utility.icons[1].cooldown, "SetCountdownFormatter") == formatter, "the utility row shares it")
	assert(essential.icons[1].countdown._points[1][1] == "TOPRIGHT", "the countdown sits in the icon's top right corner")
	local buffRow = ns.Row.New(env.UIParent, "buffs", ns.Settings.current.buffs)
	local buffIcon = buffRow:Icon(1)
	assert(W.LastCall(buffIcon.cooldown, "SetCountdownFormatter") == nil, "the tracked buff icons keep the engine's numbers")
	assert(buffIcon.countdown._points[1][1] == "CENTER", "a tracked buff icon keeps its countdown centred low")
end

-- Each icon's cooldown comes from the API's duration object, the global cooldown left out by default.
for i, spell in ipairs({ 1001, 1002, 1033 }) do
	local duration = LastArg(essential.icons[i].cooldown, "SetCooldownFromDurationObject")
	assert(duration == env._cdm.durations[spell], "icon " .. i .. " shows the duration object of spell " .. spell)
end
for _, args in ipairs(C.Calls(env, "GetSpellCooldownDuration")) do
	assert(args[2] == true, "the global cooldown is ignored by default")
end

-- A charge spell shows its charges and its recharge; the count may be secret.
env._cdm.charges[1002] = { current = 1, max = 2 }
env.FireEvent("SPELL_UPDATE_CHARGES")
local charged = essential.icons[2]
local count = charged.count:GetText()
assert(env.issecretvalue(count) and env.Reveal(count) == 1, "the charge count reaches SetText as the secret it is")
assert(LastArg(charged.chargeCooldown, "SetCooldownFromDurationObject") == env._cdm.chargeDurations[1002], "the recharge sweeps from its duration object")

-- SPELL_UPDATE_COOLDOWN refreshes every icon with the new duration objects.
env._cdm.durations[1001] = C.Duration(1001, "fresh")
env.FireEvent("SPELL_UPDATE_COOLDOWN")
assert(LastArg(essential.icons[1].cooldown, "SetCooldownFromDurationObject") == env._cdm.durations[1001], "a cooldown update reaches the icon")

-- A secret duration object passes through untouched.
env._cdm.durations[2001] = env.Secret(C.Duration(2001))
env.FireEvent("SPELL_UPDATE_COOLDOWN")
assert(LastArg(utility.icons[1].cooldown, "SetCooldownFromDurationObject") == env._cdm.durations[2001], "a secret duration reaches the widget")
assert(ns.Path.Get("utility") == "mirror", "a secret duration is not a failure")

-- Ready glow: a spell on a real cooldown has none; a ready one glows; the global cooldown alone keeps it ready.
env._cdm.cooldown[1001] = { active = true }
env._cdm.cooldown[1033] = { active = true, gcd = true }
env.FireEvent("SPELL_UPDATE_COOLDOWN")
W.Settle(env)
assert(essential.icons[1].ready == false, "a spell on cooldown is not ready")
assert(essential.icons[2].ready == true and essential.icons[2].readyGlow:IsPlaying(), "a ready spell glows")
assert(essential.icons[3].ready == true, "the global cooldown alone keeps a spell ready")
assert(utility.icons[1].ready == false, "utility icons have no ready glow by default")
assert(essential.icons[1].onCooldown == true, "the cooling icon is marked for greying")

-- The cooldown widget finishing re-checks the state.
env._cdm.cooldown[1001] = nil
essential.icons[1].cooldown:GetScript("OnCooldownDone")(essential.icons[1].cooldown)
assert(essential.icons[1].ready == true, "a finished cooldown makes the spell ready")

-- Proc glow follows Blizzard's highlight events, and a secret spell ID re-checks every icon.
env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 1001)
assert(essential.icons[1].proc == true, "the highlight event lights the icon")
env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 1001)
assert(essential.icons[1].proc == false, "the hide event clears it")
env._cdm.overlay[2002] = true
env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", env.Secret(2002))
assert(utility.icons[2].proc == true, "a secret spell ID re-checks every icon")

-- Usable shading follows SPELL_UPDATE_USABLE.
env._cdm.usable[2001] = { usable = false, noMana = true }
env.FireEvent("SPELL_UPDATE_USABLE")
assert(utility.icons[1].usable == false, "an unusable spell dims its icon")

-- An override swaps the spell an entry queries.
env.FireEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", 1001, 1111)
assert(essential.icons[1].entry.spell == 1111, "the override event moves the icon to the new spell")
local queried = C.Calls(env, "GetSpellCooldownDuration")
assert(queried[#queried][1] == 1111, "the overridden icon refreshes at once")

-- Icons go through the Icons service with the spell's file ID.
assert(essential.icons[1].icon:GetTexture() == 501001 or essential.icons[1].icon:GetTexture() == 501111, "the icon texture is the spell's file ID")

-- Blizzard's viewers are faded, kept faded against their own SetAlpha, and their items take no mouse.
local blizzard = env._viewers.EssentialCooldownViewer
assert(blizzard:GetAlpha() == 0, "Blizzard's essential viewer is faded")
blizzard:SetAlpha(0.8)
assert(blizzard:GetAlpha() == 0, "Blizzard's own SetAlpha cannot bring it back")
for _, child in ipairs({ blizzard:GetChildren() }) do
	assert(LastArg(child, "SetMouseMotionEnabled") == false, "a faded viewer's item takes no mouse")
end
local item = C.Item(env, blizzard, 9)
blizzard:OnAcquireItemFrame(item)
assert(LastArg(item, "SetMouseMotionEnabled") == false, "a newly acquired item takes no mouse while faded")
assert(env._viewers.BuffIconCooldownViewer:GetAlpha() == 1, "the buff viewers are not part of this mirror")
for _, call in ipairs(blizzard._calls) do
	assert(call.method ~= "Hide" and call.method ~= "SetParent" and call.method ~= "SetPoint" and call.method ~= "SetScript", "the viewer is never hidden, moved or scripted: " .. call.method)
end

-- Tooltips: the pointer over an icon shows its spell; switching them off lets the pointer through.
W.Enter(essential.icons[2])
assert(env.GameTooltip.shown and env.GameTooltip.spell == 1002, "an icon shows its spell's tooltip")
W.Leave(essential.icons[2])
assert(not env.GameTooltip.shown, "leaving the icon hides it")
assert(LastArg(essential.icons[2], "SetMouseClickEnabled") == false, "clicks pass through the icons")
K.Options.Write("Cooldowns", "tooltips", false)
assert(LastArg(essential.icons[2], "EnableMouse") == false, "without tooltips the icons take no mouse")

-- Settings reach the rows at once: size, spacing, columns and the timer.
K.Options.Write("Cooldowns", "essential.size", 36)
assert(essential.icons[1].opts.size == 36, "the icon size follows the setting")
local w36 = essential.holder:GetWidth()
assert(w36 == 6 * 36 + 5 * 8, "the holder follows the icon size, got " .. tostring(w36))
K.Options.Write("Cooldowns", "essential.columns", 2)
assert(essential.count == 2, "a row of two shows two icons")
assert(not essential.icons[3]:IsShown(), "the third icon hides")
K.Options.Write("Cooldowns", "essential.rows", 2)
assert(essential.count == 3, "a second row shows the third icon again")
K.Options.Write("Cooldowns", "utility.timer", false)
assert(LastArg(utility.icons[1].cooldown, "SetHideCountdownNumbers") == true, "timers can be switched off")
K.Options.Write("Cooldowns", "essential.gcd", true)
local asked
for _, args in ipairs(C.Calls(env, "GetSpellCooldownDuration")) do
	if args[1] == 1002 then
		asked = args[2]
	end
end
assert(asked == false, "with the global cooldown on, the API is asked for it")

-- A scale change in Layout Mode redraws the icons on whole pixels.
local restyles = #W.Calls(essential.icons[1], "SetSize")
K.Layout.Set("cooldowns.essential", "scale", 1.25)
assert(#W.Calls(essential.icons[1], "SetSize") > restyles, "a Layout scale change restyles the icons")

-- A custom accent tints the ready glow.
K.Options.Write("Cooldowns", "accent", "custom")
K.Options.Write("Cooldowns", "accentColor", { r = 1, g = 0, b = 0 })
local piece = essential.icons[2].readyGlow.slice[1]
local r, g, b = piece:GetVertexColor()
assert(r == 1 and g == 0 and b == 0, "the ready glow takes the custom accent")
local er, eg, eb = essential.icons[2].chrome.edge[1], essential.icons[2].chrome.edge[2], essential.icons[2].chrome.edge[3]
local wr, wg, wb = K.Tokens.Color("textHover")
local lr, lg, lb = K.Widgets.Mix(1, 0, 0, 1, wr, wg, wb, 1, 0.15)
assert(W.Near(er, lr) and W.Near(eg, lg) and W.Near(eb, lb), "the icon hairline takes the custom accent, lifted 15% toward white at rest")
K.Options.Write("Cooldowns", "accent", "class")
assert(essential.icons[2].accent == nil, "the class accent follows the theme again")

-- The devlog and /kstyle test report the path.
local passed = false
for _, line in ipairs(env.KstyleUIDB.devlog) do
	if line.module == "Cooldowns" and tostring(line.message):find("essential: mirror path", 1, true) then
		passed = true
	end
end
assert(passed, "the chosen path is logged to the devlog")

-- Disable hides the rows and gives Blizzard's viewers back their alpha.
K.Modules.Disable("Cooldowns")
assert(not essential.holder:IsShown(), "Disable hides the essential row")
assert(blizzard:GetAlpha() == 0.8, "Disable restores the alpha Blizzard last asked for")
for _, child in ipairs({ blizzard:GetChildren() }) do
	assert(LastArg(child, "SetMouseMotionEnabled") == true, "Disable gives the items their mouse back")
end
local before = #C.Calls(env, "GetSpellCooldownDuration")
env.FireEvent("SPELL_UPDATE_COOLDOWN")
assert(#C.Calls(env, "GetSpellCooldownDuration") == before, "a disabled module hears no events")

-- Enabling again reuses the rows.
C.Enable(env, K)
assert(Row(ns, "essential") == essential and essential.holder:IsShown(), "Enable again shows the same row")
assert(blizzard:GetAlpha() == 0, "Enable again fades the viewer")

-- A mirror that fails falls back: the row hides and Blizzard's viewer comes back.
env._cdm.durationError = "secret arguments are not allowed"
env.FireEvent("SPELL_UPDATE_COOLDOWN")
assert(ns.Path.Get("essential") == "reskin", "a failing duration call switches the row to the reskin")
assert(not essential.content:IsShown(), "the failed row hides its icons")
assert(blizzard:GetAlpha() == 0.8, "Blizzard's viewer shows again")
env._cdm.durationError = nil
K.Modules.Disable("Cooldowns")

-- No duration API: the mirror never starts and Blizzard's viewer stays as it is.
do
	local env2, K2, ns2 = New({ noDuration = true })
	C.Enable(env2, K2)
	assert(ns2.Path.Get("essential") == "reskin", "without duration objects the row restyles Blizzard's viewer")
	assert(env2._viewers.EssentialCooldownViewer:GetAlpha() == 1, "Blizzard's viewer is left alone")
	assert(ns2.Mirror.Row("essential") == nil, "no row is built")
end

-- A dirty Blizzard layout keeps the order the player had, and a clean one later takes over.
do
	local env3, K3, ns3 = New({ layout = { order = { 103, 101, 102, 104, 201, 202, 203, 301, 302, 401, 402 } } })
	C.Enable(env3, K3)
	local row = ns3.Mirror.Row("essential")
	assert(Spells(row) == "1033,1001,1002", "the clean layout's order: " .. Spells(row))
	env3._cdm.provider.dirty = true
	C.Trigger(env3, "CooldownViewerSettings.OnDataChanged")
	env3.RunTimers()
	assert(Spells(row) == "1033,1001,1002", "a dirty layout keeps the last order: " .. Spells(row))
	env3._cdm.provider.dirty = false
	env3._cdm.provider.displayData.orderedCooldownIDs = { 102, 101, 103, 104, 201, 202, 203, 301, 302, 401, 402 }
	C.Trigger(env3, "CooldownViewerSettings.OnDataChanged")
	env3.RunTimers()
	assert(Spells(row) == "1002,1001,1033", "a clean layout applies: " .. Spells(row))
	K3.Modules.Disable("Cooldowns")
	assert(next(env3._cdm.callbacks["CooldownViewerSettings.OnDataChanged"]) == nil, "Disable unregisters the EventRegistry callback")
end

-- A dirty layout at startup retries until Blizzard's data is clean.
do
	local env5, K5, ns5 = New({ dirty = true, layout = { order = { 103, 101, 102, 104, 201, 202, 203, 301, 302, 401, 402 } } })
	C.Enable(env5, K5)
	local row = ns5.Mirror.Row("essential")
	assert(Spells(row) == "1001,1002,1033", "a dirty start shows the defaults: " .. Spells(row))
	env5._cdm.provider.dirty = false
	env5.RunTimers()
	assert(Spells(row) == "1033,1001,1002", "the retry picks up the clean layout: " .. Spells(row))
end

-- A category set that cannot be read gives Blizzard's viewer back instead of an empty row.
do
	local env6, K6, ns6 = New()
	env6._cdm.secretSet = true
	C.Enable(env6, K6)
	assert(ns6.Path.Get("essential") == "reskin", "an unreadable category set switches the row to the reskin")
	assert(env6._viewers.EssentialCooldownViewer:GetAlpha() == 1, "Blizzard's viewer stays visible")
end

-- A potion or healthstone entry has a spell category and no spell: it shows the category's icon and
-- the cooldown of the last item used in that category.
do
	local cooldowns = C.Sample()
	cooldowns[204] = { spellCategoryID = 30, category = C.CATEGORY.Utility }
	local env7, K7, ns7 = New({ cooldowns = cooldowns })
	C.Enable(env7, K7)
	local row = ns7.Mirror.Row("utility")
	local potion = row.icons[3]
	assert(row.count == 3 and potion.entry.categoryID == 30, "the category entry gets an icon")
	assert(potion.icon:GetTexture() == ns7.Data.CATEGORY_ICONS[30], "it shows the category's icon")
	env7._cdm.categorySource[30] = env7.Secret(2222)
	env7.FireEvent("SPELL_UPDATE_COOLDOWN")
	local categorySpell
	for _, args in ipairs(C.Calls(env7, "GetSpellCooldownDuration")) do
		if env7.issecretvalue(args[1]) then
			categorySpell = env7.Reveal(args[1])
		end
	end
	assert(categorySpell == 2222, "the last item's spell drives the sweep, even while it is secret")
	assert(ns7.Path.Get("utility") == "mirror", "a category entry is not a failure")
end

-- Enabling in combat works: nothing the mirror does is protected.
do
	local env4, K4, ns4 = New()
	env4.SetCombat(true)
	K4.Options.Write("Cooldowns", "enabled", true)
	env4.SetCombat(false)
	assert(ns4.Mirror.Row("essential").count == 3, "the module starts once combat ends and builds its rows")
end

print("cooldowns mirror ok")
