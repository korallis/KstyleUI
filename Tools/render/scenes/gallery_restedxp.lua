-- gallery_restedxp.lua: every RestedXP Guides window KstyleUI_Skins restyles, each cropped as one frame of the
-- gallery, laid out as RestedXP lays them out in the game (scenes/_restedxp.lua): the active step frames, the
-- guide window with its header, step list and footer, the active item frame, the v2 guide window and the guide
-- configurator. Window-grade glass throughout, compared against the mockup's chat and tracker glass.
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local RestedXP = dofile("Tools/render/scenes/_restedxp.lua")
local Common = Gallery.Common

return Common.Run(function()
	local R = RestedXP.Build()
	local env, K = R.env, R.K
	local frames = Gallery.Frames()
	local function add(name, list, spec)
		spec.name, spec.rect = name, Gallery.Union(env, list)
		frames:Add(env, list[1], spec)
	end
	add("restedxp_steps", R.windows.steps, {
		title = "RestedXP active steps", grade = "window", reference = "tracker",
		caption = "RestedXP's active step frames: window glass grown outward so the check boxes and text sit one content inset inside it; the Step plate a tile; KstyleUI check boxes.",
		match = "Window grade as the tracker's glass; the content inset keeps every check box and line clear of the corner cuts and the light line.",
	})
	add("restedxp_guide", R.windows.guide, {
		title = "RestedXP guide window", grade = "window", reference = "chat",
		caption = "RestedXP's guide window: the header with the logo and the guide's name, the step list with its scroll bar in its own gutter, the footer tile with the cog and the resize grabber.",
		match = "Window grade as the chat panel; the glass reaches one content inset past RestedXP's text on both sides, the scroll bar sits in a gutter behind a faint line.",
	})
	add("restedxp_items", R.windows.items, {
		title = "RestedXP active items", grade = "window", reference = "chat",
		caption = "RestedXP's active item frame: window glass, a title tile in the accent, item buttons on KstyleUI rims.",
		match = "Window grade as the chat panel; the buttons as the mockup's action buttons without the bezel.",
	})
	add("restedxp_v2", R.windows.v2, {
		title = "RestedXP v2 guide window", grade = "window", reference = "chat",
		caption = "RestedXP's v2 guide window: upper and steps frames on window glass, the accent title, KstyleUI's close button and scroll bar.",
		match = "Window grade as the chat panel.",
	})
	add("restedxp_configurator", R.windows.configurator, {
		title = "RestedXP guide configurator", grade = "window", reference = "chat",
		caption = "RestedXP's guide configurator: window glass, the accent title, KstyleUI buttons and scroll bar.",
		match = "Window grade as the chat panel; buttons as the design kit's dark controls.",
	})
	local scene = frames:Finish(Gallery.Build(env), env, K, "gallery restedxp")
	for _, line in ipairs(R.log) do
		scene.log[#scene.log + 1] = line
	end
	return scene
end)
