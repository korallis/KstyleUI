-- test-skins-paperdoll.lua: the character stand-in is Forever's PaperDollFrame, laid out by its XML and Lua anchors
-- (the top strip with the level line, the model scene under it across the left pane, the equipment columns on the
-- pane's edges, the weapon row under the model, the stats pane under the stone cap), so the skin is judged on the
-- real window; and the skin spaces the sidebar tabs by the kit's gap, through Blizzard's own relayout.
local S = dofile("Tools/regression/skins_env.lua")
local Windows = dofile("Tools/regression/skins_windows.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local Measure = dofile("Tools/regression/databars_env.lua")
local W = S.W

local EPS = 0.01

local function Open(key)
	local spec = Windows.Spec(key)
	local B, parts
	local env, K, ns = S.New({
		setup = function(env)
			env._textWidth = Measure.TextWidth
		end,
		before = function(env)
			B = S.Blizzard(env)
			parts = select(2, Windows.Build(key, env, B))
		end,
	})
	K.Modules.Enable("Skins")
	if spec.addon then
		S.LoadAddOn(env, spec.addon)
	end
	for _, shown in ipairs(parts.show) do
		S.Show(shown)
	end
	env.RunTimers()
	W.Settle(env)
	for _, skin in ipairs(spec.skins) do
		assert(ns.Skins.IsApplied(skin), key .. ": the " .. skin .. " skin applies")
	end
	return env, K, ns, parts
end

local function Rect(region, root)
	local rect, why = Geometry.Rect(region, root)
	assert(rect, tostring(why))
	return rect
end

local function Same(a, b, what)
	assert(math.abs(a - b) <= EPS, what .. ": " .. a .. " vs " .. b)
end

local env, K, _, parts = Open("character")
local root = env.UIParent
local f = env.CharacterFrame
local window = Rect(f, root)
local left, right = Rect(f.LeftPaneHost, root), Rect(f.RightPaneHost, root)

-- The panes (Camelot/CharacterFrame.xml:407 and :424): the left pane is 398 wide from 20 under the window's top
-- to its bottom; the right pane is 233 wide beside it.
Same(left.left, window.left, "the left pane starts at the window's left")
Same(left.top, window.top - 20, "and 20 under its top")
Same(left.bottom, window.bottom, "down to its bottom")
Same(left.right - left.left, 398, "398 wide")
Same(right.left, left.right, "the right pane starts where the left pane ends")
Same(right.right - right.left, 233, "233 wide")

-- The paper doll (Camelot/PaperDollFrame.xml:554 onward): a 36-unit strip across the top of the left pane carries
-- the level line; the model scene fills the pane under the strip; the slots sit 24 in from the pane's left and
-- 20 from its right, 60 under its top, 6 apart; the weapons sit on the pane's bottom, 30 up, the main hand
-- centred 40 left of the pane's centre (PaperDollFrame.lua:1938), the others 6 to its right.
local doll = env.PaperDollFrame
local strip = Rect(doll.TopBackgroundStripHost, root)
Same(strip.top, left.top, "the top strip sits on the left pane's top")
Same(strip.top - strip.bottom, 36, "36 high")
Same(strip.left, left.left, "across the pane")
Same(strip.right, left.right, "to its right edge")
local level = Rect(env.CharacterLevelText, root)
Same((level.left + level.right) / 2, (strip.left + strip.right) / 2, "the level line is centred on the strip")
assert(level.top <= strip.top + EPS and level.bottom >= strip.bottom - EPS, "inside it")
local scene = Rect(env.CharacterModelScene, root)
Same(scene.top, strip.bottom, "the model scene starts under the strip")
Same(scene.bottom, left.bottom, "and reaches the pane's bottom")
Same(scene.left, left.left, "across the pane")
Same(scene.right, left.right, "to its right edge")
assert(type(parts.models) == "table" and #parts.models == 1, "the scene names the texture the game paints the model on")
local head, neck, hands = Rect(env.CharacterHeadSlot, root), Rect(env.CharacterNeckSlot, root), Rect(env.CharacterHandsSlot, root)
Same(head.left, left.left + 24, "the head slot is 24 in from the pane's left")
Same(head.top, left.top - 60, "60 under its top")
Same(head.right - head.left, 37, "37 wide")
Same(neck.top, head.bottom - 6, "the next slot is 6 under it")
Same(neck.left, head.left, "in the same column")
Same(hands.right, left.right - 20, "the hands slot is 20 in from the pane's right")
Same(hands.top, left.top - 60, "60 under its top")
local wrist = Rect(env.CharacterWristSlot, root)
Same(wrist.top, head.top - 7 * (37 + 6), "the left column holds eight slots")
local trinket = Rect(env.CharacterTrinket1Slot, root)
Same(trinket.top, hands.top - 7 * (37 + 6), "the right column holds eight")
local main, off, ranged = Rect(env.CharacterMainHandSlot, root), Rect(env.CharacterSecondaryHandSlot, root), Rect(env.CharacterRangedSlot, root)
Same(main.bottom, left.bottom + 30, "the main hand sits 30 up from the pane's bottom")
Same((main.left + main.right) / 2, (left.left + left.right) / 2 - 40, "40 left of the pane's centre")
Same(off.left, main.right + 6, "the off hand 6 to its right")
Same(ranged.left, off.right + 6, "the ranged slot 6 after that")
assert(main.left > head.right and ranged.right < hands.left, "the weapon row sits between the columns")

-- The right pane (CharacterFrame.xml:435 and :463): a 60-unit stone cap holds the sidebar tabs; the stats pane
-- runs from the cap's bottom to the pane's bottom.
local stats = Rect(env.CharacterStatsPaneScrollBox, root)
Same(stats.top, right.top - 60, "the stats pane starts under the stone cap")
Same(stats.bottom, right.bottom, "and reaches the pane's bottom")
Same(stats.left, right.left, "across the pane")
Same(stats.right, right.right, "to its right edge")

-- The skin spaces the three sidebar tabs by the kit's small gap, so their rims never cross, and keeps the gap
-- when Blizzard lays the tabs out again (PaperDollFrame_UpdateSidebarTabLayout, which Blizzard runs on every
-- sidebar update and anchors the tabs flush).
local gap = K.Widgets.Snap(f, K.Tokens.Size("gapSmall"))
local function Gaps(when)
	local t1, t2, t3 = Rect(env.PaperDollSidebarTab1, root), Rect(env.PaperDollSidebarTab2, root), Rect(env.PaperDollSidebarTab3, root)
	Same(t2.left - t1.right, gap, when .. ": a small gap between the first and second sidebar tab")
	Same(t3.left - t2.right, gap, when .. ": and between the second and third")
	Same(t1.top, t2.top, when .. ": on one row")
	local holder = Rect(env.PaperDollSidebarTabs, root)
	assert(t1.left >= holder.left - EPS and t3.right <= holder.right + EPS, when .. ": inside the holder")
end
Gaps("after the skin")
env.PaperDollFrame_UpdateSidebarTabLayout()
Gaps("after Blizzard's relayout")
assert(#env._errors == 0, tostring(env._errors[1]))
print("skins paperdoll ok")
