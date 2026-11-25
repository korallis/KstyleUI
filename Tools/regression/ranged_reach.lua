-- ranged_reach.lua: Reach.Check(sizes, classes) builds the HUD scene's action bars for a hunter, mage and warlock (or the classes named) with every crest tracker lit (RENDER_TRACKERS=lit), and the hunter's hawk perches with their summon lift, at each screen size and asserts that no texture of a break-out piece, at full alpha (a waiting flare at its peak), grown by its own Scale animations and moved over the whole path of every Translation on it or above it, draws a pixel (alpha at least a quarter, read from the texture) on an action slot, the level badge, the player or target frame or either cast bar, or outside the crest's column. The pieces that ring the whole crest (moments, the ward, the Auto Shot ring, the cooldown sigils, the five-second ring) are the ring itself and are left out.
local Png = dofile("Tools/regression/png.lua")
local Scene = dofile("Tools/render/scene.lua")
local Reach = {}

local RING = { crestGust = true, crestClearcasting = true, crestTrance = true, crestWard = true, crestAutoShot = true, crestCooldowns = true, crestFiveSecond = true }
local FRAMES = { "unitframes.player", "unitframes.target", "unitframes.castbar.player", "unitframes.castbar.target" }
local CONTENT = {}

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
		for _, class in ipairs(classes or { "HUNTER", "MAGE", "WARLOCK" }) do
			local _, ns = Hud.Module("actionbars", Hud.Options({ layout = "DPS", class = class, applyPreset = true }))
			if class == "HUNTER" then
				local known = measured.C_SpellBook.IsSpellKnown
				measured.C_SpellBook.IsSpellKnown = function(id, ...) return id == 1293241 or known(id, ...) end
				measured.GetTotemInfo = measured.GetTotemInfo or function() return false, "", 0, 0, 0, 1, 0 end
				ns.SlabHawks.Update()
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
			for _, box in ipairs(frames) do avoid[#avoid + 1] = box end
			assert(#avoid > 16, at .. " " .. class .. ": the action slots, badge, unit frames and cast bars are placed")
			local checked = 0
			local pieces = {}
			for _, p in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
				pieces[#pieces + 1] = { key = p.spec.key, regions = RING[p.spec.key] and {} or Textures(p, {}) }
			end
			for i, p in ipairs(ns.SlabHawks and ns.SlabHawks.state.perches or {}) do
				pieces[#pieces + 1] = { key = "hawk perch " .. i, regions = Textures(p.holder, {}) }
			end
			assert(class ~= "HUNTER" or #pieces > 2 and pieces[#pieces].key == "hawk perch 2", at .. ": the hunter's hawk perches are measured")
			for _, p in ipairs(pieces) do
				for _, region in ipairs(p.regions) do
					local texture = (region._barOwner and region or region)._state.Texture
					local box, content = solver:rect(region._barOwner or region), texture and Content(texture[1])
					if box and content then
						checked = checked + 1
						local scale, x0, x1, y0, y1 = Motion(region)
						local w, h = box[3] - box[1], box[4] - box[2]
						local mx, my = (box[1] + box[3]) / 2, (box[2] + box[4]) / 2
						local l, r = mx + (box[1] + content[1] * w - mx) * scale + x0 * unit, mx + (box[1] + content[2] * w - mx) * scale + x1 * unit
						local t, b = my + (box[4] - content[3] * h - my) * scale + y1 * unit, my + (box[4] - content[4] * h - my) * scale + y0 * unit
						local name = at .. " " .. class .. " " .. p.key .. "'s " .. tostring(texture[1]):match("[^\\/]+$")
						assert(math.abs(l - cx) <= 80 * unit and math.abs(r - cx) <= 80 * unit, name .. " stays inside the crest's column")
						for _, a in ipairs(avoid) do
							assert(r <= a[1] or a[3] <= l or t <= a[2] or a[4] <= b, name .. " crosses an action slot, the level badge, a unit frame or a cast bar")
						end
					end
				end
			end
			assert(checked > 20, at .. " " .. class .. ": the lit pieces are measured (" .. checked .. ")")
		end
	end
	_G.dofile, _G.RENDER_TRACKERS = original, nil
end

return Reach
