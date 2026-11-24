-- test-setup-style-fit-nil-rects.lua: moving to the HUD style page while the hint, a shown Look row or Next has no rect yet raises nothing and the page gets its fitted height a frame later; the window backing, layout cards and module list still work.
local W = dofile("Tools/regression/widget_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local env, K = W.New({ boot = false, setup = function(e)
	e.C_AddOns = { DoesAddOnExist = function() return true end, LoadAddOn = function() return false, "MISSING" end }
	e._textWidth = function(text, path, size) return Scene.TextWidth(Scene.PlainText(text), size, path) end
end })
local BARS = { bar1 = { buttons = 12, split = "off" }, bar2 = { buttons = 12, split = "off" }, useTray = true }
for _, entry in ipairs(K.Setup.PICKER) do K.Modules.Register(W.CoreEnv.Module(entry.name, entry.name == "ActionBars" and { defaults = BARS } or nil)) end
W.CoreEnv.Boot(env)
K.Setup.Open()
local panel = K.Setup.window
local function settle()
	env.RunTimers(); W.Settle(env); env.RunTimers()
end
settle()
W.Click(panel.next)
settle()
assert(K.Setup.Step() == 2 and #env._errors == 0, tostring(env._errors[1]))
assert(panel.padTabs:IsShown() and panel.lookTabs:IsShown(), "the Look and Controls rows show, so the page grows past its reset height")
local fitted = panel.opts.height
for _, case in ipairs({ { panel.styleHint, "GetBottom" }, { panel.lookTabs, "GetBottom" }, { panel.next, "GetTop" } }) do
	local region, method = case[1], case[2]
	K.Setup.Go(1)
	settle()
	region[method] = function() return nil end
	W.Click(panel.next)
	assert(K.Setup.Step() == 2 and #env._errors == 0, "no error while " .. method .. " has no rect: " .. tostring(env._errors[1]))
	assert(panel.opts.height ~= fitted, "the fit waits for the rects")
	region[method] = nil
	settle()
	assert(panel.opts.height == fitted, "the page fits once its rects resolve: " .. tostring(panel.opts.height) .. " vs " .. tostring(fitted))
end
assert(not panel.chrome.fill.pending and panel.chrome.fill[5]:IsVisible(), "the window keeps its backing")
W.Click(panel.next)
settle()
for role, card in pairs(panel.cards) do
	W.Click(card)
	assert(K.Setup.Choice().layout == role and card.selected, "the layout card picks " .. role)
end
W.Click(panel.next)
settle()
local floor = panel.moduleScroll:GetBottom()
for name, toggle in pairs(panel.toggles) do
	assert(toggle:IsVisible() and toggle:GetBottom() >= floor, "the module list shows " .. name .. " without scrolling")
end
assert(#env._errors == 0, tostring(env._errors[1]))
print("ok")
