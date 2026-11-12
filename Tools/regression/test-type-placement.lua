local M = dofile("Tools/regression/minimap_env.lua")
local A = dofile("Tools/regression/auras_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")

local screens = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 },
	{ 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 },
}

local function snapped(K, text, label)
	local _, size = text:GetFont()
	local pixels = size * K.Widgets.ScaleFactor(text) / K.Scale.Pixel(1)
	assert(math.abs(pixels - math.floor(pixels + 0.5)) < 1e-6, label .. ": the text size is on whole pixels")
end

for _, screen in ipairs(screens) do
	local label = screen[1] .. "x" .. screen[2]
	local env, K, ns = M.New({ enabled = true, setup = function(e)
		e.GetPhysicalScreenSize = function()
			return screen[1], screen[2]
		end
	end })
	assert(math.abs(K.Scale.Pixel(1) - 1080 / (screen[2] * K.Scale.AppliedUserScale())) < 1e-6, label .. ": the minimap harness uses the requested physical height")
	for _, preset in ipairs({ "DPS", "Tank", "Healer" }) do
		local map = K.Setup.Layouts.Get(preset)["minimap.main"]
		assert(map.x == -16 and map.y == -38, label .. ": " .. preset .. " uses the corrected map inset under the zone heading")
	end
	snapped(K, ns.Map.face.zone, label .. " zone")
	snapped(K, ns.Map.face.coords, label .. " coordinates")
	snapped(K, ns.Map.face.clock, label .. " clock")
	assert(#env._errors == 0, tostring(env._errors[1]))

	local ae, AK, an = A.New({ width = screen[1], height = screen[2] })
	AK.Modules.Enable("Auras")
	ae.RunTimers()
	local entry = an.Panel.Group("buffs").buttons[1]
	local _, _, _, x, y = entry.timer:GetPoint(1)
	assert(x == 0 and math.abs(y + AK.Widgets.Snap(entry.skin, 2.5)) < 1e-6, label .. ": the timer stays centred and lifted on whole pixels")
	assert(entry.timer:GetFont() == (AK.Tokens.Font("timer")), label .. ": the default timer uses Medium")
	snapped(AK, entry.timer, label .. " timer")
	local custom = AK.Tokens.FontPath("InterSemiBold")
	AK.Options.Write("Auras", "timer.font", custom)
	assert(entry.timer:GetFont() == custom, label .. ": the player's saved timer font wins")
	assert(#ae._errors == 0, tostring(ae._errors[1]))

	local ne, NK, nn = N.New({ width = screen[1], height = screen[2] })
	N.Add(ne, "nameplate1", { name = "Shadowgale Poacher" })
	local plate = nn.Plates.Get("nameplate1")
	local _, _, _, _, lift = plate.name:GetPoint(1)
	assert(math.abs(lift - NK.Widgets.Snap(plate, 3.5)) < 1e-6, label .. ": the plate name keeps its core-matched lift, snapped")
	assert(nn.Settings.Get("name.size") == 12, label .. ": the core-matched name size stays unchanged")
	snapped(NK, plate.name, label .. " plate name")
	assert(#ne._errors == 0, tostring(ne._errors[1]))

	local ue, UK, un = U.New({ width = screen[1], height = screen[2] })
	U.SetUnit(ue, "target", { name = "Shadowgale Poacher", creature = "Humanoid", canAttack = true })
	ue.SetTarget(true)
	local target = un.Frames.Get("target").views[1]
	local _, _, _, captionX = target.caption:GetPoint(1)
	assert(math.abs(captionX + UK.Widgets.Snap(target.parent, 9)) < 1e-6, label .. ": the target caption gap is snapped")
	assert(un.Settings.FontSize("target", "level") == 14.5, label .. ": the default creature caption fits the core")
	snapped(UK, target.name, label .. " target name")
	snapped(UK, target.caption, label .. " target caption")
	UK.Options.Write("UnitFrames", "target.fonts.level.size", 18)
	assert(un.Settings.FontSize("target", "level") == 18, label .. ": the player's target caption size wins")
	UK.Options.Write("UnitFrames", "target.fonts.name.font", UK.Tokens.FontPath("InterSemiBold"))
	assert(target.name:GetFont() == UK.Tokens.FontPath("InterSemiBold"), label .. ": the player's target name font wins")
	assert(#ue._errors == 0, tostring(ue._errors[1]))
end

print("type placement ok: 9 screens")
