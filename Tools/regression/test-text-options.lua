-- test-text-options.lua: shared text rows stay lazy, follow the role fonts, paint secrets and refresh tags on existing unit events.
local U = dofile("Tools/regression/unitframes_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")
local W = U.W

do
	local env, K, ns = U.New({ enabled = false })
	local builds, schema = 0, ns.Settings.Schema
	ns.Settings.Schema = function() builds = builds + 1; return schema() end
	K.Options.List()
	K.Options.Read("UnitFrames", "edit")
	assert(builds == 0, "defer unit-frame text schemas until the page opens, including setting reads")
	local page = K.Options.Get("UnitFrames")
	assert(builds == 1 and K.Options.Get("UnitFrames") == page, "build and validate a schema once")
	local other, plates, settings = N.New({ enable = false })
	assert(settings.Settings.rows == nil, "defer nameplate schemas until the page opens")
	plates.Options.Get("Nameplates")
	assert(settings.Settings.rows, "opening the page builds nameplate rows")
	assert(#env._errors == 0 and #other._errors == 0)
end

local function color(text, expected)
	local c = assert(W.LastCall(text, "SetTextColor"), "the selected text colour was not painted")
	for i = 1, 3 do assert(math.abs(c[i] - expected[i]) < 1e-6, "text colour follows its selected source") end
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = U.New({ plate = true, width = screen[1], height = screen[2] })
	local view = ns.Frames.Get("player").views[1]
	local function set(key, value)
		K.Options.Write("UnitFrames", "player." .. key, value)
		env.RunTimers()
	end
	local defaults = K.Store.Defaults("UnitFrames").player.fonts
	assert(defaults.name.textFormat == "" and defaults.health.textFormat == "", "absent formats keep today's presets")
	assert(defaults.name.colorMode == "" and defaults.health.colorMode == "", "absent colours keep today's look")
	local path = K.Tokens.FontPath("InterSemiBold")
	for _, key in ipairs({ "name", "health" }) do
		local text = key == "name" and view.name or view.healthText
		set("fonts." .. key .. ".font", path)
		set("fonts." .. key .. ".size", 12)
		set("fonts." .. key .. ".outline", "THICKOUTLINE")
		local font = W.LastCall(text, "SetFont")
		assert(font[1] == path and font[3] == "THICKOUTLINE", "font and outline apply live")
		set("fonts." .. key .. ".outline", "NONE")
		assert(W.LastCall(text, "SetFont")[3] == "", "outline can be turned off")
		set("fonts." .. key .. ".color", { r = 0.2, g = 0.3, b = 0.4 })
		for _, mode in ipairs({ "custom", "accent", "class", "reaction" }) do
			set("fonts." .. key .. ".colorMode", mode)
			local expected = mode == "custom" and { 0.2, 0.3, 0.4 }
				or mode == "accent" and { K.Theme.Accent() }
				or mode == "class" and { K.Theme.ClassTextColorForWidget(K.Theme.Class()) }
				or { K.Theme.ReactionColor(env.UnitReaction("player", "player")) }
			color(text, expected)
		end
		set("fonts." .. key .. ".colorMode", "")
		set("fonts." .. key .. ".font", "theme")
		set("fonts." .. key .. ".size", defaults[key].size)
		set("fonts." .. key .. ".outline", defaults[key].outline)
	end
	env._units.player.health, env._units.player.healthMax = 12400, 40000
	env._units.player.power, env._units.player.powerMax, env._units.player.absorb = 40, 100, 300
	env._restricted = true
	set("fonts.name.textFormat", "[name] [hp:abr]")
	set("fonts.health.textFormat", "[pp] / [absorb]")
	assert(U.Shown(env, view.name):find("12.4K", 1, true), "a name slot can contain health")
	env._units.player.health = 1000
	env.FireEvent("UNIT_HEALTH", "player")
	assert(U.Shown(env, view.name):find("1K", 1, true), "health events refresh health tags in name text")
	env._units.player.power = 60
	env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
	assert(U.Shown(env, view.healthText) == "60 / 300", "power events refresh power tags in health text")
	env._units.player.absorb = 450
	env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
	assert(U.Shown(env, view.healthText) == "60 / 450", "absorb events refresh absorb tags")
	set("healthText", "none")
	assert(U.Shown(env, view.healthText) == "", "off wins over a custom health format")
	set("fonts.name.textFormat", "")
	set("fonts.health.textFormat", "")
	set("healthText", "percent")
	assert(U.Shown(env, view.healthText) == "3%", "blank format restores the existing rounded preset")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))

	local e, P, n = N.New({ width = screen[1], height = screen[2] })
	N.Add(e, "nameplate1", { name = "Kobold", health = 12400, maxHealth = 40000, level = 10, power = 25, powerMax = 100, absorb = 300 })
	local plate = n.Plates.Get("nameplate1")
	local function write(key, value) P.Options.Write("Nameplates", key, value); e.RunTimers() end
	write("healthText.show", true)
	for _, key in ipairs({ "name", "healthText" }) do
		local text = key == "name" and plate.name or plate.healthText
		write(key .. ".font", path)
		write(key .. ".size", 14)
		write(key .. ".outline", "THICKOUTLINE")
		local font = W.LastCall(text, "SetFont")
		assert(font[1] == path and math.abs(font[2] - 14) <= 1 and font[3] == "THICKOUTLINE", "plate font, size and outline apply live")
		write(key .. ".outline", "NONE")
		assert(W.LastCall(text, "SetFont")[3] == "", "plate outline can be turned off")
		write(key .. ".color", { r = 0.2, g = 0.3, b = 0.4 })
		for _, mode in ipairs({ "custom", "accent", "class", "reaction" }) do
			write(key .. ".colorMode", mode)
			color(text, mode == "custom" and { 0.2, 0.3, 0.4 } or mode == "accent" and { P.Theme.Accent() } or { P.Theme.ReactionColor(2) })
		end
		write(key .. ".colorMode", "")
		write(key .. ".font", "")
	end
	write("name.textFormat", "[name] [hp:abr]")
	write("healthText.textFormat", "[pp] / [absorb]")
	assert(U.Shown(e, plate.name) == "Kobold 12.4K", "plate custom name keeps the format's case")
	e._units.nameplate1.health = 1000
	e.FireEvent("UNIT_HEALTH", "nameplate1")
	assert(U.Shown(e, plate.name) == "Kobold 1K", "plate name tags update on health events")
	e._units.nameplate1.power = 50
	e.FireEvent("UNIT_POWER_UPDATE", "nameplate1", "MANA")
	assert(U.Shown(e, plate.healthText) == "50 / 300", "plate health tags update on power events")
	write("healthText.show", false)
	write("name.show", false)
	assert(not plate.name:IsShown() and not plate.healthText:IsShown(), "off hides custom formats")
	write("name.textFormat", "")
	write("healthText.textFormat", "")
	write("name.show", true)
	write("healthText.show", true)
	assert(U.Shown(e, plate.name) == "KOBOLD", "blank restores the plate's existing capitalised name")
	assert(#e._errors == 0 and P.ErrorCount() == 0, tostring(e._errors[1]))
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = U.New({ width = screen[1], height = screen[2] })
	K.Options.Write("HudStyle", "style", "orbs")
	local orb = assert(ns.Orbs.Get("health"), "the health orb is built")
	K.Options.Write("UnitFrames", "player.fonts.health.textFormat", "[pp] [absorb]")
	env._units.player.power, env._units.player.absorb = 42, 100
	env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
	assert(U.Shown(env, orb.value) == "42 100", "power tags refresh on the health orb")
	env._units.player.absorb = 200
	env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
	assert(U.Shown(env, orb.value) == "42 200", "absorb tags refresh on the health orb")
	local font = K.Tokens.FontPath("InterSemiBold")
	K.Options.Write("UnitFrames", "player.fonts.health.font", font)
	K.Options.Write("UnitFrames", "player.fonts.health.size", 20)
	K.Options.Write("UnitFrames", "player.fonts.health.outline", "NONE")
	assert(W.LastCall(orb.value, "SetFont")[1] == font and W.LastCall(orb.value, "SetFont")[3] == "", "orb text follows font, size and outline")
	K.Options.Write("UnitFrames", "player.fonts.health.colorMode", "accent")
	color(orb.value, { K.Theme.Accent() })
	K.Options.Write("UnitFrames", "player.healthText", "none")
	assert(U.Shown(env, orb.value) == "", "off hides the orb's custom health text")
	K.Options.Write("UnitFrames", "player.healthText", "both")
	K.Options.Write("UnitFrames", "player.fonts.health.textFormat", "")
	assert(U.Shown(env, orb.value):find(" / ", 1, true), "blank restores the orb's existing health preset")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

do
	local env, K = U.New()
	local existing = { SetTextColor = function(self, ...) self.color = { ... } end }
	K.Widgets.TextColor(existing, "textDisabled")
	assert(existing.color, "keep Widgets.TextColor's token API; text modes use TextTint")
	local expected = { K.Tokens.Color("textDisabled") }
	for i = 1, 3 do assert(existing.color[i] == expected[i], "keep Widgets.TextColor's token API; text modes use TextTint") end
	local tags = "[name] [hp] [hp:pct] [hp:abr] [hp:max] [pp] [pp:pct] [pp:abr] [pp:max] [level] [absorb] [target] [group]"
	local widgets = K.Widgets
	assert(widgets.ParseText(tags) == widgets.ParseText(tags), "parsed format strings are cached")
	local sink = { SetText = function(self, value) self.value = value end }
	env.UnitInRaid = function() return 1 end
	env.GetRaidRosterInfo = function() return nil, nil, 3 end
	widgets.TagText(sink, tags, "player")
	assert(env.issecretvalue(sink.value), "tag composition preserves secrets until SetText")
	assert(env.Reveal(sink.value):find("3", 1, true), "group data comes from the Forever roster API")
	local unit = env._units.player
	unit.name, unit.health, unit.healthMax, unit.power, unit.powerMax, unit.absorb, unit.level = "Ada", 12400, 40000, 40, 100, 300, 38
	for tag, want in pairs({ name = "Ada", hp = "12400", ["hp:pct"] = "31%", ["hp:abr"] = "12.4K", ["hp:max"] = "40000",
		pp = "40", ["pp:pct"] = "40%", ["pp:abr"] = "40", ["pp:max"] = "100", absorb = "300", level = "38", group = "3" }) do
		widgets.TagText(sink, "[" .. tag .. "]", "player")
		local value = env.issecretvalue(sink.value) and env.Reveal(sink.value) or sink.value
		assert(tostring(value) == want, "paint the value of [" .. tag .. "]")
	end
	widgets.TagText(sink, "[unknown] 100% [hp", "player")
	assert(sink.value == "[unknown] 100% [hp", "unknown and unfinished tags remain literal text")
	widgets.TagText(sink, "", "player")
	assert(sink.value == "", "an empty format paints an empty string")
	env.UnitGetTotalAbsorbs, env.UnitHealthPercent, env.UnitPowerPercent = nil, nil, nil
	widgets.TagText(sink, "[absorb][hp:pct][pp:pct]", "player")
	assert(sink.value == "", "missing optional APIs safely paint nothing")
end

print("text options ok: lazy schemas, cached tags, defaults, off, secrets and live options at all four screens")
