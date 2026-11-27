-- ranged_reach.lua: Reach.Check(sizes, low, classes, trees, only) builds the HUD scene's action bars for a hunter, mage and warlock (or the classes named) with every crest tracker lit (RENDER_TRACKERS=lit), and the hunter's hawk perches with their summon lift, at each screen size and asserts that no texture of a break-out piece, at full alpha (a waiting flare at its peak), swept through every pass of the Scale, Rotation and Translation animations on it and on every frame above it, draws a pixel (alpha at least a quarter, read from the texture: an additive RGB aura sheet by its brightest channel, a flipbook sheet folded into one cell, a still cell through its texture coordinates; an addon file the reader cannot read stops the check) on an action slot, the level badge, the player or target frame or either cast bar, or outside the crest's column. The warlock knows every summon and Demonic Sacrifice, so its demon piece builds each demon's mark and each Sacrifice copy, and each of those aura sheets must be among the measured textures. Each class's cooldown rail is measured at its widest, four abilities, the trinket and six round medals on its second rail, with the hunter's pet, its family ability and orders, Immolation Trap, Tranquilizing Shot and a potion known too, against the Medallions cooldown row's placed rows and may reach past the crest's column. With low true each screen is built with Cast bars on unit frames off instead, where the rail must take its own flat row and every crest piece, the rail included, must clear the centred cast bars too; each layout is a call of its own, so a test file can build one screen in one layout inside the hosted runner's CPU budget. With only set to a piece's key (crestRail), only that piece is measured, with no hawk perches, so a warrior's, paladin's or rogue's rail is checked alone (test-actionbars-crest-melee-reach and its 1440 and wide files) while its armory pieces are measured by test-actionbars-crest-armory. The pieces that ring the whole crest (moments, the ward, the Auto Shot ring, the cooldown sigils, the five-second ring) are the ring itself and are left out. Each second-rail medal's flight to the crown and its fold home are swept apart from the rest, through the lift's own animation alone, as the circle its drawn pixels reach from their centre, against those obstacles and every other rail medal (each the circle of its seat), at every sample from leaving its seat to settling in the crown and back. Only its own seat is left out, and in the crown only the other medals, and only while each of its textures stays inside the crown's own texture of that name at the largest scale a main seat's landing reaches. With trees, low must be true and the mage runs once per talent tree named, its shown orb and each of that tree's orb sheets and rail seat aura sheets among the measured textures. A seat cut from a full second rail stays built, hidden, and draws nothing, so it is left out.
local Png = dofile("Tools/regression/png.lua")
local Scene = dofile("Tools/render/scene.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")
local Reach = {}

local RING = { crestGust = true, crestClearcasting = true, crestTrance = true, crestWard = true, crestAutoShot = true, crestCooldowns = true, crestFiveSecond = true }
local FRAMES = { "unitframes.player", "unitframes.target", "unitframes.castbar.player", "unitframes.castbar.target" }
local CONTENT = {}

