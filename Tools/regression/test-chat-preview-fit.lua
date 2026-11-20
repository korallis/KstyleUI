-- test-chat-preview-fit.lua: the chat page's live preview keeps its German tabs on its card at the default UI scale, where "BEUTE" once spilled past the glass.
local Guard = dofile("Tools/render/guard.lua")
local saved = { rawget(_G, "RENDER_SCREEN"), rawget(_G, "RENDER_LOCALE"), rawget(_G, "RENDER_SCENE_LIB") }
local getenv = os.getenv
rawset(_G, "RENDER_SCENE_LIB", true)
rawset(os, "getenv", function(key)
	if key == "RENDER_SHELL_MODULE" then return "Chat" end
	return getenv(key)
end)
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 } }) do
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], uiScale = 768 / 1080 })
	rawset(_G, "RENDER_LOCALE", "deDE")
	local scene = dofile("Tools/render/scenes/shell_parity.lua")()
	local findings = Guard.Sort(Guard.Check(scene), Guard.LoadAllow(), "shell_parity")
	assert(#findings == 0, "Chat deDE " .. screen[1] .. "x" .. screen[2] .. ":\n" .. table.concat(Guard.Lines(findings, {}, {}, "default"), "\n"))
	collectgarbage("collect")
end
rawset(os, "getenv", getenv)
rawset(_G, "RENDER_SCREEN", saved[1])
rawset(_G, "RENDER_LOCALE", saved[2])
rawset(_G, "RENDER_SCENE_LIB", saved[3])
print("chat preview fit ok")
