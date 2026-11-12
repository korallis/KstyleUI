-- test-ornament-restricted-plate.lua: a plate on a nameplate the game restricts for measurement builds, follows its unit, target and cast, and draws no ornament, with no error, while a plate on a free nameplate keeps its Full ornament; the restricted plate ornaments again once the restriction lifts, and Off draws nothing on either.
local N = dofile("Tools/regression/nameplates_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local MEASURE = "Action[FrameMeasurement] failed because[Can't measure restricted regions]"

local env, K, ns = N.New({ width = 1920, height = 1080, uiScale = 768 / 1080, size = "default" })
env._textWidth = function(text, fontPath, size)
	return Scene.TextWidth(Scene.PlainText(text), size, fontPath)
end
local widgets = K.Store.Module("Widgets")
widgets.cardMaterial, widgets.ornaments = "ForgedBrackets", "Full"
env.WorldFrame:SetPoint("TOPLEFT")
env.WorldFrame:SetPoint("BOTTOMRIGHT")
env._time = 10

local k = 768 / 1080
local function base(x, y)
	local frame = N.Base(env)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", env.WorldFrame, "BOTTOMLEFT", x * k, (1080 - y) * k)
	return frame
end

local free, locked = base(300, 220), base(760, 220)
env.RestrictAnchoring(locked)
N.Add(env, "nameplate1", { name = "Riverglade Snapper", health = 1420, maxHealth = 1540, level = 37 }, { base = free })
N.Add(env, "nameplate2", { name = "Bloodtalon Matriarch", health = 29800, maxHealth = 48000, level = 40, classification = "elite" }, { base = locked })

assert(#env._errors == 0 and K.ErrorCount() == 0, "a plate builds on a restricted nameplate with no error, got " .. tostring(env._errors[1]))
local open, shut = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
assert(open and shut, "both units get a plate")
assert(shut.health:IsAnchoringRestricted() == true, "a plate's health bar on a restricted nameplate is restricted, as anchors carry the restriction")
assert(open.health:IsAnchoringRestricted() == false, "a plate on a free nameplate is not restricted")
local ok, err = pcall(shut.health.GetLeft, shut.health)
assert(not ok and err == "StatusBar:GetLeft(): " .. MEASURE .. ": attempted from: StatusBar:GetLeft().",
	"the stub raises the game's error when a restricted region is measured, got " .. tostring(err))
assert(type(shut.health:GetWidth()) == "number", "a restricted bar still answers its width, as the game's did in the owner's session")

local function shown(plate)
	local count = 0
	for _, texture in ipairs(plate.ornament.textures) do
		if texture:IsShown() then count = count + 1 end
	end
	return count
end

local function settle()
	for _ = 1, 20 do N.Tick(env, 0.05) end
	env.RunTimers()
end

local function errors(label)
	assert(#env._errors == 0 and K.ErrorCount() == 0, label .. ": no error, got " .. tostring(env._errors[1]))
end

settle()
errors("plates added")
assert(shut.health:IsShown(), "the restricted plate still shows its health bar")
assert(shown(open) > 0, "a plate on a free nameplate draws its Full ornament")
assert(shown(shut) == 0, "a plate on a restricted nameplate draws no ornament")

N.Target(env, "nameplate2")
N.Cast(env, "nameplate2", { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false })
settle()
K.Callbacks.Fire("SettingChanged", "Widgets", "ornaments")
settle()
errors("target, cast and a setting change")
assert(shown(shut) == 0, "a cast, a target change and a setting change on a restricted plate draw no ornament")
assert(shown(open) > 0, "the free plate keeps its ornament through the restricted plate's restyles")

env.RestrictAnchoring(locked, false)
shut:Restyle()
settle()
errors("restriction lifted")
assert(shown(shut) > 0, "once the restriction lifts the plate ornaments again")

env.RestrictAnchoring(locked)
widgets.ornaments = "Off"
K.Callbacks.Fire("SettingChanged", "Widgets", "ornaments")
settle()
errors("Off")
assert(shown(open) == 0 and shown(shut) == 0, "Off draws nothing on either plate")

print("ok a plate on a restricted nameplate builds and drops its ornament with no error, and ornaments again once free")