-- Cells(coords) -> columns and rows of the even grid a flipbook cell's texture coordinates (left, right, top, bottom) pick from;
-- 1, 1 for the whole texture or a crop that is no grid cell.
local function Cells(coords)
	if not (coords and #coords == 4) then
		return 1, 1
	end
	local columns, rows = 1 / (coords[2] - coords[1]), 1 / (coords[4] - coords[3])
	local even = math.abs(columns - math.floor(columns + 0.5)) < 0.01 and math.abs(rows - math.floor(rows + 0.5)) < 0.01
	return even and math.floor(columns + 0.5) or 1, even and math.floor(rows + 0.5) or 1
end

-- Content(path, coords) -> the share of one cell (the whole texture, or a flipbook's cell from Cells) that the texture's pixels
-- of alpha 64 or more span in any cell, so a flipbook is measured over every frame it can show: left, right, top, bottom; false if none.
local function Content(path, coords)
	local columns, rows = Cells(coords)
	local key = tostring(path) .. " " .. columns .. "x" .. rows
	if CONTENT[key] == nil then
		local file = tostring(path):gsub("\\", "/"):match("Media/.+$")
		local ok, alpha, w, h = pcall(Png.Alpha, file or "")
		local l, r, t, b = 1, 0, 1, 0
		local cw, ch = ok and w / columns, ok and h / rows
		for y = 0, ok and h - 1 or -1 do
			for x = 0, w - 1 do
				if alpha(x, y) >= 64 then
					local cx, cy = x % cw, y % ch
					l, r, t, b = math.min(l, cx / cw), math.max(r, (cx + 1) / cw), math.min(t, cy / ch), math.max(b, (cy + 1) / ch)
				end
			end
			runs[y] = list
		end
		CONTENT[key] = ok and r > l and { l, r, t, b } or false
	end
	return CONTENT[key]
end

-- Motion(region) -> the largest scale its own Scale animations reach and the box its Translation paths sweep, in its units.
local function Motion(region)
	local scale, x0, x1, y0, y1 = 1, 0, 0, 0, 0
	local node = region
	while node do
		for _, group in ipairs(node._groups or {}) do
			local orders, x, y = {}, 0, 0
			for _, anim in ipairs(group._anims or {}) do
				local order = anim._state.Order and anim._state.Order[1] or 1
				orders[order] = orders[order] or {}
				table.insert(orders[order], anim)
				if anim._type == "Scale" and node == region then
					for _, field in ipairs({ "ScaleFrom", "ScaleTo" }) do
						local sx, sy = unpack(anim._state[field] or { 1, 1 })
						scale = math.max(scale, sx or 1, sy or 1)
					end
				end
			end
			for order = 1, 64 do
				for _, anim in ipairs(orders[order] or {}) do
					if anim._type == "Translation" then
						local ox, oy = unpack(anim._state.Offset or { 0, 0 })
						x, y = x + (ox or 0), y + (oy or 0)
						x0, x1, y0, y1 = math.min(x0, x), math.max(x1, x), math.min(y0, y), math.max(y1, y)
					end
				end
			end
			boxes = out
		end
		node = node:GetParent()
	end
	return scale, x0, x1, y0, y1
end

local function Textures(frame, list)
	for _, region in ipairs(frame._regions or {}) do
		if region._type == "Texture" then list[#list + 1] = region end
	end
	for _, kid in ipairs(frame._kids or {}) do Textures(kid, list) end
	return list
end

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
	for _, unit in ipairs({ "player", "pet", "target", "focus" }) do
		Slots.Set(env, unit, auras[unit])
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
	local scale, x0, x1, y0, y1 = 1, 0, 0, 0, 0
	if sweep then
		scale, x0, x1, y0, y1 = Motion(region)
	end
	local w, h = box[3] - box[1], box[4] - box[2]
	local mx, my = (box[1] + box[3]) / 2, (box[2] + box[4]) / 2
	local l, r = mx + (box[1] + content[1] * w - mx) * scale + x0 * unit, mx + (box[1] + content[2] * w - mx) * scale + x1 * unit
	local t, b = my + (box[4] - content[3] * h - my) * scale + y1 * unit, my + (box[4] - content[4] * h - my) * scale + y0 * unit
	return l, r, t, b, tostring(texture[1]):match("[^\\/]+$")
end

function Reach.Check(sizes, classes, popoffs)
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
		local runs = {}
		for _, class in ipairs(classes or { "HUNTER", "MAGE", "WARLOCK" }) do
			local _, ns = Hud.Module("actionbars", Hud.Options({ layout = "DPS", class = class, applyPreset = true }))
			if class == "HUNTER" then
				local known = measured.C_SpellBook.IsSpellKnown
				local widest = { [1293241] = true, [19574] = true, [3045] = true, [19577] = true, [14305] = true, [13795] = true, [24579] = true, [14916] = true, [19801] = true }
				measured.C_SpellBook.IsSpellKnown = function(id, ...) return widest[id] or known(id, ...) end
				measured.GetTotemInfo = measured.GetTotemInfo or function() return false, "", 0, 0, 0, 1, 0 end
				ns.SlabHawks.Update()
			end
			if popoffs then
				Light(measured, ns, class)
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
			for _, box in ipairs(frames) do avoid[#avoid + 1] = box end
			assert(#avoid > 16, at .. " " .. class .. ": the action slots, badge, unit frames and cast bars are placed")
			local checked = 0
			local pieces = {}
			for _, p in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
				pieces[#pieces + 1] = { key = p.spec.key, overlay = p.spec.overlay, rim = not ns.SlabSeats.Name(p.spec.seat), regions = RING[p.spec.key] and {} or Textures(p, {}) }
			end
			for i, p in ipairs(ns.SlabHawks and ns.SlabHawks.state.perches or {}) do
				pieces[#pieces + 1] = { key = "hawk perch " .. i, regions = Textures(p.holder, {}) }
			end
			assert(class ~= "HUNTER" or #pieces > 2 and pieces[#pieces].key == "hawk perch 2", at .. ": the hunter's hawk perches are measured")
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
						local l, r, t, b
						if Drawn(region) then
							l, r, t, b = Box(solver, region, unit, false)
						end
						if l then peers[#peers + 1] = { l, b, r, t, p.key, p } end
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
					local l, r, t, b, file = Box(solver, region, unit, true)
					if l then
						checked = checked + 1
						local name = at .. " " .. class .. " " .. p.key .. "'s " .. file
						assert(math.abs(l - cx) <= 80 * unit and math.abs(r - cx) <= 80 * unit, name .. " stays inside the crest's column")
						for _, a in ipairs(avoid) do
							assert(r <= a[1] or a[3] <= l or t <= a[2] or a[4] <= b, name .. " crosses an action slot, the level badge, a unit frame or a cast bar")
						end
						if popoffs and not p.overlay and Drawn(region) then
							l, r, t, b = Box(solver, region, unit, false)
							for _, a in ipairs(peers) do
								assert(a[6] == p or r <= a[1] or a[3] <= l or t <= a[2] or a[4] <= b, name .. " at its seat covers " .. tostring(a[5]) .. ", another crest piece")
							end
						end
					end
				end
			end
			assert(checked > (popoffs and 2 or 20), at .. " " .. class .. ": the lit pieces are measured (" .. checked .. ")")
		end
	end
	_G.dofile, _G.RENDER_TRACKERS = original, nil
end

return Reach
