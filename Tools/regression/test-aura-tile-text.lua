-- test-aura-tile-text.lua: an aura tile's stack count and its timer each own a place: the count on a corner badge, the timer on the bottom edge, never on top of each other, on the unit frames and on nameplates at the default sizes; the sigil's tiles are at least 28 units with a timer of at least 10 (round 4: Fable #3, "2 5 3" over "18s 9s").
local U = dofile("Tools/regression/unitframes_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")
local D = dofile("Tools/regression/databars_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local W = U.W
local SIGIL_TILE, TIMER_MIN = 28, 10
local LINE = 1.2

local OFFSET = {
	TOPLEFT = { 0, 0 }, TOP = { 0.5, 0 }, TOPRIGHT = { 1, 0 },
	LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 1 }, BOTTOM = { 0.5, 1 }, BOTTOMRIGHT = { 1, 1 },
}

local function intersects(a, b)
	return a[1] < b[1] + b[3] and b[1] < a[1] + a[3] and a[2] < b[2] + b[4] and b[2] < a[2] + a[4]
end

local function fmt(r)
	return string.format("(%.1f,%.1f %.1fx%.1f)", r[1], r[2], r[3], r[4])
end

-- The rect a one-point font string draws: its measured text at its font's line height, placed by its anchor.
local function TextBox(env, text)
	local point, relative, relPoint, x, y = text:GetPoint(1)
	local r = { Scene.Rect(env, relative) }
	assert(r[1], "the text's anchor resolves")
	local _, size = text:GetFont()
	local w = text:GetUnboundedStringWidth()
	local h = size * LINE
	local from, to = OFFSET[point], OFFSET[relPoint]
	local px, py = r[1] + to[1] * r[3] + (x or 0), r[2] + to[2] * r[4] - (y or 0)
	return { px - from[1] * w, py - from[2] * h, w, h }, size
end

-- The badge plate drawn under a text: a shown texture beside it that hangs from the text itself.
local function badgeOf(text)
	for _, region in ipairs(W.Regions(text:GetParent(), "Texture")) do
		local p, rel = region:GetPoint(1)
		if rel == text and p == "TOPLEFT" and region:IsShown() then
			return region
		end
	end
	return nil
end

-- Unit frames: target (the sigil), focus and boss tiles ------------------------------------------------------------
do
	local env, K, ns = U.New()
	env._textWidth = D.TextWidth
	assert(ns.Settings.defaults.target.auraSize >= SIGIL_TILE, "the sigil's tiles default to at least " .. SIGIL_TILE .. " units, not " .. ns.Settings.defaults.target.auraSize)
	local fonts = ns.Settings.defaults.target.fonts.aura
	assert(fonts.outline ~= "NONE", "the tile text is outlined by default")
	U.SetUnit(env, "target", { name = "Bloodtalon Matriarch", level = 38, health = 620, healthMax = 1000, reaction = 2, canAttack = true })
	env.FireEvent("PLAYER_TARGET_CHANGED")
	U.SetUnit(env, "focus", { name = "Elunara", level = 39, health = 300, healthMax = 400, reaction = 2, canAttack = true })
	env.FireEvent("PLAYER_FOCUS_CHANGED")
	U.SetUnit(env, "boss1", { name = "Magmatus", level = -1, classification = "worldboss", health = 50, healthMax = 100, reaction = 2, canAttack = true })
	env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	env.RunTimers()
	for _, kind in ipairs({ "target", "focus", "boss" }) do
		local view = ns.Frames.Get(kind).views[1]
		local entry = view.auras.buttons[1]
		assert(entry, kind .. " has aura buttons")
		entry.button:ClearAllPoints()
		entry.button:SetPoint("CENTER", env.UIParent, "CENTER")
		entry.count:SetText("3")
		entry.timer:SetText("18s")
		local tile = { Scene.Rect(env, entry.skin) }
		local count = TextBox(env, entry.count)
		local timer, timerSize = TextBox(env, entry.timer)
		assert(not intersects(count, timer), string.format("%s: the stack count %s and the timer %s overlap on a %d-unit tile", kind, fmt(count), fmt(timer), tile[3]))
		assert(badgeOf(entry.count), kind .. ": the stack count sits on its own badge")
		assert(count[2] <= tile[2] + 1 and count[1] + count[3] >= tile[1] + tile[3] - 1, kind .. ": the count sits in the tile's top-right corner, on its rim")
		if kind == "target" then
			assert(tile[3] >= SIGIL_TILE - 0.5, "the sigil's tile is " .. tile[3] .. " units")
			assert(timerSize >= TIMER_MIN, "the sigil's timer is at least " .. TIMER_MIN .. " units, not " .. timerSize)
			local _, _, flags = entry.timer:GetFont()
			assert(flags ~= "", "the sigil's timer is outlined")
		end
	end
	-- A full row of 28-unit tiles stays within the sigil's health bar.
	local d = ns.Settings.defaults.target
	local line = ns.Auras.Footprint("target")
	local bar = ns.Frames.Get("target").views[1].geometry.health.w
	assert(line <= bar, "a row of " .. d.auraColumns .. " tiles stays within the " .. bar .. "-unit health bar: " .. line)
	assert(#env._errors == 0, tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, "KstyleUI caught no errors")
end

-- Nameplates ------------------------------------------------------------------------------------------------------
do
	local env, K, ns = N.New()
	env._textWidth = D.TextWidth
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	local button = plate.auras._groups.debuffs.frames[1]
	button:ClearAllPoints()
	button:SetPoint("CENTER", env.UIParent, "CENTER")
	local parts = button._aura
	parts.count:SetText("3")
	parts.timer:SetText("18s")
	local tile = { Scene.Rect(env, button) }
	local count = TextBox(env, parts.count)
	local timer = TextBox(env, parts.timer)
	assert(not intersects(count, timer), string.format("a plate's stack count %s and timer %s overlap on a %d-unit tile", fmt(count), fmt(timer), tile[3]))
	assert(timer[2] + timer[4] >= tile[2] + tile[4] - 1, "the plate's timer owns the tile's bottom edge")
	assert(badgeOf(parts.count), "the plate's stack count sits on its own badge")
	assert(#env._errors == 0, tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, "KstyleUI caught no errors")
end

print("aura tile text ok")
