-- test-setup-modules-fit.lua: the first-run Modules page shows every module and its whole note at the window's default size, with no line cut by the list's edge.
local getenv = os.getenv
rawset(_G, "RENDER_SCENE_LIB", true)
rawset(os, "getenv", function(key)
	if key == "RENDER_SUBJECT" then return "setup" end
	if key == "RENDER_SETUP_STEP" then return "4" end
	return getenv(key)
end)
for _, case in ipairs({ { "enUS", 1920, 1080 }, { "frFR", 2560, 1440 }, { "enUS", 3840, 2160 } }) do
	local locale, width, height = unpack(case)
	local label = locale .. " " .. width .. "x" .. height
	rawset(_G, "RENDER_SCREEN", { width = width, height = height, uiScale = 768 / 1080 })
	rawset(_G, "RENDER_LOCALE", locale)
	local scene = dofile("Tools/render/scenes/options_setup.lua")()
	local clipped = 0
	for _, item in ipairs(scene.items) do
		local clip = item.kind == "text" and item.clip
		if clip then
			clipped = clipped + 1
			local over = item.rect[2] + item.rect[4] - (clip[2] + clip[4])
			assert(over <= 0.5, label .. ": \"" .. item.text .. "\" is cut " .. over .. " units by the module list's edge")
		end
	end
	assert(clipped == 30, label .. ": every module shows its name and note, got " .. clipped .. " lines")
	collectgarbage("collect")
end
print("setup modules fit ok")
