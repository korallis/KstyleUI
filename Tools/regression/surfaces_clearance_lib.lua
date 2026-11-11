-- surfaces_clearance_lib.lua: the minimap's and the data bars' ornaments on the reference HUD keep 1 physical pixel of drawn ink from all other content.
local M = {}
M.SCREENS = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 },
	{ 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 },
}

local function file(item)
	return item.file and tostring(item.file):match("Media/Textures/ForgedOrnaments/([^/]+)%.png$")
end

local function under(region, root)
	while region do
		if region == root then return true end
		region = type(region.GetParent) == "function" and region:GetParent() or nil
	end
	return false
end

-- Box(item, px) -> the item's box in physical pixels; a text's box is as wide as its string, placed by its justification.
local function Box(item, px)
	local r = item.rect
	local l, t, w, h = r[1], r[2], r[3], r[4]
	local object = item.object
	if item.kind == "text" and object and type(object.GetStringWidth) == "function" then
		local width, own = object:GetStringWidth(), object:GetWidth()
		if type(width) == "number" and type(own) == "number" and own > 0 and width < own then
			local ink = width * w / own
			local justify = item.justifyH or "CENTER"
			if justify == "LEFT" then
				w = ink
			elseif justify == "RIGHT" then
				l, w = l + w - ink, ink
			else
				l, w = l + (w - ink) / 2, ink
			end
		end
	end
	return l * px, t * px, (l + w) * px, (t + h) * px
end

