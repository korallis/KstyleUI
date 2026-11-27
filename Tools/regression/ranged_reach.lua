-- ranged_reach.lua: Reach.Check(sizes, classes, only) builds the HUD scene's action bars for a hunter, mage and warlock (or the classes named) with every crest tracker lit (RENDER_TRACKERS=lit), and the hunter's hawk perches with their summon lift, at each screen size and asserts that no texture of a break-out piece, at full alpha (a waiting flare at its peak), swept through every pass of the Scale, Rotation and Translation animations on it and on every frame above it, draws a pixel (alpha at least a quarter, read from the texture) on an action slot, the level badge, the player or target frame or either cast bar, or outside the crest's column. Each class's cooldown rail is measured at its widest, four abilities, the trinket and six round medals on its second rail, with the hunter's pet, its family ability and orders, Immolation Trap, Tranquilizing Shot and a potion known too, against the Medallions cooldown row's placed rows and may reach past the crest's column; each screen is built a second time with Cast bars on unit frames off, where the rail must take its own flat row and every crest piece, the rail included, must clear the centred cast bars too. The pieces that ring the whole crest (moments, the ward, the Auto Shot ring, the cooldown sigils, the five-second ring) are the ring itself and are left out. With only set to a piece's key (crestRail), only that piece is measured, with no hawk perches, so one class's rail can be checked at a size where another of its pieces is not yet clear. Each second-rail medal's flight to the crown and its fold home are swept apart from the rest, through the lift's own animation alone, as the circle its drawn pixels reach from their centre, against those obstacles and every other rail medal (each the circle of its seat), at every sample from leaving its seat to settling in the crown and back. Only its own seat is left out, and in the crown only the other medals, and only while each of its textures stays inside the crown's own texture of that name at the largest scale a main seat's landing reaches. Reach.Check(sizes, classes, true), with true in place of only, measures only the classes' signature pop-offs, every one known and lit on top of the lit trackers, and also asserts, pixel by pixel, that no pop-off texture, at rest or in any pose its own animations and its parents' (scale about each one's pivot, and every Translation path) reach, draws on a texture another named-seat piece, hawk perch, crown point or pop-off draws at rest (shown at an alpha above 0), except where Meant allows it: an overlay, and Evocation's ticks, over the piece on their own seat, and nothing else.
local Png = dofile("Tools/regression/png.lua")
local Scene = dofile("Tools/render/scene.lua")
local Pose = dofile("Tools/regression/anim_pose.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")
local Reach = {}

local RING = { crestGust = true, crestClearcasting = true, crestTrance = true, crestWard = true, crestAutoShot = true, crestCooldowns = true, crestFiveSecond = true }
local FRAMES = { "unitframes.player", "unitframes.target", "unitframes.castbar.player", "unitframes.castbar.target" }
local ROW = { "cooldowns.essential", "cooldowns.utility", "cooldowns.buffs", "cooldowns.bars" }
local CONTENT, SAMPLES = {}, {}

