-- gallery_setup_tracked.lua: the setup summary after Apply when more buffs and bars are tracked than fit anywhere on
-- screen: Edit Mode took the layout, Blizzard's two tracked viewers stay where they were, and the summary heads
-- "Applied, with 2 steps left", names both counts with how many would fit, and offers Try again's route through the
-- Cooldown Manager button (Core/Setup/EditMode.lua places a viewer whole or not at all), at the largest text size.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")

local MODULES = {
	"UnitFrames", "ActionBars", "Cooldowns", "GroupFrames", "Auras", "Nameplates", "CombatText", "Minimap", "Chat",
	"Bags", "Tooltips", "DataBars", "Meters", "Skins",
}
local KEY = "setup.window"
local TRACKED = { buffs = 80, bars = 60 }

return Common.Run(function()
	local W = dofile("Tools/regression/widget_env.lua")
	local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
	local CoreEnv = W.CoreEnv
	local frames = Gallery.Frames()
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
			EditModeFake.Install(env, { saved = {}, active = 1 })
			env.CooldownViewerSettings = { ShowUIPanel = function() end }
		end,
	}))
	for _, name in ipairs(MODULES) do
		K.Modules.Register(CoreEnv.Module(name))
	end
	CoreEnv.Boot(env)
	-- The largest text size, the summary's tightest case (codex review: the notes once ran into the reload help).
	K.Options.Write("Appearance", "fontScale", K.Theme.MAX_FONT_SCALE)
	K.Setup.EditMode.CountTracked(function(group)
		return TRACKED[group]
	end)
	assert(K.Setup.Open(true), "the setup opens as on the first login")
	W.Settle(env)
	assert(K.Setup.Go(4), "the setup moves to the summary")
	W.Settle(env)
	local panel = K.Setup.window
	assert(K.Layout.Set(KEY, "anchor", "CENTER"))
	assert(K.Layout.Set(KEY, "x", 0))
	assert(K.Layout.Set(KEY, "y", 0))
	W.Click(panel.apply)
	W.Settle(env)
	env.RunTimers()
	Gallery.Ticks(W, env, 40)
	env.RunTimers()
	assert(panel.manager:IsShown(), "the summary offers the Cooldown Manager")
	frames:Add(env, panel, {
		name = "setup_summary_tracked", title = "Setup: summary, too many tracked buffs",
		grade = "window", reference = "chat",
		caption = string.format("At the largest text size, the summary after Apply with %d tracked buffs and %d tracked bars, more than fit anywhere beside the frames: Edit Mode took the layout, Blizzard's tracked viewers stay where they were rather than cover another frame, the heading counts the steps left, each line names the count and how many would fit, and the Cooldown Manager button opens Blizzard's settings to untrack some before Try again.", TRACKED.buffs, TRACKED.bars),
		match = "Window grade as the mockup's chat panel: fill, two-line edge, 12-unit chamfer and drop shadow; the summary's text and buttons as on the other setup steps.",
	})
	return frames:Finish(Gallery.Build(env, {}), env, K, "gallery setup tracked")
end)
