-- test-settings-edit-journeys.lua: settings audit acceptance journeys for deferred width, recoverable imports and session discard.
local O = dofile("Tools/regression/options_env.lua")
local env, K, ns = O.New()
local W, Layout = O.W, K.Layout
K.Options.Open("General")
local list = ns.Window.Parts().content
local _, index = O.Find(ns.Window.State().items, function(item) return item.label == "Width" and item.element == "Options.Window" end)
list:ScrollToIndex(assert(index), true)
local row = assert(O.Find(list.rows, function(r) return r.index == index and r:IsShown() end))
local slider = row.controls.slider
local width = assert(Layout.Get("Options.Window").width)
local track = slider.trackBox
local function Point(fraction)
	env._cursor = { (track:GetLeft() + fraction * track:GetWidth()) * track:GetEffectiveScale(), 0 }
end
Point(0.8)
W.Down(slider)
assert(slider:GetValue() ~= width and Layout.Get("Options.Window").width == width, "press previews width without saving")
Point(0.9)
slider:GetScript("OnUpdate")(slider, 0.016)
local final = slider:GetValue()
assert(Layout.Get("Options.Window").width == width, "drag still previews")
W.Up(slider)
assert(Layout.Get("Options.Window").width == final, "release saves the final width")
print("width before and while held:", width, "after release:", final)

assert(Layout.Enter())
local entry = Layout.Get("Layout.Toolbar").x
assert(Layout.Set("Layout.Toolbar", "x", entry + 35))
local toolbar = Layout.Mode.Toolbar()
assert(toolbar.discard:IsShown())
W.Click(toolbar.discard)
assert(not Layout.IsActive() and Layout.Get("Layout.Toolbar").x == entry, "Discard restores the entry position and exits")

K.Options.Open("Profiles")
local items = ns.Pages.Find(ns.Pages.List(), "Profiles").Items()
local action = assert(O.Find(items, function(i) return i.label == "Import" and i.buttons end)).buttons[1]
local host = K.Widgets.DialogHost()
action.onClick()
for _, paste in ipairs({ "Raid night", "KSS1:bad", "KSA1:bad" }) do
	host.editBox:SetText(paste)
	W.Click(host.visibleButtons[2])
	if paste == "KSA1:bad" then W.Click(host.visibleButtons[2]) end
	assert(host.editBox:IsShown() and host.editBox:GetText() == paste, "failed paste remains editable: " .. paste)
	if paste == "Raid night" then
		for _, prefix in ipairs({ "KSUI1:", "KSS1:", "KSA1:" }) do assert(host.body:GetText():find(prefix, 1, true)) end
	end
end
assert(K.Store.CreateProfile("Raid night"))
host.editBox:SetText(assert(K.Profiles.ExportAccount()))
W.Click(host.visibleButtons[2])
W.Click(host.visibleButtons[2])
local summary = host.body:GetText()
assert(K.Store.ProfileName() == "Default (2)" and summary:find("Active profile: Default (2).", 1, true))
assert(summary:find("Profiles imported: 2.", 1, true) and summary:find("Character assignments applied: 1.", 1, true))
assert(#env._errors == 0, tostring(env._errors[1]))
print(summary)
