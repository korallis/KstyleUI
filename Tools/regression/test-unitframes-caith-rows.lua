-- test-unitframes-caith-rows.lua: mirrored Medallions rows keep their native filters, wrap upward, defer combat changes and restore cached fan geometry.
local U = dofile("Tools/regression/unitframes_env.lua")
local Engine = dofile("Tools/regression/aura_fixture_engine.lua")
local Scene = dofile("Tools/render/scene.lua")
local function Near(a, b, why) assert(math.abs(a - b) < 1.1, why .. ": " .. a .. " / " .. b) end
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = U.New({ width = screen[1], height = screen[2], size = "auto", fit = true, before = function(_, core)
		core.Store.Module("UnitFrames").player = { medallionsAuras = true }
	end })
	local fixtures = {}
	for i = 1, 9 do fixtures[i] = { id = i, icon = 135813, left = i * 3, count = i, mine = true, harmful = true } end
	fixtures[10] = { id = 10, icon = 136026, left = 1, mine = false, harmful = true }
	U.SetUnit(env, "target", { name = "Target", level = 60, health = 100, healthMax = 100, reaction = 2, auras = fixtures })
	env._units.player.auras = {}
	for i = 1, 9 do env._units.player.auras[i] = { id = 100 + i, icon = 135932, left = i * 30, mine = true, harmful = false } end
	env.SetTarget(true)
	Engine.Install(env)
	local target = ns.Frames.Get("target").views[1]
	assert(not target.auras.fan, "rows are the new default and allocate no fan")
	local rowPool = target.auras.container
	for _, kind in ipairs({ "player", "target" }) do
		local view = ns.Frames.Get(kind).views[1]
		local a = view.auras
		local group = a.container._groups[kind == "player" and "buffs" or "debuffs"]
		assert(group.filter == (kind == "player" and "HELPFUL" or "HARMFUL|PLAYER"), "retain each unit's native aura set")
		assert(#group.assigned == 9, "other players' target debuffs never enter your row")
		local first, second, wrap = group.buttons[1], group.buttons[2], group.buttons[7]
		local x, y, w = Scene.Rect(env, first)
		local x2, y2 = Scene.Rect(env, second)
		local x7, y7 = Scene.Rect(env, wrap)
		Near(y, y2, "icons form one straight row")
		Near(x, x7, "wrapping keeps the first column")
		assert(y7 < y and (kind == "player" and x2 > x or kind == "target" and x2 < x), "wrap upward and mirror horizontal growth")
		local bx, by = Scene.Rect(env, view.button)
		local factor = view.button:GetEffectiveScale() * 1080 / 768
		local medal = view.geometry.medal
		local edge = bx + (medal.x + (kind == "target" and medal.w or 0)) * factor
		Near(kind == "target" and x + w or x, edge, "align with the unit's outer medallion edge")
		assert(y + w < by + medal.y * factor, "the row clears the top of its own medallion")
		local entry
		for _, tile in ipairs(a.buttons) do if tile.button == first then entry = tile end end
		assert(entry and not entry.slab and entry.chrome.visible, "reuse the fan's chamfered tile builder")
		assert(first._aura.SetDurationText[1] == entry.timer and first._aura.SetApplicationCount[1] == entry.count, "the engine owns timers and stack counts")
		local point, relative, relPoint, _, offset = entry.timer:GetPoint()
		assert(point == "TOP" and relative == entry.skin and relPoint == "BOTTOM" and offset < 0, "timers stay below the tiles")
	end
	local settings = K.Store.Module("UnitFrames")
	local standard = K.Options.Row("UnitFrames", "player.auras")
	local medallions = K.Options.Row("UnitFrames", "player.medallionsAuras")
	assert(not standard.showWhen(settings) and medallions.showWhen(settings), "the rows layout shows the Medallions aura rows")
	K.Options.Write("UnitFrames", "player.medallionsAuras", false)
	assert(not ns.Frames.Get("player").views[1].auras.container._enabled, "the player's aura toggle can turn rows off")
	K.Options.Write("UnitFrames", "player.medallionsAuras", true)
	env.SetCombat(true)
	K.Options.Write("UnitFrames", "auraLayout", "fan")
	assert(target.auras.container == rowPool and not target.auras.fan, "changing layout during combat defers construction")
	env.SetCombat(false)
	env.RunTimers()
	local fan = assert(target.auras.fan, "the old look remains selectable")
	local points = {}
	for i, window in ipairs(fan.windows) do points[i] = { window:GetPoint() } end
	K.Options.Write("UnitFrames", "auraLayout", "rows")
	assert(target.auras.container == rowPool and not fan.enabled, "rows restore their cached native pool")
	K.Options.Write("UnitFrames", "auraLayout", "fan")
	for i, window in ipairs(fan.windows) do
		local p = { window:GetPoint() }
		for j = 1, 5 do assert(p[j] == points[i][j], "restoring the fan preserves every original anchor") end
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, "row and fan transitions raise no protected or secret-value errors")
end
print("caith rows ok: four owner screens, outer alignment, wrap, native filters, timers, counts, combat and cached fan")
