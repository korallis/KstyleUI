-- gallery_minimap.lua: KstyleUI_Minimap's drawer and preview, each cropped as one frame of the gallery: the addon
-- drawer open beside the button column with six adopted LibDBIcon buttons on button tiles, and the settings
-- window's live preview with its drawn map. The minimap face, column and footer are the HUD scene's frames.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local I = Hud.ICONS

-- The addon buttons the drawer collects, by name, with an icon each as LibDBIcon paints the addon's icon.
local ADDONS = {
	{ "Bagnon", I.sunderArmor },
	{ "Details", I.whirlwind },
	{ "Questie", I.charge },
	{ "RestedXP", I.battleShout },
	{ "WeakAuras", I.bloodrage },
	{ "Pawn", I.shieldBlock },
}
local LIB_ICON = 17

return Common.Run(function()
	local M = dofile("Tools/regression/minimap_env.lua")
	local lib
	local env, K, ns = M.New({
		enabled = true,
		zone = "Riverglades",
		setup = function(env)
			Gallery.Setup(env)
			env._clock = { hour = 14, minute = 32, realmHour = 9, realmMinute = 5 }
			lib = M.FakeLibDBIcon(env)
			for _, addon in ipairs(ADDONS) do
				local button = lib:Add(addon[1])
				-- LibDBIcon draws the addon's icon 17 units square in the button's middle.
				button.icon:SetTexture(addon[2])
				button.icon:SetSize(LIB_ICON, LIB_ICON)
				button.icon:SetPoint("CENTER", button, "CENTER")
			end
		end,
	})
	M.Settle(env)
	local drawer = ns.Map.drawer
	local toggle = ns.Map.column.buttons.drawer
	assert(drawer and toggle:IsShown(), "the column ends with the drawer button")
	-- The map's terrain: the mockup's crop when standins.py has made it, a flat tone otherwise, clipped by the mask
	-- the module set on the Minimap frame, as the game clips it.
	local _, note = Hud.Terrain(env)
	-- Open the drawer with a click, as the player does.
	M.W.Click(toggle)
	M.Settle(env)
	assert(drawer.panel:IsShown(), "the drawer is open")

	-- The preview on a plain frame the size of the minimap element, as the settings window shows it.
	local element = K.Setup.Layouts.Element("minimap.main")
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(element.width + 40, element.height + 40)
	parent:SetPoint("TOPLEFT", K.Scale.Root(), "TOPLEFT", 80, -80)
	local preview = K.Options.Preview("Minimap")(parent)
	preview:Refresh()
	M.Settle(env)

	local frames = Gallery.Frames()
	frames:Add(env, drawer.panel, {
		name = "minimap_drawer", title = "Addon drawer", grade = "panel", reference = "minimap",
		caption = "Drawer.lua open beside the button column: a panel-grade glass (Drawer.lua:145) with the accent edge, holding six LibDBIcon buttons the module adopted, each stripped to its icon on a buttonFill tile (Drawer.lua:296).",
		match = "Glass fill, two-line edge, 8-unit chamfer and drop shadow as the mockup's minimap frame, with the edge in the class colour as the frame's line is; the tiles are the mockup's button body with the plain hairline, no bezel, as its buff icons.",
	})
	frames:Add(env, preview, {
		name = "minimap_preview", title = "Minimap preview", grade = "panel", reference = "minimap",
		caption = "Preview.lua in the settings window: the shared Face with a buttonFill terrain stand-in under the grain, the player dot, the zone and clock strip, the zoom slider and the button column with the drawer button.",
		match = "Frame line, chamfer and footer as the mockup's minimap; the terrain is the button body's tone with the grain where the game draws the world.",
	})

	local scene = Gallery.Build(env)
	scene.log[#scene.log + 1] = note
	return frames:Finish(scene, env, K, "gallery minimap")
end)
