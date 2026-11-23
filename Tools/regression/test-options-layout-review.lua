-- test-options-layout-review.lua: the v0.3.0 Options and Layout Mode review probes: the fading toolbar ignores clicks after Layout Mode closes, a secret overlay visibility fades in from nothing, the Elements map follows Shown and opacity once per batch and rests while hidden, the search hint names what opens and shows only when a result can open, a pinned picker lights, the new player words follow Search takes you there, and a page change uses the page moment.
local O = dofile("Tools/regression/options_env.lua")
local W = O.W
local env, K, ns = O.New({
	before = function(_, kit)
		kit.Modules.Register(W.CoreEnv.Module("Cooldowns", { defaults = { editBar = "one" } }))
		kit.Options.Register("Cooldowns", { { type = "dropdown", key = "editBar", pin = true, label = "Bar to edit", help = "Choose the bar.", options = { { value = "one", label = "One" } } } })
	end,
})
local layout, account, L = K.Layout, K.Store.Account(), K.L

-- Reset and the switches do nothing once Layout Mode has closed, while its toolbar fades out.
local box = env.CreateFrame("Frame", nil, K.Scale.Root())
box:SetSize(95, 38)
layout.Register(box, "Review.Box", { anchor = "CENTER", x = 0, y = 0 }, { label = "Review box" })
layout.Set("Review.Box", "x", 80)
assert(layout.Enter())
W.Settle(env)
layout.Exit(true)
local toolbar, grid = layout.Mode.Toolbar(), layout.Setting("grid")
assert(not layout.IsActive() and toolbar:IsVisible() and toolbar.reset:IsEnabled(), "the toolbar is still fading out")
W.Click(toolbar.reset)
W.Click(toolbar.gridToggle)
assert(layout.Get("Review.Box").x == 80, "Reset does nothing once Layout Mode has closed")
assert(layout.Setting("grid") == grid, "nor does the Grid switch")
W.Settle(env)

-- A secret overlay visibility counts as hidden, so the overlay fades in from nothing.
local overlay = layout.Mode.Overlay()
overlay.IsShown = function() return env.Secret(false) end
assert(layout.Enter() and overlay:GetAlpha() == 0, "a secret visibility is not truth-tested")
overlay.IsShown = nil
W.Settle(env)
layout.Exit(true)
W.Settle(env)

-- The Elements map hides an element set to Never and shows its idle opacity.
K.Options.Open("Elements")
W.Settle(env)
local parts = ns.Window.Parts()
local map = parts.preview.current
local function Box()
	local left = layout.Rect("Review.Box")
	local k = map:GetWidth() / layout.RootSize()
	for _, b in ipairs(map.boxes) do
		local point = b:IsShown() and W.LastCall(b, "SetPoint")
		if point and W.Near(point[4], left * k) then return b end
	end
end
local _, _, _, full = Box():GetVertexColor()
layout.Set("Review.Box", "alphaIdle", 0.5)
env.RunTimers()
local _, _, _, half = Box():GetVertexColor()
assert(W.Near(half, full / 2), "a box shows its element's opacity")
layout.Set("Review.Box", "shown", "never")
env.RunTimers()
assert(not Box(), "an element set to Never leaves the map")
layout.Reset("Review.Box")
env.RunTimers()

-- One Reset All redraws the map once, and a hidden map does no work on a restyle.
for i = 1, 20 do
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	frame:SetSize(30, 20)
	layout.Register(frame, "Review." .. i, { anchor = "CENTER", x = 0, y = 0 }, { label = "Review " .. i })
	layout.Set("Review." .. i, "x", i)
end
env.RunTimers()
local refresh, redraws = map.Refresh, 0
map.Refresh = function(...)
	redraws = redraws + 1
	return refresh(...)
