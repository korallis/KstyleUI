-- test-nameplates-cast.lua: nameplate cast bars run from duration objects, pass secret names and icons through, and show the interruptible state.
local N = dofile("Tools/regression/nameplates_env.lua")
local Last, Calls, SameColor = N.Last, N.Calls, N.SameColor

local function barColor(bar)
	local r, g, b = bar:GetStatusBarColor()
	return r, g, b
end

local function token(K, name)
	local r, g, b = K.Tokens.Color(name)
	return r, g, b
end

local CAST = { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false }

-- A cast runs from UnitCastingDuration's duration object -----------------------------------------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	assert(plate.cast and not plate.cast:IsShown(), "the cast bar waits hidden")

	N.Cast(env, "nameplate1", CAST)
	local bar = plate.castBar
	assert(plate.cast:IsShown(), "UNIT_SPELLCAST_START shows the cast bar")
	local timer = Last(bar, "SetTimerDuration")
	assert(timer and timer[1] == env._units.nameplate1.castDuration, "the bar runs from the duration object")
	assert(timer[3] == env.Enum.StatusBarTimerDirection.ElapsedTime, "a cast fills as time passes")
	assert(Last(plate.castName, "SetText")[1] == "Molten Pulse", "the spell's name shows")
	assert(Last(plate.castIcon, "SetTexture")[1] == 135808, "the spell's icon shows")
	local ar, ag, ab = K.Theme.Accent()
	assert(SameColor(ar, ag, ab, barColor(bar)), "an interruptible cast takes the accent")
	assert(plate.castShield:GetAlpha() == 0, "no shield over the icon")

	-- The time text counts down while the bar shows.
	N.Tick(env, 0.2)
	local time = Last(plate.castTime, "SetFormattedText")
	assert(time and env.issecretvalue(time[2]) and env.Reveal(time[2]) == 1.5, "the time text formats the remaining time")

	env.FireEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "nameplate1")
	local sr, sg, sb = token(K, "textDisabled")
	assert(SameColor(sr, sg, sb, barColor(bar)), "an uninterruptible cast is grey")
	assert(plate.castShield:GetAlpha() > 0, "and its icon dims")
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "nameplate1")
	assert(SameColor(ar, ag, ab, barColor(bar)), "an interruptible cast takes the accent again")

	env._units.nameplate1.cast = nil
	env.FireEvent("UNIT_SPELLCAST_STOP", "nameplate1")
	N.Settle(env)
	assert(not plate.cast:IsShown(), "UNIT_SPELLCAST_STOP hides the bar")
	assert(not bar:GetScript("OnUpdate"), "and stops counting")
end

-- Secret casts: the name, the icon and the interruptible flag pass through whole -----------------------

do
	local env, _, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	N.Cast(env, "nameplate1", { name = "Shadow Bolt", text = "Shadow Bolt", texture = 136197, notInterruptible = true, secret = true })
	local name = Last(plate.castName, "SetText")[1]
	assert(env.issecretvalue(name) and env.Reveal(name) == "Shadow Bolt", "a secret spell name passes through whole")
	local icon = Last(plate.castIcon, "SetTexture")[1]
	assert(env.issecretvalue(icon) and env.Reveal(icon) == 136197, "a secret icon passes through whole")
	local tint = Last(plate.castBar:GetStatusBarTexture(), "SetVertexColorFromBoolean")
	assert(tint and env.issecretvalue(tint[1]) and env.Reveal(tint[1]) == true, "a secret flag colours the bar in the engine")
	local shade = Last(plate.castShield, "SetAlphaFromBoolean")
	assert(shade and env.issecretvalue(shade[1]), "and dims the icon in the engine")
end

