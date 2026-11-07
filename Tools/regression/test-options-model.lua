-- test-options-model.lua: the settings window's row visibility (showWhen, disableWhen, empty and hidden sections) and its search matching.
local O = dofile("Tools/regression/options_env.lua")
local Module = O.W.CoreEnv.Module
local Labels = O.Labels

local function same(list, expected, what)
	local got = table.concat(list, "|")
	assert(got == table.concat(expected, "|"), what .. ": got " .. got)
end

local function devlog(env, text)
	local n = 0
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if tostring(entry.message):find(text, 1, true) then
			n = n + 1
		end
	end
	return n
end

local env, _, ns = O.New()
local Model = ns.Model
assert(type(Model) == "table", "KstyleUI_Options exposes its model")

local function yes()
	return true
end
local function no()
	return false
end

-- IsShown and IsDisabled ------------------------------------------------------------------------

do
	assert(Model.IsShown({ kind = "toggle", label = "A" }) == true, "a row with no showWhen shows")
	assert(Model.IsShown({ kind = "toggle", label = "A", showWhen = no }) == false, "showWhen false hides the row")
	local seen
	local item = {
		kind = "toggle", label = "A",
		settings = function()
			return { portraits = true }
		end,
		showWhen = function(settings)
			seen = settings
			return settings.portraits
		end,
	}
	assert(Model.IsShown(item) == true and seen.portraits == true, "showWhen gets the module's settings")
	local broken = { kind = "toggle", label = "Broken", showWhen = function() error("boom") end }
	assert(Model.IsShown(broken) == true, "a showWhen that fails shows the row")
	assert(Model.IsShown(broken) == true)
	assert(devlog(env, "boom") == 1, "a failing condition is logged once")

	assert(Model.IsDisabled({ kind = "toggle", label = "A" }) == false)
	assert(Model.IsDisabled({ kind = "toggle", label = "A", disableWhen = yes }) == true, "disableWhen true disables")
	assert(Model.IsDisabled({ kind = "toggle", label = "A", disabled = true }) == true, "a fixed disabled flag disables")
	assert(Model.IsDisabled({ kind = "toggle", label = "A", disableWhen = function() error("bad") end }) == false, "a failing disableWhen leaves the row enabled")
end

-- Visible: hidden rows, empty sections and hidden sections ------------------------------------------

