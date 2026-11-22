-- test-centre-clearance-shapes.lua: the guard measures badges, rings and pendants by their ink, and a piece moved into that ink fails.
local M = dofile("Tools/regression/centre_clearance_lib.lua")
local PIXELS, SCREEN = 2, { 1920, 1080 }

local function Piece(x, y)
	return { x = x - 30, y = y - 20, w = 30, h = 20, asset = "Media/Textures/ForgedOrnaments/EndPointed47.png", ornament = true }
end

local function Passes(shape, piece, other)
	local groups = { [other] = { shape }, ["player.body"] = { piece } }
	return pcall(M.Check, groups, PIXELS, "shapes", SCREEN)
end

local function Box(rect)
	return { x = rect.x, y = rect.y, w = rect.w, h = rect.h, asset = rect.asset, ornament = rect.ornament }
end

local function Round(name, file, w, ornament, other)
	local shape = { x = 200, y = 200, w = w, h = w, asset = file, ornament = ornament, shape = name, visible = 1 }
	local radius = M.INK.circles[name] * w / 2 + 1 / PIXELS
	local cx, cy = 200 + w / 2, 200 + w / 2
	local function At(gap)
		local d = (radius + gap) / math.sqrt(2)
		return Piece(cx - d, cy - d)
	end
	local near = At(5)
	assert(M.Gap(Box(shape), near, PIXELS) < 4, name .. ": as a box the corner piece would fail")
	assert(Passes(shape, near, other), name .. ": a piece 5 units from the ink passes beside the empty corner")
	local ok, err = Passes(shape, At(3), other)
	assert(not ok and err:find("gap"), name .. ": a piece moved to 3 units from the ink fails: " .. tostring(err))
	print(string.format("ok %s: corner piece passes at %.2f units on ink (%.2f as a box); moved into the ink zone it fails", name, M.Gap(shape, near, PIXELS), M.Gap(Box(shape), near, PIXELS)))
end

Round("Dot", "Media/Textures/Dot.png", 16, false, "player.level")
Round("Ring39", "Media/Textures/ForgedOrnaments/Ring39.png", 24.5, true, "target.portrait")

local runs = M.INK.spans.BossPendantR70
local pendant = { x = 200, y = 200, w = runs[1] / PIXELS, h = runs[2] / PIXELS, asset = "Media/Textures/ForgedOrnaments/BossPendantR70.png", ornament = true, shape = "BossPendantR70", visible = 1 }
local last = #runs - 3
local top, left = 200 + runs[last] / PIXELS, 200 + runs[last + 2] / PIXELS
local mirrored = 200 + pendant.w - (left - 200)
for _, flip in ipairs({ false, true }) do
	pendant.flip = flip
	local function Place(gap)
		return flip and Piece(mirrored + gap + 30, top + 20) or Piece(left - gap, top + 20)
	end
	local near = Place(6)
	assert(M.Gap(Box(pendant), near, PIXELS) < 4, "pendant: as a box the piece beside the tip would fail")
	assert(Passes(pendant, near, "target.portrait"), "pendant: a piece 6 units beside the tip's ink passes")
	local ok, err = Passes(pendant, Place(2), "target.portrait")
	assert(not ok and err:find("gap"), "pendant: a piece moved to 2 units from the tip fails: " .. tostring(err))
	print(string.format("ok BossPendantR70%s: piece beside the tip passes at %.2f units on ink (%.2f as a box); moved into the ink zone it fails", flip and " mirrored" or "", M.Gap(pendant, near, PIXELS), M.Gap(Box(pendant), near, PIXELS)))
end
