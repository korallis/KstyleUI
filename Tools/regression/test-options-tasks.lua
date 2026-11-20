-- test-options-tasks.lua: the six task links reach existing settings, player-word search finds the right rows, and ornament samples keep the existing level choices.
local O = dofile("Tools/regression/options_env.lua")
local W = O.W
local env, K, ns = O.New({ before = function(_, K)
	for _, name in ipairs({ "ActionBars", "GroupFrames", "Nameplates" }) do
		K.Modules.Register(W.CoreEnv.Module(name, { defaults = { bindingHints = true, clickCast = { hint = true }, cast = { showName = true } } }))
	end
	K.Options.Register("ActionBars", { { type = "toggle", key = "bindingHints", label = "Binding hints", help = "Shows binding help." } })
	K.Options.Register("GroupFrames", { { type = "toggle", key = "clickCast.hint", label = "Click casting reminder", help = "Shows click casting help." } })
	K.Options.Register("Nameplates", { { type = "toggle", key = "cast.showName", label = "Spell name", help = "Shows the spell name." } })
end })
local function settle()
	env.RunTimers(); W.Settle(env); env.RunTimers()
end
local function rowAt(index)
	local list = ns.Window.Parts().content
	list:ScrollToIndex(index, true)
	settle()
	for _, row in ipairs(list.rows) do if row.index == index and row:IsShown() then return row end end
	error("missing row " .. index)
end
assert(K.Options.Open())
settle()
assert(ns.Window.State().page == "Tasks", "G9: Options opens on common tasks")
assert(#ns.Window.State().items == 6, "G9: exactly six task links")
for i, task in ipairs(ns.Pages.TASKS) do
	K.Options.Open("Tasks")
	settle()
	local row = rowAt(i)
	assert(row.item.label == task.label and row:GetHeight() > 36 and row.help:IsShown(), "every task keeps its 36-unit link and a visible explanation")
	assert(row.controls.task:GetWidth() >= K.Widgets.TextWidth(row.controls.task.label, 0) + 2 * K.Tokens.Size("gapLarge"), "G9: the whole task label fits its link")
	W.Click(row.controls.task)
	settle()
	assert(ns.Window.State().page == task.page, "G9: " .. task.label .. " reaches " .. task.page)
	local found = false
	for _, shown in ipairs(ns.Window.Parts().content.rows) do
		local item = shown.item
		if shown:IsShown() and item and (task.key and item.module == task.module and item.key == task.key or task.labelTarget and item.label == task.labelTarget) then found = true end
	end
	assert(found, "G9: the destination setting is on screen for " .. task.label)
end
local function hits(query, module, key)
	for _, item in ipairs(ns.Model.Search(ns.Pages.List(), query) or {}) do
		if item.module == module and item.key == key then return true end
	end
	return false
end
assert(hits("make kicks obvious", "Nameplates", "cast.showName"), "G9: kicks find cast settings")
assert(hits("bigger letters", "Readability", "preset"), "G9: bigger letters find the readable preset")
assert(hits("healing clicks", "GroupFrames", "clickCast.hint"), "G9: healing clicks find click casting")
assert(hits("hotkeys", "ActionBars", "bindingHints"), "G9: hotkeys find binding help")
assert(hits("plater", "Integrations", "notices"), "G9: other addon names find integration choices")
K.Options.Write("OptionsPresentation", "synonyms", false)
assert(not hits("make kicks obvious", "Nameplates", "cast.showName"), "G9: Off restores literal search")
assert(hits("Spell name", "Nameplates", "cast.showName"), "literal setting names still work")
K.Options.Open("General")
settle()
local function ornamentRow()
	for i, item in ipairs(ns.Window.State().items) do
		if item.module == "Widgets" and item.key == "ornaments" then return rowAt(i) end
	end
	error("no ornament row")
end
local row = ornamentRow()
assert(row.item.kind == "ornaments", "G9: ornament levels have samples by default")
for i, value in ipairs({ "Off", "Subtle", "Full" }) do
	local card = row.controls.ornaments.cards[i]
	assert(card.sample:GetWidth() == 180 and card.sample:GetHeight() == 90, "G9: samples are 180 by 90")
	W.Click(card)
	settle()
	assert(K.Options.Read("Widgets", "ornaments") == value, "the sample chooses the existing " .. value .. " level")
end
K.Options.Write("OptionsPresentation", "samples", false)
settle()
assert(ornamentRow().item.kind == "segmented", "G9: Off restores the text-only picker")
K.Options.Write("OptionsPresentation", "tasks", false)
K.Options.Open("General")
ns.Window.Frame():Close()
K.Options.Open()
settle()
assert(ns.Window.State().page == "General" and ns.Pages.List()[1].id == "General", "G9: Off restores the previous opening page")
assert(#env._errors == 0, table.concat(env._errors, "\n"))
print("options tasks ok")
