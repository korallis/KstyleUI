-- gallery_restedxp.lua: every RestedXP Guides window KstyleUI_Skins restyles, each cropped as one frame of the
-- gallery, laid out as RestedXP lays them out in the game (scenes/_restedxp.lua): the guide as one card (cap,
-- active steps, route, step list and footer), the active item frame, the v2 guide window and the guide
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
	add("restedxp_guide", R.windows.guide, {
		title = "RestedXP guide card", grade = "window", reference = "tracker",
		caption = "RestedXP's guide as one card: the Lumen cap with the guide's name and the current step, the active steps as rows with KstyleUI ring checks, the route's caption, the step list with its scroll bar in its own gutter, and the footer with the cog and the resize grabber.",
		match = "Window grade as the tracker's glass, one cap language with the quests; the glass reaches one content inset past RestedXP's text on both sides, the scroll bar sits in a gutter behind a faint line.",
	})
	add("restedxp_items", R.windows.items, {
		title = "RestedXP active items", grade = "window", reference = "chat",
		caption = "RestedXP's active item frame: one window glass that rises over the title plate RestedXP hangs from the frame's top edge, the title tile in the accent inside it, item buttons on KstyleUI rims.",
		match = "Window grade as the chat panel; the buttons as the mockup's action buttons without the bezel.",
	})
	add("restedxp_v2", R.windows.v2, {
		title = "RestedXP v2 guide window", grade = "window", reference = "chat",
		caption = "RestedXP's v2 guide window: upper and steps frames on window glass, the accent title, KstyleUI's close button and scroll bar.",
		match = "Window grade as the chat panel.",
	})
	add("restedxp_configurator", R.windows.configurator, {
		title = "RestedXP guide configurator", grade = "window", reference = "chat",
		caption = "RestedXP's guide configurator: window glass, the title in the kit's title role, KstyleUI buttons and scroll bar; the pane holds the guide's title, its description and RestedXP's own option rows (image, label, recommendation and check box) in RestedXP's theme colours.",
		match = "Window grade as the chat panel; buttons as the design kit's dark controls.",
	})
	local scene = frames:Finish(Gallery.Build(env), env, K, "gallery restedxp")
	for _, line in ipairs(R.log) do
		scene.log[#scene.log + 1] = line
	end
	return scene
end)
