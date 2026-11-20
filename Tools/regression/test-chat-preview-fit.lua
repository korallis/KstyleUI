-- test-chat-preview-fit.lua: the chat page's live preview keeps its German and French tabs on its card at the default UI scale, where "BEUTE" and "BUTIN" once spilled past the glass.
local Guard = dofile("Tools/render/guard.lua")
do
	local C = dofile("Tools/regression/chat_env.lua")
	local env, K = C.New()
	C.Enable(env, K)
	env.RunTimers()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(180, 240)
	local preview = K.Options.Preview("Chat")(parent)
	for i, width in ipairs({ 40, 120, 40 }) do
		preview.tabs[i].GetUnboundedStringWidth = function() return width end
	end
	preview:Refresh()
	assert(preview.tabs[1]:IsShown() and not preview.tabs[2]:IsShown() and not preview.tabs[3]:IsShown(), "a tab that cannot fit hides the tabs after it, as the live dock keeps its order")
	assert(preview.more and preview.more:IsShown(), "hidden tabs show the overflow mark, as the live dock does")
	parent:SetSize(400, 240)
	preview:Refresh()
	assert(preview.tabs[3]:IsShown() and not preview.more:IsShown(), "tabs that fit show no overflow mark")
	assert(#env._errors == 0, tostring(env._errors[1]))
end
local saved = { rawget(_G, "RENDER_SCREEN"), rawget(_G, "RENDER_LOCALE"), rawget(_G, "RENDER_SCENE_LIB") }
local getenv = os.getenv
rawset(_G, "RENDER_SCENE_LIB", true)
rawset(os, "getenv", function(key)
	if key == "RENDER_SHELL_MODULE" then return "Chat" end
	return getenv(key)
end)
for _, screen in ipairs({ { 1920, 1080, "deDE" }, { 2560, 1440, "deDE" }, { 1920, 1080, "frFR" }, { 2560, 1440, "frFR" } }) do
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], uiScale = 768 / 1080 })
	rawset(_G, "RENDER_LOCALE", screen[3])
	local scene = dofile("Tools/render/scenes/shell_parity.lua")()
	local findings = Guard.Sort(Guard.Check(scene), Guard.LoadAllow(), "shell_parity")
	assert(#findings == 0, "Chat " .. screen[3] .. " " .. screen[1] .. "x" .. screen[2] .. ":\n" .. table.concat(Guard.Lines(findings, {}, {}, "default"), "\n"))
	collectgarbage("collect")
end
rawset(os, "getenv", getenv)
rawset(_G, "RENDER_SCREEN", saved[1])
rawset(_G, "RENDER_LOCALE", saved[2])
rawset(_G, "RENDER_SCENE_LIB", saved[3])
print("chat preview fit ok")
