-- test-cooldowns-parity-round3.lua: EllesmereUI parity round 3 for Cooldowns: every new option keeps today's defaults on a v0.2.8 profile, applies when switched on (recharge swipe and countdown, threshold colour, forms, swing sweep and late glow, ready sound, numbers above glows, two-row sizes, item counts, missing items, all trinkets, the focus interrupt, its cast sound and reminders), follows the events that change it, restores when switched off, and reaches the preview.
local C = dofile("Tools/regression/cooldowns_env.lua")
local W = C.W

local game

local function Setup(e)
	C.Game(e)
	game = { sounds = {}, forms = {}, plates = {}, units = { player = "self" }, power = {}, equipped = {}, counts = { [7001] = 3 } }
	local U = C.CATEGORY.Utility
	e._cdm.cooldowns[204] = { category = U, spellCategoryID = 30 }
	e._cdm.charges[1002] = { current = 1, max = 2 }
	e.SOUNDKIT = { RAID_WARNING = 8959, READY_CHECK = 8960 }
	e.PlaySound = function(kit) game.sounds[#game.sounds + 1] = kit end
	e.GetNumShapeshiftForms = function() return #game.forms end
	e.GetShapeshiftFormInfo = function(i) return 1, game.forms[i].active, true, game.forms[i].spell end
	e.Enum.PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 }
	e.C_Spell.IsCurrentSpell = function(spell) return game.queued == spell end
	e.C_Spell.GetSpellIDForSpellIdentifier = function(name) return name == "Kick" and 1766 or nil end
	e.C_Spell.GetSpellCastCount = function(spell) return game.counts[spell] or 0 end
	e.C_Spell.GetLastCategoryCooldownSource = function() return 7001, 8001 end
	e.C_Spell.GetItemCooldown = function() return { startTime = 0, duration = 0, modRate = 1, isEnabled = true, isActive = false, isOnGCD = false } end
	e.C_NamePlate = { GetNamePlateForUnit = function(unit) return game.plates[unit] end }
	e.UnitExists = function(unit) return game.units[unit] ~= nil end
	e.UnitIsUnit = function(a, b) return a == b end
	e.UnitCanAttack = function(_, unit) return game.units[unit] == "enemy" end
	e.UnitPowerType = function(unit) return game.power[unit] or 1 end
	e.IsInInstance = function() return game.instance ~= nil, game.instance or "none" end
	e.GetInventoryItemID = function(_, slot) return game.equipped[slot] end
	e.GetInventoryItemCooldown = function() return 0, 0, 1, false end
	e.GetInventoryItemTexture = function(_, slot) return 600000 + slot end
end

local function New(path)
	local saved = { version = 42, profiles = { Default = { Cooldowns = { enabled = true, path = path } } }, characters = {} }
	local env, K, ns = C.New({ saved = saved, setup = Setup })
	env.RunTimers()
	return env, K, ns, function(key, value) K.Options.Write("Cooldowns", key, value); env.RunTimers() end
end

local function IconOf(ns, group, test)
	local row = ns.Mirror.Row(group)
	for i = 1, row.count do
		local entry = row.icons[i].entry
		if entry and (entry.spellID == test or entry.categoryID == test or entry.equipSlot == test) then return row.icons[i] end
	end
end

