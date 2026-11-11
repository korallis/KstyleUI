-- crest_states.lua: the window, tooltip and card crests before and after each state that changes their picture, at RENDER_ORNAMENTS (Off when unset), one state per run. RENDER_STATE names it: window-default, window-resized, window-dragged, window-top (dropped against the screen's top edge), window-combat (opened in combat), window-apart and window-flush (a Layout element moved against the window's top edge), tooltip-short and tooltip-long (one tooltip shown for two units of different width), tooltip-item (an item), tooltip-top (anchored at the screen's top edge). Not a gallery_ scene, so the gallery test does not run it.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Tooltip = dofile("Tools/render/scenes/tooltip.lua")

local STATE = os.getenv("RENDER_STATE") or "window-default"

local function level(K)
	local ornaments = os.getenv("RENDER_ORNAMENTS")
	if ornaments and ornaments ~= "" then
		K.Options.Write("Widgets", "ornaments", ornaments)
	end
end

local function window(frames)
	local O = dofile("Tools/regression/options_env.lua")
	local Load = dofile("Tools/regression/load_files.lua")
	local W = O.W
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
	level(K)
	if STATE == "window-combat" then
		env.SetCombat(true)
	end
	assert(K.Options.Open("General") == true, "the settings window opens on General")
	env.RunTimers()
	W.Settle(env)
	local ns = env._addons.KstyleUI_Options
	local win = ns.Window.Frame()
	local root = K.Scale.Root()
	if STATE == "window-resized" then
		win:SetSize(1240, 760)
	elseif STATE == "window-dragged" or STATE == "window-top" then
		win:StartMoving()
		win:ClearAllPoints()
		if STATE == "window-top" then
			win:SetPoint("TOP", root, "TOP", -180, 0)
		else
			win:SetPoint("CENTER", root, "CENTER", -180, -60)
		end
		win:StopMovingOrSizing()
	end
	local list = { win }
	if STATE == "window-apart" or STATE == "window-flush" then
		local neighbour = K.Widgets.Panel(root, { width = 300, height = 90 })
		neighbour:ClearAllPoints()
		neighbour:SetPoint("BOTTOM", win, "TOP", 0, STATE == "window-flush" and 0 or 40)
		list[2] = neighbour
	end
	env.RunTimers()
	W.Settle(env)
	frames:Add(env, win, { rect = Gallery.Union(env, list), name = "crest_" .. STATE:gsub("%-", "_"), title = "Settings window: " .. STATE, grade = "window", reference = "chat", caption = "The settings window's crest, " .. STATE .. ".", match = "Crest on the top edge, clear of the logo, title, search box and close button." })
	return env, K, Gallery.Build(env)
end

local UNITS = {
	short = { { "Wolf", 1, 0.1, 0.1 }, { "Level 12", 1, 1, 1 }, { "Beast", 1, 1, 1 }, { "Hostile", 1, 0.1, 0.1 } },
	long = { { "Shadowgale Poacher Lookout", 1, 0.1, 0.1 }, { "<Shadowgale Raiders of the Vale>", 0.6, 0.6, 0.6 }, { "Level 38 Humanoid (Elite)", 1, 1, 1 }, { "Target: Valerin Brightwind", 1, 1, 1 } },
	item = { { "Thornpaw Ranger's Longbow", 0.12, 1, 0 }, { "Binds when picked up", 1, 1, 1 }, { "Ranged                Bow", 1, 1, 1 }, { "38 - 71 Damage    Speed 2.80", 1, 1, 1 }, { "+7 Agility", 1, 1, 1 }, { "Requires Level 12", 1, 1, 1 } },
}

local function tooltip(frames)
	local T = dofile("Tools/regression/tooltips_env.lua")
	local env, K = T.New({
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		saved = { version = 2, profiles = { Default = { Tooltips = { enabled = true } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} },
		setup = function(env)
			Common.ForceScreen(env)
		end,
	})
	if not K.Modules.IsRunning("Tooltips") then
		K.Modules.Enable("Tooltips")
	end
	level(K)
	env.RunTimers()
	local tip = env.GameTooltip
	tip:SetOwner(env.UIParent, "ANCHOR_NONE")
	tip:ClearAllPoints()
	if STATE == "tooltip-top" then
		tip:SetPoint("TOP", env.UIParent, "TOP", 0, 0)
	else
		tip:SetPoint("BOTTOMRIGHT", env.UIParent, "BOTTOMRIGHT", -240, 300)
	end
	for _, line in ipairs(UNITS[STATE == "tooltip-short" and "short" or STATE == "tooltip-item" and "item" or "long"]) do
		tip:AddLine(line[1], line[2], line[3], line[4])
	end
	T.BlizzardShow(tip, true)
	Tooltip.Layout(env, tip)
	env.RunTimers()
	T.W.Settle(env)
	frames:Add(env, tip, { name = "crest_" .. STATE:gsub("%-", "_"), title = "Tooltip: " .. STATE, grade = "panel", reference = "player", caption = "GameTooltip's crest, " .. STATE .. ".", match = "Crest centred on the top edge, clear of the first line." })
	return env, K, Gallery.Build(env)
end

return Common.Run(function()
	local frames = Gallery.Frames()
	local build = STATE:find("^tooltip") and tooltip or window
	local env, K, scene = build(frames)
	local err = Common.Errors(env, K)
	assert(not err, tostring(err))
	return frames:Finish(scene, env, K, "crest states")
end)
