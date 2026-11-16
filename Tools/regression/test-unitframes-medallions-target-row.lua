local U = dofile("Tools/regression/unitframes_env.lua")
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

local types = { "Beast", "Dragonkin", "Demon", "Elemental", "Giant", "Undead", "Humanoid", "Critter", "Mechanical", "Not specified", "Totem", "Non-combat Pet", "Gas Cloud", "Wild Pet", "Aberration" }
local failures = {}
local function check(ok, why)
	if not ok then failures[#failures + 1] = why end
end

for _, screen in ipairs({ { 5120, 1440 }, { 3456, 2234 }, { 1920, 1080 } }) do
	_G.RENDER_SCREEN = { width = screen[1], height = screen[2], size = "auto" }
	_G.RENDER_HUD_STYLE = "Medallions"
	local env, K, ns = U.New({ width = screen[1], height = screen[2], uiScale = 768 / 1080, size = "auto",
		saved = Hud.Saved(Hud.Options({ layout = "DPS" }), "UnitFrames", {}),
		setup = function(e) Common.ForceScreen(e, true) end,
	})
	env.RunTimers()
	local view = ns.Frames.Get("target").views[1]
	local path = ns.Settings.Font("target", "name")
	local tag = screen[1] .. "x" .. screen[2]
	for _, creature in ipairs(types) do
		for _, name in ipairs({ "Ash", "Riverglade Crocolisk" }) do
			U.SetUnit(env, "target", { name = name, creature = creature, level = 39, health = 90, healthMax = 100, marker = 8, reaction = 2 })
			env.SetTarget(true)
			check(not view.caption:IsTruncated(), tag .. " " .. name .. ": show full " .. creature .. " (" .. tostring(view.caption:GetUnboundedStringWidth()) .. " in " .. tostring(view.caption:GetWidth()) .. ")")
			local g = view.geometry
			check(g.caption.x + g.caption.w + 3 <= g.name.x + 0.01, tag .. ": creature type clears the name")
			if creature == "Beast" then
				check(view.name:GetFont() == path, tag .. ": shrink Riverglade Crocolisk in the caps face before falling back")
				check(U.Shown(env, view.name) == ns.Unit.Tracked(name, path), tag .. ": preserve capitals")
				check(not view.name:IsTruncated(), tag .. ": readable long name fits")
				local pixels = select(2, view.name:GetFont()) * view.name:GetEffectiveScale() * screen[2] / 768
				check(pixels >= math.ceil(9 * screen[2] / 1080 - 1e-6) - 1e-6, tag .. ": caps name stays at or above the 9-unit reading floor")
			end
		end
	end
	local g, s = view.geometry, view.s
	local row = { x = g.aura.x, y = g.aura.y, w = s.auraColumns * s.auraSize + (s.auraColumns - 1) * s.auraSpacing, h = s.auraSize + 16 }
	local m = g.marker
	check(m.x >= row.x + row.w + ns.Geometry.MARKER_GAP or m.x + m.w + ns.Geometry.MARKER_GAP <= row.x or m.y >= row.y + row.h or m.y + m.h <= row.y, tag .. ": raid marker clears debuffs and timers")
	check(m.x >= g.medal.x + g.medal.w or m.x + m.w <= g.medal.x, tag .. ": raid marker sits beside medallion")
	check(m.y + m.h <= 0, tag .. ": raid marker clears an outboard target-of-target slab")
	local fontSizes = {}
	local setFont = view.name.SetFont
	view.name.SetFont = function(text, font, size, flags)
		fontSizes[#fontSizes + 1] = { font, size }
		return setFont(text, font, size, flags)
	end
	U.SetUnit(env, "target", { name = string.rep("Everlasting ", 12), creature = "Not specified", level = 39, health = 90, healthMax = 100 })
	env.SetTarget(true)
	local shrank
	for _, font in ipairs(fontSizes) do
		if font[1] == path and font[2] < fontSizes[1][2] then shrank = true end
	end
	check(shrank and view.name:IsTruncated(), tag .. ": an extreme name reaches the caps floor before fallback and truncation")
	view.name.SetFont = setFont
	U.SetUnit(env, "target", { name = "Ash", creature = "Beast", level = 39, health = 90, healthMax = 100 })
	env.SetTarget(true)
	check(view.name:GetFont() == path and U.Shown(env, view.name) == ns.Unit.Tracked("Ash", path), tag .. ": short name restores caps")
	local nameMeasure, captionMeasure = view.name.GetUnboundedStringWidth, view.caption.GetUnboundedStringWidth
	local function plainMeasure(measure)
		return function(text)
			assert(not env.issecretvalue(text:GetText()), "never measure secret unit text")
			return measure(text)
		end
	end
	view.name.GetUnboundedStringWidth, view.caption.GetUnboundedStringWidth = plainMeasure(nameMeasure), plainMeasure(captionMeasure)
	env.UnitName = function() return env.Secret("Hidden name") end
	env.UnitCreatureType = function() return env.Secret("Mechanical") end
	env.FireEvent("UNIT_NAME_UPDATE", "target")
	env.FireEvent("UNIT_LEVEL", "target")
	check(U.Shown(env, view.name) == "Hidden name" and U.Shown(env, view.caption) == "Mechanical", tag .. ": pass secret text to setters")
	check(view.nameBound and view.geometry.caption.w > 0, tag .. ": reserve safe space for secret text")
	check(#env._errors == 0 and K.ErrorCount() == 0, tag .. ": no errors")
end
_G.RENDER_SCREEN, _G.RENDER_HUD_STYLE = nil, nil
assert(#failures == 0, table.concat(failures, "\n"))
print("unitframes medallions target row ok")
