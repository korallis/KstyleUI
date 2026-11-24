-- test-container-fades.lua: with Motion on and client animations that never step, every window, page, menu, tooltip, drawer, feed card, Layout Mode screen and target body shows whole the moment it opens and is gone the moment it closes, as with Motion Off.

local function Whole(env, frame, what)
	local alpha = frame:GetEffectiveAlpha()
	assert(frame:IsVisible() and alpha == 1, what .. " shows whole the moment it opens with Motion on (effective alpha " .. tostring(alpha) .. "); show a window, page, menu or card at once, with no alpha fade")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

local function Gone(env, frame, what)
	assert(not frame:IsShown(), what .. " hides the moment it closes with Motion on; hide it at once, since a close fade the client never steps leaves an invisible window that takes clicks")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

local function Stall(env, K)
	env.RunTimers()
	K.Motion.SetLevel("full")
	env._stalled = true
end

-- Core: the card panel, a dropdown menu, the kit tooltip and a skinned Blizzard window.
do
	local W = dofile("Tools/regression/widget_env.lua")
	local env, K = W.New()
	Stall(env, K)
	local panel = K.Widgets.Panel(nil, { hidden = true })
	panel:Open()
	Whole(env, panel, "A KstyleUI window")
	panel:Close()
	Gone(env, panel, "A KstyleUI window")
	local dropdown = K.Widgets.Dropdown(K.Scale.Root(), { options = { { value = 1, label = "One" }, { value = 2, label = "Two" } } })
	local menu = K.Widgets.DropdownMenu()
	dropdown:Open()
	Whole(env, menu, "A dropdown menu")
	dropdown:Close()
	Gone(env, menu, "A dropdown menu")
	local tip = K.Widgets.Tooltip()
	tip:SetOwner(K.Scale.Root(), "ANCHOR_TOP")
	tip:AddLine("One")
	tip:Show()
	Whole(env, tip, "The kit tooltip")
	tip:Hide()
	Gone(env, tip, "The kit tooltip")
	local blizzard = env.CreateFrame("Frame", nil, env.UIParent)
	K.Skin.Window(blizzard)
	blizzard:Hide()
	blizzard:Show()
	Whole(env, blizzard, "A skinned Blizzard window")
	assert(K.Layout.Enter())
	Whole(env, K.Layout.Mode.Overlay(), "Layout Mode's screen")
	K.Layout.Exit(true)
	Gone(env, K.Layout.Mode.Overlay(), "Layout Mode's screen")
end

-- Options: the window, a page change and its preview.
do
	local O = dofile("Tools/regression/options_env.lua")
	local env, K, ns = O.New()
	Stall(env, K)
	K.Options.Open("General")
	local win, parts = ns.Window.Frame(), ns.Window.Parts()
	Whole(env, win, "The Options window")
	K.Options.Open("About")
	K.Options.Open("General")
	Whole(env, parts.content, "An Options page after a page change")
	Whole(env, parts.preview.current, "The Options live preview after a page change")
	win:Close()
	Gone(env, win, "The Options window")
end

-- Minimap: the addon-button drawer and the micro menu.
do
	local M = dofile("Tools/regression/minimap_env.lua")
	local env, K, ns = M.New({ enabled = true, setup = function(e)
		M.FakeLibDBIcon(e):Add("Bravo")
		e.CreateFrame("Button", "CharacterMicroButton", e.UIParent)
	end })
	Stall(env, K)
	local drawer = ns.Map.drawer
	drawer:Open()
	Whole(env, drawer.panel, "The minimap drawer")
	drawer:Close()
	Gone(env, drawer.panel, "The minimap drawer")
	K.Options.Write("Minimap", "microMenu", true)
	ns.Micro.Toggle(env.Minimap)
	Whole(env, ns.Micro.panel, "The micro menu")
	ns.Micro.Close()
	Gone(env, ns.Micro.panel, "The micro menu")
end

-- Tooltips: the game tooltip on the quest card.
do
	local T = dofile("Tools/regression/tooltips_env.lua")
	local env, K = T.New()
	K.Modules.Enable("Tooltips")
	Stall(env, K)
	T.BlizzardShow(env.GameTooltip, true)
	Whole(env, env.GameTooltip, "The game tooltip")
end

-- QoL: the loot feed's card.
do
	local Q = dofile("Tools/regression/qol_env.lua")
	local env, K, ns = Q.New()
	env._items[2589] = { icon = 132889, quality = 2 }
	Q.Enable(env, K)
	Stall(env, K)
	env.FireEvent("CHAT_MSG_LOOT", "You receive loot: |cff1eff00|Hitem:2589::::::::38:::::|h[Linen Cloth]|h|r", "Korallis", "", "", "Korallis", "", 0, 0, "", 0, 1, "Player-1-1", 0)
	Whole(env, ns.Feed.Backdrop(), "The loot feed card")
	env.Release()
	Gone(env, ns.Feed.Backdrop(), "The loot feed card")
end

-- Unit frames: the target body on a new target, a target change and target loss.
do
	local U = dofile("Tools/regression/unitframes_env.lua")
	local env, K, ns = U.New()
	local view = ns.Frames.Get("target").views[1]
	local function Target(name)
		U.SetUnit(env, "target", { name = name, level = 10, health = 80, healthMax = 100, reaction = 2, canAttack = true })
		env.SetTarget(true)
	end
	Stall(env, K)
	Target("Wolf")
	Whole(env, view.body, "The target frame on a new target")
	Target("Boar")
	Whole(env, view.body, "The target frame on a target change")
	assert(U.Shown(env, view.name) == "BOAR", "a target change shows the new target at once")
	env._units.target = nil
	env.SetTarget(false)
	Gone(env, view.body, "The target frame on target loss")
end
print("container fades ok")
