-- setup_ornaments.lua: the ornaments level picked in the two places a player picks it (KSTY-23). RENDER_SUBJECT=setup
-- (the default) draws the first-run setup on its ornaments step, Full picked as it opens; RENDER_SUBJECT=options draws
-- the settings window's General page scrolled to the Ornaments row's three-way control, at RENDER_ORNAMENTS (Off when
-- unset). Not a gallery_ scene, so the gallery test does not run it.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local W = O.W

local MODULES = {
	"UnitFrames", "ActionBars", "Cooldowns", "GroupFrames", "Auras", "Nameplates", "CombatText", "Minimap", "Chat",
	"Bags", "Tooltips", "DataBars", "Meters", "Skins", "QoL",
}

local function settle(env)
	env.RunTimers()
	Gallery.Ticks(W, env, 40)
	env.RunTimers()
end

local function setup(frames)
	local CoreEnv = W.CoreEnv
	local env, K = W.New(Common.ScreenOpts({
		saved = Gallery.Saved({}),
		boot = false,
		setup = function(env)
			Gallery.Setup(env)
			env.C_AddOns = {
				DoesAddOnExist = function()
					return true
				end,
				LoadAddOn = function()
					return false, "MISSING"
				end,
			}
		end,
	}))
	for _, name in ipairs(MODULES) do
		K.Modules.Register(CoreEnv.Module(name))
	end
	CoreEnv.Boot(env)
	assert(K.Setup.Open(true), "the setup opens as on the first login")
	W.Settle(env)
	assert(K.Setup.Go(4), "the setup moves to the ornaments step")
	W.Settle(env)
	local panel = K.Setup.window
	assert(panel.ornamentCards.Full.selected, "Full is picked as the step opens")
	settle(env)
	frames:Add(env, panel, {
		name = "setup_ornaments", title = "Setup: ornaments", grade = "window", reference = "chat",
		caption = "The ornaments step: one card per level (Off, Subtle, Full) with its note, Full picked with the accent edge and glow, and the hint that ornaments move nothing, Glass hides them and the settings window changes them later.",
		match = "The cards are the layout step's cards: the button body with the one-border light line, the accent hairline and selection glow on the picked one.",
	})
	return env, K, Gallery.Build(env)
end

local function options(frames)
	local env, K = O.New(Common.ScreenOpts({
		saved = Gallery.Saved({}),
		setup = function(env)
			Gallery.Setup(env)
			env.C_AddOns = env.C_AddOns or {}
			env.C_AddOns.LoadAddOn = function(name)
				if name == "KstyleUI_Options" and not env._addons.KstyleUI_Options then
					Load(O.Files(), env)
				end
				return true
			end
		end,
	}))
	local level = os.getenv("RENDER_ORNAMENTS")
	if level and level ~= "" then
		K.Options.Write("Widgets", "ornaments", level)
	end
	assert(K.Options.Open("General") == true, "the window opens on General")
	settle(env)
	local ns = env._addons.KstyleUI_Options
	local _, index = O.Find(ns.Window.State().items, function(item)
		return item.module == "Widgets" and item.key == "ornaments"
	end)
	assert(index, "General lists the Ornaments row")
	ns.Window.Parts().content:ScrollToIndex(index + 4)
	settle(env)
	frames:Add(env, ns.Window.Frame(), {
		name = "options_ornaments", title = "Settings: ornaments", grade = "window", reference = "chat",
		caption = "The General page scrolled to the Widgets section: the Ornaments row's three-way control (Off, Subtle, Full) on the tab strip's button body, the stored level underlined in the accent.",
		match = "The control is the kit's tab strip at the row's control width: button body with the one-border light line and the accent underline.",
	})
	return env, K, Gallery.Build(env)
end

return Common.Run(function()
	local frames = Gallery.Frames()
	local subject = os.getenv("RENDER_SUBJECT")
	local build = subject == "options" and options or setup
	local env, K, scene = build(frames)
	local err = Common.Errors(env, K)
	assert(not err, tostring(err))
	return frames:Finish(scene, env, K, "setup ornaments")
end)
