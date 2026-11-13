-- test-setup-editmode-orbs.lua: a HUD style switch moves Blizzard's tracked buff viewers in the active KstyleUI Edit Mode layout of the current preset only, keeps a viewer or tracker the player moved, and Apply's own style change rewrites only the layout it applies.
local W = dofile("Tools/regression/widget_env.lua")
local CoreEnv = W.CoreEnv
local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
local VIEWER, BUFF_ICON, TRACKER = EditModeFake.VIEWER, EditModeFake.BUFF_ICON, EditModeFake.TRACKER
local Find, Named, Copy = EditModeFake.Find, EditModeFake.Named, EditModeFake.Copy

local function Same(a, b)
	return a.point == b.point and math.abs(a.offsetX - b.offsetX) < 0.01 and math.abs(a.offsetY - b.offsetY) < 0.01
end

local function Anchor(state, name, system, index)
	local layout = assert(Named(state, name), name .. " exists")
	return Copy(Find(layout, system, index).anchorInfo)
end

local state = { saved = { { layoutName = "Mine", layoutType = EditModeFake.ACCOUNT, systems = EditModeFake.Modern().systems } }, active = 1 }
local env, K = W.New({ boot = false, setup = function(e) EditModeFake.Install(e, state) end })
CoreEnv.Boot(env)
local function Style(style)
	K.Options.Write("HudStyle", "style", style)
	assert(K.HudStyle.Current() == style, "the HUD style is " .. style)
end

assert(K.Setup.Apply({ layout = "DPS", modules = {}, hudStyle = "frames" }), "Apply DPS under Frames")
local framesIcons = Anchor(state, "KstyleUI DPS", VIEWER, BUFF_ICON)
local tracker = Find(Named(state, "KstyleUI DPS"), TRACKER)
tracker.anchorInfo.offsetX = tracker.anchorInfo.offsetX + 50
local moved = Copy(tracker.anchorInfo)
local saves = state.saves

-- A switch to Orbs moves the tracked buff icons in the active layout and leaves the tracker the player moved.
Style("orbs")
assert(state.saves == saves + 1, "the switch saves the Edit Mode layouts once")
local orbsIcons = Anchor(state, "KstyleUI DPS", VIEWER, BUFF_ICON)
assert(not Same(orbsIcons, framesIcons), "the tracked buff icons move for the Orbs layout")
assert(Same(Anchor(state, "KstyleUI DPS", TRACKER), moved), "the tracker the player moved stays")

-- Apply Healer under Frames while KstyleUI DPS is active: Apply's own style change does not rewrite KstyleUI DPS.
assert(K.Setup.Apply({ layout = "Healer", modules = {}, hudStyle = "frames" }), "Apply Healer under Frames")
assert(K.HudStyle.Current() == "frames", "Apply switched the style")
assert(Same(Anchor(state, "KstyleUI DPS", VIEWER, BUFF_ICON), orbsIcons), "KstyleUI DPS keeps the placement it had")
local healerFrames = Anchor(state, "KstyleUI Healer", VIEWER, BUFF_ICON)

-- With Healer active, a switch moves Healer's viewers only.
Style("orbs")
local healerOrbs = Anchor(state, "KstyleUI Healer", VIEWER, BUFF_ICON)
assert(not Same(healerOrbs, healerFrames), "Healer's tracked buff icons move for Orbs")
assert(Same(Anchor(state, "KstyleUI DPS", VIEWER, BUFF_ICON), orbsIcons), "KstyleUI DPS is not touched")

-- A viewer the player moved in Edit Mode stays where they put it.
local icons = Find(Named(state, "KstyleUI Healer"), VIEWER, BUFF_ICON)
icons.anchorInfo.offsetY = icons.anchorInfo.offsetY + 40
local mine = Copy(icons.anchorInfo)
Style("frames")
assert(Same(Anchor(state, "KstyleUI Healer", VIEWER, BUFF_ICON), mine), "the viewer the player moved stays")

-- A switch while another layout than KstyleUI's own is active writes nothing.
state.active = 1
saves = state.saves
Style("orbs")
assert(state.saves == saves, "a switch on the player's own layout saves nothing")
-- Apply that changes the style saves Edit Mode once: its own write, not a second one from the style switch.
assert(K.Setup.Apply({ layout = "Healer", modules = {}, hudStyle = "frames" }), "Apply Healer under Frames")
saves = state.saves
assert(K.Setup.Apply({ layout = "Healer", modules = {}, hudStyle = "orbs" }), "Apply Healer with Orbs while KstyleUI Healer is active")
assert(K.HudStyle.Current() == "orbs", "Apply switched the style")
assert(state.saves == saves + 1, "Apply saves the Edit Mode layouts once, got " .. (state.saves - saves))
assert(not Same(Anchor(state, "KstyleUI Healer", VIEWER, BUFF_ICON), healerFrames), "Apply placed the viewers for Orbs")
assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
print("ok setup editmode orbs")
