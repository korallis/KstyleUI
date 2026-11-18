-- test-options-groupframes-preview.lua: hidden Medallions chrome must not re-enter its restyle wrapper while Options builds the preview.
local G = dofile("Tools/regression/group_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local env, K = G.New({ setup = function(e)
	e.C_AddOns = { LoadAddOn = function(name)
		if name == "KstyleUI_Options" and not e._addons[name] then
			Load(O.Files(), e)
		end
		return true
	end }
end })

local function settle()
	env.RunTimers()
	O.W.Settle(env)
	env.RunTimers()
end

K.Options.Write("HudStyle", "style", "medallions")
assert(K.Options.Open("Profiles"))
settle()
local options = env._addons.KstyleUI_Options
options.Window.Frame():SetSize(880, 520)
settle()
assert(K.Options.Open("GroupFrames"))
settle()
assert(#env._errors == 0, "opening GroupFrames after Profiles must not recurse through Chrome:SetShown: " .. table.concat(env._errors, "\n"))
local pane = options.Window.Parts().preview
assert(pane.current and pane.current.partyFrames, "the real GroupFrames preview must finish building")
assert(pane.current:IsVisible(), "the GroupFrames preview must appear in the small Options window")
for _, frame in ipairs(pane.current.partyFrames) do
	assert(frame.chrome.fill == nil or frame.chrome.fill[5]:IsShown() == not frame.tileless, "first show must retain the GroupFrames tile visibility")
end
print("options GroupFrames preview ok")
