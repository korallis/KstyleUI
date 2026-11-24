-- test-setup-style-fit-nil-rects.lua: moving to the HUD style page before the client resolves its rects raises nothing, and the page gets the same fitted height once they resolve.
local W = dofile("Tools/regression/widget_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local env, K = W.New({ boot = false, setup = function(e)
	e.C_AddOns = { DoesAddOnExist = function() return true end, LoadAddOn = function() return false, "MISSING" end }
	e._textWidth = function(text, path, size) return Scene.TextWidth(Scene.PlainText(text), size, path) end
end })
for _, entry in ipairs(K.Setup.PICKER) do K.Modules.Register(W.CoreEnv.Module(entry.name)) end
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
local fitted = panel.opts.height
K.Setup.Go(1)
settle()
local pending = true
for _, region in ipairs({ panel.styleHint, panel.lookTabs, panel.lookNote, panel.padTabs, panel.padNote, panel.next }) do
	local top, bottom = region.GetTop, region.GetBottom
	region.GetTop = function(self) if not pending then return top(self) end end
	region.GetBottom = function(self) if not pending then return bottom(self) end end
end
local ok, err = pcall(W.Click, panel.next)
assert(ok and #env._errors == 0, "the HUD style page must not error before its rects resolve: " .. tostring(err or env._errors[1]))
assert(K.Setup.Step() == 2, "Next still reaches the HUD style page")
pending = false
settle()
assert(panel.opts.height == fitted, "the HUD style page fits once its rects resolve: " .. tostring(panel.opts.height) .. " vs " .. tostring(fitted))
print("ok")
