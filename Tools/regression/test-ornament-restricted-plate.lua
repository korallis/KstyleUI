-- test-ornament-restricted-plate.lua: a plate on a nameplate the game restricts for measurement draws the same Full trim as a plate on a free base, from KstyleUI's recorded layout and with no edge read, through a target change, a cast and a setting change; a secret IsAnchoringRestricted answer counts as restricted, and Off draws nothing.
local N = dofile("Tools/regression/nameplates_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local MEASURE = "Action[FrameMeasurement] failed because[Can't measure restricted regions]"
local UNIT = { name = "Bloodtalon Matriarch", health = 29800, maxHealth = 48000, level = 40, classification = "elite", reaction = 2, canAttack = true }

local env, K, ns = N.New({ width = 1920, height = 1080, uiScale = 768 / 1080 })
env._textWidth = function(text, fontPath, size)
	return Scene.TextWidth(Scene.PlainText(text), size, fontPath)
end
local widgets = K.Store.Module("Widgets")
widgets.cardMaterial, widgets.ornaments = "ForgedBrackets", "Full"
env.WorldFrame:SetPoint("TOPLEFT")
env.WorldFrame:SetPoint("BOTTOMRIGHT")
env._time = 10

local function base(x, y, free)
	local frame = N.Base(env, { free = free })
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", env.WorldFrame, "BOTTOMLEFT", x, y)
	return frame
end

local function errors(label)
	assert(#env._errors == 0 and K.ErrorCount() == 0, label .. ": no error, got " .. tostring(env._errors[1]))
end

local function settle()
	for _ = 1, 20 do N.Tick(env, 0.05) end
	env.RunTimers()
	Scene.Build(env)
	for _, token in ipairs({ "nameplate1", "nameplate2" }) do ns.Plates.Get(token).ornament:Restyle() end
end

local free, locked = base(300, 700, true), base(800, 700)
N.Add(env, "nameplate1", UNIT, { base = free })
N.Add(env, "nameplate2", UNIT, { base = locked })
errors("plates added")
local open, shut = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
assert(open and shut, "both units get a plate")
N.Align(env, free, open.health)
assert(shut.health:IsAnchoringRestricted() == true, "a plate's health bar on a restricted nameplate is restricted, as anchors carry the restriction")
assert(open.health:IsAnchoringRestricted() == false, "a plate on a free base is not restricted")
local ok, err = pcall(shut.health.GetLeft, shut.health)
assert(not ok and err == "StatusBar:GetLeft(): " .. MEASURE .. ": attempted from: StatusBar:GetLeft().",
	"the stub raises the game's error when a restricted region is measured, got " .. tostring(err))

local function pieces(plate)
	local list = {}
	for _, texture in ipairs(plate.ornament.textures) do
		if texture:IsShown() then
			local p = texture._points[1]
			list[#list + 1] = { name = tostring(texture:GetTexture()), x = p[4], y = p[5], w = texture._width, h = texture._height }
		end
	end
	table.sort(list, function(a, b)
		if a.name ~= b.name then return a.name < b.name end
		if a.x ~= b.x then return a.x < b.x end
		return a.y < b.y
	end)
	return list
end

local function same(label)
	local a, b = pieces(open), pieces(shut)
	assert(#a > 0, label .. ": the free plate draws its Full trim")
	assert(#a == #b, label .. ": the restricted plate draws " .. #b .. " pieces, the free plate " .. #a)
	local unit = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(shut.health)
	for i = 1, #a do
		assert(a[i].name == b[i].name, label .. ": piece " .. i .. " is " .. a[i].name .. " on the free plate, " .. b[i].name .. " on the restricted one")
		for _, key in ipairs({ "x", "y", "w", "h" }) do
			assert(math.abs(a[i][key] - b[i][key]) <= unit + 1e-6, string.format("%s: %s %s is %.3f on the free plate, %.3f on the restricted one", label, a[i].name, key, a[i][key], b[i][key]))
		end
	end
	return #a
end

settle()
errors("settled")
local drawn = same("idle")
assert(drawn >= 4, "a Full elite plate draws rails and both ends, got " .. drawn .. " pieces")

N.Target(env, "nameplate2")
N.Target(env, "nameplate1")
N.Target(env, nil)
local cast = { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false }
N.Cast(env, "nameplate1", cast)
N.Cast(env, "nameplate2", cast)
settle()
K.Callbacks.Fire("SettingChanged", "Widgets", "ornaments")
settle()
errors("target, cast and a setting change")
same("casting")

local ask = shut.health.IsAnchoringRestricted
shut.health.IsAnchoringRestricted = function()
	return env.Secret(true)
end
shut.ornament:Restyle()
errors("a secret answer")
same("a secret IsAnchoringRestricted answer")
shut.health.IsAnchoringRestricted = ask

widgets.ornaments = "Off"
K.Callbacks.Fire("SettingChanged", "Widgets", "ornaments")
settle()
errors("Off")
assert(#pieces(open) == 0 and #pieces(shut) == 0, "Off draws nothing on either plate")

print(string.format("ok a plate on a restricted nameplate draws the same %d Full pieces as a free plate, from its recorded layout, with no error", drawn))
