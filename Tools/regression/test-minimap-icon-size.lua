-- test-minimap-icon-size.lua: native map pins, tracking and drawer icons retain readable sizes on every screen.
local M = dofile("Tools/regression/minimap_env.lua")
local W = M.W
local G = dofile("Tools/regression/geometry.lua")

for index, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local lib, pin, native
	local env, K, ns = M.New({ enabled = true, width = screen[1], height = screen[2], size = 0.6,
		settings = index % 2 == 0 and { compactIcons = true } or nil, setup = function(e)
		native = e.Minimap:GetEffectiveScale()
		lib = M.FakeLibDBIcon(e)
		local button = lib:Add("Questie")
		button.icon:SetSize(17, 17)
		button.icon:SetPoint("CENTER", button, "CENTER")
		local large = lib:Add("Wide")
		large:SetSize(40, 32)
		large:SetScale(1.25)
		pin = e.CreateFrame("Frame", nil, e.Minimap)
		pin:SetSize(12, 12)
		pin:SetPoint("CENTER", e.Minimap, "CENTER", 20, 10)
	end })
	M.Settle(env)
	assert(K.Options.Default("Minimap", "compactIcons") == false, "compact map icons must default to off")
	K.Options.Write("Minimap", "compactIcons", false)
	M.Settle(env)
	local button, tracking = lib.objects.Questie, ns.Map.column.buttons.tracking
	local function Readable()
		assert(pin:GetEffectiveScale() >= native - 1e-6, "minimap pins must retain Blizzard's scale after reparenting")
		assert(button:GetWidth() * button:GetEffectiveScale() >= 31 * native - 1e-6, "drawer buttons must retain their full native size")
		assert(button.icon:GetWidth() * button:GetEffectiveScale() >= 17 * native - 1e-6, "drawer artwork must retain at least its native size")
		assert(button.icon:GetWidth() < button:GetWidth(), "drawer icons must keep the inset tile style")
		local large = lib.objects.Wide
		assert(large:GetWidth() * large:GetEffectiveScale() >= 50 * native - 1e-6, "larger addon buttons retain their native scale and full size")
		local panel = assert(G.ScaledRect(ns.Map.drawer.panel, env.UIParent, K.Scale.Root()))
		for _, item in pairs(lib.objects) do
			local rect = assert(G.ScaledRect(item, env.UIParent, K.Scale.Root()))
			assert(rect.left >= panel.left - 1e-6 and rect.right <= panel.right + 1e-6, "scaled addon buttons must stay inside the drawer")
		end
		assert(tracking:GetWidth() * tracking:GetEffectiveScale() >= 23 * native - 1e-6, "tracking discs must be at least Blizzard's 23-unit size")
		assert(tracking:GetWidth() * tracking:GetEffectiveScale() < 23 * native + 2 * K.Scale.Pixel(1), "tracking discs must not enlarge the native button to glyph size")
		local map, area = env.Minimap, ns.Map.face.mapArea
		assert(W.Near(map:GetWidth() * map:GetEffectiveScale(), area:GetWidth() * area:GetEffectiveScale()), "preserving icon scale must still fit terrain to the map card")
	end
	Readable()
	for _, control in ipairs({ { "column.size", tracking.icon }, { "drawer.size", button.icon } }) do
		local width = control[2]:GetWidth()
		for _, row in ipairs(ns.Settings.schema) do
			if row.key == control[1] then K.Options.Write("Minimap", control[1], row.max) end
		end
		assert(control[2]:GetWidth() > width, "raise minimap icon size slider maxima above the native-size floor so icons can still be enlarged")
		K.Options.Write("Minimap", control[1], K.Options.Default("Minimap", control[1]))
	end
	local getScale = button.GetScale
	button.GetScale = function() return env.Secret(1) end
	assert(pcall(ns.Map.drawer.Place, ns.Map.drawer, button), "a secret addon-button scale must not be used in arithmetic")
	button.GetScale = getScale
	env.Minimap.IsProtected = function() return true end
	env._combat = true
	local previousScale = env.Minimap:GetScale()
	K.Options.Write("Minimap", "compactIcons", true)
	assert(env.Minimap:GetScale() == previousScale, "protected minimap scaling waits for combat to end")
	env._combat = false
	env.FireEvent("PLAYER_REGEN_ENABLED")
	M.Settle(env)
	local compactSize = K.Widgets.Snap(button, 24)
	assert(W.Near(button:GetWidth(), compactSize) and W.Near(button.icon:GetWidth(), K.Widgets.Snap(button.icon, compactSize * 0.72)), "compact icons restores the previous drawer")
	assert(W.Near(tracking:GetWidth(), K.Widgets.Snap(tracking, 19.5)), "compact icons restores the previous column")
	assert(env.Minimap:GetScale() == 1, "compact icons restores inherited minimap pin scale")
	K.Options.Write("Minimap", "compactIcons", false)
	M.Settle(env)
	Readable()
	K.Options.Write("Appearance", "uiScale", 1.5)
	M.Settle(env)
	Readable()
	K.Modules.Disable("Minimap")
	M.Settle(env)
	assert(env.Minimap:GetScale() == 1 and env.Minimap:GetWidth() == 198, "disabling restores Blizzard's minimap scale and size")
	assert(button:GetWidth() == 31 and button.icon:GetWidth() == 17, "disabling restores the addon's button and icon sizes")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	for _, size in ipairs({ 0.6, "auto" }) do
		local env, K, ns = M.New({ enabled = true, width = screen[1], height = screen[2], uiScale = 768 / 1080, size = size, setup = function(e)
			local lib = M.FakeLibDBIcon(e)
			for index = 1, 6 do lib:Add("Addon" .. index) end
		end })
		M.Settle(env)
		local function Rect(frame) return assert(G.ScaledRect(frame, env.UIParent, K.Scale.Root())) end
		for _, side in ipairs({ "left", "right" }) do
			K.Options.Write("Minimap", "column.side", side)
			for _, direction in ipairs({ "auto", "left", "right", "up", "down" }) do
				K.Options.Write("Minimap", "drawer.direction", direction)
				local panel, card = Rect(ns.Map.drawer.panel), Rect(ns.Map.face.card)
				for _, button in pairs(ns.Map.column.buttons) do
					if button:IsShown() then
						local rect = Rect(button)
						assert(rect.left >= card.left and rect.right <= card.right and rect.top <= card.top and rect.bottom >= card.bottom,
							"keep native-size side buttons inside the minimap card")
					end
				end
				assert(panel.left >= card.left and panel.right <= card.right and panel.top <= card.top and panel.bottom >= card.bottom,
					"wrap full-size drawer buttons inside the minimap card at every screen size and direction")
			end
		end
	end
end

print("minimap icon size ok (1080p, 1440p, ultrawide, 4K)")
