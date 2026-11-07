-- test-options-registry.lua: Options.Register validates declarative setting rows against the module's defaults, and Read, Write and Open behave.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local Raises, Module = CoreEnv.Raises, CoreEnv.Module

local function fresh()
	local env, K = CoreEnv.New()
	K.Modules.Register(Module("UnitFrames", {
		defaults = {
			portraits = true,
			width = 220,
			texture = "Flat",
			font = "Body",
			label = "Player",
			mode = "class",
			colour = { r = 0.5, g = 0.5, b = 0.5 },
			player = { healthText = { size = 11 } },
		},
	}))
	return env, K
end

local function rows()
	local showWhen = function(db)
		return db.portraits
	end
	return {
		{ type = "header", label = "Frames" },
		{ type = "toggle", key = "enabled", label = "Enable", help = "Turn the unit frames on or off." },
		{ type = "toggle", key = "portraits", label = "Portraits", help = "Show a portrait on each frame." },
		{ type = "slider", key = "width", label = "Width", help = "Frame width in units.", min = 100, max = 400, step = 1, disableWhen = showWhen },
		{ type = "slider", key = "player.healthText.size", label = "Text size", help = "Health text size.", min = 6, max = 24, step = 1 },
		{ type = "dropdown", key = "mode", label = "Colour", help = "Where the bar colour comes from.", options = {
			{ value = "class", label = "Class" }, { value = "reaction", label = "Reaction" }, { value = "custom", label = "Custom" },
		} },
		{ type = "color", key = "colour", label = "Custom colour", help = "The bar colour in custom mode.", showWhen = showWhen },
		{ type = "texture", key = "texture", label = "Texture", help = "The bar texture." },
		{ type = "font", key = "font", label = "Font", help = "The text font." },
		{ type = "text", key = "label", label = "Label", help = "Text shown on the frame.", maxLetters = 32 },
	}
end

-- A valid schema registers, and Get returns it in order --------------------------------------------

