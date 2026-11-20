-- test-layout-mover-jump.lua: double-clicking a mover opens that element's own settings, and Enter in the Layout Mode finder selects a single match.
local U = dofile("Tools/regression/unitframes_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local env, K = U.New({ setup = function(e)
	e.C_AddOns = e.C_AddOns or {}
	e.C_AddOns.LoadAddOn = function(name)
		if name == "KstyleUI_Options" and not e._addons[name] then Load(O.Files(), e) end
		return true
	end
end })
K.Options.Write("UnitFrames", "targettarget.enabled", true)
env.RunTimers()
local Mode = K.Layout.Mode
local KEY = "unitframes.targettarget"
local label = K.Layout.Element(KEY).label

assert(K.Layout.Enter())
local finder = Mode.Toolbar()
finder.search:SetText(label)
finder.search:GetScript("OnTextChanged")(finder.search, true)
assert(#finder.elements:GetOptions() == 1, "the finder narrows to one mover")
finder.search:GetScript("OnEnterPressed")(finder.search)
assert(Mode.Selected() == KEY, "Enter in the finder selects its single match, got " .. tostring(Mode.Selected()))
finder.search:SetText("no such mover")
finder.search:GetScript("OnTextChanged")(finder.search, true)
finder.search:GetScript("OnEnterPressed")(finder.search)
assert(Mode.Selected() == KEY, "Enter with no match selects nothing")

local function Open(key, page)
	if not K.Layout.IsActive() then assert(K.Layout.Enter()) end
	local plate = assert(Mode.Plate(key), key .. " has a mover")
	plate:GetScript("OnDoubleClick")(plate, "LeftButton")
	env.RunTimers()
	U.W.Settle(env)
	env.RunTimers()
	local ns = env._addons.KstyleUI_Options
	assert(not K.Layout.IsActive() and ns.Window.State().page == page, "double-click opens the mover's page " .. page .. ", got " .. tostring(ns.Window.State().page))
	local first
	for _, row in ipairs(ns.Window.Parts().content.rows) do
		if row.index and row:IsShown() and (first == nil or row.index < first) then first = row.index end
	end
	return ns.Window.State().items[first] or {}
end
local top = Open(KEY, "UnitFrames")
assert(K.Options.Read("UnitFrames", "edit") == "targettarget", "double-clicking Target of Target picks it, not Player")
assert(top.key == "edit", "the page opens at the frame picker above Target of Target's settings, got " .. tostring(top.label))
top = Open("integrations.timerLane", "Elements")
assert(K.Options.Read("UnitFrames", "edit") == "targettarget", "another module's mover leaves the frame picker alone")
assert(top.kind == "header" and top.label == K.Layout.Element("integrations.timerLane").label, "an element without a picker opens at its own section, got " .. tostring(top.label))
top = Open("unitframes.castbar.player", "UnitFrames")
assert(K.Options.Read("UnitFrames", "edit") == "player" and top.key == "player.castbar", "the Player cast bar mover opens at Player's cast bar settings, not the frame picker, got " .. tostring(top.label))
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("layout mover jump ok")
