-- ranged_reach.lua: Reach.Check(sizes, low, classes, trees) builds the HUD scene's action bars for a hunter, mage and warlock (or the classes named) with every crest tracker lit (RENDER_TRACKERS=lit), and the hunter's hawk perches with their summon lift, at each screen size and asserts that no texture of a break-out piece, at full alpha (a waiting flare at its peak), swept through every pass of the Scale, Rotation and Translation animations on it and on every frame above it, draws a pixel (alpha at least a quarter, read from the texture: an additive RGB aura sheet by its brightest channel, a flipbook sheet folded into one cell, a still cell through its texture coordinates; an addon file the reader cannot read stops the check) on an action slot, the level badge, the player or target frame or either cast bar, or outside the crest's column. The warlock knows every summon and Demonic Sacrifice, so its demon piece builds each demon's mark and each Sacrifice copy, and each of those aura sheets must be among the measured textures. Each class's cooldown rail is measured at its widest, four abilities, the trinket and six round medals on its second rail, with the hunter's pet, its family ability and orders, Immolation Trap, Tranquilizing Shot and a potion known too, against the Medallions cooldown row's placed rows and may reach past the crest's column. With low true each screen is built with Cast bars on unit frames off instead, where the rail must take its own flat row and every crest piece, the rail included, must clear the centred cast bars too; each layout is a call of its own, so a test file can build one screen in one layout inside the hosted runner's CPU budget. The pieces that ring the whole crest (moments, the ward, the Auto Shot ring, the cooldown sigils, the five-second ring) are the ring itself and are left out. Each second-rail medal's flight to the crown and its fold home are swept apart from the rest, through the lift's own animation alone, as the circle its drawn pixels reach from their centre, against those obstacles and every other rail medal (each the circle of its seat), at every sample from leaving its seat to settling in the crown and back. Only its own seat is left out, and in the crown only the other medals, and only while each of its textures stays inside the crown's own texture of that name at the largest scale a main seat's landing reaches. With trees, low must be true and the mage runs once per talent tree named, its shown orb and each of that tree's orb sheets and rail seat aura sheets among the measured textures.
local Png = dofile("Tools/regression/png.lua")
local Scene = dofile("Tools/render/scene.lua")
local Pose = dofile("Tools/regression/anim_pose.lua")
local Reach = {}

local RING = { crestGust = true, crestClearcasting = true, crestTrance = true, crestWard = true, crestAutoShot = true, crestCooldowns = true, crestFiveSecond = true }
local FRAMES = { "unitframes.player", "unitframes.target", "unitframes.castbar.player", "unitframes.castbar.target" }
local ROW = { "cooldowns.essential", "cooldowns.utility", "cooldowns.buffs", "cooldowns.bars" }
local RUNS, CONTENT, SAMPLES = {}, {}, {}
local DEMON_SHEETS = { "HornsPet", "Imp", "Voidwalker", "Succubus", "Fangs", "ImpFel", "VoidwalkerFel", "SuccubusFel", "FangsFel" }
local floor, min, max, abs, find = math.floor, math.min, math.max, math.abs, string.find

