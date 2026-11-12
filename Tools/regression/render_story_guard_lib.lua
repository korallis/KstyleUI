-- render_story_guard_lib.lua: the strict render guard over the story rail's two cards (the RestedXP guide and the quest card, with the owner's live story state: a long guide and nine quests) on every screen of the matrix, for one preset per test file so each stays inside its time budget.
local Reference = dofile("Tools/render/scenes/_reference.lua")
local Guard = dofile("Tools/render/guard.lua")

local SCREENS = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 3840, 1080 }, { 5120, 1440 },
	{ 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 },
}

return function(preset)
	local screen = Reference.SCREEN
	local checked = 0
	for _, size in ipairs(SCREENS) do
		Reference.SCREEN = { width = size[1], height = size[2], uiScale = 768 / 1080 }
		for _, live in ipairs({ false, true }) do
			local scene = Reference.Build({ layout = preset, modules = { "tracker", "restedxp" }, live = live })
			local findings = Guard.Check(scene)
			assert(#findings == 0, string.format("%s at %dx%d%s: %s", preset, size[1], size[2], live and " (live story)" or "",
				table.concat(Guard.Lines(findings, {}, {}, "strict"), "; ")))
			checked = checked + 1
		end
	end
	Reference.SCREEN = screen
	return checked
end
