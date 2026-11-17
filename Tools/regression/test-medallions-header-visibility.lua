-- test-medallions-header-visibility.lua: wanted header state controls the band without reading region visibility.
local W = dofile("Tools/regression/widget_env.lua")
local saved = { version = 12, profiles = { Default = { HudStyle = { style = "medallions" } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
local env, K = W.New({ width = 1920, height = 1080, saved = saved })
local panel = K.Widgets.Panel(K.Scale.Root(), { width = 320, height = 200, title = "Header" })
K.Widgets.Point(panel, "TOPLEFT", K.Scale.Root(), "TOPLEFT", 100, -100)
W.Settle(env)
local chrome, gem = panel.chrome, panel.cap.gem
gem.IsVisible = function() error("header measurement must use wanted state, never read gem visibility") end
chrome:MeasureHeader()
assert(chrome.header[3]:IsVisible(), "a visible owned header gem paints its header band and rule")

K.Widgets.CardHeader(gem, false)
assert(gem.headerHidden == true and panel.cap:IsShown(), "wanted state can exclude a gem independently of region visibility")
for _, region in ipairs(chrome.header) do assert(not region:IsVisible(), "a gem marked hidden must not paint a header") end
K.Widgets.CardHeader(gem, true)
assert(gem.headerHidden == false and chrome.header[3]:IsVisible(), "clearing wanted hidden state remeasures and restores the band")

panel.cap:Hide()
chrome:MeasureHeader()
W.Settle(env)
for _, region in ipairs(chrome.header) do assert(not region:IsVisible(), "a hidden owned cap must not leave an empty header band or rule") end
panel.cap:Show()
assert(panel.cap:GetScript("OnShow"), "the cap has a header measurement hook")(panel.cap)
W.Settle(env)
assert(chrome.header[3]:IsVisible(), "the cap's existing OnShow hook restores the header band")

panel.cap:SetShown(false)
assert(gem.headerHidden == true and chrome.headerUnits == nil, "SetShown records wanted hidden state")
panel.cap:SetShown(true)
assert(gem.headerHidden == false and chrome.header[3]:IsVisible(), "SetShown clears wanted hidden state and restores the band")

env.RestrictAnchoring(panel.cap)
chrome:MeasureHeader()
assert(chrome.headerUnits == nil, "restricted parents still stop measurement")
env.RestrictAnchoring(panel.cap, false)
chrome:MeasureHeader()
assert(chrome.header[3]:IsVisible(), "an unrestricted public header paints normally again")
K.Options.Write("HudStyle", "style", "frames")
local other = K.Widgets.Panel(K.Scale.Root(), { width = 320, height = 200, title = "Hidden before Medallions" })
K.Widgets.Point(other, "TOPLEFT", K.Scale.Root(), "TOPLEFT", 450, -100)
other.cap:Hide()
assert(other.cap.gem.headerHidden == true, "wanted state is recorded before the Medallions style is selected")
K.Options.Write("HudStyle", "style", "medallions")
W.Settle(env)
assert(other.chrome.headerUnits == nil, "entering Medallions preserves a header's wanted hidden state")
other.cap:Show()
assert(other.chrome.header[3]:IsVisible(), "showing the cap restores the band after a style switch")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("test-medallions-header-visibility: ok")