-- A pushed-back cast runs again from a fresh duration; a theme change keeps a secret cast's colouring ------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183, notInterruptible = true, secret = true })
	local runs = #Calls(plate.castBar, "SetTimerDuration")
	env.FireEvent("UNIT_SPELLCAST_DELAYED", "nameplate1")
	assert(#Calls(plate.castBar, "SetTimerDuration") == runs + 1, "UNIT_SPELLCAST_DELAYED runs the bar again")
	local texture = plate.castBar:GetStatusBarTexture()
	local tints = #Calls(texture, "SetVertexColorFromBoolean")
	K.Callbacks.Fire("ThemeChanged")
	assert(#Calls(texture, "SetVertexColorFromBoolean") > tints, "a restyle colours the secret cast again")
end

-- The preview shows a cast ------------------------------------------------------------------------------

do
	local env, K = N.New()
	local preview = K.Options.Preview("Nameplates")(env.CreateFrame("Frame", nil, K.Scale.Root()))
	assert(preview.plates[1].cast:IsShown(), "the preview's first plate is casting")
	assert(preview.plates[2].castShield:GetAlpha() > 0, "its second shows an uninterruptible cast")
	K.Options.Write("Nameplates", "cast.enabled", false)
	preview:Refresh()
	assert(not preview.plates[1].cast:IsShown(), "and follows the cast switch")
end

-- A secret duration object is never indexed or tested: the bar falls back to the start and end times -----

do
	local env, _, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183, secret = true, secretDuration = true })
	assert(plate.cast:IsShown(), "the cast shows")
	assert(#Calls(plate.castBar, "SetTimerDuration") == 0, "a secret duration never reaches SetTimerDuration")
	local range = Last(plate.castBar, "SetMinMaxValues")
	assert(env.issecretvalue(range[1]) and env.Reveal(range[2]) == 3000, "the bar spans the secret start and end")
	N.Tick(env, 0.2)
	assert(#env._errors == 0, "no error: " .. tostring(env._errors[1]))
end

-- A failed attempt at another spell, or a STOP for another cast, leaves the shown cast alone ---------------

do
	local env, _, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	N.Cast(env, "nameplate1", CAST)
	env.FireEvent("UNIT_SPELLCAST_FAILED", "nameplate1", "other-cast", 116)
	assert(plate.cast:IsShown() and plate.casting, "a failure of another cast keeps the bar")
	env.FireEvent("UNIT_SPELLCAST_STOP", "nameplate1", "other-cast", 116)
	assert(plate.casting, "so does a STOP for another cast")
end

-- An interrupted channel shows as interrupted ---------------------------------------------------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	N.Cast(env, "nameplate1", { name = "Drain Life", text = "Drain Life", texture = 136169, channel = true })
	env._units.nameplate1.cast = nil
	env.FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "nameplate1", "cast-guid", 689, "Player-1-0001")
	assert(Last(plate.castName, "SetText")[1] == K.L["Interrupted"], "a channel stopped by someone says Interrupted")
	N.Settle(env)
	N.Cast(env, "nameplate1", { name = "Drain Life", text = "Drain Life", texture = 136169, channel = true })
	env._units.nameplate1.cast = nil
	env.FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "nameplate1", "cast-guid", 689, nil)
	assert(Last(plate.castName, "SetText")[1] == "Drain Life", "a channel that ran out just fades")
end

-- The spark follows the fill direction ------------------------------------------------------------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	local spark = plate.castBar.spark
	assert(select(3, spark:GetPoint(1)) == "RIGHT", "a normal bar's spark rides the right edge of the fill")
	K.Options.Write("Nameplates", "cast.reverse", true)
	assert(select(3, spark:GetPoint(1)) == "LEFT", "a reversed bar's spark rides the left edge")
	K.Options.Write("Nameplates", "cast.orientation", "VERTICAL")
	assert(select(3, spark:GetPoint(1)) == "BOTTOM", "a reversed vertical bar's spark rides the bottom edge")
	K.Options.Write("Nameplates", "cast.reverse", false)
	assert(select(3, spark:GetPoint(1)) == "TOP", "a vertical bar's spark rides the top edge")
end

-- Channels drain; a unit already casting when its plate appears shows its cast ----------------------------

