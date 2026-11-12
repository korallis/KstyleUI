-- surfaces_clearance_lib.lua: the data bars' ornaments on the reference HUD keep 1 physical pixel of drawn ink from all other content, and the minimap, a card since the overhaul, draws no ornament piece.
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

-- Handles(captured) -> { name = { handle, own = function(region) } } for every data-bar ornament. own
-- answers "flush" for what a piece frames (it may touch it and covers none of it; a bar's own drop shadow, whose
-- outer row is within one colour level of the backdrop, is exempt, so a rail flush on the border may lie on it), "exempt" for what the spec lets it
-- sit on, and "top" for a picture it may cover only above its floor.
function M.Handles(captured)
	local out = {}
	local bars = captured.databars and captured.databars.ns.Bars
	for id, view in pairs(bars and bars.views or {}) do
		if not view.ornament then break end
		out["databars." .. id] = { handle = view.ornament, own = function(region, item)
			local own = under(region, view.track) or under(region, view.fill)
			if own and tostring(item.file or ""):find("Shadow%.png$") then return "exempt" end
			return own and "flush" or nil
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

-- Blocker(scene, handle, rects, px) -> a piece of another handle, drawn only at this level, that comes within 1
-- physical pixel of one of rects (where Subtle drew its end or rail), or nil.
local function Blocker(scene, handle, rects, px)
	local mine, gap = {}, 1 / px
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

-- RailBlocker(scene, handle, rects, px) -> a piece of another handle that takes so much of each rail in rects (the
-- rails Subtle drew on one side) that no stretch longer than 8 root units is left free, or nil: a rail that is only
-- partly blocked must be split, not dropped.
local function RailBlocker(scene, handle, rects, px)
	local mine, gap, by = {}, 1 / px, nil
	for i = 1, handle.used do mine[handle.textures[i]] = true end
	for _, q in ipairs(rects) do
		local spans = {}
		for _, item in ipairs(scene.items) do
			local r = item.rect
			if file(item) and not mine[item.object] and r[2] < q[2] + q[4] + gap and q[2] < r[2] + r[4] + gap then
				spans[#spans + 1] = { r[1] - gap, r[1] + r[3] + gap }
				by = by or file(item)
			end
		end
		table.sort(spans, function(a, b) return a[1] < b[1] end)
		local x, longest = q[1], 0
		for _, span in ipairs(spans) do
			if span[2] > x then
				longest = math.max(longest, span[1] - x)
				x = math.max(x, span[2])
			end
		end
		longest = math.max(longest, q[1] + q[3] - x)
		if longest > 8 then return nil end
	end
	return by
end

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

-- CapShare(scene, handle, label, px) fails when a cap (`Wing` or `Arrow`) is shorter than 40% of the room between
-- the handle's top and bottom rails: an end that small reads as a speck and is dropped, never drawn (Captain,
-- 2026-11-11; `CAP_SHARE` in Core/Widgets/Ornaments.lua).
function M.CapShare(scene, handle, label, px)
	local above, below = M.RailSides(scene, handle)
	if #above == 0 or #below == 0 then return end
	local top, bottom = -math.huge, math.huge
	for _, r in ipairs(above) do top = math.max(top, r[2] + r[4]) end
	for _, r in ipairs(below) do bottom = math.min(bottom, r[2]) end
	local mine = {}
	for i = 1, handle.used do mine[handle.textures[i]] = true end
	for _, item in ipairs(scene.items) do
		local name = mine[item.object] and file(item)
		if name and (name:find("^Wing") or name:find("^Arrow")) and item.rect[4] < 0.4 * (bottom - top) - 1e-3 then
			error(string.format("%s: %s is %.2f units tall, under 40%% of the %.2f units between the rails", label, name, item.rect[4], bottom - top), 0)
		end
	end
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
			local railBy = blocked and blocked(before, true)
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
			if name:find("^databars%.") then M.CapShare(scene, entry.handle, label, case.screen[2] / 1080) end
			M.NotSmaller(sizes, string.format("%s %s%s %dx%d", name, case.layout, case.faction and " watching a faction" or "", case.screen[1], case.screen[2]), case.level, h, w, label, above, below, rects, function(old, rails)
				return (rails and RailBlocker or Blocker)(scene, entry.handle, old, case.screen[2] / 1080)
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

-- Bare(cases, title) builds the reference HUD for each case and checks that nothing under the minimap's holder draws
-- a forged ornament piece, at any level: the overhaul's minimap is a card whose only corner pieces are its brackets.
function M.Bare(cases, title)
	local captured, release = M.Capture()
	local Reference = dofile("Tools/render/scenes/_reference.lua")
	local saved, oldLevel = Reference.SCREEN, rawget(_G, "RENDER_ORNAMENTS")
	for _, case in ipairs(cases) do
		rawset(_G, "RENDER_ORNAMENTS", case.level)
		Reference.SCREEN = { width = case.screen[1], height = case.screen[2], uiScale = saved.uiScale }
		for name in pairs(captured) do captured[name] = nil end
		local scene = Reference.Build({ layout = case.layout, modules = case.modules })
		local label = string.format("%s %s %dx%d", case.level, case.layout, case.screen[1], case.screen[2])
		local map = captured.minimap
		assert(map and map.env.KstyleUI.Widgets.Setting("ornaments") == case.level, label .. ": the level is " .. case.level)
		local face = map.ns.Map.face
		local arms = {}
		for _, bracket in ipairs(face.brackets) do
			arms[bracket.across], arms[bracket.down] = true, true
		end
		local brackets = 0
		for _, item in ipairs(scene.items) do
			if under(item.object, map.ns.Map.holder) then
				assert(not file(item), label .. ": the minimap draws no forged ornament piece, not " .. tostring(file(item)))
				if arms[item.object] then brackets = brackets + 1 end
			end
		end
		assert(brackets == 8 and face.ornament == nil and face.plaqueOrnament == nil, label .. ": its corners are the card's four gilt brackets, eight arms drawn, not " .. brackets)
		collectgarbage("collect")
	end
	Reference.SCREEN = saved
	rawset(_G, "RENDER_ORNAMENTS", oldLevel)
	release()
	print("ok " .. title .. ": " .. #cases .. " cases, no ornament piece on the minimap card")
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
	local cases = 0
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
				assert(ns.Bars.views[shown].content:IsShown(), label .. ": the " .. shown .. " bar shows")
				if state == "hover" then
					assert(ns.Bars.views.rep.plate:IsShown(), label .. ": the hovered reputation bar shows its label's plate on its line")
				end
				for id, view in pairs(ns.Bars.views) do
					assert(view.ornament == nil, label .. ": the " .. id .. " bar owns no ornament")
					for _, item in ipairs(scene.items) do
						if under(item.object, view.holder) then
							assert(not file(item), label .. ": no forged ornament piece, not " .. tostring(file(item)))
						end
					end
				end
				cases = cases + 1
				collectgarbage("collect")
			end
		end
	end
	rawset(_G, "dofile", originalDo)
	print("ok data bar states " .. title .. ": " .. cases .. " cases, no ornament piece on the data bars")
end

-- NoBarPieces(cases, title) builds the reference HUD for each case and checks that nothing under a data bar draws a
-- forged ornament piece: since the overhaul (KSTY-44 bible 3.4) the data bars are clean bars.
function M.NoBarPieces(cases, title)
	local captured, release = M.Capture()
	local Reference = dofile("Tools/render/scenes/_reference.lua")
	local saved, oldLevel, savedFaction = Reference.SCREEN, rawget(_G, "RENDER_ORNAMENTS"), Reference.STATE.game.faction
	for _, case in ipairs(cases) do
		rawset(_G, "RENDER_ORNAMENTS", case.level)
		Reference.SCREEN = { width = case.screen[1], height = case.screen[2], uiScale = saved.uiScale }
		Reference.STATE.game.faction = case.faction and M.FACTION or savedFaction
		for name in pairs(captured) do captured[name] = nil end
		local scene = Reference.Build({ layout = case.layout, modules = case.modules })
		local label = string.format("%s %s %dx%d", case.level, case.layout, case.screen[1], case.screen[2])
		local bars = captured.databars and captured.databars.ns.Bars
		assert(bars and captured.databars.env.KstyleUI.Widgets.Setting("ornaments") == case.level, label .. ": the level is " .. case.level)
		for id, view in pairs(bars.views) do
			assert(view.ornament == nil, label .. ": the " .. id .. " bar owns no ornament")
			for _, item in ipairs(scene.items) do
				if under(item.object, view.holder) then
					assert(not file(item), label .. ": the " .. id .. " bar draws no forged ornament piece, not " .. tostring(file(item)))
				end
			end
		end
		collectgarbage("collect")
	end
	Reference.SCREEN = saved
	Reference.STATE.game.faction = savedFaction
	rawset(_G, "RENDER_ORNAMENTS", oldLevel)
	release()
	print("ok " .. title .. ": " .. #cases .. " cases, no ornament piece on the data bars")
end

return M
