-- popoff_reach.lua: Reach.Check(sizes, classes) builds the HUD scene's action bars for each class named with every crest tracker lit (RENDER_TRACKERS=lit), the hunter's hawk perches out and every one of the class's signature pop-offs (KstyleUI_ActionBars/SlabPopoffs.lua) known and lit on top, at each screen size, with the cast bars on the unit frames. A mage or warlock also knows its widest crest rail (ranged_reach.lua's Reach.WIDEST), so the rail's medals stand where they reach furthest; the warlock's Amplify Curse also runs, so the rail's crown shows beside Shadow Trance. It asserts that no pop-off texture, at full alpha, in any pose its own animations and its parents' reach together (anim_pose.lua's sampled poses, scale about each one's pivot), draws a pixel (alpha at least a quarter, read from the texture) on an action slot, the level badge, the player or target frame or either cast bar, or outside the crest's column, and, pixel by pixel, that it draws on no texture another named-seat piece, hawk perch, crown point, the rail's running crown or pop-off draws at rest (shown at an alpha above 0), with no exemption, Divine Shield's dome over the emblem included. The pieces that ring the whole crest (rim seats) are no peer.
local Png = dofile("Tools/regression/png.lua")
local Scene = dofile("Tools/render/scene.lua")
local Pose = dofile("Tools/regression/anim_pose.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")
local Ranged = dofile("Tools/regression/ranged_reach.lua")
local Reach = {}

local RING = { crestGust = true, crestClearcasting = true, crestTrance = true, crestWard = true, crestAutoShot = true, crestCooldowns = true, crestFiveSecond = true }
local FRAMES = { "unitframes.player", "unitframes.target", "unitframes.castbar.player", "unitframes.castbar.target" }
local CONTENT = {}
-- The moment a class's crest rail crowns beside its pop-offs (SlabRanged.lua's rail abilities): the rail seat's key and its buff.
local RAIL = { WARLOCK = { key = "amplify", spell = 18288 } }

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
		end
		CONTENT[key] = ok and r > l and { l, r, t, b, alpha = alpha, w = cw, h = ch, columns = columns, rows = rows, full = { w, h } } or false
	end
	return CONTENT[key]
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