local function Last(object, method) local call = W.LastCall(object, method) return call and call[1] end
local function Clean(env, K, what) assert(#env._errors == 0 and K.ErrorCount() == 0, what .. " raised no errors") end
local function Registered(env, event)
	for _, frame in ipairs(env._frames) do if frame._events[event] then return true end end
	return false
end
local function Fire(env, ...) env.FireEvent(...); env.RunTimers() end

-- Defaults: a v0.2.8 profile keeps every new option off and every icon as it was.
do
	local env, K, ns = New("mirror")
	local current = ns.Settings.current
	assert(current.thresholdBelow == 5 and current.swingWindow == 0.5 and current.readySound == "" and not current.textAboveGlow, "new module options default off")
	assert(current.focusSpell == "" and current.focusSide == "LEFT" and not current.focusTarget and current.focusSound == "" and not current.focusReminder, "the focus interrupt defaults off")
	for _, group in ipairs({ "essential", "utility" }) do
		local cfg = current[group]
		assert(cfg.baseCount == 0 and cfg.baseSize == 0 and cfg.secondSize == 0 and cfg.itemCount and not cfg.hideMissing and not cfg.trinkets, group .. " keeps its grid and items")
	end
	local a, b, potion = IconOf(ns, "essential", 1001), IconOf(ns, "essential", 1002), IconOf(ns, "utility", 30)
	assert(Last(a.cooldown, "SetCountdownFormatter").breakpoints[1].format == "%d", "countdowns keep their plain numbers")
	assert(b.chargeCooldown and Last(b.chargeCooldown, "SetDrawSwipe") == false and Last(b.chargeCooldown, "SetHideCountdownNumbers") == true, "a recharge still draws only its edge")
	assert(potion and tostring(potion.count:GetText()) == "3" and potion:GetAlpha() == 1, "a potion shows its count as before")
	assert(not a.swingSweep and not a.lateGlow and #game.sounds == 0, "no sweep, glow or sound")
	assert(not Registered(env, "NAME_PLATE_UNIT_ADDED") and not Registered(env, "UNIT_SPELLCAST_START") and not ns.Focus.icon, "the focus interrupt listens to nothing")
	assert(ns.Mirror.Row("utility").count == 3, "no trinket is added")
	Clean(env, K, "defaults")
end

-- Recharge swipe and countdown, each on alone, through events, then off.
do
	local env, K, ns, Write = New("mirror")
	local b = IconOf(ns, "essential", 1002)
	local charge = b.chargeCooldown
	Write("rules.chargeTimer", "1002")
	assert(Last(charge, "SetHideCountdownNumbers") == false and Last(charge, "SetDrawSwipe") == false, "Recharge countdown works without Recharge swipe")
	assert(W.LastCall(charge:GetCountdownFontString(), "SetPoint")[2] == b.countdown, "the recharge countdown sits where the countdown does")
	Write("rules.chargeSwipe", "1002")
	assert(Last(charge, "SetDrawSwipe") == true and Last(charge, "SetSwipeTexture"), "Recharge swipe shades the recharge in the socket's mask")
	local writes = #W.Calls(charge, "SetDrawSwipe")
	Fire(env, "SPELL_UPDATE_CHARGES")
	assert(#W.Calls(charge, "SetDrawSwipe") == writes, "a charge event writes nothing it already set")
	env._cdm.cooldown[1002] = { active = true }; Fire(env, "SPELL_UPDATE_COOLDOWN")
	assert(Last(charge, "SetHideCountdownNumbers") == true and Last(charge, "SetDrawSwipe") == false, "with no charge left the spell's own countdown and swipe show alone")
	env._cdm.cooldown[1002] = { active = false }; Fire(env, "SPELL_UPDATE_COOLDOWN")
	assert(Last(charge, "SetHideCountdownNumbers") == false and Last(charge, "SetDrawSwipe") == true, "a charge back brings the recharge look back")
	Write("essential.timer", false)
	assert(Last(charge, "SetHideCountdownNumbers") == true, "Timers off hides the recharge countdown too")
	Write("essential.timer", true); Write("rules.chargeSwipe", ""); Write("rules.chargeTimer", "")
	assert(Last(charge, "SetDrawSwipe") == false and Last(charge, "SetHideCountdownNumbers") == true, "clearing the lists restores the edge-only recharge")
	Clean(env, K, "recharge")
end

-- Colour below threshold: its own colour or a spell's, alone or with tenths, then off.
do
	local env, K, ns, Write = New("mirror")
	local a, c = IconOf(ns, "essential", 1001), IconOf(ns, "essential", 1003)
	Write("thresholdColor", { r = 1, g = 0, b = 0 }); Write("rules.threshold", "1001, 1003 #00FF00")
	local points = Last(a.cooldown, "SetCountdownFormatter").breakpoints
	assert(points[1].format == "|cffff0000%d|r" and points[2].threshold == 5 and points[2].format == "%d", "listed countdowns turn the threshold colour below 5 seconds")
	assert(Last(c.cooldown, "SetCountdownFormatter").breakpoints[1].format == "|cff00ff00%d|r", "a spell's own colour wins")
	Write("rules.decimals", "1001"); Write("decimalBelow", 3)
	points = Last(a.cooldown, "SetCountdownFormatter").breakpoints
	assert(points[1].format == "|cffff0000%.1f|r" and points[2].threshold == 3 and points[2].format == "|cffff0000%d|r" and points[3].threshold == 5, "tenths and colour share the countdown")
	Write("readableCountdown", false)
	assert(Last(a.cooldown, "SetCountdownFormatter").breakpoints[1].format:find("|cff"), "the colour stays with the seconds style")
	Write("readableCountdown", true); Write("rules.decimals", ""); Write("rules.threshold", "")
	assert(Last(a.cooldown, "SetCountdownFormatter").breakpoints[1].format == "%d", "clearing the list restores the plain countdown")
	Clean(env, K, "threshold")
end

-- Hide outside form: a named form or any form, on its event, with Close gaps, then off.
do
	local env, K, ns, Write = New("mirror")
	local a, b = IconOf(ns, "essential", 1001), IconOf(ns, "essential", 1002)
	Write("essential.growth", "right")
	local slotA = Last(a, "SetPoint") and W.LastCall(a, "SetPoint")[4]
	game.forms = { { spell = 768, active = false }, { spell = 5487, active = false } }
	Write("rules.form", "1001=spell 768")
	assert(a:GetAlpha() == 0 and not a:IsMouseEnabled(), "outside the named form the icon hides")
	game.forms[2].active = true; Fire(env, "UPDATE_SHAPESHIFT_FORM")
	assert(a:GetAlpha() == 0, "another form keeps it hidden")
	game.forms[2].active, game.forms[1].active = false, true; Fire(env, "UPDATE_SHAPESHIFT_FORM")
	assert(a:GetAlpha() == 1 and a:IsMouseEnabled(), "the named form shows it, in any case")
	Write("rules.form", "1001")
	assert(a:GetAlpha() == 1, "a spell named alone shows in any form")
	game.forms[1].active = false; Fire(env, "UPDATE_SHAPESHIFT_FORM")
	assert(a:GetAlpha() == 0, "and hides outside every form")
	Write("closeGaps", true)
	assert(W.LastCall(b, "SetPoint")[4] == slotA, "Close gaps moves the next icon into its place")
	env.SetCombat(true); game.forms[1].active = true; Fire(env, "UPDATE_SHAPESHIFT_FORM")
	assert(a:GetAlpha() == 1, "forms apply in combat")
	env.SetCombat(false); game.forms[1].active = false; Fire(env, "UPDATE_SHAPESHIFT_FORM")
	env.GetNumShapeshiftForms = nil; Fire(env, "UPDATE_SHAPESHIFT_FORM")
	assert(a:GetAlpha() == 1, "without the form API nothing is hidden")
	Write("closeGaps", false); Write("rules.form", "")
	assert(a:GetAlpha() == 1 and W.LastCall(a, "SetPoint")[4] == slotA, "clearing the list restores the icon and its slot")
	Clean(env, K, "forms")
end

-- Swing timer and the late-swing glow, on main hand swings only, with the queue and the window, then off.
do
	local env, K, ns, Write = New("mirror")
	local a, b = IconOf(ns, "essential", 1001), IconOf(ns, "essential", 1002)
	local after, delays = env.C_Timer.After, {}
	env.C_Timer.After = function(delay, fn) if delay > 0 then delays[#delays + 1] = { delay, fn } else after(delay, fn) end end
	Write("rules.swing", "1001")
	Fire(env, "PLAYER_SWING", 2.6, 1)
	assert(not a.swingSweep, "an off-hand swing sweeps nothing")
	Fire(env, "PLAYER_SWING", env.Secret(2.6), 0)
	assert(not a.swingSweep, "a secret swing is refused")
	Fire(env, "PLAYER_SWING", 2.6, 0)
	local sweep = W.LastCall(a.swingSweep, "SetCooldown")
	assert(sweep[1] == env._time and sweep[2] == 2.6 and not b.swingSweep, "a main hand swing sweeps the listed icon only")
	Write("rules.swingGlow", "1001 #FF0000"); Write("swingWindow", 0.8)
	Fire(env, "PLAYER_SWING", 2.6, 0)
	assert(#delays == 2 and math.abs(delays[1][1] - 1.8) < 1e-6 and delays[2][1] == 2.6, "the glow waits for the last 0.8 seconds")
	assert(not a.lateGlow or not a.lateGlow.playing, "no glow early in the swing")
	delays[1][2]()
	assert(a.lateGlow.playing and a.lateGlow.colorRGB[1] == 1 and a.lateGlow.colorRGB[2] == 0 and not b.lateGlow, "late in the swing the listed icon glows in its colour")
	game.queued = 1001; Fire(env, "CURRENT_SPELL_CAST_CHANGED")
	assert(not a.lateGlow.playing, "a queued attack does not glow")
	game.queued = nil; Fire(env, "CURRENT_SPELL_CAST_CHANGED")
	assert(a.lateGlow.playing, "and glows again when unqueued")
	delays[2][2]()
	assert(not a.lateGlow.playing, "the swing's end stops the glow")
	local stale = delays[1][2]
	Fire(env, "PLAYER_SWING", 2.6, 0); stale()
	assert(not a.lateGlow.playing, "an earlier swing's timer is ignored")
	delays[#delays - 1][2]()
	Write("rules.swingGlow", ""); Write("rules.swing", "")
	assert(not a.lateGlow.playing and #W.Calls(a.swingSweep, "Clear") > 0, "clearing the lists stops the glow and the sweep at once")
	env.C_Timer.After = after
	Clean(env, K, "swing")
end

-- Sound when ready plays the chosen sound for listed spells only.
do
	local env, K, _, Write = New("mirror")
	local cdm = env._cdm
	Write("rules.sound", "1001"); Write("readySound", "ready")
	for _, spell in ipairs({ 1001, 1003 }) do cdm.cooldown[spell] = { active = true } end
	Fire(env, "SPELL_UPDATE_COOLDOWN")
	for _, spell in ipairs({ 1001, 1003 }) do cdm.cooldown[spell] = { active = false } end
	Fire(env, "SPELL_UPDATE_COOLDOWN")
	assert(#game.sounds == 1 and game.sounds[1] == 8960, "a listed spell coming off cooldown plays the ready sound once")
	Write("readySound", "")
	cdm.cooldown[1001] = { active = true }; Fire(env, "SPELL_UPDATE_COOLDOWN")
	cdm.cooldown[1001] = { active = false }; Fire(env, "SPELL_UPDATE_COOLDOWN")
	assert(#game.sounds == 1, "no sound chosen, no sound")
	Clean(env, K, "sound")
end

-- Numbers above glows lowers the proc glow under the countdown and count, and back.
do
	local env, K, ns, Write = New("mirror")
	local a = IconOf(ns, "essential", 1001)
	env._cdm.overlay[1001] = true
	Fire(env, "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 1001)
	local top = a.lumenGlow
	local native = top:GetFrameLevel()
	assert(a.proc and native > a.cooldown:GetFrameLevel(), "the proc glow sits over the countdown by default")
	Write("textAboveGlow", true)
	assert(top:GetFrameLevel() == a:GetFrameLevel() and a.overlay:GetFrameLevel() > top:GetFrameLevel() and a.cooldown:GetFrameLevel() > top:GetFrameLevel(), "switched on, the numbers draw over the glow")
	Fire(env, "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 1001); Fire(env, "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 1001)
	assert(top:GetFrameLevel() == a:GetFrameLevel(), "a new proc keeps it")
	Write("textAboveGlow", false)
	assert(top:GetFrameLevel() == native, "switched off, the glow returns to its level")
	Clean(env, K, "numbers above glows")
end

-- Two-row grids: the first row's count and each row's size, placed by wrap and growth, then off.
do
	local Grid = select(3, New("mirror")).Grid
	local cfg = { columns = 3, rows = 2, spacing = 2, cellWidth = 10, cellHeight = 10, growth = "right", wrap = "down", baseCount = 2, baseSize = 4, secondSize = 0 }
	assert(Grid.Capacity(cfg) == 5, "the first row holds two, the second its full three")
	local w, h = Grid.Size(cfg)
	assert(w == 34 and h == 26, "the holder fits the wider row and both heights")
	local x1, y1 = Grid.Offset(1, 5, cfg)
	local x3, y3 = Grid.Offset(3, 5, cfg)
	assert(x1 == 0 and y1 == 0 and x3 == 0 and y3 == 16 and Grid.Cell(1, cfg) == 14 and Grid.Cell(3, cfg) == 10, "wrap down puts the first row on top at its own size")
	cfg.wrap, cfg.growth = "up", "center"
	local _, upper = Grid.Offset(1, 5, cfg)
	local cx = Grid.Offset(1, 5, cfg)
	assert(upper == 12 and math.abs(cx - 2) < 1e-6, "wrap up puts it below, centred")
	cfg.vertical = true
	assert(Grid.Capacity(cfg) == 6, "a vertical grid ignores the row options")

	local env, K, ns, Write = New("mirror")
	Write("essential.columns", 2); Write("essential.rows", 2); Write("essential.growth", "right")
	local a, b, c = IconOf(ns, "essential", 1001), IconOf(ns, "essential", 1002), IconOf(ns, "essential", 1003)
	local size = ns.Settings.current.essential.size
	Write("essential.baseCount", 1); Write("essential.baseSize", 4); Write("essential.secondSize", -6)
	assert(a.opts.size == size + 4 and b.opts.size == size - 6 and c.opts.size == size - 6, "each row takes its own icon size")
	assert(W.LastCall(b, "SetPoint")[5] == W.LastCall(c, "SetPoint")[5] and W.LastCall(a, "SetPoint")[5] ~= W.LastCall(b, "SetPoint")[5], "one icon on the first row, two on the second")
	env.SetCombat(true); Write("essential.baseSize", 2)
	assert(a.opts.size == size + 2, "sizes apply in combat")
	env.SetCombat(false)
	Write("essential.baseCount", 0); Write("essential.baseSize", 0); Write("essential.secondSize", 0)
	assert(a.opts.size == size and b.opts.size == size and c.opts.size == size, "zero restores one size")
	Clean(env, K, "two rows")
end

-- Items: counts, missing items and every trinket on KstyleUI icons, through their events, then off.
do
	local env, K, ns, Write = New("mirror")
	local potion = IconOf(ns, "utility", 30)
	Write("utility.itemCount", false)
	assert((potion.count:GetText() or "") == "", "Item counts off hides the potion count")
	assert(IconOf(ns, "essential", 1002).count:GetText(), "and leaves spell charges alone")
	Write("utility.itemCount", true)
	assert(tostring(potion.count:GetText()) == "3", "on, it returns")

	game.counts[7001] = 0; Fire(env, "SPELL_UPDATE_USES")
	assert(potion:GetAlpha() == 1, "a used-up potion stays while Hide missing items is off")
	Write("utility.hideMissing", true)
	assert(potion:GetAlpha() == 0 and not potion:IsMouseEnabled(), "on, it hides with none left")
	game.counts[7001] = 2; Fire(env, "BAG_UPDATE_COOLDOWN")
	assert(potion:GetAlpha() == 1, "and returns when you have one again")
	Write("utility.hideMissing", false)

	game.equipped[13] = 9001
	Write("utility.trinkets", true)
	local trinket = IconOf(ns, "utility", 13)
	assert(trinket and Last(trinket.icon, "SetTexture") == 600013 and ns.Mirror.Row("utility").count == 4, "All trinkets adds an equipped trinket")
	game.equipped[14] = 9002; Fire(env, "PLAYER_EQUIPMENT_CHANGED", 14, false)
	assert(IconOf(ns, "utility", 14), "equipping another adds it")
	Write("essential.trinkets", true)
	assert(not IconOf(ns, "essential", 13), "a trinket shows on one row only")
	Write("essential.trinkets", false); Write("utility.trinkets", false)
	assert(ns.Mirror.Row("utility").count == 3 and not IconOf(ns, "utility", 13), "off, they are gone")
	Clean(env, K, "items")
end

-- The focus interrupt: its icon on the plate, its side, the target option, its cooldown, its sound and the reminders.
do
	local env, K, ns, Write = New("mirror")
	local plate, other, caster = env.CreateFrame("Frame"), env.CreateFrame("Frame"), env.CreateFrame("Frame")
	Write("focusSpell", "Kick")
	assert(Registered(env, "PLAYER_FOCUS_CHANGED") and not ns.Focus.icon, "a named interrupt listens, with nothing to show yet")
	game.units.focus, game.plates.focus = "enemy", plate
	Fire(env, "PLAYER_FOCUS_CHANGED")
	local icon = ns.Focus.icon
	local point = W.LastCall(icon, "SetPoint")
	assert(icon:IsShown() and point[1] == "RIGHT" and point[2] == plate and point[3] == "LEFT" and icon:GetParent() == plate, "the icon sits left of the focus's plate, hiding with it")
	assert(Last(icon.icon, "SetTexture") == 501766 and not icon:IsMouseEnabled(), "showing the interrupt, letting clicks reach the plate")
	assert(W.LastCall(icon.cooldown, "SetCooldownFromDurationObject"), "with its cooldown")
	local writes = #W.Calls(icon, "SetPoint")
	Fire(env, "NAME_PLATE_UNIT_ADDED", "nameplate9")
	assert(#W.Calls(icon, "SetPoint") == writes, "another plate leaves it in place")
	Write("focusSide", "TOP")
	point = W.LastCall(icon, "SetPoint")
	assert(point[1] == "BOTTOM" and point[3] == "TOP", "Nameplate side moves it above")
	game.units.focus = "friend"; Fire(env, "PLAYER_FOCUS_CHANGED")
	assert(not icon:IsShown(), "a friendly focus shows nothing")
	Write("focusTarget", true)
	game.units.target, game.plates.target = "enemy", other
	Fire(env, "PLAYER_TARGET_CHANGED")
	assert(icon:IsShown() and W.LastCall(icon, "SetPoint")[2] == other, "Show on target uses the target's plate")
	game.plates.target = nil; Fire(env, "NAME_PLATE_UNIT_REMOVED", "nameplate2")
	assert(not icon:IsShown(), "it hides with the plate")

	Write("focusSound", "warning")
	Fire(env, "UNIT_SPELLCAST_START", "target")
	assert(#game.sounds == 1 and game.sounds[1] == 8959, "a cast by the unit plays the sound while the interrupt is ready")
	env._cdm.cooldown[1766] = { active = true }
	Fire(env, "UNIT_SPELLCAST_CHANNEL_START", "target")
	assert(#game.sounds == 1, "not while the interrupt is cooling")
	Write("focusSpell", "")
	Fire(env, "UNIT_SPELLCAST_START", "target")
	assert(#game.sounds == 2 and not icon:IsShown(), "with no interrupt named, any cast plays it and no icon shows")
	game.units.target = "friend"; Fire(env, "UNIT_SPELLCAST_START", "target")
	assert(#game.sounds == 2, "a friendly cast is silent")
	Write("focusSound", "")

	Write("focusTarget", false); Write("focusReminder", true)
	game.units.focus, game.units.nameplate1, game.power.nameplate1, game.plates.nameplate1 = nil, "enemy", 0, caster
	Fire(env, "NAME_PLATE_UNIT_ADDED", "nameplate1")
	assert(not ns.Focus.notes.nameplate1, "outside a dungeon no reminder shows")
	game.instance = "party"; Fire(env, "PLAYER_ENTERING_WORLD"); Fire(env, "NAME_PLATE_UNIT_ADDED", "nameplate1")
	local note = ns.Focus.notes.nameplate1
	assert(note and note:IsShown() and W.LastCall(note, "SetPoint")[2] == caster and note:GetParent() == caster, "in a dungeon an enemy caster without a focus is marked")
	game.units.focus = "enemy"; Fire(env, "PLAYER_FOCUS_CHANGED")
	assert(not note:IsShown(), "setting a focus clears the reminders")
	game.units.focus = nil; Fire(env, "PLAYER_FOCUS_CHANGED")
	assert(note:IsShown(), "clearing it brings them back")
	Write("focusSound", "ready")
	assert(note:IsShown(), "another setting keeps the reminders")
	Write("focusReminder", false); Write("focusReminder", true)
	assert(note:IsShown(), "switching it back on finds the plates already shown")
	Fire(env, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
	assert(not note:IsShown(), "a removed plate drops its reminder")
	Write("focusReminder", false)
	assert(not Registered(env, "NAME_PLATE_UNIT_ADDED") and not Registered(env, "PLAYER_FOCUS_CHANGED"), "off, it listens to nothing")
	ns.definition.Disable()
	Clean(env, K, "focus")
end

-- The restyle path keeps its icons and hides the KstyleUI-only rows; the focus interrupt still works.
do
	local env, K, ns, Write = New("reskin")
	for _, option in ipairs(ns.Settings.Schema()) do
		for _, key in ipairs({ "essential.baseCount", "utility.itemCount", "utility.trinkets", "rules.form", "rules.swing", "textAboveGlow" }) do
			if option.key == key then assert(option.showWhen and not option.showWhen(ns.Settings.current), key .. " is offered on KstyleUI icons only") end
		end
	end
	game.units.focus, game.plates.focus = "enemy", env.CreateFrame("Frame")
	Write("focusSpell", "1766")
	assert(ns.Focus.icon and ns.Focus.icon:IsShown(), "the focus interrupt shows on the restyle path too")
	Clean(env, K, "restyle")
end

-- The preview follows the new options.
do
	local env, K, ns, Write = New("mirror")
	local parent = env.CreateFrame("Frame", nil, env.UIParent)
	parent:SetSize(280, 300)
	local frame = ns.Preview.Build(parent)
	assert(not frame.focus and frame.rows.utility.count == 4, "the default preview adds no samples")
	Write("rules.threshold", "x"); Write("rules.chargeSwipe", "x"); Write("rules.chargeTimer", "x"); Write("rules.swing", "x"); Write("rules.swingGlow", "x")
	Write("utility.trinkets", true); Write("focusSpell", "Kick")
	frame:Refresh()
	local essential, utility = frame.rows.essential, frame.rows.utility
	local first, charged = essential.icons[1], essential.icons[2]
	assert(Last(first.cooldown, "SetCountdownFormatter").breakpoints[1].format:find("|cff"), "the preview colours countdowns below the threshold")
	assert(Last(charged.chargeCooldown, "SetDrawSwipe") == true and Last(charged.chargeCooldown, "SetHideCountdownNumbers") == false, "the preview recharges a charge sample with its swipe and countdown")
	assert(first.swingSweep and first.lateGlow.playing, "the preview sweeps and glows for the swing")
	assert(utility.count == 6, "the preview adds a potion and a trinket")
	assert(frame.focus and frame.focus:IsShown() and Last(frame.focus.icon, "SetTexture") == 501766, "the preview shows the focus interrupt")
	Write("utility.hideMissing", true); frame:Refresh()
	assert(utility.icons[5]:GetAlpha() == 0, "the preview hides a missing potion")
	Write("focusSpell", ""); Write("rules.swingGlow", ""); frame:Refresh()
	assert(not frame.focus:IsShown() and not first.lateGlow.playing, "and clears them again")
	Clean(env, K, "preview")
end

print("cooldowns parity round 3 ok")
