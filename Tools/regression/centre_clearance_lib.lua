-- centre_clearance_lib.lua: source-drawn centre assets after Setup.Apply, with all lanes occupied, checked separately from their mostly empty Layout holders.
local Hud = dofile("Tools/render/scenes/hud.lua")

local M = {}
local SCREENS = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 },
	{ 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 },
}
local EXCEPTIONS = {
	["player.level/player.portrait"] = true,
	["target.level/target.portrait"] = true,
}
M.ORNAMENT_PAIRS = {
	["player.body/player.cast"] = "the block end: the end or cap that closes the player's health and power block may run into the gap above the player's own cast bar, keeping 1 physical pixel clear of its fill, track, text, icon and white cursor",
	["target.body/target.cast"] = "the block end: the end or cap that closes the target's health and power block may run into the gap above the target's own cast bar, keeping 1 physical pixel clear of its fill, track, text, icon and white cursor",
}
local ORNAMENT_FILE = "Media/Textures/ForgedOrnaments/"
local INK = (function()
	local ns = { Widgets = {} }
	assert(loadfile("Core/Widgets/OrnamentInk.lua"))(nil, ns)
	return ns.Widgets.OrnamentInk
end)()
M.INK = INK

local function Options(layout, class, form)
	local opts = {
		class = class, layout = layout, applyPreset = true, settings = Hud.PresetSettings(layout),
		target = { name = "Shadowgale Poacher", creature = "Humanoid", power = 240, powerMax = 345 },
		targetAuras = { { 135813, "9s" }, { 136026, "3s" } },
	}
	if class == "DRUID" then
		opts.player = {
			powerType = form == "cat" and 3 or 1, powerToken = form == "cat" and "ENERGY" or "RAGE",
			power = 60, powerMax = 100, powers = { [0] = 2200 }, powerMaxes = { [0] = 4000 },
		}
		opts.spec = { combo = 3 }
	elseif class == "ROGUE" then
		opts.spec = { cast = { "First Aid", 135966, 746, 8 } }
	end
	return opts
end

local function Collect(scene, roots, groups, painted, scale, label)
	for _, line in ipairs(scene.log) do
		assert(not line:find("error:", 1, true), label .. ": " .. line)
	end
	for _, item in ipairs(scene.items) do
		local r = item.rect
		if r[3] > 0 and r[4] > 0 then
			local object, group = item.object
			while object do
				painted[object] = true
				group, object = group or roots[object], object._parent
			end
			assert(group, label .. ": unclaimed drawn asset: " .. (item.text or item.file or item.kind))
			groups[group] = groups[group] or {}
			local file = item.file and item.file:gsub("\\", "/")
			local ornament = file ~= nil and file:find(ORNAMENT_FILE, 1, true) ~= nil
			local coords = item.texCoord
			groups[group][#groups[group] + 1] = {
				x = r[1] / scale, y = r[2] / scale, w = r[3] / scale, h = r[4] / scale,
				asset = item.text or item.file or item.kind, ornament = ornament, file = file, texCoord = coords,
				shape = (group:find("%.level$") or group:find("%.portrait$"))
					and (item.text and group:find("%.level$") and "Dot" or file and file:match("([^/]+)%.png$")) or nil,
				flip = coords ~= nil and coords[1] > coords[2],
				visible = (ornament or not coords) and 1 or math.abs(coords[2] - coords[1]),
			}
		end
	end
end