do
	local _, K = fresh()
	local schema = rows()
	K.Options.Register("UnitFrames", schema)
	local got = K.Options.Get("UnitFrames")
	assert(type(got) == "table" and #got == #schema, "Get returns every row")
	for i, row in ipairs(schema) do
		assert(got[i].type == row.type and got[i].key == row.key, "row " .. i .. " keeps its place")
	end
	assert(K.Options.Get("ActionBars") == nil, "a module with no schema returns nil")
	assert(K.Options.Row("UnitFrames", "player.healthText.size").max == 24, "Row finds a row by key")
	assert(K.Options.Row("UnitFrames", "nope") == nil)
	local list = K.Options.List()
	-- The core registers its own Appearance page at load, before any module.
	assert(#list == 2 and list[1] == "Appearance" and list[2] == "UnitFrames", "List names every schema in registration order")
	Raises(function() K.Options.Register("UnitFrames", rows()) end, "already registered", "a second schema for one module")
end

-- Every rule names the row and the problem ---------------------------------------------------------

local function rejects(change, want, label)
	local _, K = fresh()
	local schema = rows()
	change(schema)
	Raises(function() K.Options.Register("UnitFrames", schema) end, want, label)
end

rejects(function(s) s[3].type = "checkbox" end, "unknown type checkbox", "an unknown row type")
rejects(function(s) s[3].key = nil end, "key", "a setting row without a key")
rejects(function(s) s[3].label = nil end, "label", "a row without a label")
rejects(function(s) s[3].help = nil end, "help", "a setting row without help")
rejects(function(s) s[3].help = string.rep("h", 100) end, "under 100", "help of 100 characters or more")
rejects(function(s) s[3].key = "nope" end, "no default", "a key the defaults do not have")
rejects(function(s) s[3].key = "player.missing.size" end, "no default", "a nested key the defaults do not have")
rejects(function(s) s[3].key = "player..size" end, "key", "a malformed key")
rejects(function(s) s[3].showWhen = true end, "showWhen", "a showWhen that is not a function")
rejects(function(s) s[4].disableWhen = "portraits" end, "disableWhen", "a disableWhen that is not a function")
rejects(function(s) s[3].showwhen = function() end end, "unknown field showwhen", "a misspelt field")
rejects(function(s) s[1].key = "portraits" end, "header", "a header with a key")
rejects(function(s) s[3].type = "slider"; s[3].min = 0; s[3].max = 1; s[3].step = 1 end, "number", "a slider on a boolean")
rejects(function(s) s[4].min = nil end, "min", "a slider without min")
rejects(function(s) s[4].min = 500 end, "min", "a slider whose min is not below max")
rejects(function(s) s[4].step = 0 end, "step", "a slider with no step")
rejects(function(s) s[4].max = 200 end, "range", "a slider whose default is outside its range")
rejects(function(s) s[6].options = nil end, "options", "a dropdown without options")
rejects(function(s) s[6].options = { { value = "class" } } end, "label", "a dropdown option without a label")
rejects(function(s) table.remove(s[6].options, 1) end, "default", "a dropdown whose default is not an option")
rejects(function(s) s[7].key = "texture" end, "colour", "a colour row on a string")
rejects(function(s) s[8].key = "width" end, "string", "a texture row on a number")
rejects(function(s) s[10].maxLetters = 0 end, "maxLetters", "a text row with a bad maxLetters")
rejects(function(s) s[11] = s[3] end, "twice", "the same key twice")
rejects(function(s) s[2].type = "slider"; s[2].min = 0; s[2].max = 1; s[2].step = 1 end, "number", "a slider on the module switch")

do
	local _, K = fresh()
	Raises(function() K.Options.Register("ActionBars", { { type = "header", label = "Bars" } }) end, "defaults", "a module whose defaults are not registered")
	Raises(function() K.Options.Register("UnitFrames", "rows") end, "schema", "a schema that is not a list")
	Raises(function() K.Options.Register("UnitFrames", { [2] = rows()[2] }) end, "schema", "a schema with a gap")
	K.Store.RegisterDefaults("General", { scale = 1 })
	K.Options.Register("General", {
		{ type = "slider", key = "scale", label = "Scale", help = "The size of everything.", min = 0.75, max = 1.5, step = 0.05 },
	})
	assert(K.Options.Get("General")[1].key == "scale", "a core service registers its own page after its defaults")
	-- A dropdown may list its options at run time.
	K.Store.RegisterDefaults("Fonts", { face = "Body" })
	K.Options.Register("Fonts", {
		{ type = "dropdown", key = "face", label = "Face", help = "The font face.", options = function()
			return { { value = "Body", label = "Body" } }
		end },
	})
end

-- Read and Write -----------------------------------------------------------------------------------

do
	local env, K = fresh()
	K.Options.Register("UnitFrames", rows())
	CoreEnv.Boot(env)
	local changes = {}
	K.Callbacks.Register("SettingChanged", "test", function(_, module, key, value)
		changes[#changes + 1] = module .. "." .. key .. "=" .. tostring(value)
	end)
	assert(K.Options.Read("UnitFrames", "player.healthText.size") == 11, "Read follows a dotted key")
	K.Options.Write("UnitFrames", "player.healthText.size", 14)
	assert(K.Store.Module("UnitFrames").player.healthText.size == 14, "Write stores the value in the profile")
	assert(changes[1] == "UnitFrames.player.healthText.size=14", "Write fires SettingChanged(module, key, value)")
	Raises(function() K.Options.Write("UnitFrames", "width", "wide") end, "number", "Write of the wrong type")
	Raises(function() K.Options.Write("UnitFrames", "nope", 1) end, "no default", "Write of an unknown key")
	Raises(function() K.Options.Read("UnitFrames", "nope") end, "no default", "Read of an unknown key")

	-- The module switch goes through the lifecycle.
	K.Options.Write("UnitFrames", "enabled", true)
	assert(K.Modules.IsRunning("UnitFrames"), "writing the switch starts the module")
	K.Options.Write("UnitFrames", "enabled", false)
	assert(not K.Modules.IsRunning("UnitFrames"), "writing the switch stops the module")
end

-- Open loads the settings addon on demand and shows its window --------------------------------------

do
	local loads = {}
	local env, K = CoreEnv.New({
		setup = function(env)
			env.C_AddOns = {
				LoadAddOn = function(name)
					loads[#loads + 1] = name
					env.KstyleUI.Options.SetWindow(function(page)
						loads[#loads + 1] = "open:" .. tostring(page)
					end)
					return true
				end,
				IsAddOnLoaded = function()
					return false, false
				end,
			}
		end,
	})
	CoreEnv.Boot(env)
	assert(K.Options.Open("UnitFrames") == true)
	assert(loads[1] == "KstyleUI_Options" and loads[2] == "open:UnitFrames", "Open loads KstyleUI_Options, then opens the page")
	assert(K.Options.Open() == true and #loads == 3 and loads[3] == "open:nil", "a loaded window opens without loading again")
	Raises(function() K.Options.SetWindow("show") end, "function", "SetWindow without a function")

	local env2, K2 = CoreEnv.New({
		setup = function(e)
			e.C_AddOns = {
				LoadAddOn = function()
					return false, "DISABLED"
				end,
			}
		end,
	})
	CoreEnv.Boot(env2)
	assert(K2.Options.Open() == false, "Open reports a settings addon that cannot load")
	assert(CoreEnv.Printed(env2, "DISABLED"), "the player sees why the settings cannot open")
	local env3, K3 = CoreEnv.New()
	CoreEnv.Boot(env3)
	assert(K3.Options.Open() == false and CoreEnv.Printed(env3, "settings"), "no C_AddOns: Open says the settings are unavailable")
end

print("options registry ok")
