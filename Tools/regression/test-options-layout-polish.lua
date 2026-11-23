-- test-options-layout-polish.lua: search takes you to a setting and lights it, player-word synonyms, previews on Elements and Profiles, one motion style for menus and Layout Mode, and clear snap guides; each switch off restores the previous behaviour.
local O = dofile("Tools/regression/options_env.lua")
local W = O.W
local env, K, ns = O.New({
	before = function(_, kit)
		kit.Modules.Register(W.CoreEnv.Module("Cooldowns", { defaults = { edit = "player", focus = { glow = true } } }))
		kit.Options.Register("Cooldowns", {
			{ type = "dropdown", key = "edit", label = "Frame", help = "Which frame to set.", options = { { value = "player", label = "Player" }, { value = "focus", label = "Focus" } } },
			{ type = "toggle", key = "focus.glow", label = "Focus glow", help = "Glow on the focus frame.", scope = { key = "edit", value = "focus" }, showWhen = function(s) return s.edit == "focus" end },
		})
	end,
})
local Motion, Tokens, Model = K.Motion, K.Tokens, ns.Model
local account = K.Store.Account()

-- One motion style: each moment reads the shared tokens.
for moment, want in pairs({ open = { "panelOpen", "enter" }, close = { "panelClose", "exit" }, page = { "fade", "enter" }, snap = { "hover", "enter" }, highlight = { "combatOut", "exit" } }) do
	local duration, ease = Motion.Moment(moment)
	assert(duration == Tokens.Duration(want[1]) and ease == Tokens.Easing(want[2]), moment .. " uses the shared " .. want[1] .. " timing")
end