local function Case(layout, class, form, screen)
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2] })
	local label = string.format("%s %s %s %dx%d", layout, class, form or "", screen[1], screen[2])
	local opts = Options(layout, class, form)
	local units, U = Hud.Module("unitframes", opts)
	local cooldowns, C = Hud.Module("cooldowns", opts)
	local ue, ce = Hud.envs[units], Hud.envs[cooldowns]
	local K = ue.KstyleUI
	assert(ue._renderPreset == layout and ce._renderPreset == layout, label .. ": both modules ran Setup.Apply")
	assert(K.Store.Module("Layout").preset == layout and ce.KstyleUI.Store.Module("Layout").preset == layout, label .. ": selected preset persisted")
	assert(math.abs(K.Scale.AppliedUserScale() - K.Scale.DEFAULT_USER_SCALE) < 1e-9, label .. ": shipped Interface size")
	assert(math.abs(ce.KstyleUI.Scale.AppliedUserScale() - K.Scale.AppliedUserScale()) < 1e-9, label .. ": module canvases share a size")
	local scale = K.Scale.Root():GetEffectiveScale() / ue.UIParent:GetEffectiveScale()
	local groups, roots, painted, required = {}, {}, {}, {}
	local function Require(object, name)
		required[#required + 1] = { object = assert(object, label .. ": exists " .. name), name = name }
	end
	for _, kind in ipairs({ "player", "target" }) do
		local view = U.Frames.Get(kind).views[1]
		roots[view.parent] = kind .. ".body"
		roots[view.portraitFrame] = kind .. ".portrait"
		roots[view.disc], roots[view.levelText] = kind .. ".level", kind .. ".level"
		for _, part in ipairs({ "health", "power", "name", "caption", "portraitFrame", "disc" }) do
			Require(view[part], kind .. "." .. part)
		end
		local cast = kind == "player" and U.CastBars.Get(kind)[1] or U.CastBars.Inline(kind)[1]
		roots[cast.frame] = kind .. ".cast"
		assert(cast.active, label .. ": " .. kind .. " casts during the measurement")
		for _, part in ipairs({ "bar", "text", "timer" }) do
			Require(cast[part], kind .. ".cast." .. part)
		end
		if kind == "target" then
			roots[view.auras.host] = "target.auras"
			for i = 1, 2 do
				Require(view.auras.container._groups.debuffs.buttons[i], "target.debuff" .. i)
			end
		end
	end
	roots[U.Resource.state.content] = "resource"
	local resource = U.Resource.state
	assert(resource.showCombo == (class == "ROGUE" or class == "DRUID" and form == "cat"), label .. ": combo visibility")
	assert(resource.showMana == (class == "DRUID"), label .. ": shifted mana visibility")
	if resource.showCombo then
		for i, pip in ipairs(resource.pips) do
			Require(pip, "combo pip " .. i)
		end
	end
	if resource.showMana then
		Require(resource.mana, "shifted mana")
	end
	assert(C.Path.Get("essential") == "mirror" and C.Path.Get("utility") == "mirror", label .. ": automatic cooldown mirrors")
	assert(C.Path.Get("buffs") == "reskin" and C.Path.Get("bars") == "reskin", label .. ": automatic native tracked viewers")
	assert(C.Mirror.Row("essential").count == 6 and C.Mirror.Row("utility").count == 4, label .. ": all cooldown slots occupied")
	Collect(units, roots, groups, painted, scale, label)
	roots = {}
	for _, group in ipairs({ "essential", "utility", "buffs", "bars" }) do
		local holder = C.Path.Get(group) == "mirror" and C.Mirror.Row(group).holder or C.Viewers.Frame(group)
		roots[holder] = "cooldowns." .. group
		local icons = C.Path.Get(group) == "mirror" and C.Mirror.Row(group).icons or holder._items
		local count = ({ essential = 6, utility = 4, buffs = 5, bars = 2 })[group]
		assert(#icons == count, label .. ": " .. group .. " item count")
		for i, icon in ipairs(icons) do
			Require(icon, group .. " item " .. i)
		end
	end
	Collect(cooldowns, roots, groups, painted, scale, label)
	for _, entry in ipairs(required) do
		assert(painted[entry.object], label .. ": paints " .. entry.name)
	end
	for _, key in ipairs({
		"player.body", "player.portrait", "player.level", "player.cast", "target.body", "target.portrait",
		"target.level", "target.cast", "target.auras", "cooldowns.essential", "cooldowns.utility", "cooldowns.buffs", "cooldowns.bars",
	}) do
		assert(groups[key] and #groups[key] > 0, label .. ": draws " .. key)
	end
	assert((groups.resource ~= nil) == (class ~= "PALADIN"), label .. ": secondary resource is drawn only where supported")
	return groups, scale * screen[2] / 1080, label, screen
end

local function Prims(r, pixels)
	local runs = r.shape and INK.spans[r.shape]
	if runs then
		local sx, sy, list = r.w / runs[1], r.h / runs[2], {}
		for i = 3, #runs, 4 do
			local x0, x1 = runs[i + 2] * sx, runs[i + 3] * sx
			list[#list + 1] = { x = r.flip and r.x + r.w - x1 or r.x + x0, y = r.y + runs[i] * sy, w = x1 - x0, h = (runs[i + 1] - runs[i]) * sy }
		end
		return list
	end
	local fraction = r.shape and INK.circles[r.shape]
	if fraction then
		return { { x = r.x, y = r.y, w = r.w, h = r.h, radius = fraction * r.w / 2 / r.visible + 1 / pixels } }
	end
	return { r }
end
M.Prims = Prims

local function BoxGap(a, b)
	local dx = math.max(a.x - b.x - b.w, b.x - a.x - a.w)
	local dy = math.max(a.y - b.y - b.h, b.y - a.y - a.h)
	return math.sqrt(math.max(0, dx) ^ 2 + math.max(0, dy) ^ 2), dx, dy
end

local function Round(c, b)
	local cx, cy = c.x + c.w / 2, c.y + c.h / 2
	if b.radius then
		return math.sqrt((cx - b.x - b.w / 2) ^ 2 + (cy - b.y - b.h / 2) ^ 2) - c.radius - b.radius
	end
	local dx, dy = math.max(b.x - cx, cx - b.x - b.w, 0), math.max(b.y - cy, cy - b.y - b.h, 0)
	return math.sqrt(dx * dx + dy * dy) - c.radius
end

function M.Gap(r, s, pixels)
	local gap, dx, dy = BoxGap(r, s)
	if not (r.ornament or s.ornament) then return gap, dx, dy end
	local a, b = Prims(r, pixels), Prims(s, pixels)
	if #a == 1 and #b == 1 and a[1] == r and b[1] == s then return gap, dx, dy end
	local least = math.huge
	for _, p in ipairs(a) do
		for _, q in ipairs(b) do
			local d = BoxGap(p, q)
			if p.radius then d = math.max(d, Round(p, q)) elseif q.radius then d = math.max(d, Round(q, p)) end
			least = math.min(least, math.max(d, 0))
		end
	end
	return least, least, least
end

function M.Check(groups, pixels, label, screen)
	local keys = {}
	for key, parts in pairs(groups) do
		keys[#keys + 1] = key
		for _, r in ipairs(parts) do
			assert(r.x * pixels >= -0.001 and r.y * pixels >= -0.001
				and (r.x + r.w) * pixels <= screen[1] + 0.001 and (r.y + r.h) * pixels <= screen[2] + 0.001,
				label .. ": " .. key .. " leaves the screen: " .. r.asset)
		end
	end
	table.sort(keys)
	for i, a in ipairs(keys) do
		for j = i + 1, #keys do
			local b = keys[j]
			local pair = M.ORNAMENT_PAIRS[a .. "/" .. b]
			if not EXCEPTIONS[a .. "/" .. b] then
				for _, r in ipairs(groups[a]) do
					for _, s in ipairs(groups[b]) do
						local gap, dx, dy = M.Gap(r, s, pixels)
						local art = pair and (r.ornament and 1 or 0) + (s.ornament and 1 or 0) or 0
						if art == 1 then
							assert(not (dx < -0.001 and dy < -0.001), label .. ": " .. a .. " ornament overlaps " .. b .. ": " .. r.asset .. " / " .. s.asset)
							assert(gap * pixels >= 1 - 0.001,
								string.format("%s: %s / %s ornament gap %.4f px, needs 1 px: %s / %s", label, a, b, gap * pixels, r.asset, s.asset))
						elseif art == 0 then
							assert(not (dx < -0.001 and dy < -0.001), label .. ": " .. a .. " overlaps " .. b .. ": " .. r.asset .. " / " .. s.asset)
							assert(gap >= 4 - 0.001 and gap * pixels >= 3 - 0.001,
								string.format("%s: %s / %s gap %.4f root, %.4f px: %s / %s", label, a, b, gap, gap * pixels, r.asset, s.asset))
						end
					end
				end
			end
		end
	end
end

function M.Run(layout, class, form)
	local previous, level = rawget(_G, "RENDER_SCREEN"), rawget(_G, "RENDER_ORNAMENTS")
	rawset(_G, "RENDER_ORNAMENTS", "Full")
	for _, screen in ipairs(SCREENS) do
		M.Check(Case(layout, class, form, screen))
		collectgarbage("collect")
	end
	rawset(_G, "RENDER_SCREEN", previous)
	rawset(_G, "RENDER_ORNAMENTS", level)
	print("ok centre clearance " .. layout .. " " .. class .. " " .. (form or "") .. ": nine screens")
end

return M
