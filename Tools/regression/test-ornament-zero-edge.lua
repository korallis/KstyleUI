-- test-ornament-zero-edge.lua: a frame or an obstacle whose edge lies exactly at 0 is a known edge, so bars at Subtle and Full, and rings and the pieces that avoid a frame at Full, place the same set at the screen's left or bottom edge, and off it, as one step inside it, while a frame with no anchors still draws nothing.
local W = dofile("Tools/regression/widget_env.lua")
local env, K = W.New()
local widgets = K.Widgets
local profile = K.Store.Module("Widgets")
profile.cardMaterial, profile.ornaments = "ForgedBrackets", "Full"
local root = K.Scale.Root()
local pixel = K.Scale.Pixel(1) / widgets.ScaleFactor(root)
local STEP = 40

local function set(handle)
	local names = {}
	for i = 1, handle.used do
		local texture = handle.textures[i]
		if texture:IsShown() then
			local _, _, _, x, y = texture:GetPoint(1)
			local w, h = texture:GetSize()
			names[#names + 1] = string.format("%s@%.3f,%.3f,%.3f,%.3f", (texture:GetTexture() or ""):match("([%w]+)%.png$") or "Fill", x / pixel, y / pixel, w / pixel, h / pixel)
		end
	end
	return table.concat(names, " ")
end

local function frame(w, h)
	local f = env.CreateFrame("Frame", nil, root)
	f:SetSize(w * pixel, h * pixel)
	return f
end

local function at(f, point, x, y)
	f:ClearAllPoints()
	f:SetPoint(point, root, point, x * pixel, y * pixel)
end

local checked = 0
local function same(label, place, handle, levels)
	for _, level in ipairs(levels or { "Subtle", "Full" }) do
		profile.ornaments = level
		place(STEP)
		handle:Restyle()
		local inside = set(handle)
		assert(inside ~= "", level .. " " .. label .. ": one step inside the screen the handle draws")
		place(0)
		handle:Restyle()
		local edge = set(handle)
		assert(edge == inside, level .. " " .. label .. ": an edge at 0 is known and draws the same set\n  inside " .. inside .. "\n  at 0   " .. edge)
		place(-STEP / 2)
		handle:Restyle()
		local beyond = set(handle)
		assert(beyond == inside, level .. " " .. label .. ": a negative edge off the screen is known and draws the same set\n  inside " .. inside .. "\n  beyond " .. beyond)
		checked = checked + 1
	end
end

local bar = frame(120, 10)
local caps = widgets.Ornament(bar, "bar")
same("a bar whose left edge is at 0", function(d) at(bar, "TOPLEFT", d, -300) end, caps)
same("a bar whose bottom edge is at 0", function(d) at(bar, "BOTTOMLEFT", 500, d) end, caps)

local lane = frame(120, 6)
caps.near = { lane }
same("a bar above a neighbouring lane whose bottom edge is at 0", function(d)
	at(lane, "BOTTOMLEFT", 500, d)
	at(bar, "BOTTOMLEFT", 500, d + 10)
end, caps)
caps.near = nil

local label = env.CreateFrame("Frame", nil, bar)
label:SetSize(30 * pixel, 8 * pixel)
caps.texts = { label }
same("a bar beside a text whose left edge is at 0", function(d)
	at(bar, "TOPLEFT", d + 60, -300)
	label:ClearAllPoints()
	label:SetPoint("TOPLEFT", root, "TOPLEFT", d * pixel, -280 * pixel)
end, caps)
caps.texts = nil

local portrait = frame(59, 59)
local ring = widgets.Ornament(portrait, "ring")
same("a portrait ring whose left edge is at 0", function(d) at(portrait, "TOPLEFT", d, -300) end, ring, { "Full" })

local far = frame(20, 20)
ring.avoid, ring.avoidShown = { far }, true
same("a portrait ring that avoids a frame whose left and bottom edges are at 0", function(d)
	at(portrait, "TOPLEFT", 600, -300)
	at(far, "BOTTOMLEFT", d, d)
end, ring, { "Full" })
ring.avoid, ring.avoidShown = nil, nil

local loose = env.CreateFrame("Frame", nil, root)
loose:SetSize(120 * pixel, 10 * pixel)
local unplaced = widgets.Ornament(loose, "bar")
for _, level in ipairs({ "Subtle", "Full" }) do
	profile.ornaments = level
	unplaced:Restyle()
	assert(set(unplaced) == "", level .. ": a bar with no anchors has unknown edges and draws nothing")
end

assert(#env._errors == 0, tostring(env._errors[1]))
print(string.format("ok an edge at 0 is known: %d bar, ring and avoided-frame cases draw the same set at 0 and off the screen as one step inside it (bars at Subtle and Full, rings at Full), and an unanchored bar draws nothing", checked))