-- Ink(item, px, ink) -> the boxes a piece draws ink in: its OrnamentInk row runs, narrowed back by the texel the
-- generator widens them by, where it has them, else its box.
local function Ink(item, px, ink)
	local l, t, r, b = Box(item, px)
	local runs = ink.spans[file(item)]
	if not runs then return { { l, t, r, b } } end
	local uv = item.texCoord or { 0, 1, 0, 1 }
	local flipX, flipY = uv[1] > uv[2], uv[3] > uv[4]
	local w, h = runs[1], runs[2]
	local out = {}
	for i = 3, #runs, 4 do
		local r0, r1, x0, x1 = runs[i], runs[i + 1], runs[i + 2] + 1, runs[i + 3] - 1
		if flipX then x0, x1 = w - x1, w - x0 end
		if flipY then r0, r1 = h - r1, h - r0 end
		out[#out + 1] = { l + x0, t + r0, l + x1, t + r1 }
	end
	return out
end

-- Gap(a, b) -> how many physical pixels part two boxes along the axis that parts them most; 0 when they touch.
function M.Gap(a, b)
	return math.max(b[1] - a[3], a[1] - b[3], b[2] - a[4], a[2] - b[4])
end

-- Capture() -> a table the next HUD build fills with each module's scene and namespace.
function M.Capture()
	local captured = {}
	local originalDo = dofile
	rawset(_G, "dofile", function(path)
		local value = originalDo(path)
		if path == "Tools/render/scenes/hud.lua" and type(value) == "table" and not value._surfaces then
			value._surfaces = true
			local module = value.Module
			value.Module = function(name, opts)
				local scene, ns, extra = module(name, opts)
				captured[name] = { scene = scene, ns = ns, env = value.envs[scene] }
				return scene, ns, extra
			end
		end
		return value
	end)
	return captured, function()
		rawset(_G, "dofile", originalDo)
	end
end

-- Handles(captured) -> { name = { handle, own = function(region) } } for every data-bar and minimap ornament. own
-- answers "flush" for what a piece frames (it may touch it and covers none of it; a bar's own drop shadow, whose
-- outer row is within one colour level of the backdrop, is exempt, so a rail flush on the border may lie on it), "exempt" for what the spec lets it
-- sit on, and "top" for a picture it may cover only above its floor. The plaque's named exemption (spec, Exemptions):
-- it sits on the face's gilt top rim and the map's top rows, as many as the north plate it frames is tall (the plate
-- is centred on the face's top edge); it keeps 1 px from the N glyph, the caption texts and every button, lies
-- behind its crystal disc (the scene paints the disc after it, so no disc pixel changes) and covers no map row below.
function M.Handles(captured)
	local out = {}
	local bars = captured.databars and captured.databars.ns.Bars
	for id, view in pairs(bars and bars.views or {}) do
		out["databars." .. id] = { handle = view.ornament, own = function(region, item)
			local own = under(region, view.track) or under(region, view.fill)
			if own and tostring(item.file or ""):find("Shadow%.png$") then return "exempt" end
			return own and "flush" or nil
		end }
	end
	local map = captured.minimap and captured.minimap.ns.Map
	local face = map and map.face
	if face then
		local env = captured.minimap.env
		local lines = {}
		for _, set in ipairs({ face.rim, face.shade }) do
			for _, line in pairs(set) do lines[line] = true end
		end
		local function picture(region)
			return lines[region] or under(region, env.Minimap)
		end
		out["minimap.map"] = { handle = face.ornament, own = function(region)
			return picture(region) and "flush" or nil
		end }
		local edge = { [face.rim.top] = true, [face.shade.top] = true }
		out["minimap.plaque"] = { handle = face.plaqueOrnament, own = function(region)
			if edge[region] then return "exempt" end
			if lines[region] then return nil end
			if under(region, env.Minimap) then return "top" end
			return region ~= face.north and under(region, face.plate) and "behind" or nil
		end, floor = function(scene, px)
			local top, bottom
			for _, item in ipairs(scene.items) do
				if item.object ~= face.north and under(item.object, face.plate) and not file(item) then
					local _, t, _, b = Box(item, px)
					top, bottom = math.min(top or t, t), math.max(bottom or b, b)
				end
			end
			assert(bottom, "the north plate draws")
			return bottom + (bottom - top) / 2
		end }
	end
	return out
end

-- Check(scene, handles, px, label, ink) -> the number of pieces measured; raises on a piece within 1 px of content.
function M.Check(scene, handles, px, label, ink)
	local index, pieces = {}, 0
	for i, item in ipairs(scene.items) do index[item.object] = i end
	for name, entry in pairs(handles) do
		local handle = entry.handle
		local own = {}
		for i = 1, handle.used do own[handle.textures[i]] = true end
		for i = 1, handle.used do
			local item = scene.items[index[handle.textures[i]] or 0]
			assert(item and file(item), label .. ": " .. name .. " #" .. i .. " is not drawn")
			pieces = pieces + 1
			local shapes = Ink(item, px, ink)
			local floor = entry.floor and entry.floor(scene, px)
			for _, other in ipairs(scene.items) do
				local foreign = file(other) and not own[other.object]
				local rule = not file(other) and other.object ~= item.object and entry.own(other.object, other)
				local box = { Box(other, px) }
				if rule == "top" then box[2] = math.max(box[2], floor) end
				if rule == "behind" and index[other.object] < index[item.object] then rule = "flush" end
				if (foreign or not file(other)) and other.object ~= item.object and rule ~= "exempt" and rule ~= "behind" and box[2] < box[4] then
					local need = (rule == "flush" or rule == "top") and 0 or 1
					for _, shape in ipairs(shapes) do
						local gap = M.Gap(shape, box)
						if gap < need - 1e-3 then
							error(string.format("%s: %s #%d %s [%.1f %.1f %.1f %.1f] is %.2f px from %s %s [%.1f %.1f %.1f %.1f]", label, name, i,
								file(item), shape[1], shape[2], shape[3], shape[4], gap, tostring(other.kind),
								tostring(other.text or other.file or ""), box[1], box[2], box[3], box[4]), 0)
						end
					end
				end
			end
		end
	end
	return pieces
end

-- EndSize(scene, handle) -> the height and width, in units, of the tallest end piece or cap the handle draws, or 0, 0,
-- and the rects of its end pieces and caps.
function M.EndSize(scene, handle)
	local mine, h, w, rects = {}, 0, 0, {}
	for i = 1, handle.used do mine[handle.textures[i]] = true end
	for _, item in ipairs(scene.items) do
		local name = mine[item.object] and file(item)
		if name and (name:find("^End") or name:find("^Wing") or name:find("^Arrow")) then
			rects[#rects + 1] = item.rect
			if item.rect[4] > h or item.rect[4] == h and item.rect[3] > w then h, w = item.rect[4], item.rect[3] end
		end
	end
	return h, w, rects
end

-- Blocker(scene, handle, rects, px) -> a piece of another handle that comes within the centre column's gap (4 root
-- units or 3 physical pixels, ruling C) of one of rects, or nil.
local function Blocker(scene, handle, rects, px)
	local mine, gap = {}, math.max(4, 3 / px)
	for i = 1, handle.used do mine[handle.textures[i]] = true end
	for _, item in ipairs(scene.items) do
		if file(item) and not mine[item.object] then
			local r = item.rect
			for _, q in ipairs(rects) do
				if r[1] < q[1] + q[3] + gap and q[1] < r[1] + r[3] + gap and r[2] < q[2] + q[4] + gap and q[2] < r[2] + r[4] + gap then
					return file(item)
				end
			end
		end
	end
end
M.Blocker = Blocker

-- RailSides(scene, handle) -> the rects of the rails the handle draws above and below the middle of its end pieces, or of
-- the bar its target sits on when it draws no end.
function M.RailSides(scene, handle)
	local mine, middle, ends, rails = {}, 0, 0, {}
	for i = 1, handle.used do mine[handle.textures[i]] = true end
	for _, item in ipairs(scene.items) do
		local name = mine[item.object] and file(item)
		if name and name:find("^Rail") then
			rails[#rails + 1] = item.rect
		elseif name then
			middle, ends = middle + item.rect[2] + item.rect[4] / 2, ends + 1
		end
	end
	middle = ends > 0 and middle / ends or nil
	if not middle then
		local frame = handle.target and handle.target:GetParent()
		local top, bottom
		for _, item in ipairs(scene.items) do
			if not file(item) and under(item.object, frame) then
				top, bottom = math.min(top or item.rect[2], item.rect[2]), math.max(bottom or 0, item.rect[2] + item.rect[4])
			end
		end
		middle = top and (top + bottom) / 2
	end
	local above, below = {}, {}
	for _, rect in ipairs(rails) do
		local y = rect[2] + rect[4] / 2
		if middle and y < middle then above[#above + 1] = rect elseif middle then below[#below + 1] = rect end
	end
	return above, below
end

-- NotSmaller(sizes, key, level, h, w, label) records Subtle's end size under key and fails when Full's, at the same
-- key, is shorter, or as tall and narrower, or drops a rail Subtle draws: Full never draws less than Subtle.
function M.NotSmaller(sizes, key, level, h, w, label, above, below, rects, blocked)
	if level == "Subtle" then
		sizes[key] = { h, w, above, below, rects }
		return
	end
	local subtle = sizes[key]
	local smaller = subtle and (h < subtle[1] - 1e-6 or math.abs(h - subtle[1]) < 1e-6 and w < subtle[2] - 1e-6)
	local by = smaller and blocked and blocked(subtle[5])
	if by then
		M.yields = M.yields or {}
		M.yields[#M.yields + 1] = label .. ": " .. key .. " gives way at Full to " .. by
		print("  " .. M.yields[#M.yields])
	elseif smaller then
		error(string.format("%s: %s draws a smaller end at Full (%.2f x %.2f units) than at Subtle (%.2f x %.2f)", label, key, w, h, subtle[2], subtle[1]), 0)
	end
	for side, rails in pairs({ above = above, below = below }) do
		local before = subtle and subtle[side == "above" and 3 or 4]
		if before and #before > 0 and #rails == 0 then
			local railBy = blocked and blocked(before)
			if not railBy then
				error(string.format("%s: %s draws a rail %s the bar at Subtle and none at Full", label, key, side), 0)
			end
			M.yields = M.yields or {}
			M.yields[#M.yields + 1] = label .. ": " .. key .. " drops its rail " .. side .. " the bar at Full for " .. railBy
			print("  " .. M.yields[#M.yields])
		end
	end
end

-- Run(cases) builds the reference HUD for each case ({ layout, level, screen, modules, only }) and checks the
-- handles whose names start with only; a Full case after the Subtle case of its layout and screen also checks that
-- no handle draws a smaller end than it did at Subtle.
function M.Run(cases, title)
	local sizes = {}
	local captured, release = M.Capture()
	local Reference = dofile("Tools/render/scenes/_reference.lua")
	local saved, oldLevel, savedFaction = Reference.SCREEN, rawget(_G, "RENDER_ORNAMENTS"), Reference.STATE.game.faction
	local total = 0
	for _, case in ipairs(cases) do
		rawset(_G, "RENDER_ORNAMENTS", case.level)
		Reference.SCREEN = { width = case.screen[1], height = case.screen[2], uiScale = saved.uiScale }
		Reference.STATE.game.faction = case.faction and M.FACTION or savedFaction
		for name in pairs(captured) do captured[name] = nil end
		local scene = Reference.Build({ layout = case.layout, modules = case.modules })
		local label = string.format("%s %s %dx%d", case.level, case.layout, case.screen[1], case.screen[2])
		local first = captured[case.modules[1]]
		local K = first.env.KstyleUI
		assert(K.Widgets.Setting("ornaments") == case.level, label .. ": the level is " .. case.level)
		local handles = {}
		for name, entry in pairs(M.Handles(captured)) do
			if name:find(case.only, 1, true) == 1 then handles[name] = entry end
		end
		for _, name in ipairs(case.placed) do
			assert(handles[name] and handles[name].handle.used > 0, label .. ": " .. name .. " places pieces")
		end
		total = total + M.Check(scene, handles, case.screen[2] / 1080, label, K.Widgets.OrnamentInk)
		for name, entry in pairs(handles) do
			local h, w, rects = M.EndSize(scene, entry.handle)
			local above, below = M.RailSides(scene, entry.handle)
			M.NotSmaller(sizes, string.format("%s %s%s %dx%d", name, case.layout, case.faction and " watching a faction" or "", case.screen[1], case.screen[2]), case.level, h, w, label, above, below, rects, function(old)
				return Blocker(scene, entry.handle, old, case.screen[2] / 1080)
			end)
		end
		collectgarbage("collect")
	end
	Reference.SCREEN = saved
	Reference.STATE.game.faction = savedFaction
	rawset(_G, "RENDER_ORNAMENTS", oldLevel)
	release()
	print("ok " .. title .. ": " .. #cases .. " cases, " .. total .. " pieces keep 1 px of ink from all other content")
	return total
end

-- FACTION is the watched faction a case with faction set shows on the reputation bar, as RENDER_FACTION=1 does.
M.FACTION = { factionID = 72, name = "Stormwind", reaction = 5, currentReactionThreshold = 3000, nextReactionThreshold = 9000, currentStanding = 4500 }

-- Cases(layouts, levels, screens, modules, only, placed) -> every combination as Run's cases.
function M.Cases(layouts, levels, screens, modules, only, placed)
	local out = {}
	for _, layout in ipairs(layouts) do
		for _, level in ipairs(levels) do
			for _, screen in ipairs(screens) do
				out[#out + 1] = { layout = layout, level = level, screen = screen, modules = modules, only = only, placed = placed }
			end
		end
	end
	return out
end

-- States(screens, title) renders every state of the databars_ornaments scene at Subtle and Full on each screen and
-- checks that the data bars' pieces keep 1 px of ink from all other content, that the hovered reputation bar (its
-- label's glass plate on its line) draws none, that the reputation bar's rails lie flush on its border, and that Full
-- never draws a smaller end than Subtle in the same state.
function M.States(screens, title)
	rawset(_G, "RENDER_SCENE_LIB", true)
	local captured
	local originalDo = dofile
	rawset(_G, "dofile", function(path)
		local value = originalDo(path)
		if path == "Tools/regression/databars_env.lua" then
			local New = value.New
			value.New = function(...)
				local env, K, ns = New(...)
				captured = { env = env, K = K, ns = ns }
				return env, K, ns
			end
		end
		return value
	end)
	local total, cases, sizes = 0, 0, {}
	for _, screen in ipairs(screens) do
		for _, level in ipairs({ "Subtle", "Full" }) do
			for _, state in ipairs({ "empty", "rested", "full", "rep", "hover" }) do
				rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], uiScale = 768 / 1080 })
				rawset(_G, "RENDER_ORNAMENTS", level)
				rawset(_G, "RENDER_STATE", state)
				local build = originalDo("Tools/render/scenes/databars_ornaments.lua")
				local scene = build()
				local label = string.format("%s %s %dx%d", level, state, screen[1], screen[2])
				local K, ns = captured.K, captured.ns
				assert(K.Widgets.Setting("ornaments") == level, label .. ": the level is " .. level)
				local shown = state == "rep" and "rep" or "xp"
				assert(ns.Bars.views[shown].ornament.used >= 2, label .. ": the " .. shown .. " bar places pieces")
				if state == "hover" then
					assert(ns.Bars.views.rep.plate:IsShown() and ns.Bars.views.rep.ornament.used == 0, label .. ": the hovered reputation bar shows its label's plate on its line and draws no ornament")
				end
				total = total + M.Check(scene, M.Handles({ databars = { ns = ns } }), screen[2] / 1080, label, K.Widgets.OrnamentInk)
				for id, view in pairs(ns.Bars.views) do
					local h, w = M.EndSize(scene, view.ornament)
					M.NotSmaller(sizes, string.format("databars.%s %s %dx%d", id, state, screen[1], screen[2]), level, h, w, label)
				end
				if state == "rep" then
					local view, px = ns.Bars.views.rep, screen[2] / 1080
					local top, bottom, mine = math.huge, -math.huge, {}
					for i = 1, view.ornament.used do mine[view.ornament.textures[i]] = true end
					for _, item in ipairs(scene.items) do
						if under(item.object, view.track.borderFrame) then
							top, bottom = math.min(top, item.rect[2] * px), math.max(bottom, (item.rect[2] + item.rect[4]) * px)
						end
					end
					local rails = 0
					for _, item in ipairs(scene.items) do
						if mine[item.object] and tostring(item.file):find("/Rail%d+%.png$") then
							local t, b = item.rect[2] * px, (item.rect[2] + item.rect[4]) * px
							assert(math.abs(b - top) < 1e-3 or math.abs(t - bottom) < 1e-3, string.format("%s: the reputation bar's rail [%.1f %.1f] lies flush on its border [%.1f %.1f]", label, t, b, top, bottom))
							rails = rails + 1
						end
					end
					assert(rails == 2, label .. ": the reputation bar draws a rail above and below, not " .. rails)
				end
				cases = cases + 1
				collectgarbage("collect")
			end
		end
	end
	rawset(_G, "dofile", originalDo)
	print("ok data bar states " .. title .. ": " .. cases .. " cases, " .. total .. " pieces keep 1 px of ink from all other content")
end

return M
