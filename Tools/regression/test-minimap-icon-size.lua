-- test-minimap-icon-size.lua: native map pins, tracking and drawer icons retain readable sizes on every screen.
local M = dofile("Tools/regression/minimap_env.lua")
local W = M.W

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local lib, pin, native
	local env, K, ns = M.New({ enabled = true, width = screen[1], height = screen[2], size = 0.6, setup = function(e)
		native = e.Minimap:GetEffectiveScale()
		lib = M.FakeLibDBIcon(e)
		local button = lib:Add("Questie")
		button.icon:SetSize(17, 17)
		button.icon:SetPoint("CENTER", button, "CENTER")
		pin = e.CreateFrame("Frame", nil, e.Minimap)
		pin:SetSize(12, 12)
		pin:SetPoint("CENTER", e.Minimap, "CENTER", 20, 10)
	end })
	M.Settle(env)
	local button, tracking = lib.objects.Questie, ns.Map.column.buttons.tracking
	local function Readable()
		assert(pin:GetEffectiveScale() >= native - 1e-6, "minimap pins must retain Blizzard's scale after reparenting")
		assert(button:GetWidth() * button:GetEffectiveScale() >= 31 * native - 1e-6, "drawer buttons must retain their full native size")
		assert(button.icon:GetWidth() >= button:GetWidth() - 1e-6, "drawer artwork fills its tile instead of being squeezed to 72 percent")
		assert(tracking.icon:GetWidth() * tracking:GetEffectiveScale() >= 17 * native - 1e-6, "tracking artwork must be at least Blizzard's 17-unit size")
		local map, area = env.Minimap, ns.Map.face.mapArea
		assert(W.Near(map:GetWidth() * map:GetEffectiveScale(), area:GetWidth() * area:GetEffectiveScale()), "preserving icon scale must still fit terrain to the map card")
	end
	Readable()
	K.Options.Write("Minimap", "compactIcons", true)
	M.Settle(env)
	assert(W.Near(button:GetWidth(), 24) and W.Near(button.icon:GetWidth(), K.Widgets.Snap(button.icon, 24 * 0.72)), "compact icons restores the previous drawer")
	assert(W.Near(tracking:GetWidth(), K.Widgets.Snap(tracking, 19.5)), "compact icons restores the previous column")
	assert(env.Minimap:GetScale() == 1, "compact icons restores inherited minimap pin scale")
	K.Options.Write("Minimap", "compactIcons", false)
	M.Settle(env)
	Readable()
	K.Options.Write("Appearance", "size", 1.5)
	M.Settle(env)
	Readable()
	K.Modules.Disable("Minimap")
	M.Settle(env)
	assert(env.Minimap:GetScale() == 1 and env.Minimap:GetWidth() == 198, "disabling restores Blizzard's minimap scale and size")
	assert(button:GetWidth() == 31 and button.icon:GetWidth() == 17, "disabling restores the addon's button and icon sizes")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

print("minimap icon size ok (1080p, 1440p, ultrawide, 4K)")
