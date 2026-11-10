local M = dofile("Tools/regression/minimap_env.lua")
local A = dofile("Tools/regression/auras_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")

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
		e._physical = screen
	end })
	for _, preset in ipairs({ "DPS", "Tank", "Healer" }) do
		local map = K.Setup.Layouts.Get(preset)["minimap.main"]
		assert(map.x == -16 and map.y == -16, label .. ": " .. preset .. " uses the corrected map inset")
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
	assert(math.abs(lift - NK.Widgets.Snap(plate, 4)) < 1e-6, label .. ": the plate name's lift is snapped")
	assert(nn.Settings.Get("name.size") == 12, label .. ": the core-matched name size stays unchanged")
	snapped(NK, plate.name, label .. " plate name")
	assert(#ne._errors == 0, tostring(ne._errors[1]))
end

print("type placement ok: 9 screens")
