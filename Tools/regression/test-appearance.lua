-- test-appearance.lua: the Appearance settings drive Theme, Scale and Motion through Store and Options, and register media with LibSharedMedia.
local CoreEnv = dofile("Tools/regression/core_env.lua")

local function near(a, b)
	return math.abs(a - b) < 1e-9
end

local function saved(values)
	return { version = 1, profiles = { Default = { Appearance = values } } }
end

local function setup(extra)
	return function(env)
		env.UnitClass = function()
			return "Mage", "MAGE", 8
		end
		if extra then
			extra(env)
		end
	end
end

-- The defaults and the settings page are registered at load, and the page passes Options' checks.
do
	local _, K = CoreEnv.New({ setup = setup() })
	local defaults = K.Store.Defaults("Appearance")
	assert(defaults, "Appearance registers its defaults with Store")
	assert(defaults.accentSource == "class" and defaults.font == "Lumen" and defaults.uiScale == 1 and defaults.motion == "full", "the defaults are class colour, the Lumen fonts, size 1 and full motion")
	local r, g, b = K.Tokens.Color("accentDefault")
	assert(near(defaults.accentColor.r, r) and near(defaults.accentColor.g, g) and near(defaults.accentColor.b, b), "the custom colour defaults to the kit's accent")
	local schema = K.Options.Get("Appearance")
	assert(schema == K.Appearance.schema, "Options holds the Appearance page")
	for _, key in ipairs({ "accentSource", "accentColor", "font", "fontScale", "uiScale", "motion" }) do
		assert(K.Options.Row("Appearance", key), "the page has a row for " .. key)
	end
	local size = K.Options.Row("Appearance", "uiScale")
	assert(size.type == "slider" and size.min == 0.75 and size.max == 1.5, "the size slider runs from 0.75 to 1.5")
	local colour = K.Options.Row("Appearance", "accentColor")
	assert(colour.showWhen({ accentSource = "custom" }) and not colour.showWhen({ accentSource = "class" }), "the colour row shows only for a custom accent")
	local faces = K.Options.Row("Appearance", "font").options()
	assert(#faces == 8 and faces[1].value == "Lumen" and faces[6].value == "SourceSans3Semibold", "the font row offers the Lumen set and the seven bundled faces")
	assert(K.Appearance.Get("uiScale") == 1, "Get answers with the default before the saved settings load")
end

-- Saved settings apply when the saved data loads, before PLAYER_LOGIN builds frames.
do
	local env, K = CoreEnv.New({
		setup = setup(),
		saved = saved({ uiScale = 0.75, accentSource = "custom", accentColor = { r = 0.5, g = 0.6, b = 0.7 }, font = "InterSemiBold", motion = "off" }),
	})
	CoreEnv.LoadSaved(env)
	assert(K.Scale.UserScale() == 0.75, "the saved size applies")
	assert(K.Motion.ReducedMotion() == true, "the saved motion switch applies")
	assert(K.Theme.FontFace() == "InterSemiBold", "the saved face applies")
	local r, g, b = K.Theme.Accent()
	assert(near(r, 0.5) and near(g, 0.6) and near(b, 0.7), "the saved custom accent applies")
	CoreEnv.Login(env)
	r = K.Theme.Accent()
	assert(near(r, 0.5), "the custom accent survives login")
end

-- The settings window writes through Options.Write, and each change applies at once.
do
	local env, K = CoreEnv.New({ setup = setup() })
	CoreEnv.Boot(env)
	K.Options.Write("Appearance", "uiScale", 1.25)
	assert(K.Scale.UserScale() == 1.25, "a size change applies at once")
	K.Options.Write("Appearance", "uiScale", 9)
	assert(K.Scale.UserScale() == 1.5 and K.Appearance.Get("uiScale") == 1.5, "an out-of-range size is clamped")
	K.Options.Write("Appearance", "accentColor", { r = 0.1, g = 0.2, b = 0.3 })
	K.Options.Write("Appearance", "accentSource", "custom")
	local r, g, b = K.Theme.Accent()
	assert(near(r, 0.1) and near(g, 0.2) and near(b, 0.3), "the accent settings apply at once")
	K.Options.Write("Appearance", "accentSource", "class")
	r = K.Theme.Accent()
	assert(K.Theme.AccentSource() == "class" and not near(r, 0.1), "switching back to the class colour drops the custom one")
	K.Options.Write("Appearance", "font", "InterSemiBold")
	assert(K.Theme.FontFace() == "InterSemiBold" and K.Tokens.Font("body"):match("Inter%-SemiBold"), "the face applies at once")
	K.Options.Write("Appearance", "motion", "off")
	assert(K.Motion.ReducedMotion() == true, "the motion setting applies at once")
end

-- A saved value that is the right type but not allowed falls back to its default.
do
	local env, K = CoreEnv.New({
		setup = setup(),
		saved = saved({ uiScale = "huge", accentSource = "rainbow", font = "Comic", accentColor = { r = 2, g = 0, b = 0 }, motion = "yes" }),
	})
	CoreEnv.Boot(env)
	assert(K.Scale.UserScale() == 1 and K.Appearance.Get("uiScale") == 1, "a broken size falls back to 1")
	assert(K.Theme.AccentSource() == "class" and K.Appearance.Get("accentSource") == "class", "an unknown accent source falls back to class")
	assert(K.Theme.FontFace() == "Lumen", "an unknown face falls back to the Lumen set")
	local r = K.Theme.CustomAccent()
	assert(r <= 1, "an out-of-range colour falls back to the default")
	assert(K.Motion.ReducedMotion() == false, "a broken motion setting falls back to full motion")
end

-- A profile switch applies the new profile's settings.
do
	local env, K = CoreEnv.New({ setup = setup(), saved = saved({ uiScale = 1.25, motion = "off" }) })
	CoreEnv.Boot(env)
	assert(K.Scale.UserScale() == 1.25)
	assert(K.Store.SetProfile("Plain"), "a new profile")
	assert(K.Scale.UserScale() == 1 and K.Motion.ReducedMotion() == false, "the new profile's defaults apply")
	K.Options.Write("Appearance", "uiScale", 0.75)
	assert(K.Store.SetProfile("Default"))
	assert(K.Scale.UserScale() == 1.25 and K.Motion.ReducedMotion() == true, "switching back applies the first profile again")
end

-- LibSharedMedia gets KstyleUI's fonts and bars at login, once, and only when it is already loaded.
do
	local calls = {}
	local lsm = {}
	function lsm:Register(kind, key, path)
		calls[#calls + 1] = { kind = kind, key = key, path = path }
		return true
	end
	local env = CoreEnv.New({
		setup = setup(function(e)
			e.LibStub = function(major, silent)
				assert(silent, "LibStub is asked silently, so a missing library is not an error")
				if major == "LibSharedMedia-3.0" then
					return lsm
				end
			end
		end),
	})
	CoreEnv.Boot(env)
	env.FireEvent("PLAYER_LOGIN")
	local counts = { font = 0, statusbar = 0 }
	local names = {}
	for _, c in ipairs(calls) do
		counts[c.kind] = counts[c.kind] + 1
		assert(c.key:match("^KstyleUI %u"), "media names start with KstyleUI: " .. c.key)
		assert(not names[c.key], "each name once: " .. c.key)
		names[c.key] = true
		assert(c.path:match("^Interface\\AddOns\\KstyleUI\\Media\\"), "media paths are KstyleUI's own")
	end
	assert(counts.font == 7 and counts.statusbar == 3, "seven fonts and three bars, registered once; the Lumen set is not a font")
	assert(names["KstyleUI Glass"] and names["KstyleUI Source Sans 3 Semibold"], "names read well in other addons' lists")

	local without = CoreEnv.New({ setup = setup() })
	CoreEnv.Boot(without) -- no LibStub: nothing to do, and no error

	local noLibrary = CoreEnv.New({
		setup = setup(function(e)
			e.LibStub = function()
				return nil
			end
		end),
	})
	CoreEnv.Boot(noLibrary)

	local broken = CoreEnv.New({
		setup = setup(function(e)
			e.LibStub = function()
				return {
					Register = function()
						error("broken library")
					end,
				}
			end
		end),
	})
	CoreEnv.Boot(broken)
	assert(#broken._errors == 0, "a broken library is never reported as a KstyleUI error")
end

print("appearance ok")
