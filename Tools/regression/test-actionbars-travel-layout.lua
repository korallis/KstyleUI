-- test-actionbars-travel-layout.lua: both travel fixtures remain on screen, above both casts and clear of every live unit frame at the owner's four screen sizes.
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = dofile("Tools/render/scene.lua")

local function Overlap(a, b)
	return a[1] < b[1] + b[3] - 1 and b[1] < a[1] + a[3] - 1 and a[2] < b[2] + b[4] - 1 and b[2] < a[2] + a[4] - 1
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], size = "auto" })
	rawset(_G, "RENDER_HUD_STYLE", "Medallions")
	for _, mode in ipairs({ "mage", "simple" }) do
		rawset(_G, "RENDER_TRAVEL", mode)
		local class = mode == "mage" and "MAGE" or "WARRIOR"
		local opts = { class = class, layout = "DPS", applyPreset = true }
		local bars, ns = Hud.Module("actionbars", opts)
		local env = Hud.envs[bars]
		local menu = ns.Travel.menu
		assert(menu:IsShown(), "render the open flyout")
		local rect = { Scene.Rect(env, menu) }
		local what = mode .. " at " .. screen[1] .. "x" .. screen[2]
		assert(rect[1] >= 0 and rect[2] >= 0 and rect[1] + rect[3] <= 1080 * screen[1] / screen[2] and rect[2] + rect[4] <= 1080, what .. ": menu must stay on screen")
		local units = Hud.Module("unitframes", opts)
		local unitEnv = Hud.envs[units]
		for _, key in ipairs({ "player", "target", "pet", "focus", "targettarget", "focustarget", "boss", "castbar.player", "castbar.target" }) do
			local element = unitEnv.KstyleUI.Layout.Element("unitframes." .. key)
			local frame = element and element.frame
			if frame and frame:IsVisible() then
				local other = { Scene.Rect(unitEnv, frame) }
				assert(other[1] and not Overlap(rect, other), what .. ": travel overlaps " .. key .. ": menu " .. table.concat(rect, ",") .. "; unit " .. table.concat(other, ","))
			end
		end
		assert(#env._errors == 0 and #unitEnv._errors == 0, what .. ": clean fixture environments")
	end
end
rawset(_G, "RENDER_SCREEN", nil)
rawset(_G, "RENDER_HUD_STYLE", nil)
rawset(_G, "RENDER_TRAVEL", nil)
print("ok crest travel layout at all four screen sizes")