-- Player words: hp finds health rows while Search in player words is on.
local page = { id = "Test", label = "Test", items = {
	{ kind = "toggle", label = "Health text", module = "T", key = "health" },
	{ kind = "toggle", label = "Mana colour", module = "T", key = "mana" },
} }
local function Keys(results)
	local out = {}
	for _, item in ipairs(results or {}) do
		if item.key then out[#out + 1] = item.key end
	end
	return table.concat(out, ",")
end
assert(Keys(Model.Search({ page }, "hp")) == "health", "hp finds the health row")
assert(Keys(Model.Search({ page }, "mana color")) == "mana", "color finds colour, and every term must still match")
assert(Keys(Model.Search({ page }, "health")) == "health", "a plain word still matches its label")
K.Options.Write("OptionsPresentation", "synonyms", false)
assert(Keys(Model.Search({ page }, "hp")) == "", "off matches labels and help only")
K.Options.Write("OptionsPresentation", "synonyms", true)

-- Search takes you there: Enter opens the first result's page at its row and lights it briefly.
local box = env.CreateFrame("Frame", nil, K.Scale.Root())
box:SetSize(200, 50)
K.Layout.Register(box, "Test.Box", { anchor = "CENTER", x = 0, y = 0 }, { label = "Test box" })
K.Options.Open("Profiles")
W.Settle(env)
local parts = ns.Window.Parts()
local list = parts.content
local state = ns.Window.State()
local function Type(text)
	parts.search:SetText(text)
	parts.search:GetScript("OnTextChanged")(parts.search, true)
end
local function Enter()
	parts.search:GetScript("OnEnterPressed")(parts.search)
end
local LABEL = "Double-click the header to fold"
Type("double-click the header")
assert(state.items[1].kind == "note" and state.items[1].label == K.L["Press Enter or click a result to go to it."], "results start with how to go to one")
Enter()
assert(state.page == "General" and state.query == nil and parts.search:GetText() == "", "Enter opens the result's page and clears the search")
local function Lit()
	for _, row in ipairs(list.rows) do
		if row:IsShown() and row.index == list.flashIndex then
			return row
		end
	end
end
local row = Lit()
assert(row and row.item.label == LABEL, "the row the search found is in view")
local _, _, _, alpha = W.Color(row.flash)
assert(alpha > 0, "and lit")
W.Tick(env, 0.3)
local _, _, _, later = W.Color(row.flash)
assert(later > 0 and later < alpha, "the light fades")
W.Settle(env)
_, _, _, alpha = W.Color(row.flash)
assert(alpha == 0, "and goes out")

-- A click on a result goes there too, picking the frame a scoped row belongs to.
K.Options.Open("Profiles")
Type("search current page only")
local result
for _, r in ipairs(list.rows) do
	if r:IsShown() and r.item and r.item.label == K.L["Search current page only"] then result = r end
end
assert(result and result:IsMouseEnabled(), "a result row takes clicks")
W.Up(result, "LeftButton")
assert(state.page == "General" and state.query == nil and Lit().item.label == K.L["Search current page only"], "a click goes to the result")
Type("focus glow")
Enter()
assert(K.Store.Module("Cooldowns").edit == "focus" and state.page == "Cooldowns" and Lit().item.key == "focus.glow", "a scoped row opens with its frame picked")

-- Off keeps results in the list, as before.
account.optionsSearchJump = false
Type("double-click the header")
assert(state.items[1].kind ~= "note", "off shows no hint")
Enter()
assert(state.query ~= nil, "off leaves Enter in the search")
Type("")
account.optionsSearchJump = nil

-- Previews on Elements and Profiles: a screen map that follows the layout and the section in view.
K.Options.Open("Elements")
W.Settle(env)
local pane = parts.preview
local map = pane.current
assert(pane:IsShown() and map and map.boxes, "Elements shows where each element sits")
local function Drawn()
	local left = K.Layout.Rect("Test.Box")
	local k = map:GetWidth() / K.Layout.RootSize()
	for _, b in ipairs(map.boxes) do
		local point = b:IsShown() and W.LastCall(b, "SetPoint")
		if point and W.Near(point[4], left * k) then return b end
	end
end
assert(Drawn(), "the element's box sits where the element does")
K.Layout.Set("Test.Box", "x", 300)
local drawn = Drawn()
assert(drawn, "moving an element moves its box at once")
local r, g, b = drawn:GetVertexColor()
local ar, ag, ab = Tokens.Color("accent")
assert(not (W.Near(r, ar) and W.Near(g, ag) and W.Near(b, ab)), "boxes outside the section in view stay muted")
K.Options.Open("Profiles")
assert(pane:IsShown() and pane.current and pane.current.body, "Profiles shows the text sample")
account.optionsPreviewAll = false
K.Options.Open("About")
K.Options.Open("Elements")
assert(not pane:IsShown(), "off hides the Elements preview, as before")
K.Options.Open("Profiles")
assert(not pane:IsShown(), "and the Profiles preview")
account.optionsPreviewAll = nil
K.Options.Open(false)
W.Settle(env)

-- One motion style: menus open and close with the window timing; off restores the quicker hover fade.
local dropdown = K.Widgets.Dropdown(K.Scale.Root(), { options = { { value = 1, label = "One" }, { value = 2, label = "Two" } } })
local menu = K.Widgets.DropdownMenu()
dropdown:Open()
W.Tick(env, 0.13)
assert(menu:GetAlpha() > 0 and menu:GetAlpha() < 1, "a menu opens with the window open timing")
W.Settle(env)
dropdown:Close()
W.Tick(env, 0.13)
assert(menu:IsShown() and menu:GetAlpha() > 0, "and closes with the window close timing")
W.Settle(env)
account.motionOneStyle = false
dropdown:Open()
W.Tick(env, 0.13)
assert(menu:GetAlpha() == 1, "off restores the hover fade")
dropdown:Close()
W.Settle(env)
account.motionOneStyle = nil

-- Clear snap guides: two units wide and fading in; a snapped element is not re-placed while the pointer moves.
K.Layout.Set("Test.Box", "x", 0)
assert(K.Layout.Enter())
W.Settle(env)
local Mode = K.Layout.Mode
local overlay, plate = Mode.Overlay(), Mode.Plate("Test.Box")
local rw, rh = K.Layout.RootSize()
local function Cursor(cx, cy)
	local scale = K.Scale.Root():GetEffectiveScale()
	env._cursor = { (cx + K.Scale.Origin()) * scale, cy * scale }
end
local function Drag(dx, dy)
	Cursor(rw / 2, rh / 2)
	plate:GetScript("OnDragStart")(plate, "LeftButton")
	Cursor(rw / 2 + dx, rh / 2 + dy)
	overlay:GetScript("OnUpdate")(overlay, 0.016)
end
Drag(3, 2)
local gx = Mode.Guides()
assert(gx:IsShown() and W.Near(gx:GetWidth(), K.Scale.Snap(2)) and gx:GetAlpha() == 0, "a clear guide is two units wide and starts faded")
local placed = #W.Calls(box, "SetPoint")
Cursor(rw / 2 + 4, rh / 2 + 1)
W.Tick(env, 0.2)
assert(gx:GetAlpha() == 1, "the guide fades in with the snap timing")
assert(#W.Calls(box, "SetPoint") == placed, "a snapped element is not re-placed while the pointer moves inside the snap")
plate:GetScript("OnDragStop")(plate)
K.Options.Write("LayoutControls", "guides", false)
Drag(3, 2)
assert(gx:IsShown() and W.Near(gx:GetWidth(), K.Scale.Border()) and W.Near(gx:GetAlpha(), 0.9), "off restores the thin guide shown at once")
plate:GetScript("OnDragStop")(plate)
K.Layout.Exit(true)
W.Settle(env)
assert(not overlay:IsShown(), "Layout Mode closes")

assert(#env._errors == 0, tostring(env._errors[1]))
print("options and layout polish ok")
