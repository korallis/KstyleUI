-- gallery_setup.lua: the first-run setup window on each of its four steps, each in its own environment so the one
-- window shows four times: the welcome step, the layout step with the DPS card picked and the Tank card under the
-- mouse, the module step with every module on but one, and the summary ready to apply. Every module in the picker
-- is registered (Icons is a core module and needs no stand-in) so the toggles are live. The windows are scaled to 0.9 so four fit the screen apart.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Scene = Common.Scene

local MODULES = {
	"UnitFrames", "ActionBars", "Cooldowns", "GroupFrames", "Auras", "Nameplates", "CombatText", "Minimap", "Chat",
	"Bags", "Tooltips", "DataBars", "Meters", "Skins",
}
local KEY = "setup.window"
local SCALE = 0.9

-- Step(W, step, x, y, prepare) -> env, K, panel: the setup open on one step, its window's top left at x, y.
local function Step(W, step, x, y, prepare)
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
	assert(K.Setup.Go(step), "the setup moves to step " .. step)
	W.Settle(env)
	local panel = K.Setup.window
	assert(K.Layout.Set(KEY, "scale", SCALE))
	assert(K.Layout.Set(KEY, "anchor", "TOPLEFT"))
	assert(K.Layout.Set(KEY, "x", x))
	assert(K.Layout.Set(KEY, "y", -y))
	local hover = {}
	if prepare then
		prepare(env, K, panel, hover)
	end
	env.RunTimers()
	Gallery.Ticks(W, env, 40)
	env.RunTimers()
	return env, K, panel, hover
end

return Common.Run(function()
	local W = dofile("Tools/regression/widget_env.lua")
	local frames = Gallery.Frames()
	local scenes = {}
	local lastEnv, lastK

	local function add(env, K, panel, hover, spec)
		frames:Add(env, panel, spec)
		scenes[#scenes + 1] = Gallery.Build(env, { hover = hover })
		lastEnv, lastK = env, K
		local err = Common.Errors(env, K)
		assert(not err, spec.name .. ": " .. tostring(err))
	end

	-- Step 1: welcome.
	local env, K, panel, hover = Step(W, 1, 60, 30)
	add(env, K, panel, hover, {
		name = "setup_welcome", title = "Setup: welcome", grade = "window", reference = "chat",
		caption = "The first-run setup on its welcome step: a titled glass window with the four-step tab strip on the button body, the logo, the welcome text, the note that closing applies the DPS layout, the Keep my UI opt-out and the primary Next button.",
		match = "Window grade as the mockup's chat panel: the surface fill, the dark outer and light inner lines, the 12-unit chamfer and the drop shadow; the tab strip inside is the button body.",
	})

	-- Step 2: the three layout cards, DPS picked, Tank under the mouse.
	env, K, panel, hover = Step(W, 2, 880, 30, function(stepEnv, _, stepPanel, stepHover)
		W.Enter(stepPanel.cards.Tank)
		stepHover[stepPanel.cards.Tank] = true
		W.Settle(stepEnv)
	end)
	add(env, K, panel, hover, {
		name = "setup_layouts", title = "Setup: layouts", grade = "window", reference = "chat",
		caption = "The layout step: three role cards on the button body over one large 16:9 preview drawing the hovered layout's real footprints, each block named where its name fits and the role blocks in the accent; DPS is picked with the accent edge and glow, Tank is under the mouse, so the preview shows Tank's threat card in the cluster. The legend beside it names the story rail.",
		match = "The window is the chat panel's glass; the cards are the button body #101214 with the one-border light line, as the mockup's data strip; the preview is the glass fill with the two lines and shadow at the tile chamfer, as the mockup's level badges.",
	})

	-- Step 3: the module toggles, every module on but the window skins.
	env, K, panel, hover = Step(W, 3, 60, 560, function(_, _, modules)
		modules.toggles.Skins:SetValue(false)
	end)
	add(env, K, panel, hover, {
		name = "setup_modules", title = "Setup: modules", grade = "window", reference = "chat",
		caption = "The module step: fifteen toggles with a one-line note each, All on and All off, every module on but Window skins.",
		match = "Window grade as the mockup's chat panel; the toggles' pill tracks are the bar grade's surface fill and the text buttons the button body.",
	})

	-- Step 4: the summary after Apply, when Edit Mode refused the layout because every account slot was taken.
	env, K, panel, hover = Step(W, 4, 880, 560, function(stepEnv, _, stepPanel)
		local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
		local full = {}
		for i = 1, 5 do
			full[i] = { layoutName = "Mine " .. i, layoutType = EditModeFake.ACCOUNT, systems = EditModeFake.Modern().systems }
		end
		EditModeFake.Install(stepEnv, { saved = full, active = 3, max = 5 })
		W.Click(stepPanel.apply)
		W.Settle(stepEnv)
	end)
	add(env, K, panel, hover, {
		name = "setup_summary", title = "Setup: summary", grade = "window", reference = "chat",
		caption = "The summary step after Apply: the layout and the modules on and off, a preview of the layout Apply built, what Edit Mode did (here it refused, every account layout being taken, with the reason and a one-click Try again), the reload help, Later and the primary Reload button.",
		match = "Window grade as the mockup's chat panel: fill, two-line edge, 12-unit chamfer and drop shadow; the preview is the glass fill at the tile chamfer, as on the layout step.",
	})

	return frames:Finish(Scene.Merge(scenes), lastEnv, lastK, "gallery setup")
end)
