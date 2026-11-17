-- test-medallions-header-visibility.lua: hidden, restricted and secret header gems cannot paint a Medallions header band.
local W = dofile("Tools/regression/widget_env.lua")
local saved = { version = 12, profiles = { Default = { HudStyle = { style = "medallions" } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
local env, K = W.New({ width = 1920, height = 1080, saved = saved })
local panel = K.Widgets.Panel(K.Scale.Root(), { width = 320, height = 200, title = "Header" })
K.Widgets.Point(panel, "TOPLEFT", K.Scale.Root(), "TOPLEFT", 100, -100)
W.Settle(env)
local chrome, gem = panel.chrome, panel.cap.gem
chrome:MeasureHeader()
assert(chrome.header[3]:IsVisible(), "a visible owned header gem paints its header band and rule")

panel.cap:Hide()
chrome:MeasureHeader()
W.Settle(env)
for _, region in ipairs(chrome.header) do assert(not region:IsVisible(), "a hidden owned cap must not leave an empty header band or rule") end
panel.cap:Show()
assert(panel.cap:GetScript("OnShow"), "the cap has a header measurement hook")(panel.cap)
W.Settle(env)
assert(chrome.header[3]:IsVisible(), "the cap's existing OnShow hook restores the header band")

local visible, top = gem.IsVisible, gem.GetTop
gem.IsVisible = function() return env.Secret(true) end
gem.GetTop = function() error("a secret header visibility must stop measurement before reading its geometry") end
chrome:MeasureHeader()
assert(chrome.headerUnits == nil, "secret visibility must be rejected before boolean comparisons")
gem.IsVisible, gem.GetTop = visible, top
chrome:MeasureHeader()
assert(chrome.header[3]:IsVisible(), "public visibility restores the normal header")

env.RestrictAnchoring(panel.cap)
gem.IsVisible = function() error("restricted header visibility must not be read") end
chrome:MeasureHeader()
assert(chrome.headerUnits == nil, "restricted parents stop measurement before visibility is read")
gem.IsVisible = visible
env.RestrictAnchoring(panel.cap, false)
chrome:MeasureHeader()
assert(chrome.header[3]:IsVisible(), "an unrestricted public header paints normally again")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("test-medallions-header-visibility: ok")
