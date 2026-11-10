-- native_menu_env.lua: the three KstyleUI menu generators and the context-menu skin in one stub environment, over the native menu fixture.
--
--   local E = dofile("Tools/regression/native_menu_env.lua")
--   local env, K, ns, nm = E.New({ material = "Slate" })
--   local menu, owner = E.Tracking(env, nm)     -- Column.OpenTracking, through a click on the minimap's tracking button
--   local menu, owner = E.Compartment(env, nm)  -- Drawer.OpenCompartment, through a right click on the drawer button
--   local menu, owner = E.Quest(env, nm)        -- the quest card's right-click menu on its first row
-- A true last-but-one argument (the third; Quest takes the row index after it) runs the opener's own function or script directly,
-- for an owner a test has made protected, so the click helpers' own writes cannot reach it.
--
-- New(opts) boots the core, KstyleUI_Skins (with its quest card) and KstyleUI_Minimap, the three with Blizzard's minimap
-- frames and the quest fakes the module tests use, and installs the native menu fixture last so it replaces the
-- tests' MenuUtil. opts: material (the saved card material), skins (false leaves the Skins module off), skin (false
-- switches the context-menu skin off in the saved data), variant (the fixture's menu style), at ({ x, y } puts every menu there),
-- hooks (the fixture's hooks), setup (runs first, on the bare environment, and may replace env._textWidth, which the fixture then measures with), modify (Menu.ModifyMenu callbacks by tag, registered before the skin's, as an addon loaded earlier would), quests (the tracked quests), measure (false keeps the fixture's fixed text advance).
local S = dofile("Tools/regression/skins_env.lua")
local M = dofile("Tools/regression/minimap_env.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local Native = dofile("Tools/regression/native_menu_fixture.lua")
local Measure = dofile("Tools/regression/databars_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local W = S.W

local E = { S = S, M = M, W = W, Quests = Quests, Native = Native }

E.MATERIALS = { "Glass", "Flat", "Slate", "ForgedTicks", "ForgedBrackets" }

local function Saved(opts)
	local profile = { Appearance = { uiScale = 16 / 19 } }
	if opts.material then
		profile.Widgets = { cardMaterial = opts.material }
	end
	if opts.skin == false then
		profile.Skins = { contextMenus = { enabled = false } }
	end
	return { version = 12, profiles = { Default = profile }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

function E.New(opts)
	opts = opts or {}
	local nm, tracker, log
	local env, K, ns = S.New({
		saved = opts.saved or Saved(opts),
		setup = function(env)
			M.Blizzard(env, {})
			log = Quests.Install(env, opts.quests or Quests.List(4))
			log.super = 0
			env._textWidth = Measure.TextWidth
			if opts.setup then
				opts.setup(env)
			end
			nm = Native.Install(env, {
				variant = opts.variant,
				at = opts.at,
				hooks = opts.hooks,
				measure = opts.measure ~= false and env._textWidth or nil,
			})
			for tag, callback in pairs(opts.modify or {}) do
				env.Menu.ModifyMenu(tag, callback)
			end
		end,
		before = function(env)
			tracker = Quests.Tracker(env, S.Blizzard(env))
		end,
	})
	Load(M.Files(), env)
	if opts.skins ~= false then
		K.Modules.Enable("Skins")
		S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	end
	K.Modules.Enable("Minimap")
	env.RunTimers()
	W.Settle(env)
	env._quests, env._tracker = log, tracker
	return env, K, ns, nm
end

function E.Minimap(env)
	return env._addons.KstyleUI_Minimap
end

function E.Tracking(env, nm, direct)
	local buttons = E.Minimap(env).Map.column.buttons
	nm.last = nil
	if direct then
		E.Minimap(env).Column.OpenTracking(buttons.tracking)
	else
		W.Click(buttons.tracking)
	end
	return nm.last, buttons.tracking
end

function E.Compartment(env, nm, direct)
	local buttons = E.Minimap(env).Map.column.buttons
	env.AddonCompartmentFrame.registeredAddons = env.AddonCompartmentFrame.registeredAddons or {}
	if #env.AddonCompartmentFrame.registeredAddons == 0 then
		env.AddonCompartmentFrame.registeredAddons = {
			{ text = "Details!", func = function() end },
			{ text = "BugSack", func = function() end },
			{ text = "Plater", func = function() end },
		}
	end
	nm.last = nil
	if direct then
		E.Minimap(env).Drawer.OpenCompartment(buttons.drawer)
	else
		W.Click(buttons.drawer, "RightButton")
	end
	return nm.last, buttons.drawer
end

function E.Quest(env, nm, direct, index)
	local ns = env._addons.KstyleUI_Skins
	local row = ns.Quests.Rows()[index or 1]
	nm.last = nil
	if direct then
		row:GetScript("OnClick")(row, "RightButton")
	else
		W.Click(row, "RightButton")
	end
	return nm.last, row
end

return E