do
	local env, _, ns = N.New()
	local u = { cast = { name = "Drain Life", text = "Drain Life", texture = 136169, channel = true } }
	N.Add(env, "nameplate1", u)
	local plate = ns.Plates.Get("nameplate1")
	assert(plate.cast:IsShown(), "a channel in progress shows when the plate attaches")
	local timer = Last(plate.castBar, "SetTimerDuration")
	assert(timer[3] == env.Enum.StatusBarTimerDirection.RemainingTime, "a channel drains")
	env._units.nameplate1.cast = nil
	env.FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "nameplate1")
	N.Settle(env)
	assert(not plate.cast:IsShown(), "UNIT_SPELLCAST_CHANNEL_STOP hides the bar")
end

-- An interrupt shows on the bar, then fades; the STOP that follows does not cut it short -----------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	N.Cast(env, "nameplate1", CAST)
	env._units.nameplate1.cast = nil
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "nameplate1")
	env.FireEvent("UNIT_SPELLCAST_STOP", "nameplate1")
	assert(plate.cast:IsShown(), "the interrupted bar stays a moment")
	assert(Last(plate.castName, "SetText")[1] == K.L["Interrupted"], "and says so")
	local hr, hg, hb = token(K, "hostile")
	assert(SameColor(hr, hg, hb, barColor(plate.castBar)), "in the hostile colour")
	N.Settle(env)
	assert(not plate.cast:IsShown(), "then fades out")
	N.Cast(env, "nameplate1", CAST)
	assert(plate.cast:IsShown() and plate.cast:GetAlpha() == 1, "the next cast shows at full opacity")
end

-- Without duration objects the bar runs from the cast's start and end times --------------------------------

do
	local env, K, ns = N.New({ setup = function(env)
		env.UnitCastingDuration = nil
		env.UnitChannelDuration = nil
	end })
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	N.Cast(env, "nameplate1", CAST)
	local range = Last(plate.castBar, "SetMinMaxValues")
	assert(range and range[1] == 1000 and range[2] == 3000, "the fallback bar spans the cast's start and end")
	env._time = 2
	N.Tick(env, 0.2)
	assert(Last(plate.castBar, "SetValue")[1] == 2000, "and its OnUpdate moves the value")
	assert(not plate.castTime:IsShown(), "the fallback shows no time text")
	local logged = false
	for _, entry in ipairs(K.Store.Data().devlog) do
		logged = logged or entry.message:find("UnitCastingDuration", 1, true) ~= nil
	end
	assert(logged, "the fallback is logged")
end

-- Settings ----------------------------------------------------------------------------------------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	local base = env._bases.nameplate1
	local y = select(5, plate:GetPoint(1))
	K.Options.Write("Nameplates", "cast.height", 20)
	assert(plate.castBar.opts.height == 20, "the cast bar height follows the setting")
	assert(select(5, plate:GetPoint(1)) > y, "and the plate makes room for it")
	assert(plate:GetParent() == base)
	K.Options.Write("Nameplates", "cast.showIcon", false)
	N.Cast(env, "nameplate1", CAST)
	assert(not plate.castIcon:IsShown(), "the icon can be switched off")
	K.Options.Write("Nameplates", "cast.showName", false)
	assert(not plate.castName:IsShown(), "the spell name can be switched off")
	K.Options.Write("Nameplates", "cast.showTime", false)
	assert(not plate.castTime:IsShown(), "the time can be switched off")
	K.Options.Write("Nameplates", "cast.colorSource", "custom")
	K.Options.Write("Nameplates", "cast.color", { r = 0.2, g = 0.4, b = 0.6 })
	assert(SameColor(0.2, 0.4, 0.6, barColor(plate.castBar)), "a custom cast colour applies at once")
	local path = K.Tokens.MediaList("statusbar")[2].path
	K.Options.Write("Nameplates", "cast.texture", path)
	assert(Last(plate.castBar, "SetStatusBarTexture")[1] == path, "the cast texture follows the setting")
	K.Options.Write("Nameplates", "cast.enabled", false)
	assert(not plate.cast:IsShown(), "cast bars can be switched off")
	N.Cast(env, "nameplate1", CAST)
	assert(not plate.cast:IsShown(), "and stay off")
	N.Remove(env, "nameplate1")
	assert(#Calls(plate.castBar, "SetTimerDuration") >= 1)
end

print("nameplates cast ok")