-- Grid(coords) -> columns and rows of the even grid a flipbook cell's texture coordinates (left, right, top, bottom) pick from;
-- 1, 1 for the whole texture or a crop that is no grid cell.
local function Grid(coords)
	if not (coords and #coords == 4) then
		return 1, 1
	end
	local columns, rows = 1 / (coords[2] - coords[1]), 1 / (coords[4] - coords[3])
	local even = math.abs(columns - math.floor(columns + 0.5)) < 0.01 and math.abs(rows - math.floor(rows + 0.5)) < 0.01
	return even and math.floor(columns + 0.5) or 1, even and math.floor(rows + 0.5) or 1
end

-- Content(path, coords) -> the share of one cell (the whole texture, or a flipbook's cell from Grid) that the texture's pixels
-- of alpha 64 or more span in any cell, so a flipbook is measured over every frame it can show: left, right, top, bottom; false if none.
local function Content(path, coords)
	local columns, rows = Grid(coords)
	local key = tostring(path) .. " " .. columns .. "x" .. rows
	if CONTENT[key] == nil then
		local file = tostring(path):gsub("\\", "/"):match("Media/.+$")
		local ok, alpha, w, h = pcall(Png.Alpha, file or "")
		local l, r, t, b = 1, 0, 1, 0
		local cw, ch = ok and math.floor(w / columns), ok and math.floor(h / rows)
		for y = 0, ok and h - 1 or -1 do
			for x = 0, w - 1 do
				if alpha(x, y) >= 64 then
					local cx, cy = x % cw, y % ch
					l, r, t, b = math.min(l, cx / cw), math.max(r, (cx + 1) / cw), math.min(t, cy / ch), math.max(b, (cy + 1) / ch)
				end
			end
			runs[y] = list
		end
		CONTENT[key] = ok and r > l and { l, r, t, b, alpha = alpha, w = cw, h = ch, columns = columns, rows = rows, full = { w, h } } or false
	end
	return CONTENT[key]
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

-- Solid(region, u, v) -> whether the texture draws a pixel of alpha 64 or more at u, v of its box (0 to 1 from the left and the top):
-- in any frame of a flipbook's cells, or at the texel its texture coordinates pick.
local function Solid(region, u, v)
	local texture, coords = region._state.Texture, region._state.TexCoord
	local content = texture and Content(texture[1], coords)
	if not content then
		return false
	end
	if content.columns * content.rows > 1 then
		local x, y = math.floor(u * content.w), math.floor(v * content.h)
		if x < 0 or y < 0 or x >= content.w or y >= content.h then
			return false
		end
		for row = 0, content.rows - 1 do
			for column = 0, content.columns - 1 do
				if content.alpha(column * content.w + x, row * content.h + y) >= 64 then
					return true
				end
			end
		end
		return false
	end
	local c = coords and #coords == 4 and coords or { 0, 1, 0, 1 }
	local x, y = math.floor((c[1] + u * (c[2] - c[1])) * content.full[1]), math.floor((c[3] + v * (c[4] - c[3])) * content.full[2])
	if x < 0 or y < 0 or x >= content.full[1] or y >= content.full[2] then
		return false
	end
	return content.alpha(x, y) >= 64
end

-- Moves(node) -> the scales the node's own Scale animations reach through each pass, composed as anim_pose.lua does (1 among them), their pivot as an anchor point and offset in the
-- node's units, and the offsets its Translation paths pass through, sampled along each move.
local function Moves(node)
	local scales, origin, offsets = { 1 }, nil, { { 0, 0 } }
	for _, group in ipairs(node._groups or {}) do
		local orders, x, y = {}, 0, 0
		for _, anim in ipairs(group._anims or {}) do
			local order = anim._state.Order and anim._state.Order[1] or 1
			orders[order] = orders[order] or {}
			table.insert(orders[order], anim)
			if anim._type == "Scale" then
				origin = origin or anim._state.Origin
			end
		end
		local timed, times = Pose.Passes(group)
		for _, time in ipairs(times) do
			local _, _, _, scale = Pose.At(timed, time)
			scales[#scales + 1] = scale
		end
		for order = 1, 64 do
			for _, anim in ipairs(orders[order] or {}) do
				if anim._type == "Translation" then
					local ox, oy = unpack(anim._state.Offset or { 0, 0 })
					for step = 1, 4 do
						offsets[#offsets + 1] = { x + (ox or 0) * step / 4, y + (oy or 0) * step / 4 }
					end
					x, y = x + (ox or 0), y + (oy or 0)
				end
			end
		end
	end
	return scales, origin, offsets
end

local PIVOT = { CENTER = { 0.5, 0.5 }, BOTTOM = { 0.5, 0 }, TOP = { 0.5, 1 }, LEFT = { 0, 0.5 }, RIGHT = { 1, 0.5 }, BOTTOMLEFT = { 0, 0 }, BOTTOMRIGHT = { 1, 0 }, TOPLEFT = { 0, 1 }, TOPRIGHT = { 1, 1 } }

-- Poses(solver, region, unit) -> the screen boxes (left, right, top, bottom; y up) the region's box reaches as it and every parent above
-- it play their animations: each node, from the region up, scales the box about its own pivot to each scale it reaches, so a parent's
-- scale also carries the child's offset from that pivot, and moves it to each offset along its Translation paths; the first is at rest.
local function Poses(solver, region, unit)
	local box = solver:rect(region._barOwner or region)
	local poses = { { box[1], box[3], box[4], box[2] } }
	local node = region
	while node do
		local scales, origin, offsets = Moves(node)
		if #scales > 1 or #offsets > 1 then
			local rect = solver:rect(node._barOwner or node) or box
			local at = PIVOT[origin and origin[1] or "CENTER"] or PIVOT.CENTER
			local px = rect[1] + (rect[3] - rect[1]) * at[1] + (origin and origin[2] or 0) * unit
			local py = rect[2] + (rect[4] - rect[2]) * at[2] + (origin and origin[3] or 0) * unit
			local moved = {}
			for _, p in ipairs(poses) do
				for _, k in ipairs(scales) do
					for _, o in ipairs(offsets) do
						local dx, dy = o[1] * unit, o[2] * unit
						moved[#moved + 1] = { px + (p[1] - px) * k + dx, px + (p[2] - px) * k + dx, py + (p[3] - py) * k + dy, py + (p[4] - py) * k + dy }
					end
				end
			end
			poses = {}
			local seen = {}
			for _, p in ipairs(moved) do
				local key = string.format("%.1f %.1f %.1f %.1f", p[1], p[2], p[3], p[4])
				if not seen[key] then
					seen[key] = true
					poses[#poses + 1] = p
				end
			end
		end
		node = node:GetParent()
	end
	return poses
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

-- Light(env, ns, class): the character knows every one of the class's signature pop-offs (KstyleUI_ActionBars/SlabPopoffs.lua) and has each one's aura on its unit, its allies' and its after debuff too.
local function Light(env, ns, class)
	local rows, known, auras = {}, {}, {}
	for _, entry in ipairs(ns.SlabPopoffs.CLASSES) do
		rows = entry[1] == class and entry[2] or rows
	end
	local function Give(unit, aura)
		auras[unit] = auras[unit] or {}
		table.insert(auras[unit], aura)
	end
	for _, row in ipairs(rows) do
		for _, id in ipairs(row.known or row.spells) do known[id] = true end
		Give(row.unit or "player", { id = row.spells[1], start = env._now, duration = 30 })
		for _, unit in ipairs(row.allies or {}) do Give(unit, { id = row.spells[1], start = env._now, duration = 30 }) end
		if row.after then Give("player", { id = row.after.spell, start = env._now, duration = 60, harmful = true }) end
	end
	assert(#rows > 0, class .. " has pop-offs")
	if not env._slotContainers then Slots.Install(env) end
	local before = env.C_SpellBook.IsSpellKnown
	env.C_SpellBook.IsSpellKnown = function(id, bank) return known[id] == true or before(id, bank) end
	ns.SlabTrackers.Update()
	for _, unit in ipairs({ "player", "target", "focus" }) do
		local list = {}
		for _, aura in ipairs(env._slotAuras[unit] or {}) do list[#list + 1] = aura end
		for _, aura in ipairs(auras[unit] or {}) do list[#list + 1] = aura end
		Slots.Set(env, unit, list)
	end
	local lit = 0
	for _, p in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		if p.spec.key == "crestPopoffs" and p.lits[1]:IsShown() then lit = lit + 1 end
	end
	assert(lit == #rows, class .. ": every pop-off is built and lit (" .. lit .. " of " .. #rows .. ")")
end

-- Drawn(region) -> whether the texture draws at rest: shown, under shown frames, at an alpha above 0 through every parent.
local function Drawn(region)
	local alpha, node = region:GetAlpha(), region:GetParent()
	while node do
		alpha, node = alpha * node:GetAlpha(), node:GetParent()
	end
	return region:IsVisible() and alpha > 0
end

-- Box(solver, region, unit, sweep) -> the screen box a texture's drawn pixels reach at full alpha, at rest or, with sweep, grown by its Scale animations and moved along its Translation paths, and its file name; nil when it draws nothing.
local function Box(solver, region, unit, sweep)
	local texture = region._state.Texture
	local box, content = solver:rect(region._barOwner or region), texture and Content(texture[1], region._state.TexCoord)
	if not (box and content) then
		return nil
	end
	local l, r, t, b = math.huge, -math.huge, -math.huge, math.huge
	for _, p in ipairs(sweep and Poses(solver, region, unit) or { { box[1], box[3], box[4], box[2] } }) do
		local w, h = p[2] - p[1], p[3] - p[4]
		l, r = math.min(l, p[1] + content[1] * w), math.max(r, p[1] + content[2] * w)
		t, b = math.max(t, p[3] - content[3] * h), math.min(b, p[3] - content[4] * h)
	end
	return l, r, t, b, tostring(texture[1]):match("[^\\/]+$")
end

-- Covers(region, poses, peer, meant) -> the first screen pixel where the region, in any of its poses (from Poses), draws a pixel (alpha
-- 64 or more) on a pixel the peer's texture draws at rest, unless meant(x, y, pose) allows it; nil when they never meet.
local function Covers(region, poses, peer, meant)
	for _, p in ipairs(poses) do
		local l, r, t, b = math.max(p[1], peer[1]), math.min(p[2], peer[2]), math.min(p[3], peer[3]), math.max(p[4], peer[4])
		for y = math.floor(b) + 0.5, t, 1 do
			for x = math.floor(l) + 0.5, r, 1 do
				if Solid(region, (x - p[1]) / (p[2] - p[1]), (p[3] - y) / (p[3] - p[4])) and Solid(peer.region, (x - peer[1]) / (peer[2] - peer[1]), (peer[3] - y) / (peer[3] - peer[4])) then
					if not meant(x, y, p, peer) then
						return x, y
					end
				end
			end
		end
	end
end

-- Meant(popoff) -> whether a region of the pop-off draws a pixel over another piece on purpose: an overlay (Ice Block's shell,
-- Divine Shield's bubble, Evocation over the mana gem) and Evocation's ticks cover only the piece on their own seat; the sigil, ring and flare are held
-- to every peer. Seats compare in crest units.
local function Near(a, b)
	return a and b and math.abs(a[1] - b[1]) < 4 and math.abs(a[2] - b[2]) < 4
end

local function Meant(popoff)
	local seat, own = popoff.at, popoff.overlay or popoff.frame.spec.ticks
	return function(_, _, _, peer)
		return own and Near(peer.piece.at, seat) or false
	end
end

function Reach.Check(sizes, classes, only)
	local popoffs = only == true
	only = only ~= true and only or nil
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
	for _, run in ipairs({ { sizes = sizes }, { sizes = popoffs and {} or sizes, low = true } }) do
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
			for _, id in ipairs(WIDEST[class] or {}) do widest[id] = true end
			measured.C_SpellBook.IsSpellKnown = function(id, ...) return widest[id] or known(id, ...) end
			measured.GetInventoryItemID = function(_, slot) return slot == 13 and 5002 or nil end
			measured.C_Item.GetItemSpell = function(id) if id == 5002 then return "Use", 9002 end end
			measured.GetTotemInfo = measured.GetTotemInfo or function() return false, "", 0, 0, 0, 1, 0 end
			for i = 3, low and 4 or 0 do
				measured.KstyleUI.Layout.Register(measured.CreateFrame("Frame"), FRAMES[i], measured.KstyleUI.Setup.Layouts.Default(FRAMES[i]))
			end
			if ns.SlabHawks then ns.SlabHawks.Update() end
			ns.SlabTrackers.Update()
			if popoffs then
				Light(measured, ns, class)
			end
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
					local seat = p.spec.seat
					seat = type(seat) == "table" and seat or ns.SlabSeats.AT[seat]
					pieces[#pieces + 1] = { key = p.spec.key, frame = p, overlay = p.spec.overlay, at = seat, seat = ns.SlabSeats.Name(p.spec.seat), rim = not ns.SlabSeats.Name(p.spec.seat), regions = RING[p.spec.key] and {} or Textures(p, {}) }
				end
			end
			for i, p in ipairs(not low and not only and ns.SlabHawks and ns.SlabHawks.state.perches or {}) do
				pieces[#pieces + 1] = { key = "hawk perch " .. i, regions = Textures(p.holder, {}) }
			end
			assert(class ~= "HUNTER" or low or only or #pieces > 2 and pieces[#pieces].key == "hawk perch 2", at .. ": the hunter's hawk perches are measured")
			local seated = ns.SlabTrackers.state.forms.crest.pieces
			local railPiece
			for _, p in pairs(seated) do railPiece = p.spec.key == "crestRail" and p or railPiece end
			local rails = WIDEST[class] and not popoffs
			assert(not rails or railPiece and railPiece:IsShown() and #railPiece.order == 5 and #railPiece.spare == SPARES and #rail >= #ROW,
				at .. " " .. class .. ": the rail's five seats and full second rail are measured against the cooldown row")
			assert(not rails or railPiece.low == low, at .. ": the rail takes its own flat row exactly while the centred cast bars show")
			local flying = {}
			for _, seat in ipairs(rails and railPiece.spare or {}) do
				for _, layer in ipairs(seat.lift and { seat.lift, seat.ghost } or {}) do
					for _, region in ipairs(Textures(layer, {})) do flying[region] = true end
				end
			end
			local peers = {}
			if popoffs then
				-- The combo heat hangs off the first crown point but rings the whole crest (SlabHeat.lua), so it is left out with the ring.
				local crown = ns.SlabCrown.state
				local heat = crown.pips.heat and crown.pips.heat.holder
				for i, p in ipairs(crown.pips) do
					local own = {}
					for _, region in ipairs(Textures(p.frame, {})) do
						local node = region:GetParent()
						while node and node ~= heat do node = node:GetParent() end
						if not node then own[#own + 1] = region end
					end
					pieces[#pieces + 1] = { key = "crown point " .. i, regions = own }
				end
				for kind, p in pairs(crown.crowns) do
					pieces[#pieces + 1] = { key = "crown " .. kind, regions = Textures(p.frame or p, {}) }
				end
				for _, p in ipairs(pieces) do
					for _, region in ipairs(not p.rim and p.regions or {}) do
						if Drawn(region) and Box(solver, region, unit, false) then
							local box = solver:rect(region._barOwner or region)
							peers[#peers + 1] = { box[1], box[3], box[4], box[2], key = p.key, piece = p, region = region }
						end
					end
				end
				assert(#peers > 8, at .. " " .. class .. ": the other drawn crest pieces are measured (" .. #peers .. ")")
			end
			-- A seat the full second rail cut stays built until it is seated again: hidden, its crown layers at alpha 0.
			local cut = {}
			local function Hidden(frame, off)
				off = off or not frame:IsShown()
				for _, region in ipairs(off and frame._regions or {}) do cut[region] = true end
				for _, kid in ipairs(frame._kids or {}) do Hidden(kid, off) end
			end
			Hidden(railPiece)
			for _, seat in pairs(railPiece.made) do
				for _, layer in ipairs(not seat:IsShown() and seat.gate and { seat.gate, seat.ghost } or {}) do
					assert(layer:GetAlpha() == 0, where .. " " .. class .. ": a cut seat's crown layer is hidden")
					Hidden(layer, true)
				end
			end
			local sampled = {}
			for _, p in ipairs(pieces) do
				for _, region in ipairs((not popoffs or p.key == "crestPopoffs") and p.regions or {}) do
					local texture = region._state.Texture
					local box, content = solver:rect(region._barOwner or region), texture and Content(texture[1], region._state.TexCoord)
					if box and content and not flying[region] then
						checked = checked + 1
						local w, h = box[3] - box[1], box[4] - box[2]
						local name = at .. " " .. class .. " " .. p.key .. "'s " .. tostring(texture[1]):match("[^\\/]+$")
						local own = p.key == "crestRail" and railed or avoid
						local swept = popoffs and { { Box(solver, region, unit, true) } } or Sweep(solver, region, box[1] + content[1] * w, box[1] + content[2] * w, box[4] - content[3] * h, box[4] - content[4] * h, unit)
						for _, each in ipairs(swept) do
							local l, r, t, b = each[1], each[2], each[3], each[4]
							assert(own == railed or math.abs(l - cx) <= 80 * unit and math.abs(r - cx) <= 80 * unit, name .. " stays inside the crest's column")
							for _, a in ipairs(own) do
								assert(r <= a[1] or a[3] <= l or t <= a[2] or a[4] <= b, name .. " crosses an action slot, the level badge, a unit frame, a cast bar or the cooldown row")
							end
						end
						local poses, meant = popoffs and Poses(solver, region, unit), popoffs and Meant(p)
						for _, a in ipairs(popoffs and peers or {}) do
							local x, y
							if a.piece ~= p then
								x, y = Covers(region, poses, a, meant)
							end
							assert(not x, string.format("%s covers %s's %s, another crest piece, at %d, %d (at its seat or on its way there)", name, a.key, tostring(a.region._state.Texture[1]):match("[^\\/]+$"), x or 0, y or 0))
						end
					end
				end
			end
			assert(checked > (popoffs and 2 or (low or only) and 10 or 20), at .. " " .. class .. ": the lit pieces are measured (" .. checked .. ")")
			if rails then
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
	end
	_G.dofile, _G.RENDER_TRACKERS, _G.RENDER_CAST_ON_FRAME = original, nil, nil
end

return Reach
