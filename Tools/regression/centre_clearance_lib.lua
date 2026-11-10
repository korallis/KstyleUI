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
		local object, group = item.object
		while object do
			painted[object] = true
			group, object = group or roots[object], object._parent
		end
		if group then
			local r = item.rect
			if r[3] > 0 and r[4] > 0 then
				groups[group] = groups[group] or {}
				groups[group][#groups[group] + 1] = {
					x = r[1] / scale, y = r[2] / scale, w = r[3] / scale, h = r[4] / scale,
					asset = item.text or item.file or item.kind,
				}
			end
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
			if not EXCEPTIONS[a .. "/" .. b] then
				for _, r in ipairs(groups[a]) do
					for _, s in ipairs(groups[b]) do
						local dx = math.max(r.x - s.x - s.w, s.x - r.x - r.w)
						local dy = math.max(r.y - s.y - s.h, s.y - r.y - r.h)
						local gap = math.sqrt(math.max(0, dx) ^ 2 + math.max(0, dy) ^ 2)
						assert(not (dx < -0.001 and dy < -0.001), label .. ": " .. a .. " overlaps " .. b .. ": " .. r.asset .. " / " .. s.asset)
						assert(gap >= 4 - 0.001 and gap * pixels >= 3 - 0.001,
							string.format("%s: %s / %s gap %.4f root, %.4f px: %s / %s", label, a, b, gap, gap * pixels, r.asset, s.asset))
					end
				end
			end
		end
	end
end

function M.Run(layout, class, form)
	local previous = rawget(_G, "RENDER_SCREEN")
	for _, screen in ipairs(SCREENS) do
		M.Check(Case(layout, class, form, screen))
		collectgarbage("collect")
	end
	rawset(_G, "RENDER_SCREEN", previous)
	print("ok centre clearance " .. layout .. " " .. class .. " " .. (form or "") .. ": nine screens")
end

return M
