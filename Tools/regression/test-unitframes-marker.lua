-- test-unitframes-marker.lua: a raid marker never covers its unit's name, on every frame kind in both styles, for short and long names (round 4: Opus #2, the skull centred on the sigil's "FROST HOWLER").
local U = dofile("Tools/regression/unitframes_env.lua")
local D = dofile("Tools/regression/databars_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local TOKENS = { player = "player", target = "target", targettarget = "targettarget", focus = "focus", focustarget = "focustarget", pet = "pet", boss = "boss1" }
local NAMES = { "Wolf", "Bloodtalon Matriarch", "Elunara Frostweaver the Everlasting" }

local function intersects(a, b)
	return a[1] < b[1] + b[3] - 0.01 and b[1] < a[1] + a[3] - 0.01 and a[2] < b[2] + b[4] - 0.01 and b[2] < a[2] + a[4] - 0.01
end

local function justify(text)
	local last = text._calls
	for i = #last, 1, -1 do
		if last[i].method == "SetJustifyH" then
			return last[i].args[1]
		end
	end
	return "LEFT"
end

-- The rect the name's glyphs cover: its region, narrowed to the measured text by its justification.
local function inked(env, text)
	local r = { Scene.Rect(env, text) }
	assert(r[1], "the name resolves")
	local w = text:GetUnboundedStringWidth()
	if type(w) ~= "number" or r[3] <= 0 then
		return r
	end
	w = math.min(w, r[3])
	local side = justify(text)
	local x = r[1]
	if side == "CENTER" then
		x = r[1] + (r[3] - w) / 2
	elseif side == "RIGHT" then
		x = r[1] + r[3] - w
	end
	return { x, r[2], w, r[4] }
end

local function unit(name)
	return { name = name, level = 61, health = 50, healthMax = 200, power = 10, powerMax = 100, reaction = 2, canAttack = true, marker = 8, classification = "elite" }
end

local function Check(style)
	local env, K, ns = U.New({ plate = style == "plate" })
	env._textWidth = D.TextWidth
	for _, name in ipairs(NAMES) do
		for _, token in pairs(TOKENS) do
			U.SetUnit(env, token, unit(name))
		end
		env._units.player.marker = 8
		env.FireEvent("PLAYER_ENTERING_WORLD")
		env.FireEvent("RAID_TARGET_UPDATE")
		for kind in pairs(TOKENS) do
			local view = ns.Frames.Get(kind).views[1]
			local where = style .. " " .. kind .. " '" .. name .. "'"
			assert(view.marker:IsShown(), where .. ": the marker shows")
			if view.name:IsShown() then
				local m = { Scene.Rect(env, view.marker) }
				local n = inked(env, view.name)
				assert(m[1], where .. ": the marker resolves")
				assert(not intersects(m, n), string.format("%s: the marker (%.1f,%.1f %.1fx%.1f) covers the name (%.1f,%.1f %.1fx%.1f)", where, m[1], m[2], m[3], m[4], n[1], n[2], n[3], n[4]))
			end
		end
	end
	-- With no marker set, the name takes its whole lane back.
	for _, token in pairs(TOKENS) do
		env._units[token].marker = nil
	end
	env.FireEvent("RAID_TARGET_UPDATE")
	local target = ns.Frames.Get("target").views[1]
	local lane = target.geometry.name
	local _, _, w = Scene.Rect(env, target.name)
	assert(math.abs(w - lane.w) < 1, style .. ": a target with no marker keeps its whole name lane: " .. w .. " of " .. lane.w)
	assert(#env._errors == 0, tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, "KstyleUI caught no errors")
end

Check("lumen")
Check("plate")

-- The sigil's marker sits beside the name, not out at the lane's end.
do
	local env, _, ns = U.New()
	env._textWidth = D.TextWidth
	U.SetUnit(env, "target", unit("Frost Howler"))
	env.SetTarget(true)
	local view = ns.Frames.Get("target").views[1]
	local m = { Scene.Rect(env, view.marker) }
	local n = inked(env, view.name)
	local gap = n[1] - (m[1] + m[3])
	assert(gap >= 0 and gap <= 8, "the sigil's skull sits just left of the name: gap " .. gap)
	assert(math.abs((m[2] + m[4] / 2) - (n[2] + n[4] / 2)) <= 1, "level with the name")
end

-- A marker that arrives after the name narrows the lane, and the name fits itself to the narrower lane at once:
-- it drops to the body face before it truncates (codex review of round 4).
do
	local env, _, ns = U.New()
	env._textWidth = D.TextWidth
	U.SetUnit(env, "pet", { name = "Snow Wolf", level = 38, health = 300, healthMax = 400, reaction = 5 })
	env.FireEvent("UNIT_PET", "player")
	local pet = ns.Frames.Get("pet").views[1]
	assert(not pet.name:IsTruncated(), "the pet's name fits its lane")
	env._units.pet.marker = 8
	env.FireEvent("RAID_TARGET_UPDATE")
	assert(pet.marker:IsShown(), "the pet's marker shows")
	assert(not pet.name:IsTruncated(), "the narrower lane still shows the whole name: " .. tostring(pet.name:GetUnboundedStringWidth()) .. " in " .. tostring(pet.name:GetWidth()))
	env._units.pet.marker = nil
	env.FireEvent("RAID_TARGET_UPDATE")
	assert(U.Shown(env, pet.name):upper():gsub("[^%u ]", "") == "SNOW WOLF", "the cleared marker gives the name its lane back")
end

print("unitframes marker ok")
