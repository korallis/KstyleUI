-- test-options-entry.lua: Blizzard's Settings panel gets a KstyleUI canvas category, and the addon compartment entry opens the settings window.
local W = dofile("Tools/regression/widget_env.lua")

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local function devlog(env, text)
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if tostring(entry.message):find(text, 1, true) then
			return true
		end
	end
	return false
end

-- A stand-in for Blizzard's Settings API and the on-demand settings addon.
local function setup(record)
	return function(env)
		env.Settings = {
			RegisterCanvasLayoutCategory = function(frame, name)
				record.canvas = { frame = frame, name = name }
				record.category = { name = name }
				return record.category, {}
			end,
			RegisterAddOnCategory = function(category)
				record.added = category
			end,
		}
		env.C_AddOns = {
			LoadAddOn = function(name)
				record.loaded = name
				env.KstyleUI.Options.SetWindow(function(page)
					record.opened = (record.opened or 0) + 1
					record.page = page
				end)
				return true
			end,
		}
	end
end

-- PLAYER_LOGIN registers one canvas category, built from the kit on first show ----------------------

do
	local record = {}
	local env = W.New({ setup = setup(record), boot = false })
	assert(record.canvas == nil, "nothing registers before login")
	W.CoreEnv.Boot(env)
	assert(record.canvas and record.canvas.name == "KstyleUI", "the category is named KstyleUI")
	assert(record.added == record.category, "the category is registered as an addon category")
	local canvas = record.canvas.frame
	assert(#{ canvas:GetChildren() } == 0, "the canvas builds nothing until it is shown")
	env.FireEvent("PLAYER_LOGIN")
	assert(record.added == record.category, "a second PLAYER_LOGIN does not register again")

	canvas:GetScript("OnShow")(canvas)
	local button = canvas.openButton
	assert(button and button.label and button.label:GetText() ~= "", "the canvas has an open button")
	local children = #{ canvas:GetChildren() }
	canvas:GetScript("OnShow")(canvas)
	assert(#{ canvas:GetChildren() } == children, "showing the canvas again builds nothing new")

	W.Click(button)
	assert(record.loaded == "KstyleUI_Options" and record.opened == 1, "the button loads and opens the settings window")
end

-- The addon compartment calls a global that the core TOC names --------------------------------------

do
	local toc = read("KstyleUI.toc")
	assert(toc:find("\n## AddonCompartmentFunc: KstyleUI_OnAddonCompartmentClick\r?\n"), "the core TOC declares the compartment function")
	local record = {}
	local env = W.New({ setup = setup(record) })
	assert(type(env.KstyleUI_OnAddonCompartmentClick) == "function", "the compartment function is a global")
	env.KstyleUI_OnAddonCompartmentClick("KstyleUI", "LeftButton")
	assert(record.opened == 1 and record.page == nil, "a click opens the settings window")
end

-- A client without the Settings API, or one that refuses the category, logs and carries on -----------

do
	local env = W.New({ boot = false })
	env.Settings = nil
	W.CoreEnv.Boot(env)
	assert(#env._errors == 0, "a missing Settings API raises nothing")
	assert(devlog(env, "Settings"), "a missing Settings API is logged")
end

do
	local env = W.New({
		boot = false,
		setup = function(e)
			e.Settings = {
				RegisterCanvasLayoutCategory = function()
					error("blocked")
				end,
				RegisterAddOnCategory = function() end,
			}
		end,
	})
	W.CoreEnv.Boot(env)
	assert(#env._errors == 0, "a refused category raises nothing")
	assert(devlog(env, "blocked"), "the refusal is logged")
end

print("options entry ok")
