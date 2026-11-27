-- ranged_reach.lua: Reach.Check(sizes, classes, only) builds the HUD scene's action bars for a hunter, mage and warlock (or the classes named) with every crest tracker lit (RENDER_TRACKERS=lit), and the hunter's hawk perches with their summon lift, at each screen size and asserts that no texture of a break-out piece, at full alpha (a waiting flare at its peak), swept through every pass of the Scale, Rotation and Translation animations on it and on every frame above it, draws a pixel (alpha at least a quarter, read from the texture) on an action slot, the level badge, the player or target frame or either cast bar, or outside the crest's column. Each class's cooldown rail is measured at its widest, four abilities, the trinket and six round medals on its second rail, with the hunter's pet, its family ability and orders, Immolation Trap, Tranquilizing Shot and a potion known too, against the Medallions cooldown row's placed rows and may reach past the crest's column; each screen is built a second time with Cast bars on unit frames off, where the rail must take its own flat row and every crest piece, the rail included, must clear the centred cast bars too. The pieces that ring the whole crest (moments, the ward, the Auto Shot ring, the cooldown sigils, the five-second ring) are the ring itself and are left out. With only set to a piece's key (crestRail), only that piece is measured, with no hawk perches, so one class's rail can be checked at a size where another of its pieces is not yet clear. Each second-rail medal's flight to the crown and its fold home are swept apart from the rest, through the lift's own animation alone, as the circle its drawn pixels reach from their centre, against those obstacles and every other rail medal (each the circle of its seat), at every sample from leaving its seat to settling in the crown and back. Only its own seat is left out, and in the crown only the other medals, and only while each of its textures stays inside the crown's own texture of that name at the largest scale a main seat's landing reaches.
local Png = dofile("Tools/regression/png.lua")
local Scene = dofile("Tools/render/scene.lua")
local Pose = dofile("Tools/regression/anim_pose.lua")
local Reach = {}

local RING = { crestGust = true, crestClearcasting = true, crestTrance = true, crestWard = true, crestAutoShot = true, crestCooldowns = true, crestFiveSecond = true }
local FRAMES = { "unitframes.player", "unitframes.target", "unitframes.castbar.player", "unitframes.castbar.target" }
local ROW = { "cooldowns.essential", "cooldowns.utility", "cooldowns.buffs", "cooldowns.bars" }
local CONTENT, SAMPLES = {}, {}

-- Content(path) -> the share of the texture its pixels of alpha 64 or more span: left, right, top, bottom; false if none.
local function Content(path)
	if CONTENT[path] == nil then
		local file = tostring(path):gsub("\\", "/"):match("Media/.+$")
		local ok, alpha, w, h = pcall(Png.Alpha, file or "")
		local l, r, t, b = 1, 0, 1, 0
		for y = 0, ok and h - 1 or -1 do
			for x = 0, w - 1 do
				if alpha(x, y) >= 64 then
					l, r, t, b = math.min(l, x / w), math.max(r, (x + 1) / w), math.min(t, y / h), math.max(b, (y + 1) / h)
				end
			end
		end
		CONTENT[path] = ok and r > l and { l, r, t, b } or false
	end
	return CONTENT[path]
end

-- Spread(path, rows, columns, coords) -> how far from its cell's centre, as a share of the cell's width, the texture's pixels of alpha
-- 64 or more reach in any direction, so a round medal measures as round however it turns. A flipbook sheet folds into one cell;
-- otherwise only the part the texture coordinates show counts.
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
		local ok, alpha, w, h = pcall(Png.Alpha, file or "")
		local most = 0
		if ok then
			local x0, x1, y0, y1 = math.floor(u0 * w), math.ceil(u1 * w) - 1, math.floor(v0 * h), math.ceil(v1 * h) - 1
			local cw, ch = (x1 - x0 + 1) / columns, (y1 - y0 + 1) / rows
			for y = y0, y1 do
				for x = x0, x1 do
					if alpha(x, y) >= 64 then
						local dx = math.abs(((x - x0) % cw + 0.5) / cw - 0.5) + 0.5 / cw
						local dy = (math.abs(((y - y0) % ch + 0.5) / ch - 0.5) + 0.5 / ch) * ch / cw
						most = math.max(most, math.sqrt(dx * dx + dy * dy))
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
-- character's one or two so every class fills it.
local WIDEST = {
	HUNTER = { 1293241, 19574, 3045, 19577, 14305, 19263, 20572, 20554, 20594, 1259799, 20600, 1260270, 13795, 24579, 14916, 19801 },
	MAGE = { 12042, 12043, 12051, 11129, 11958, 12472, 2136, 20572, 20554, 1260270 },
	WARLOCK = { 6789, 1122, 18288, 18708, 6353, 20572, 20554, 1259821, 1299026, 7744, 1260270 },
}
local SPARES = 6

