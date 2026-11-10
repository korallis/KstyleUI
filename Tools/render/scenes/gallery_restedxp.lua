-- gallery_restedxp.lua: every RestedXP Guides window KstyleUI_Skins restyles, each cropped as one frame of the
-- gallery, laid out as RestedXP lays them out in the game (scenes/_restedxp.lua): the guide as one card (cap,
-- active steps, route, step list and footer), the item and target windows, arrow, tip, report, splits,
-- configurator, importer and popups, communication dialogs, quest cleanup and context menu.
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
	for _, spec in ipairs({
		{ "targets", "Active targets", "RestedXP's hostile and friendly target rows, on the fake's game-sized secure buttons and title plate." },
		{ "arrow", "Waypoint arrow", "RestedXP's waypoint arrow and its two-line destination and distance label." },
		{ "tip", "Guide tip", "A separate 230-unit tip step, with two lines of levelling advice." },
		{ "report", "Leveling report", "The character leveling report: level dropdown, player, headings, and measured experience and timing data in AceGUI's scroll frame." },
		{ "splits", "Level splits", "Recent level splits, current level time and total played time, with the title and settings cog." },
		{ "importer", "Guide importer", "The beta-enabled importer: guide string, import and splice actions, imported-guide dropdown, management actions, progress and history." },
		{ "purge", "Purge confirmation", "The importer's confirmation before removing every imported guide." },
		{ "delete", "Delete confirmation", "The importer's confirmation before removing the selected guide." },
		{ "feedback", "Feedback form", "The support Discord instructions and a filled step feedback form inside the resizable AceGUI window." },
		{ "export", "Branded export", "An editable guide export with its description, guide string and Accept button." },
		{ "cleanup", "Quest log cleanup", "RestedXP's 200-unit cleanup button on the quest-details parent." },
		{ "menu", "Context menu", "The fake's shared dropdown list, opened by RestedXP with the six step-context entries." },
	}) do
		add("restedxp_" .. spec[1], R.windows[spec[1]], {
			title = "RestedXP " .. spec[2], grade = spec[1] == "cleanup" and "button" or "window", reference = "chat",
			caption = spec[3], match = "Kit glass, controls and type on RestedXP's own window geometry.",
		})
	end
	local scene = frames:Finish(Gallery.Build(env), env, K, "gallery restedxp")
	for _, line in ipairs(R.log) do
		scene.log[#scene.log + 1] = line
	end
	return scene
end)
