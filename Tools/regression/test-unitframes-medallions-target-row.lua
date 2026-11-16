local U = dofile("Tools/regression/unitframes_env.lua")
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

local types = { "Beast", "Dragonkin", "Demon", "Elemental", "Giant", "Undead", "Humanoid", "Critter", "Mechanical", "Not specified", "Totem", "Non-combat Pet", "Gas Cloud", "Wild Pet", "Aberration" }
local failures = {}
local function check(ok, why)
	if not ok then failures[#failures + 1] = why end
end

for _, screen in ipairs({ { 5120, 1440 }, { 3456, 2234 }, { 1920, 1080 } }) do
	RENDER_SCREEN = { width = screen[1], height = screen[2], size = "auto" }
	RENDER_HUD_STYLE = "Medallions"
	local env, K, ns = U.New({ width = screen[1], height = screen[2], size = "auto",
		saved = Hud.Saved(Hud.Options({ layout = "DPS" }), "UnitFrames", {}),
		setup = function(e) Common.ForceScreen(e, true) end,
	})
	local view = ns.Frames.Get("target").views[1]
	local path, full = ns.Settings.Font("target", "name")
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
			end
		end
	end
	local g, s = view.geometry, view.s
	local row = { x = g.aura.x, y = g.aura.y, w = s.auraColumns * s.auraSize + (s.auraColumns - 1) * s.auraSpacing, h = s.auraSize + 16 }
	local m = g.marker
	check(m.x >= row.x + row.w + ns.Geometry.MARKER_GAP or m.x + m.w + ns.Geometry.MARKER_GAP <= row.x or m.y >= row.y + row.h or m.y + m.h <= row.y, tag .. ": raid marker clears debuffs and timers")
	check(m.x >= g.medal.x + g.medal.w or m.x + m.w <= g.medal.x, tag .. ": raid marker sits beside medallion")
	U.SetUnit(env, "target", { name = "Ash", creature = "Beast", level = 39, health = 90, healthMax = 100 })
	env.SetTarget(true)
	check(view.name:GetFont() == path and U.Shown(env, view.name) == ns.Unit.Tracked("Ash", path), tag .. ": short name restores caps")
	check(#env._errors == 0 and K.ErrorCount() == 0, tag .. ": no errors")
end
RENDER_SCREEN, RENDER_HUD_STYLE = nil, nil
assert(#failures == 0, table.concat(failures, "\n"))
print("unitframes medallions target row ok")