-- Moves(node) -> the poses the node's own animation groups reach, each {x, y, scale} as anim_pose.lua gives it at one sampled time of a
-- group's pass, so an offset goes only with the scale it plays beside; the first is at rest. Also the Scale pivot as an anchor point and
-- offset in the node's units.
local function Moves(node)
	local poses, origin = { { 0, 0, 1 } }, nil
	for _, group in ipairs(node._groups or {}) do
		for _, anim in ipairs(group._anims or {}) do
			if anim._type == "Scale" then
				origin = origin or anim._state.Origin
			end
		end
		local timed, times = Pose.Passes(group)
		for _, time in ipairs(#timed > 0 and times or {}) do
			local x, y, _, scale = Pose.At(timed, time)
			poses[#poses + 1] = { x, y, scale }
		end
	end
	return poses, origin
end

local PIVOT = { CENTER = { 0.5, 0.5 }, BOTTOM = { 0.5, 0 }, TOP = { 0.5, 1 }, LEFT = { 0, 0.5 }, RIGHT = { 1, 0.5 }, BOTTOMLEFT = { 0, 0 }, BOTTOMRIGHT = { 1, 0 }, TOPLEFT = { 0, 1 }, TOPRIGHT = { 1, 1 } }

-- Poses(solver, region, unit) -> the screen boxes (left, right, top, bottom; y up) the region's box reaches as it and every parent above
-- it play their animations: each node, from the region up, scales the box about its own pivot and moves it by each pose from Moves, so
-- a parent's scale also carries the child's offset from that pivot; the first is at rest.
local function Poses(solver, region, unit)
	local box = solver:rect(region._barOwner or region)
	local poses = { { box[1], box[3], box[4], box[2] } }
	local node = region
	while node do
		local moves, origin = Moves(node)
		if #moves > 1 then
			local rect = solver:rect(node._barOwner or node) or box
			local at = PIVOT[origin and origin[1] or "CENTER"] or PIVOT.CENTER
			local px = rect[1] + (rect[3] - rect[1]) * at[1] + (origin and origin[2] or 0) * unit
			local py = rect[2] + (rect[4] - rect[2]) * at[2] + (origin and origin[3] or 0) * unit
			local moved = {}
			for _, p in ipairs(poses) do
				for _, m in ipairs(moves) do
					local k, dx, dy = m[3], m[1] * unit, m[2] * unit
					moved[#moved + 1] = { px + (p[1] - px) * k + dx, px + (p[2] - px) * k + dx, py + (p[3] - py) * k + dy, py + (p[4] - py) * k + dy }
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

-- Light(env, ns, class): the character knows every one of the class's signature pop-offs (KstyleUI_ActionBars/SlabPopoffs.lua) and has each one's aura on its unit, its allies' too, and the buff of the moment its rail crowns (RAIL).
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
	end
	if RAIL[class] then Give("player", { id = RAIL[class].spell, start = env._now, duration = 30 }) end
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

-- Covers(region, poses, peer) -> the first screen pixel where the region, in any of its poses (from Poses), draws a pixel (alpha
-- 64 or more) on a pixel the peer's texture draws at rest; nil when they never meet.
local function Covers(region, poses, peer)
	for _, p in ipairs(poses) do
		local l, r, t, b = math.max(p[1], peer[1]), math.min(p[2], peer[2]), math.min(p[3], peer[3]), math.max(p[4], peer[4])
		for y = math.floor(b) + 0.5, t, 1 do
			for x = math.floor(l) + 0.5, r, 1 do
				if Solid(region, (x - p[1]) / (p[2] - p[1]), (p[3] - y) / (p[3] - p[4])) and Solid(peer.region, (x - peer[1]) / (peer[2] - peer[1]), (peer[3] - y) / (peer[3] - peer[4])) then
					return x, y
				end
			end
		end
	end
end

function Reach.Check(sizes, classes)
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
	_G.RENDER_SCENE_LIB, _G.RENDER_TRACKERS, _G.RENDER_CAST_ON_FRAME = true, "lit", nil
	for _, size in ipairs(sizes) do
		local at = size[1] .. "x" .. size[2]
		_G.RENDER_SCREEN = { width = size[1], height = size[2], size = "auto" }
		local Hud = dofile("Tools/render/scenes/hud.lua")
		Hud.Module("unitframes", Hud.Options({ layout = "DPS", class = "HUNTER", applyPreset = true }))
		local frames = {}
		for _, key in ipairs(FRAMES) do
			local element = measured.KstyleUI.Layout.Element(key)
			frames[#frames + 1] = assert(element and Scene.RectSolver(measured):rect(element.frame), at .. ": " .. key .. " is placed")
		end
		for _, class in ipairs(classes) do
			local _, ns = Hud.Module("actionbars", Hud.Options({ layout = "DPS", class = class, applyPreset = true }))
			local known, widest = measured.C_SpellBook.IsSpellKnown, {}
			for _, id in ipairs(Ranged.WIDEST[class] or {}) do widest[id] = true end
			measured.C_SpellBook.IsSpellKnown = function(id, ...) return widest[id] or known(id, ...) end
			measured.GetInventoryItemID = function(_, slot) return slot == 13 and 5002 or nil end
			measured.C_Item.GetItemSpell = function(id) if id == 5002 then return "Use", 9002 end end
			measured.GetTotemInfo = measured.GetTotemInfo or function() return false, "", 0, 0, 0, 1, 0 end
			if ns.SlabHawks then ns.SlabHawks.Update() end
			ns.SlabTrackers.Update()
			Light(measured, ns, class)
			local solver = Scene.RectSolver(measured)
			local hub = solver:rect(ns.Slab.hub)
			local cx, unit = (hub[1] + hub[3]) / 2, (hub[3] - hub[1]) / ns.Slab.RING
			local avoid = { solver:rect(ns.Slab.hub.plaque) }
			for _, bar in pairs(ns.bars) do
				for _, button in ipairs(bar.buttons or {}) do
					if button:IsVisible() then avoid[#avoid + 1] = solver:rect(button) end
				end
			end
			for _, box in ipairs(frames) do avoid[#avoid + 1] = box end
			assert(#avoid > 16, at .. " " .. class .. ": the action slots, badge, unit frames and cast bars are placed")
			local pieces = {}
			for _, p in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
				pieces[#pieces + 1] = { key = p.spec.key, rim = not ns.SlabSeats.Name(p.spec.seat), regions = RING[p.spec.key] and {} or Textures(p, {}) }
			end
			for i, p in ipairs(ns.SlabHawks and ns.SlabHawks.state.perches or {}) do
				pieces[#pieces + 1] = { key = "hawk perch " .. i, regions = Textures(p.holder, {}) }
			end
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
			local moment = RAIL[class]
			if moment then
				local rail
				for _, p in pairs(ns.SlabTrackers.state.forms.crest.pieces) do rail = p.spec.key == "crestRail" and p or rail end
				local seat = assert(rail and rail.made[moment.key], at .. " " .. class .. ": the rail seats " .. moment.key)
				assert(rail.owner == seat and seat.crowned:IsShown(), at .. " " .. class .. ": " .. moment.key .. " runs and owns the rail's crown")
				pieces[#pieces + 1] = { key = "the rail's " .. moment.key .. " crown", crown = true, regions = Textures(seat.gate, {}) }
			end
			local peers = {}
			for _, p in ipairs(pieces) do
				for _, region in ipairs(not p.rim and p.regions or {}) do
					if Drawn(region) and Box(solver, region, unit, false) then
						local box = solver:rect(region._barOwner or region)
						peers[#peers + 1] = { box[1], box[3], box[4], box[2], key = p.key, piece = p, region = region }
					end
				end
			end
			assert(#peers > 8, at .. " " .. class .. ": the other drawn crest pieces are measured (" .. #peers .. ")")
			local checked, crowned = 0, 0
			for _, p in ipairs(pieces) do
				for _, region in ipairs(p.key == "crestPopoffs" and p.regions or {}) do
					local texture = region._state.Texture
					local l, r, t, b = Box(solver, region, unit, true)
					if l then
						checked = checked + 1
						local name = at .. " " .. class .. " " .. p.key .. "'s " .. tostring(texture[1]):match("[^\\/]+$")
						assert(math.abs(l - cx) <= 80 * unit and math.abs(r - cx) <= 80 * unit, name .. " stays inside the crest's column")
						for _, a in ipairs(avoid) do
							assert(r <= a[1] or a[3] <= l or t <= a[2] or a[4] <= b, name .. " crosses an action slot, the level badge, a unit frame or a cast bar")
						end
						local poses = Poses(solver, region, unit)
						for _, a in ipairs(peers) do
							local x, y
							if a.piece ~= p then
								x, y = Covers(region, poses, a)
								crowned = crowned + (a.piece.crown and 1 or 0)
							end
							assert(not x, string.format("%s covers %s's %s, another crest piece, at %d, %d (at its seat or on its way there)", name, a.key, tostring(a.region._state.Texture[1]):match("[^\\/]+$"), x or 0, y or 0))
						end
					end
				end
			end
			assert(checked > 2, at .. " " .. class .. ": the lit pop-offs are measured (" .. checked .. ")")
			assert(not moment or crowned > 0, at .. " " .. class .. ": the pop-offs are measured against the rail's running crown")
		end
	end
	_G.dofile, _G.RENDER_TRACKERS = original, nil
end

return Reach
