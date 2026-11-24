-- test-unitframes-aura-timer-rim.lua: on Medallions each player, target and focus aura timer and stack count stays clear of its portrait rim and slab at the four owner screens, live and in the Options preview, while a Frames row set to grow up keeps its place.
local Reach = dofile("Tools/regression/hud_reach_lib.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local A = dofile("Tools/regression/auras_env.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local function overlaps(a, b)
	return a.left < b.right and b.left < a.right and a.bottom < b.top and b.bottom < a.top
end

local function clear(text, root, rims, label)
	text:SetSize(text:GetStringWidth(), text:GetStringHeight())
	local r = assert(Geometry.Rect(text, root))
	for name, rim in pairs(rims) do
		assert(not overlaps(r, rim), string.format("%s (bottom %.1f) overlaps the %s (top %.1f): lift the row above its timer lane (Auras.Lift) and clear the portrait (Geometry slab aura spot)", label, r.bottom, name, rim.top))
	end
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K = Reach.New(screen[1], screen[2], "medallions", "DPS")
	K.Options.Write("UnitFrames", "player.medallionsAuras", true)
	K.Options.Write("UnitFrames", "player.auraFilter", "buffs")
	env.RunTimers()
	local ns, root = env._addons.KstyleUI_UnitFrames, K.Scale.Root()
	for _, kind in ipairs({ "player", "target", "focus" }) do
		local view = ns.Frames.Get(kind).views[1]
		assert(view.auras, kind .. ": the fixture shows its aura row")
		local key = kind == "player" and "buffs" or "debuffs"
		local c = view.auras.container
		local group = c._groups[key]
		A.Assign(env, c, key, group.maxFrameCount)
		Hud.PlaceAuras(c, group, group.active, ns.Settings.Value(kind, "auraColumns"))
		assert(#group.active > 0, kind .. ": the fixture shows auras")
		local rims = { ["portrait rim"] = assert(Geometry.Rect(view.medallion, root)), slab = assert(Geometry.Rect(view.button, root)) }
		for i, button in ipairs(group.active) do
			button._aura.timer:SetText("30s")
			button._aura.count:SetText("3")
			local label = string.format("%dx%d %s aura %d", screen[1], screen[2], kind, i)
			clear(button._aura.timer, root, rims, label .. " timer")
			clear(button._aura.count, root, rims, label .. " count")
		end
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end

local env, K, ns = U.New()
env._textWidth = function(text, path, size) return Scene.TextWidth(text, size, path) end
for _, kind in ipairs({ "target", "focus" }) do
	K.Options.Write("UnitFrames", "edit", kind)
	env.RunTimers()
	local pane = env.CreateFrame("Frame", nil, K.Scale.Root())
	pane:SetSize(280, 560)
	pane:SetPoint("CENTER")
	local preview = K.Options.Preview("UnitFrames")(pane)
	local root = preview.holders[kind]
	local rims = { ["preview portrait rim"] = assert(Geometry.Rect(preview.views[kind].medallion, root)) }
	local shown = 0
	for i, tile in ipairs(preview.auraTiles[kind]) do
		if tile.skin:IsShown() then
			shown = shown + 1
			clear(tile.timer, root, rims, "Options preview " .. kind .. " aura " .. i .. " timer")
		end
	end
	assert(shown > 0, kind .. ": the preview shows auras")
end
assert(#env._errors == 0, tostring(env._errors[1]))

env, K, ns = U.New({ frames = true })
for _, growth in ipairs({ "LEFT_UP", "RIGHT_UP" }) do
	K.Options.Write("UnitFrames", "target.auraGrowth", growth)
	env.RunTimers()
	local _, _, _, x, y = ns.Frames.Get("target").views[1].auras.container:GetPoint(1)
	assert(x == 0 and y == 0, "Frames: a target row set to " .. growth .. " keeps its place in its host, got " .. tostring(x) .. ", " .. tostring(y))
end
assert(#env._errors == 0, tostring(env._errors[1]))
print("ok Medallions aura timers clear the portrait rim and slab")