function Reach.Check(sizes, classes, only)
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
	for _, run in ipairs({ { sizes = sizes }, { sizes = sizes, low = true } }) do
	for _, size in ipairs(run.sizes) do
		local low = run.low == true
		_G.RENDER_CAST_ON_FRAME = low and "off" or nil
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
		for _, class in ipairs(classes or { "HUNTER", "MAGE", "WARLOCK" }) do
			SAMPLES = {}
			local _, ns = Hud.Module("actionbars", Hud.Options({ layout = "DPS", class = class, applyPreset = true }))
			local known, widest = measured.C_SpellBook.IsSpellKnown, {}
			for _, id in ipairs(WIDEST[class]) do widest[id] = true end
			measured.C_SpellBook.IsSpellKnown = function(id, ...) return widest[id] or known(id, ...) end
			measured.GetInventoryItemID = function(_, slot) return slot == 13 and 5002 or nil end
			measured.C_Item.GetItemSpell = function(id) if id == 5002 then return "Use", 9002 end end
			measured.GetTotemInfo = measured.GetTotemInfo or function() return false, "", 0, 0, 0, 1, 0 end
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
			assert(#avoid > 16, at .. " " .. class .. ": the action slots, badge, unit frames and cast bars are placed")
			local checked = 0
			local pieces = {}
			for _, p in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
				if not only or p.spec.key == only then
					pieces[#pieces + 1] = { key = p.spec.key, regions = RING[p.spec.key] and {} or Textures(p, {}) }
				end
			end
			for i, p in ipairs(not low and not only and ns.SlabHawks and ns.SlabHawks.state.perches or {}) do
				pieces[#pieces + 1] = { key = "hawk perch " .. i, regions = Textures(p.holder, {}) }
			end
			assert(class ~= "HUNTER" or low or only or #pieces > 2 and pieces[#pieces].key == "hawk perch 2", at .. ": the hunter's hawk perches are measured")
			local seated = ns.SlabTrackers.state.forms.crest.pieces
			local railPiece
			for _, p in pairs(seated) do railPiece = p.spec.key == "crestRail" and p or railPiece end
			assert(railPiece and railPiece:IsShown() and #railPiece.order == 5 and #railPiece.spare == SPARES and #rail >= #ROW,
				at .. " " .. class .. ": the rail's five seats and full second rail are measured against the cooldown row")
			assert(railPiece.low == low, at .. ": the rail takes its own flat row exactly while the centred cast bars show")
			local flying = {}
			for _, seat in ipairs(railPiece.spare) do
				for _, layer in ipairs(seat.lift and { seat.lift, seat.ghost } or {}) do
					for _, region in ipairs(Textures(layer, {})) do flying[region] = true end
				end
			end
			for _, p in ipairs(pieces) do
				for _, region in ipairs(p.regions) do
					local texture = (region._barOwner and region or region)._state.Texture
					local box, content = solver:rect(region._barOwner or region), texture and Content(texture[1])
					if box and content and not flying[region] then
						checked = checked + 1
						local w, h = box[3] - box[1], box[4] - box[2]
						local name = at .. " " .. class .. " " .. p.key .. "'s " .. tostring(texture[1]):match("[^\\/]+$")
						local own = p.key == "crestRail" and railed or avoid
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
			assert(checked > ((low or only) and 10 or 20), at .. " " .. class .. ": the lit pieces are measured (" .. checked .. ")")
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
							local name = at .. " " .. class .. " second-rail " .. seat.key .. "'s flight " .. tostring(texture[1]):match("[^\\/]+$")
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
			assert(fliers > 0, at .. " " .. class .. ": a second-rail medal's flight is measured against the other medals")
		end
	end
	end
	_G.dofile, _G.RENDER_TRACKERS, _G.RENDER_CAST_ON_FRAME = original, nil, nil
end

return Reach
