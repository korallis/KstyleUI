-- test-bags-preview-cap.lua: the Bags page's live preview keeps its BAGS cap title inside the preview's clip at 1920x1080, 2560x1440, 5120x1440 and 3840x2160, measured as addon code measures it, before any draw pass.
rawset(_G, "RENDER_SCENE_LIB", true)
local getenv = os.getenv
local function measure(env)
	local pane = env._addons.KstyleUI_Options.Window.Parts().preview
	local title, holder = pane.current.title.label, pane.holder
	local function edge(object, method)
		local value = object[method](object)
		return value and value * object:GetEffectiveScale()
	end
	local l, r, t, b = edge(title, "GetLeft"), edge(title, "GetRight"), edge(title, "GetTop"), edge(title, "GetBottom")
	assert(l and r and t and b, "BAGS has no rect before a draw pass: the stubs must size natural text when addon code measures it")
	local slack = math.min(l - edge(holder, "GetLeft"), edge(holder, "GetRight") - r, edge(holder, "GetTop") - t, b - edge(holder, "GetBottom"))
	return slack * select(2, env.GetPhysicalScreenSize()) / 768
end
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], uiScale = 768 / 1080 })
	local slack
	local function load(path)
		local lib = dofile(path)
		if path:find("_gallery.lua", 1, true) then
			lib.Build = function(env)
				slack = measure(env)
				return { log = {} }
			end
		end
		return lib
	end
	local scene = assert(loadfile("Tools/render/scenes/shell_parity.lua"))
	setfenv(scene, setmetatable({ dofile = load, os = { getenv = function(key)
		if key == "RENDER_SHELL_MODULE" then return "Bags" end
		return getenv(key)
	end } }, { __index = _G }))
	scene()()
	assert(slack >= -0.5, string.format("%dx%d: BAGS crosses the preview's clip by %.2f physical pixels", screen[1], screen[2], -slack))
	collectgarbage("collect")
end
print("ok BAGS stays inside the Bags preview's clip at four screens")
