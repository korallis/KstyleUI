-- test-unitframes-column-keep.lua: a column frame's portrait and side auras stand outside its element, so a saved position that would put them off screen is shifted back on, out of combat only.
local U = dofile("Tools/regression/unitframes_env.lua")

local env, K, ns = U.New()
local Layout, Geometry, Frames, Settings = K.Layout, ns.Geometry, ns.Frames, ns.Settings
local Measure = dofile("Tools/regression/geometry.lua")

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 0.5)
end

local rootW = Layout.RootSize()
local PLAYER, TARGET = "unitframes.player", "unitframes.target"
local playerLeft, targetRight = Geometry.Reach(Settings.Snapshot("player")), select(2, Geometry.Reach(Settings.Snapshot("target")))
assert(near(playerLeft, 91.5), "the player reaches 91.5 left of its element")
assert(near(targetRight, 14 + 77.5 + 16.5 + 4 * 27.6 + 3 * 4), "the target reaches its portrait and four 27.6-unit debuffs to the right, got " .. targetRight)

U.SetUnit(env, "target", { name = "Shadowgale Poacher", level = 12, health = 50, healthMax = 100, reaction = 2, canAttack = true })
env.FireEvent("PLAYER_TARGET_CHANGED")
env.RunTimers()

local function Fill(view)
	view.auras.container:_Acquire("debuffs", 4)
	for _, entry in ipairs(view.auras.buttons) do
		ns.Auras.LayoutTile(entry)
	end
end

local function Edges(kind)
	local root = K.Scale.Root()
	local view = Frames.Get(kind).views[1]
	if kind == "target" then
		Fill(view)
	end
	local left, right = math.huge, -math.huge
	for _, frame in ipairs({ view.button, view.portraitFrame, kind == "target" and view.auras.host or nil }) do
		local r = assert(Measure.Rect(frame, root), kind .. ": a part has no rect")
		left, right = math.min(left, r.left), math.max(right, r.right)
	end
	return left, right
end

local function PutLeft(key, left)
	local was = Layout.Rect(key)
	assert(Layout.Set(key, "x", Layout.Get(key).x + (left - was)), "Layout takes the position")
end

PutLeft(PLAYER, 20)
env.RunTimers()
local left, _, w = Layout.Rect(PLAYER)
assert(near(left, playerLeft, 1), "a player saved 20 units from the screen's left edge is moved so its portrait is on screen: left " .. left)
assert(Layout.Get(PLAYER).x == Layout.Get(PLAYER).x and left - playerLeft >= -1, "and no further")
assert(w == 491, "its size is unchanged")
local settled = Layout.Get(PLAYER).x
Frames.Relayout(Frames.Get("player"))
env.RunTimers()
assert(Layout.Get(PLAYER).x == settled, "a position that already clears the edge is left alone")
PutLeft(PLAYER, 300)
env.RunTimers()
assert(near(Layout.Rect(PLAYER), 300), "a centred player is not moved")

local _, _, tw = Layout.Rect(TARGET)
PutLeft(TARGET, rootW - tw - 30)
env.RunTimers()
local tl = Layout.Rect(TARGET)
local _, edge = Edges("target")
assert(near(edge, rootW, 0.01), "a target saved 30 units from the right edge is moved so its snapped debuffs end at the edge: " .. edge .. " of " .. rootW)
local nominal = tl + tw + targetRight
assert(edge - nominal > -0.01 and edge - nominal < 3, "the whole-pixel row ends under three units past the nominal reach: " .. edge - nominal)
PutLeft(TARGET, 500)
env.RunTimers()
assert(near(Layout.Rect(TARGET), 500), "a target with room to spare is not moved")

K.Options.Write("UnitFrames", "target.auras", false)
local reachOff = select(2, Geometry.Reach(Settings.Snapshot("target")))
assert(near(reachOff, 14 + 77.5), "with the debuffs off the target reaches only its portrait")
PutLeft(TARGET, rootW - tw - 100)
env.RunTimers()
assert(near(Layout.Rect(TARGET), rootW - tw - 100), "which still fits at 100 units from the edge")
K.Options.Write("UnitFrames", "target.auras", true)