do
	local items = {
		{ kind = "toggle", label = "Loose" },
		{ kind = "header", label = "Frames" },
		{ kind = "toggle", label = "Portraits" },
		{ kind = "color", label = "Portrait colour", showWhen = no },
		{ kind = "header", label = "Empty" },
		{ kind = "slider", label = "Gone", showWhen = no },
		{ kind = "header", label = "Hidden section", showWhen = no },
		{ kind = "toggle", label = "Under hidden" },
		{ kind = "header", label = "Sub", level = 2 },
		{ kind = "toggle", label = "Under hidden sub" },
		{ kind = "header", label = "Back" },
		{ kind = "header", label = "Element", level = 2 },
		{ kind = "toggle", label = "Shown rule" },
		{ kind = "header", label = "Hidden element", level = 2, showWhen = no },
		{ kind = "toggle", label = "Element row" },
		{ kind = "header", label = "Next element", level = 2 },
		{ kind = "toggle", label = "Visible again" },
		{ kind = "header", label = "Trailing" },
	}
	same(Labels(Model.Visible(items)), {
		"Loose", "Frames", "Portraits", "Back", "Element", "Shown rule", "Next element", "Visible again",
	}, "Visible")
	assert(#items == 18, "Visible leaves the input list alone")
	assert(#Model.Visible({}) == 0)
end

-- Search terms and matching --------------------------------------------------------------------

do
	same(Model.Terms("  Health  BAR "), { "health", "bar" }, "Terms splits and lowers")
	assert(#Model.Terms("") == 0 and #Model.Terms(nil) == 0 and #Model.Terms("   ") == 0, "a blank query has no terms")
	assert(Model.Matches("Health bar colour", Model.Terms("bar HEALTH")) == true, "every term, any order, any case")
	assert(Model.Matches("Health bar colour", Model.Terms("bar mana")) == false, "every term must match")
	assert(Model.Matches("Opacity (100%)", Model.Terms("(100%")) == true, "terms are plain text, not patterns")
	assert(Model.Matches("anything", {}) == true)
end

local function pages()
	return {
		{
			id = "UnitFrames", label = "Unit Frames",
			items = {
				{ kind = "header", label = "Player frame" },
				{ kind = "toggle", label = "Show player frame", help = "Display your unit frame on screen." },
				{ kind = "dropdown", label = "Health bar style", help = "Choose the appearance of the health bar." },
				{ kind = "color", label = "Health bar colour", help = "The colour in custom mode.", showWhen = no },
				{ kind = "header", label = "Auras and debuffs" },
				{ kind = "slider", label = "Aura size", help = "Sets the size of aura icons." },
			},
		},
		{
			id = "Nameplates", label = "Nameplates",
			items = {
				{ kind = "slider", label = "Plate width", help = "How wide each plate is." },
				{ kind = "toggle", label = "Show health text", help = "Shows health as a percentage." },
			},
		},
		{
			id = "Built", label = "Built later",
			Items = function()
				return { { kind = "text", label = "Profile name", help = "Health is not here." } }
			end,
		},
	}
end

do
	assert(Model.Search(pages(), "") == nil and Model.Search(pages(), "   ") == nil, "a blank query is no search")

	local found = Model.Search(pages(), "health")
	same(Labels(found), {
		"Unit Frames", "Player frame", "Health bar style",
		"Nameplates", "Show health text",
		"Built later", "Profile name",
	}, "Search groups matches under page and section headers")
	assert(found[1].kind == "header" and (found[1].level or 1) == 1, "the page is a level 1 header")
	assert(found[2].kind == "header" and found[2].level == 2, "the section is a level 2 header")
	assert(found[3].page == "UnitFrames" and found[5].page == "Nameplates", "each result knows its page")

	same(Labels(Model.Search(pages(), "UNIT aura")), { "Unit Frames", "Auras and debuffs", "Aura size" }, "terms match the page and section names too")
	same(Labels(Model.Search(pages(), "percentage")), { "Nameplates", "Show health text" }, "help text matches")
	same(Labels(Model.Search(pages(), "custom mode")), {}, "a row hidden by showWhen is not found")
	same(Labels(Model.Search(pages(), "zzz")), {}, "no match is an empty list")
end

-- Search finds a scoped row whichever value its selector holds -------------------------------------

do
	local settings = { edit = "player", target = { custom = false } }
	local function scoped(kind, kindOf, label, extra)
		return {
			kind = kindOf, label = label, help = "",
			settings = function()
				return settings
			end,
			showWhen = function(s)
				return s.edit == kind and (extra == nil or extra(s[kind]))
			end,
			scope = { key = "edit", value = kind },
		}
	end
	local list = {
		{
			id = "UnitFrames", label = "Unit Frames",
			items = {
				{ kind = "dropdown", label = "Frame to customise", help = "Pick a frame." },
				scoped("player", "header", "Player: health bar"),
				scoped("player", "texture", "Bar texture"),
				scoped("target", "header", "Target: health bar"),
				scoped("target", "texture", "Bar texture"),
				scoped("target", "color", "Custom bar colour", function(t)
					return t.custom
				end),
			},
		},
	}
	local items = list[1].items
	same(Labels(Model.Visible(items)), { "Frame to customise", "Player: health bar", "Bar texture" }, "the page shows only the picked frame")
	local found = Model.Search(list, "bar texture")
	same(Labels(found), { "Unit Frames", "Player: health bar", "Bar texture", "Target: health bar", "Bar texture" }, "search finds every frame's rows")
	assert(found[3] == items[3] and found[5] == items[5], "each result is the row bound to its own frame")
	same(Labels(Model.Search(list, "custom bar")), {}, "search still hides a row that its own condition hides")
	settings.target.custom = true
	same(Labels(Model.Search(list, "custom bar")), { "Unit Frames", "Target: health bar", "Custom bar colour" }, "the row's own condition decides")
	assert(settings.edit == "player", "search leaves the selector setting alone")
	same(Labels(Model.Visible(items)), { "Frame to customise", "Player: health bar", "Bar texture" }, "the page still follows the selector")
end

-- Schema rows bind to the module's settings ----------------------------------------------------------

do
	local env2, K2, ns2 = O.New({
		before = function(_, Kb)
			Kb.Modules.Register(Module("UnitFrames", { defaults = { portraits = true, size = 20, colour = { r = 1, g = 0, b = 0 } } }))
			Kb.Options.Register("UnitFrames", {
				{ type = "header", label = "Frames" },
				{ type = "toggle", key = "portraits", label = "Portraits", help = "Show portraits." },
				{ type = "slider", key = "size", label = "Size", help = "Portrait size.", min = 10, max = 40, step = 1, disableWhen = function(s) return not s.portraits end },
				{ type = "color", key = "colour", label = "Colour", help = "Portrait ring colour.", showWhen = function(s) return s.portraits end },
			})
		end,
	})
	local changes = {}
	K2.Callbacks.Register("SettingChanged", "test", function(_, module, key, value)
		changes[#changes + 1] = module .. "." .. key .. "=" .. tostring(value)
	end)
	local items = ns2.Model.SchemaItems("UnitFrames", K2.Options.Get("UnitFrames"), "UnitFrames")
	assert(#items == 4 and items[1].kind == "header" and items[2].kind == "toggle", "one item per row, in order")
	local toggle, slider, colour = items[2], items[3], items[4]
	assert(toggle.page == "UnitFrames" and toggle.module == "UnitFrames" and toggle.key == "portraits")
	assert(colour.kind == "color" and colour.get().r == 1, "a colour row reads its table")
	assert(toggle.get() == true and slider.get() == 20, "get reads the active profile")
	assert(slider.min == 10 and slider.max == 40 and slider.step == 1, "slider limits carry over")
	same(Labels(ns2.Model.Visible(items)), { "Frames", "Portraits", "Size", "Colour" }, "all rows show with portraits on")
	assert(ns2.Model.IsDisabled(slider) == false)
	toggle.set(false)
	assert(changes[1] == "UnitFrames.portraits=false", "set writes through Options.Write")
	assert(K2.Store.Module("UnitFrames").portraits == false)
	same(Labels(ns2.Model.Visible(items)), { "Frames", "Portraits", "Size" }, "showWhen follows the new value")
	assert(ns2.Model.IsDisabled(slider) == true, "disableWhen follows the new value")
	assert(#env2._errors == 0)
end

-- A schema row's scope reaches the item, so search finds it ------------------------------------------

do
	local _, K3, ns3 = O.New({
		before = function(_, Kb)
			Kb.Modules.Register(Module("ActionBars", { defaults = { editBar = "a", a = { size = 30 }, b = { size = 30 } } }))
			local function editing(key)
				return function(s)
					return s.editBar == key
				end
			end
			local schema = {
				{ type = "dropdown", key = "editBar", label = "Bar to edit", help = "Pick a bar.", options = {
					{ value = "a", label = "Bar A" }, { value = "b", label = "Bar B" },
				} },
			}
			for _, key in ipairs({ "a", "b" }) do
				local scope = { key = "editBar", value = key }
				schema[#schema + 1] = { type = "header", label = "Bar " .. key, showWhen = editing(key), scope = scope }
				schema[#schema + 1] = {
					type = "slider", key = key .. ".size", label = "Button size", help = "The size of each button.",
					min = 16, max = 64, step = 1, showWhen = editing(key), scope = scope,
				}
			end
			Kb.Options.Register("ActionBars", schema)
		end,
	})
	local items = ns3.Model.SchemaItems("ActionBars", K3.Options.Get("ActionBars"), "ActionBars")
	assert(items[5].scope and items[5].scope.value == "b", "a schema row's scope reaches its item")
	local list = { { id = "ActionBars", label = "Action Bars", items = items } }
	same(Labels(ns3.Model.Visible(items)), { "Bar to edit", "Bar a", "Button size" }, "the page shows the picked bar")
	local found = ns3.Model.Search(list, "button size")
	same(Labels(found), { "Action Bars", "Bar a", "Button size", "Bar b", "Button size" }, "search finds every bar's rows")
	assert(found[5].key == "b.size", "the second result edits bar b")
	assert(K3.Store.Module("ActionBars").editBar == "a", "search does not change the picked bar")
end

print("options model ok")