end
layout.ResetAll()
env.RunTimers()
map.Refresh = refresh
assert(redraws == 1, "one Reset All redraws the map once, not " .. redraws .. " times")
account.optionsPreviewAll = false
K.Options.Open("About")
K.Options.Open("Elements")
K.Options.Open(false)
W.Settle(env)
local rect, reads = layout.Rect, 0
layout.Rect = function(...)
	reads = reads + 1
	return rect(...)
end
map:Restyle()
layout.Rect = rect
assert(reads == 0, "a hidden map does no work on a restyle, not " .. reads .. " lookups")
account.optionsPreviewAll = nil

-- The hint names what a click opens, as a result's switch still changes its setting, and shows only when a result can open.
K.Options.Open("Profiles")
local state = ns.Window.State()
local HINT = L["Press Enter or click a result's name to go to it."]
local function Query(text)
	parts.search:SetText(text)
	parts.search:GetScript("OnTextChanged")(parts.search, true)
end
Query("Double-click the header to fold")
assert(state.items[1].label == HINT, "the hint says a result's name opens it")
Query("/kstyle profile")
assert(state.items[#state.items].kind == "note", "the slash commands show as notes")
for _, item in ipairs(state.items) do
	assert(not tostring(item.label):find("^Press Enter"), "no hint when no result can open")
end

-- Enter on a pinned picker's result opens its page and lights the picker.
Query("Bar to edit")
parts.search:GetScript("OnEnterPressed")(parts.search)
local picker = parts.picker
assert(state.page == "Cooldowns" and picker:IsShown() and picker.item.key == "editBar", "Enter opens the pinned picker's page")
assert(picker.flash and select(4, picker.flash:GetVertexColor()) > 0, "and lights the picker")
W.Settle(env)
assert(select(4, picker.flash:GetVertexColor()) == 0, "the light goes out")

-- The new player words follow Search takes you there; Search in player words keeps only its row words.
local page = { id = "P", label = "P", items = {
	{ kind = "toggle", label = "HUD", module = "HudStyle", key = "style" },
	{ kind = "toggle", label = "Health", module = "Test", key = "hp" },
} }
local function Hits(term)
	local n = 0
	for _, item in ipairs(ns.Model.Search({ page }, term) or {}) do
		if item.kind == "toggle" then n = n + 1 end
	end
	return n
end
account.optionsSearchJump = false
assert(Hits("hp") == 0 and Hits("portraits") == 1, "Search takes you there off restores the previous search")
account.optionsSearchJump = nil
K.Options.Write("OptionsPresentation", "synonyms", false)
assert(Hits("hp") == 1 and Hits("portraits") == 0, "Search in player words off drops only its row words")
K.Options.Write("OptionsPresentation", "synonyms", true)

-- One motion style names what it times: a page change fades the list with the page moment; off keeps the 450 ms cascade.
local help
for _, item in ipairs(ns.Model.PageItems(ns.Pages.Find(ns.Pages.List(), "General"))) do
	if item.label == L["One motion style"] then help = item.help end
end
assert(help == L["Menus, page changes and Layout Mode use the window timing. Off restores their previous motion."], "the switch's help lists what it times")
local list = parts.content
K.Options.Open("About")
K.Options.Open("General")
local fade = list.kstylePageIn
assert(list:GetAlpha() == 1 and list.rows[1]:GetAlpha() == 1, "a page change keeps the list at alpha 1 with no frame run, so a fade the client never steps cannot hide it")
assert(fade and fade:IsPlaying() and fade.alpha:GetDuration() == K.Motion.Moment("page"), "the whole list fades in over the page moment")
account.motionOneStyle = false
K.Options.Open("About")
K.Options.Open("General")
assert(list:GetAlpha() == 1 and list.rows[1]:GetAlpha() == 0 and list.revealLimit == 0.45, "off keeps the 450 ms cascade")
account.motionOneStyle = nil
W.Settle(env)

assert(#env._errors == 0, tostring(env._errors[1]))
print("options and layout review ok")
