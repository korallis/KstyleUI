-- test-folio-fixed-labels.lua: shipped category captions and setup instructions stay whole inside unchanged windows at narrow-screen font snap boundaries.
local Guard = dofile("Tools/render/guard.lua")
local savedScreen, savedLocale, savedLibrary = rawget(_G, "RENDER_SCREEN"), rawget(_G, "RENDER_LOCALE"), rawget(_G, "RENDER_SCENE_LIB")
rawset(_G, "RENDER_SCENE_LIB", true)

local cases = {
	{ "gallery_bags", "deDE", 1280, 720 },
	{ "gallery_bags_browse", "deDE", 3456, 2234 },
	{ "gallery_bags", "esES", 1280, 720 },
	{ "gallery_setup", "esES", 1280, 720 },
	{ "gallery_setup", "enUS", 1920, 1080 },
	{ "gallery_setup_tracked", "deDE", 1280, 720 },
	{ "gallery_setup_tracked", "frFR", 1280, 720 },
	{ "gallery_setup_tracked", "esES", 1280, 720 },
}
for _, case in ipairs(cases) do
	local name, locale, width, height = unpack(case)
	rawset(_G, "RENDER_SCREEN", { width = width, height = height, uiScale = 768 / 1080 })
	rawset(_G, "RENDER_LOCALE", locale)
	local scene = dofile("Tools/render/scenes/" .. name .. ".lua")()
	local findings = Guard.Sort(Guard.Check(scene), Guard.LoadAllow(), name)
	assert(#findings == 0, name .. " " .. locale .. " " .. width .. "x" .. height .. ":\n" .. table.concat(Guard.Lines(findings, {}, {}, "default"), "\n"))
	for _, line in ipairs(scene.log or {}) do
		assert(not line:find("error:", 1, true), line)
	end
	if name == "gallery_setup_tracked" then
		local instructions = false
		for _, item in ipairs(scene.items) do
			if item.kind == "text" and item.text:find("80", 1, true) and item.text:find("60", 1, true) then
				instructions = true
			end
		end
		assert(instructions, "the full tracked-buff and bar counts remain in the setup instructions")
	end
	collectgarbage("collect")
end
rawset(_G, "RENDER_SCREEN", savedScreen)
rawset(_G, "RENDER_LOCALE", savedLocale)
rawset(_G, "RENDER_SCENE_LIB", savedLibrary)
print("folio fixed labels ok")