-- Runs(file) -> runs, width and height of an addon file, read once for both sweeps: runs[y] holds row y's spans of pixels of alpha
-- 64 or more as first and last x, in pairs. A file the reader cannot read stops the check. The runs hold only the texture's own
-- pixels, so Content and Spread stop on texture coordinates past its edge instead of measuring nothing there.
local function Runs(file)
	if not RUNS[file] then
		local rows, w, h = Png.Coverage(file)
		local runs = {}
		for y = 0, h - 1 do
			local row, list, at = rows[y], {}, 1
			while true do
				local first, last = find(row, "[\64-\255]+", at)
				if not first then break end
				list[#list + 1], list[#list + 2] = first - 1, last - 1
				at = last + 1
			end
			runs[y] = list
		end
		RUNS[file] = { runs, w, h }
	end
	return RUNS[file][1], RUNS[file][2], RUNS[file][3]
end

-- Cuts(x0, x1, cw) -> the first x of each cell of width cw from x0 to x1, then x1 + 1. A cell is the one x % cw measures x in
-- (Lua's floor((x - x0) / cw)), so inside each piece of a run cut here a pixel's place in its cell grows with x, and the per-pixel
-- measures below reach their extremes at the piece's two ends: Content and Spread read only those, which gives the same answer
-- as reading every pixel.
local function Cuts(x0, x1, cw)
	local cuts, cell = { x0 }, 0
	for x = x0, x1 do
		local k = floor((x - x0) / cw)
		if k ~= cell then cuts[#cuts + 1], cell = x, k end
	end
	cuts[#cuts + 1] = x1 + 1
	return cuts
end

-- Spread(path, rows, columns, coords) -> how far from its cell's centre, as a share of the cell's width, the texture's pixels of alpha
-- 64 or more reach in any direction, so a round medal measures as round however it turns. A flipbook sheet folds into one cell;
-- otherwise only the part the texture coordinates show counts. False for a texture that is not one of the addon's own files; an
-- addon file the reader cannot read stops the check.
local SPREAD = {}
local function Spread(path, rows, columns, coords)
	local u0, u1, v0, v1 = 0, 1, 0, 1
	if rows == 1 and columns == 1 and coords then
		u0, u1 = math.min(coords[1], coords[2]), math.max(coords[1], coords[2])
		v0, v1 = math.min(coords[3], coords[4]), math.max(coords[3], coords[4])
	end
	local key = table.concat({ tostring(path), rows, columns, u0, u1, v0, v1 }, "/")
	if SPREAD[key] == nil then
		local file = tostring(path):gsub("\\", "/"):match("Media/.+$")
		local most = 0
		if file then
			local runs, w, h = Runs(file)
			local x0, x1, y0, y1 = math.floor(u0 * w), math.ceil(u1 * w) - 1, math.floor(v0 * h), math.ceil(v1 * h) - 1
			assert(x0 >= 0 and x1 < w and y0 >= 0 and y1 < h, file .. ": the texture coordinates measured reach past the texture")
			local cw, ch = (x1 - x0 + 1) / columns, (y1 - y0 + 1) / rows
			local cuts = Cuts(x0, x1, cw)
			for y = y0, y1 do
				local list = runs[y]
				local dy = (abs(((y - y0) % ch + 0.5) / ch - 0.5) + 0.5 / ch) * ch / cw
				for i = 1, #list, 2 do
					local s, e = max(list[i], x0), min(list[i + 1], x1)
					for j = 1, #cuts - 1 do
						local lo, hi = max(s, cuts[j]), min(e, cuts[j + 1] - 1)
						if lo <= hi then
							local a = abs(((lo - x0) % cw + 0.5) / cw - 0.5) + 0.5 / cw
							local b = abs(((hi - x0) % cw + 0.5) / cw - 0.5) + 0.5 / cw
							local dx = max(a, b)
							most = max(most, math.sqrt(dx * dx + dy * dy))
						end
					end
				end
			end
		end
		SPREAD[key] = most > 0 and most or false
	end
	return SPREAD[key]
end

-- Cells(region) -> the rows and columns of the flipbook a group on the region plays, or 1, 1.
local function Cells(region)
	for _, group in ipairs(region._groups or {}) do
		for _, anim in ipairs(group._anims or {}) do
			local state = anim._state or {}
			if anim._type == "FlipBook" and state.FlipBookRows then return state.FlipBookRows[1], state.FlipBookColumns[1] end
		end
	end
	return 1, 1
end

-- Window(region) -> the texture coordinates at the region's left, right, top and bottom edges (reversed for a flipped texture), or
-- nil when they turn the texture, reach past it or show a single texel row or column, where the whole region counts as drawn.
local function Window(region)
	local c = region._state.TexCoord
	if not c or (c.n or #c) < 4 then return 0, 1, 0, 1 end
	local l, r, t, b = c[1], c[2], c[3], c[4]
	if (c.n or #c) >= 8 then
		if c[1] ~= c[3] or c[5] ~= c[7] or c[2] ~= c[6] or c[4] ~= c[8] then return nil end
		l, r, t, b = c[1], c[5], c[2], c[4]
	end
	for _, v in ipairs({ l, r, t, b }) do
		if type(v) ~= "number" or v < 0 or v > 1 then return nil end
	end
	if l == r or t == b then return nil end
	return l, r, t, b
end

-- Content(region) -> the share of the region its texture's pixels of alpha 64 or more span: left, right, top, bottom; false if none
-- or if the texture is not one of the addon's own files. A flipbook sheet folds into one cell, since the region shows one cell at a
-- time; otherwise only the part the texture coordinates show counts, mirrored as they mirror it. An addon file the reader cannot
-- read stops the check, so a piece is never passed unmeasured.
local function Content(region)
	local texture = region._state.Texture
	local file = texture and tostring(texture[1]):gsub("\\", "/"):match("Media/.+$")
	if not file then return false end
	local runs, w, h = Runs(file)
	local rows, columns = Cells(region)
	local ul, ur, vt, vb = 0, 1, 0, 1
	if rows == 1 and columns == 1 then
		ul, ur, vt, vb = Window(region)
		if not ul then return { 0, 1, 0, 1 } end
	end
	local key = table.concat({ file, rows, columns, ul, ur, vt, vb }, "/")
	if CONTENT[key] == nil then
		local x0, x1 = math.floor(math.min(ul, ur) * w), math.ceil(math.max(ul, ur) * w) - 1
		local y0, y1 = math.floor(math.min(vt, vb) * h), math.ceil(math.max(vt, vb) * h) - 1
		assert(x0 >= 0 and x1 < w and y0 >= 0 and y1 < h, file .. ": the texture coordinates measured reach past the texture")
		local cw, ch = (x1 - x0 + 1) / columns, (y1 - y0 + 1) / rows
		local cells, cuts = columns > 1 or rows > 1, Cuts(x0, x1, cw)
		local l, r, t, b = 1, 0, 1, 0
		for y = y0, y1 do
			local list, drawn = runs[y], false
			for i = 1, #list, 2 do
				local s, e = max(list[i], x0), min(list[i + 1], x1)
				for j = 1, #cuts - 1 do
					local lo, hi = max(s, cuts[j]), min(e, cuts[j + 1] - 1)
					if lo <= hi then
						drawn = true
						for k = 1, 2 do
							local x = k == 1 and lo or hi
							local sx, ex
							if cells then
								sx = ((x - x0) % cw) / cw
								ex = sx + 1 / cw
							else
								sx, ex = (x / w - ul) / (ur - ul), ((x + 1) / w - ul) / (ur - ul)
							end
							l, r = min(l, sx, ex), max(r, sx, ex)
						end
					end
				end
			end
			if drawn then
				local sy, ey
				if cells then
					sy = ((y - y0) % ch) / ch
					ey = sy + 1 / ch
				else
					sy, ey = (y / h - vt) / (vb - vt), ((y + 1) / h - vt) / (vb - vt)
				end
				t, b = min(t, sy, ey), max(b, sy, ey)
			end
		end
		CONTENT[key] = r > l and { l, r, t, b } or false
	end
	return CONTENT[key]
end

-- Samples(group) -> the group's offset, turn and scale at each sampled time of its pass (anim_pose.lua), worked out once per group and check.
local function Samples(group)
	if not SAMPLES[group] then
		local timed, times = Pose.Passes(group)
		local list = {}
		for _, time in ipairs(#timed > 0 and times or {}) do
			local x, y, turn, scale = Pose.At(timed, time)
			list[#list + 1] = { x, y, math.cos(math.rad(turn)), math.sin(math.rad(turn)), scale }
		end
		SAMPLES[group] = list
	end
	return SAMPLES[group]
end

-- Sweep(solver, region, l, r, t, b, unit) -> the boxes {l, r, t, b} the region's drawn content takes over every pass of every Translation,
-- Rotation and Scale animation group on it and on each frame above it, sampled through each pass: a frame's scale and turn about its own
-- centre, then its offset, as the client applies them; a frame's groups are swept one at a time. Each sample keeps its own box, so a
-- path that turns a corner is measured where it goes rather than by the box round its ends; only where nested groups would multiply
-- past CAP boxes are the boxes coming in from the frames below merged into one first.
local CAP = 256
local function Sweep(solver, region, l, r, t, b, unit)
	local boxes, node = { { l, r, t, b } }, region
	while node do
		local groups = node._groups or {}
		if #groups > 0 then
			local count = 0
			for _, group in ipairs(groups) do count = count + #Samples(group) end
			if #boxes * (count + 1) > CAP then
				local u = { boxes[1][1], boxes[1][2], boxes[1][3], boxes[1][4] }
				for _, box in ipairs(boxes) do
					u[1], u[2], u[3], u[4] = math.min(u[1], box[1]), math.max(u[2], box[2]), math.max(u[3], box[3]), math.min(u[4], box[4])
				end
				boxes = { u }
			end
			local at = solver:rect(node)
			local out = {}
			for _, box in ipairs(boxes) do
				local bl, br, bt, bb = box[1], box[2], box[3], box[4]
				local cx, cy = at and (at[1] + at[3]) / 2 or (bl + br) / 2, at and (at[2] + at[4]) / 2 or (bt + bb) / 2
				out[#out + 1] = box
				for _, group in ipairs(groups) do
					for _, sample in ipairs(Samples(group)) do
						local x, y, c, s, scale = sample[1], sample[2], sample[3], sample[4], sample[5]
						local nl, nr, nt, nb = math.huge, -math.huge, -math.huge, math.huge
						for _, corner in ipairs({ { bl, bt }, { br, bt }, { bl, bb }, { br, bb } }) do
							local dx, dy = (corner[1] - cx) * scale, (corner[2] - cy) * scale
							local px, py = cx + dx * c - dy * s + x * unit, cy + dx * s + dy * c + y * unit
							nl, nr, nt, nb = math.min(nl, px), math.max(nr, px), math.max(nt, py), math.min(nb, py)
						end
						out[#out + 1] = { nl, nr, nt, nb }
					end
				end
			end
			boxes = out
		end
		node = node:GetParent()
	end
	return boxes
end

local function Textures(frame, list)
	for _, region in ipairs(frame._regions or {}) do
		if region._type == "Texture" then list[#list + 1] = region end
	end
	for _, kid in ipairs(frame._kids or {}) do Textures(kid, list) end
	return list
end

-- Each class's widest rail: four seats, the trinket and a full second rail of six, with the racials standing in for a
-- character's one or two so every class fills it. The warlock also knows every summon and Demonic Sacrifice, so the demon
-- piece builds each demon's mark and each Sacrifice copy (SlabRanged.lua's Pet).
local WIDEST = {
	HUNTER = { 1293241, 19574, 3045, 19577, 14305, 19263, 20572, 20554, 20594, 1259799, 20600, 1260270, 13795, 24579, 14916, 19801 },
	MAGE = { 12042, 12043, 12051, 11129, 11958, 12472, 10199, 1953, 10230, 13033, 13021, 1240047, 20589, 20572, 20554, 1260270 },
	WARLOCK = { 6789, 1122, 18288, 18708, 6353, 20572, 20554, 1259821, 1299026, 7744, 1260270, 688, 697, 712, 691, 18788 },
}
local SPARES = 6
Reach.WIDEST = WIDEST

-- Key(path) -> the texture's path from Media/ on, so a forged face and its aura sheet of the same file name stay apart.
local function Key(path)
	return tostring(path):gsub("\\", "/"):match("Media/.+$") or tostring(path)
end

-- OrbSheets(ns, Tokens, orb) -> the Media key of every sheet the shown orb's tree builds: its race's vessel, its school's light,
-- core and meniscus, the glass, and each of the tree's procs (one sheet per stack where a proc draws its stacks apart).
local function OrbSheets(ns, Tokens, orb)
	local school = orb.school
	local names = { "orbVessel" .. orb.race, "orbLight" .. school, "orbCore" .. school, "orbMeniscus" .. school, "orbGlass" }
	for _, each in ipairs(ns.SlabOrb.PROCS) do
		if not each.school or each.school == school then
			for n = 1, each.stacks and not each.bands and each.stacks or 1 do
				names[#names + 1] = each.token .. (each.stacks and not each.bands and n or "")
			end
		end
	end
	for i, name in ipairs(names) do
		names[i] = Key((Tokens.Texture(name)))
	end
	return names
end

function Reach.Check(sizes, low, classes, trees)
	assert(type(low) == "boolean" and (low or not trees), "Reach.Check takes low: true for the centred cast bars, which trees need, or false for the cast bars on the unit frames")
	local original, measured = dofile, nil
	_G.dofile = function(path)
		local result = original(path)
		if path == "Tools/render/scenes/_common.lua" then
			local force = result.ForceScreen
			result.ForceScreen = function(env, ...)
				measured = env
				return force(env, ...)
			end
		end
		return result
	end
	_G.RENDER_SCENE_LIB, _G.RENDER_TRACKERS = true, "lit"
	_G.RENDER_CAST_ON_FRAME = low and "off" or nil
	for _, size in ipairs(sizes) do
		local at = size[1] .. "x" .. size[2] .. (low and " with the centred cast bars" or "")
		_G.RENDER_SCREEN = { width = size[1], height = size[2], size = "auto" }
		local Hud = dofile("Tools/render/scenes/hud.lua")
		Hud.Module("unitframes", Hud.Options({ layout = "DPS", class = "HUNTER", applyPreset = true }))
		local frames, rail, casts = {}, {}, 0
		for i, key in ipairs(FRAMES) do
			local element = measured.KstyleUI.Layout.Element(key)
			frames[#frames + 1] = assert(element and Scene.RectSolver(measured):rect(element.frame), at .. ": " .. key .. " is placed")
			if element.live ~= false then
				rail[#rail + 1] = frames[#frames]
				casts = casts + (i > 2 and 1 or 0)
			end
		end
		assert(casts == (low and 2 or 0), at .. ": the rail is measured against both centred cast bars exactly while they show (" .. casts .. ")")
		local Layouts, cast = measured.KstyleUI.Setup.Layouts, frames[3]
		local from = Layouts.Style("DPS", FRAMES[3], "medallions")
		local k = (cast[3] - cast[1]) / from.width
		for _, key in ipairs(ROW) do
			local place, box = Layouts.Style("DPS", key, "medallions"), Layouts.Element(key)
			local x, y = (cast[1] + cast[3]) / 2 + (place.x - from.x) * k, cast[2] + (place.y - from.y) * k
			rail[#rail + 1] = { x - box.width * k / 2, y, x + box.width * k / 2, y + box.height * k }
		end
		local runs = {}
		for _, class in ipairs(classes or { "HUNTER", "MAGE", "WARLOCK" }) do
			-- The mage's trees are measured in the centred layout, where the rail's flat row sits lowest. Each tree is a whole HUD
			-- build, so Fire and Frost run in their own files (trees) to keep every file inside its wall-clock guard.
			for _, tree in ipairs(class == "MAGE" and low and (trees or { 1 }) or { false }) do
				runs[#runs + 1] = { class = class, tree = tree or nil }
			end
		end
		for _, each in ipairs(runs) do
			local class, tree = each.class, each.tree
			SAMPLES = {}
			local _, ns = Hud.Module("actionbars", Hud.Options({ layout = "DPS", class = class, applyPreset = true }))
			local known, widest = measured.C_SpellBook.IsSpellKnown, {}
			for _, id in ipairs(WIDEST[class]) do widest[id] = true end
			measured.C_SpellBook.IsSpellKnown = function(id, ...) return widest[id] or known(id, ...) end
			measured.GetInventoryItemID = function(_, slot) return slot == 13 and 5002 or nil end
			measured.C_Item.GetItemSpell = function(id) if id == 5002 then return "Use", 9002 end end
			measured.GetTotemInfo = measured.GetTotemInfo or function() return false, "", 0, 0, 0, 1, 0 end
			if tree then
				measured.C_SpecializationInfo = measured.C_SpecializationInfo or {}
				measured.C_SpecializationInfo.GetSpecialization = function() return tree end
			end
			local where = at .. (tree and " tree " .. tree or "")
			for i = 3, low and 4 or 0 do
				measured.KstyleUI.Layout.Register(measured.CreateFrame("Frame"), FRAMES[i], measured.KstyleUI.Setup.Layouts.Default(FRAMES[i]))
			end
			if ns.SlabHawks then ns.SlabHawks.Update() end
			ns.SlabTrackers.Update()
			local solver = Scene.RectSolver(measured)
			local hub = solver:rect(ns.Slab.hub)
			local cx, unit = (hub[1] + hub[3]) / 2, (hub[3] - hub[1]) / ns.Slab.RING
			local avoid = { solver:rect(ns.Slab.hub.plaque) }
			for _, bar in pairs(ns.bars) do
				for _, button in ipairs(bar.buttons or {}) do
					if button:IsVisible() then avoid[#avoid + 1] = solver:rect(button) end
				end
			end
			local railed = { unpack(avoid) }
			for _, box in ipairs(frames) do avoid[#avoid + 1] = box end
			for _, box in ipairs(rail) do railed[#railed + 1] = box end
			local orbed = { unpack(avoid) }
			for _, box in ipairs(rail) do orbed[#orbed + 1] = box end
			assert(#avoid > 16, where .. " " .. class .. ": the action slots, badge, unit frames and cast bars are placed")
			local checked, demons = 0, {}
			local pieces = {}
			for _, p in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
				pieces[#pieces + 1] = { key = p.spec.key, regions = RING[p.spec.key] and {} or Textures(p, {}) }
			end
			for i, p in ipairs(not low and ns.SlabHawks and ns.SlabHawks.state.perches or {}) do
				pieces[#pieces + 1] = { key = "hawk perch " .. i, regions = Textures(p.holder, {}) }
			end
			assert(class ~= "HUNTER" or low or #pieces > 2 and pieces[#pieces].key == "hawk perch 2", where .. ": the hunter's hawk perches are measured")
			local seated = ns.SlabTrackers.state.forms.crest.pieces
			local railPiece
			for _, p in pairs(seated) do railPiece = p.spec.key == "crestRail" and p or railPiece end
			assert(railPiece and railPiece:IsShown() and #railPiece.order == 5 and #railPiece.spare == SPARES and #rail >= #ROW,
				where .. " " .. class .. ": the rail's five seats and full second rail are measured against the cooldown row")
			assert(railPiece.low == low, where .. ": the rail takes its own flat row exactly while the centred cast bars show")
			local flying = {}
			for _, seat in ipairs(railPiece.spare) do
				for _, layer in ipairs(seat.lift and { seat.lift, seat.ghost } or {}) do
					for _, region in ipairs(Textures(layer, {})) do flying[region] = true end
				end
			end
			local sampled = {}
			for _, p in ipairs(pieces) do
				local strict = p.key == "crestOrb" or p.key == "crestRail"
				for _, region in ipairs(p.regions) do
					local texture = (region._barOwner and region or region)._state.Texture
					local box, content = solver:rect(region._barOwner or region), texture and Content(region)
					-- A layer pinned to a status bar's fill (the orb's light and its meniscus) has no rectangle of its own; it never
					-- leaves the frame it is drawn on, so that frame's whole rectangle stands in for it.
					box = box or strict and region.GetParent and solver:rect(region:GetParent()) or box
					assert(not (strict and texture and tostring(texture[1]):match("Media[\\/]")) or box,
						where .. " " .. class .. " " .. p.key .. "'s " .. tostring(texture and tostring(texture[1]):match("[^\\/]+$")) .. " is placed")
					if box and content and not flying[region] then
						sampled[Key(texture[1])] = true
						checked = checked + 1
						if p.key == "crestDemon" then demons[tostring(texture[1]):gsub("\\", "/"):match("Auras/Glyphs/(.+)%.png$") or ""] = true end
						local w, h = box[3] - box[1], box[4] - box[2]
						local name = where .. " " .. class .. " " .. p.key .. "'s " .. tostring(texture[1]):match("[^\\/]+$")
						local own = p.key == "crestRail" and railed or p.key == "crestOrb" and orbed or avoid
						for _, swept in ipairs(Sweep(solver, region, box[1] + content[1] * w, box[1] + content[2] * w, box[4] - content[3] * h, box[4] - content[4] * h, unit)) do
							local l, r, t, b = swept[1], swept[2], swept[3], swept[4]
							assert(own == railed or math.abs(l - cx) <= 80 * unit and math.abs(r - cx) <= 80 * unit, name .. " stays inside the crest's column")
							for _, a in ipairs(own) do
								assert(r <= a[1] or a[3] <= l or t <= a[2] or a[4] <= b, name .. " crosses an action slot, the level badge, a unit frame, a cast bar or the cooldown row")
							end
						end
					end
				end
			end
			assert(checked > (low and 10 or 20), where .. " " .. class .. ": the lit pieces are measured (" .. checked .. ")")
			if class == "MAGE" then
				local Tokens, orb = measured.KstyleUI.Tokens, nil
				for _, p in pairs(seated) do orb = p.spec.key == "crestOrb" and p:IsShown() and p or orb end
				local need = OrbSheets(ns, Tokens, assert(orb, where .. ": the mage's orb shows"))
				for _, list in ipairs({ railPiece.order, railPiece.spare }) do
					for _, seat in ipairs(list) do
						-- The seat's aura sheet, found as the rail's Baked finds it: the sheet its forged sigil names.
						local sigil = seat.ability.sigil
						local found, _, _, _, _, aura = pcall(Tokens.Texture, "sigil" .. tostring(sigil))
						if sigil and found and aura then need[#need + 1] = Key((Tokens.Texture(aura))) end
					end
				end
				for _, name in ipairs(need) do
					assert(sampled[name], where .. ": " .. name .. " is measured")
				end
			end
			for _, sheet in ipairs(class == "WARLOCK" and DEMON_SHEETS or {}) do
				assert(demons[sheet], at .. " WARLOCK: the demon piece's " .. sheet .. " aura sheet is measured")
			end
			local medals, fliers, faces, landing = {}, 0, {}, 1
			for _, seat in ipairs(railPiece.order) do
				for _, sample in ipairs(seat.rise and Samples(seat.rise) or {}) do landing = math.max(landing, sample[5]) end
			end
			for _, region in ipairs(Textures(railPiece.crown, {})) do
				local texture, box = region._state.Texture, solver:rect(region)
				local rows, columns = Cells(region)
				local reach = texture and box and not flying[region] and Spread(texture[1], rows, columns, region._state.TexCoord)
				if reach then
					local face = { (box[1] + box[3]) / 2, (box[2] + box[4]) / 2, reach * math.max(box[3] - box[1], box[4] - box[2]) * landing }
					faces[texture[1]] = faces[texture[1]] and faces[texture[1]][3] > face[3] and faces[texture[1]] or face
				end
			end
			for _, list in ipairs({ railPiece.order, railPiece.spare }) do
				for _, seat in ipairs(list) do
					local box = solver:rect(seat)
					medals[#medals + 1] = { seat = seat, x = (box[1] + box[3]) / 2, y = (box[2] + box[4]) / 2, r = (box[3] - box[1]) / 2 }
				end
			end
			for _, seat in ipairs(railPiece.spare) do
				for _, leg in ipairs(seat.lift and { { seat.lift, seat.rise }, { seat.ghost, seat.home } } or {}) do
					fliers = fliers + 1
					local layer = solver:rect(leg[1])
					local lx, ly = (layer[1] + layer[3]) / 2, (layer[2] + layer[4]) / 2
					for _, region in ipairs(Textures(leg[1], {})) do
						local texture = region._state.Texture
						local rows, columns = Cells(region)
						local box, reach = solver:rect(region), texture and Spread(texture[1], rows, columns, region._state.TexCoord)
						if box and reach then
							local rx, ry, across = (box[1] + box[3]) / 2 - lx, (box[2] + box[4]) / 2 - ly, math.max(box[3] - box[1], box[4] - box[2])
							local name = where .. " " .. class .. " second-rail " .. seat.key .. "'s flight " .. tostring(texture[1]):match("[^\\/]+$")
							for _, sample in ipairs(Samples(leg[2])) do
								local x, y, c, s, scale = sample[1], sample[2], sample[3], sample[4], sample[5]
								local px = lx + (rx * c - ry * s) * scale + x * unit
								local py = ly + (rx * s + ry * c) * scale + y * unit
								local radius = reach * across * scale
								for _, a in ipairs(railed) do
									local nx, ny = math.max(a[1], math.min(px, a[3])), math.max(a[2], math.min(py, a[4]))
									assert((px - nx) ^ 2 + (py - ny) ^ 2 >= radius ^ 2, name .. " crosses an action slot, the level badge, a unit frame, a cast bar or the cooldown row")
								end
								local face = faces[texture[1]]
								local crowned = face and math.sqrt((px - face[1]) ^ 2 + (py - face[2]) ^ 2) + radius <= face[3] + 1e-6
								for _, m in ipairs(medals) do
									assert(m.seat == seat or crowned or (px - m.x) ^ 2 + (py - m.y) ^ 2 >= (radius + m.r) ^ 2, name .. " crosses the " .. m.seat.key .. " medal")
								end
							end
						end
					end
				end
			end
			-- The Fire mage's orb holds Combustion and its main seats take Arcane Power and Presence of Mind, so its second rail holds
			-- no buff to fly to the crown.
			assert(fliers > 0 or tree == 2, where .. " " .. class .. ": a second-rail medal's flight is measured against the other medals")
		end
		-- A full collect once each screen is done frees its scene before the next is built: the peak then stays near 2 GB
		-- instead of drifting with the collector's phase towards the test runner's 4096 MB limit.
		measured = nil
		collectgarbage("collect")
	end
	_G.dofile, _G.RENDER_TRACKERS, _G.RENDER_CAST_ON_FRAME = original, nil, nil
end

return Reach