assert(Layout.Set(PLAYER, "scale", 1.5) == false, "these elements cannot be scaled, so a reach is always in root units")
PutLeft(PLAYER, 300)
env.RunTimers()

local before = Layout.Get(PLAYER).x
env.SetCombat(true)
PutLeft(PLAYER, 20)
env.RunTimers()
local inCombat = Layout.Get(PLAYER).x
assert(near(Layout.Rect(PLAYER), 20), "in combat the saved position stays where it was put")
assert(inCombat ~= before, "the move itself was written")
env.SetCombat(false)
env.RunTimers()
assert(near(Layout.Rect(PLAYER), playerLeft, 1), "the shift runs when combat ends")
local after = Layout.Get(PLAYER).x
env.RunTimers()
assert(Layout.Get(PLAYER).x == after, "and runs once")
noErrors("keep")

local SCREENS = { { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3456, 2234 }, { 3840, 2160 }, { 5120, 1440 } }
for _, uiScale in ipairs({ 0.65, 768 / 1080, 1.15 }) do
	local senv, SK, sns = U.New({ fit = true, size = "default", uiScale = uiScale })
	U.SetUnit(senv, "target", { name = "Shadowgale Poacher", level = 12, health = 50, healthMax = 100, reaction = 2, canAttack = true })
	senv.FireEvent("PLAYER_TARGET_CHANGED")
	senv.RunTimers()
	for _, screen in ipairs(SCREENS) do
		senv.GetPhysicalScreenSize = function() return screen[1], screen[2] end
		senv.UIParent:SetSize(768 * screen[1] / screen[2] / uiScale, 768 / uiScale)
		senv.FireEvent("DISPLAY_SIZE_CHANGED")
		for _, size in ipairs({ 0.6, 16 / 19, 1.5 }) do
			SK.Scale.SetUserScale(size)
			senv.RunTimers()
			local where = string.format("%dx%d UI %.4f requested %.4f applied %.4f", screen[1], screen[2], uiScale, size, SK.Scale.AppliedUserScale())
			local root = SK.Scale.Root()
			local width = SK.Layout.RootSize()
			local function edges(kind)
				local view = sns.Frames.Get(kind).views[1]
				if kind == "target" then
					view.auras.container:_Acquire("debuffs", 4)
					for _, entry in ipairs(view.auras.buttons) do
						sns.Auras.LayoutTile(entry)
					end
				end
				local lo, right = math.huge, -math.huge
				for _, frame in ipairs({ view.button, view.portraitFrame, kind == "target" and view.auras.host or nil }) do
					local r = assert(Measure.Rect(frame, root), where .. ": " .. kind .. " has a part without a rect")
					lo, right = math.min(lo, r.left), math.max(right, r.right)
				end
				return lo, right
			end
			local function put(key, to)
				local was = SK.Layout.Rect(key)
				SK.Layout.Set(key, "x", SK.Layout.Get(key).x + (to - was))
				senv.RunTimers()
			end
			local _, tw2 = SK.Layout.Rect(TARGET)
			local pw = select(3, SK.Layout.Rect(PLAYER))
			put(TARGET, width - tw2 + 40)
			local _, right = edges("target")
			assert(math.abs(right - width) < 0.01, where .. ": a target pushed off the right edge ends its snapped debuffs exactly at it: " .. right .. " of " .. width)
			put(PLAYER, -60)
			local lo = edges("player")
			assert(math.abs(lo) < 0.01, where .. ": a player pushed off the left edge starts its portrait exactly at it: " .. lo)
			put(TARGET, width / 2 - tw2 / 2)
			put(PLAYER, width / 2 - pw / 2)
			local settledX = SK.Layout.Get(TARGET).x
			sns.Frames.Relayout(sns.Frames.Get("target"))
			senv.RunTimers()
			assert(SK.Layout.Get(TARGET).x == settledX, where .. ": a position with room to spare is not moved")
			assert(#senv._errors == 0 and SK.ErrorCount() == 0, where .. ": " .. tostring(senv._errors[1]))
		end
	end
end
