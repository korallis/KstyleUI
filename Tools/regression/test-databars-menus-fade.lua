-- test-databars-menus-fade.lua: the micro menu and the bag bar are out of sight at rest, as the owner's picture shows neither, and fade in while the pointer is over them, in Blizzard's Edit Mode and KstyleUI's Layout Mode, while a bag is open (the bag bar), while the game points at a micro button (the micro menu), and always with their setting; only KstyleUI's own content frames change alpha, in or out of combat, and Blizzard's frames are never hidden, moved or faded by the fade.
local D = dofile("Tools/regression/databars_env.lua")
local W = D.W

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local function Boot(extra)
	local world = { bagOpen = false, editMode = false, tip = false, callbacks = {} }
	local env, K, ns = D.New({
		setup = function(env, game)
			D.Menus(env)
			env.IsAnyBagOpen = function()
				return world.bagOpen
			end
			env.EditModeManagerFrame = env.CreateFrame("Frame", "EditModeManagerFrame", env.UIParent)
			env.EditModeManagerFrame.IsEditModeActive = function()
				return world.editMode
			end
			env.EventRegistry = {
				RegisterCallback = function(_, event, fn, owner)
					world.callbacks[event] = world.callbacks[event] or {}
					world.callbacks[event][owner or fn] = fn
				end,
			}
			env.HelpTip = {
				IsShowingAnyInSystem = function(_, system)
					return world.tip and system == "MicroButtons"
				end,
				Show = function() end,
				Hide = function() end,
				HideAllSystem = function() end,
				Release = function() end,
			}
			env.MicroButtonPulse = env.MicroButtonPulse or function() end
			env.MicroButtonPulseStop = env.MicroButtonPulseStop or function() end
			if extra then
				extra(env, game)
			end
		end,
	})
	env.RunTimers()
	W.Settle(env)
	return env, K, ns, world
end

local function Alpha(env, ns, id)
	env.RunTimers()
	W.Settle(env)
	return ns.Menus.Content(id):GetAlpha()
end

local function Fire(world, event)
	for _, fn in pairs(world.callbacks[event] or {}) do
		fn()
	end
end

local BLIZZARD = { "MicroMenuContainer", "MicroMenu", "BagsBar", "CharacterMicroButton", "MainMenuMicroButton", "MainMenuBarBackpackButton" }

local function Untouched(env, marks, what)
	for _, name in ipairs(BLIZZARD) do
		local frame = env[name]
		if frame then
			for i = (marks[name] or 0) + 1, #frame._calls do
				local method = frame._calls[i].method
				assert(method ~= "SetAlpha" and method ~= "Hide" and method ~= "SetShown" and method ~= "SetParent" and method ~= "SetPoint",
					what .. ": Blizzard's " .. name .. " is left alone, got " .. method)
			end
		end
	end
end

local function Mark(env)
	local marks = {}
	for _, name in ipairs(BLIZZARD) do
		if env[name] then
			marks[name] = #env[name]._calls
		end
	end
	return marks
end

-- At rest both rows are laid out but invisible; the pointer brings a row in and takes it away again --------------

do
	local env, _, ns = Boot()
	local marks = Mark(env)
	local tickers = env.LiveTickers()
	eq(Alpha(env, ns, "micro"), 0, "the micro menu is out of sight at rest")
	eq(Alpha(env, ns, "bags"), 0, "the bag bar is out of sight at rest")
	assert(ns.Menus.Content("micro"):IsShown() and ns.Menus.Content("bags"):IsShown(), "both stay shown, so they fade by alpha alone")
	local micro = ns.Menus.Shown("micro")[1]
	W.Enter(micro)
	eq(Alpha(env, ns, "micro"), 1, "the pointer over a micro button brings the micro menu in")
	eq(Alpha(env, ns, "bags"), 0, "and leaves the bag bar out of sight")
	-- Between two buttons the pointer is still over the row, so it stays.
	ns.Menus.Content("micro")._mouseOver = true
	W.Leave(micro)
	eq(Alpha(env, ns, "micro"), 1, "in the gap between buttons the row stays in sight")
	ns.Menus.Content("micro")._mouseOver = false
	env.RunTickers()
	eq(Alpha(env, ns, "micro"), 0, "once the pointer leaves the row it fades out")
	eq(env.LiveTickers(), tickers, "and nothing keeps watching the pointer")
	local bag = ns.Menus.Shown("bags")[1]
	W.Enter(bag)
	eq(Alpha(env, ns, "bags"), 1, "the bag bar comes in under the pointer")
	W.Leave(bag)
	eq(Alpha(env, ns, "bags"), 0, "and goes again")
	Untouched(env, marks, "hover")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- In combat the fade is the same, and it only ever sets the alpha of KstyleUI's own content frame -------------------

do
	local env, _, ns = Boot()
	local content = ns.Menus.Content("micro")
	local buttons = ns.Menus.Shown("micro")
	local marks = Mark(env)
	local mark, buttonMarks = #content._calls, {}
	for i, b in ipairs(buttons) do
		buttonMarks[i] = #b._calls
	end
	env.SetCombat(true)
	W.Enter(buttons[2])
	eq(Alpha(env, ns, "micro"), 1, "in combat the pointer still brings the micro menu in")
	W.Leave(buttons[2])
	eq(Alpha(env, ns, "micro"), 0, "and the row fades out again in combat")
	local PROTECTED = {
		SetPoint = true, ClearAllPoints = true, SetAllPoints = true, SetSize = true, SetWidth = true, SetHeight = true, SetScale = true,
		Show = true, Hide = true, SetShown = true, SetParent = true, SetFrameLevel = true, SetAttribute = true, EnableMouse = true,
	}
	local faded = 0
	for i = mark + 1, #content._calls do
		local method = content._calls[i].method
		assert(not PROTECTED[method], "in combat the row's frame only changes its alpha, got " .. method)
		faded = faded + (method == "SetAlpha" and 1 or 0)
	end
	assert(faded > 0, "the row fades by SetAlpha")
	for i, b in ipairs(buttons) do
		for n = buttonMarks[i] + 1, #b._calls do
			assert(not PROTECTED[b._calls[n].method], "a secure micro button is never changed by the fade, got " .. b._calls[n].method)
		end
	end
	Untouched(env, marks, "combat")
	env.SetCombat(false)
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- The setting keeps both in sight; off again, they go back out of sight ------------------------------------------

do
	local env, K, ns = Boot()
	local row = assert(K.Options.Row("DataBars", "menus.always"), "menus.always has a settings row")
	eq(row.type, "toggle", "menus.always is a toggle")
	assert(type(row.help) == "string" and row.help ~= "", "with help text")
	K.Options.Write("DataBars", "menus.always", true)
	eq(Alpha(env, ns, "micro"), 1, "always shown: the micro menu is in sight")
	eq(Alpha(env, ns, "bags"), 1, "always shown: the bag bar is in sight")
	K.Options.Write("DataBars", "menus.always", false)
	eq(Alpha(env, ns, "micro"), 0, "the setting off, the micro menu goes")
	eq(Alpha(env, ns, "bags"), 0, "and the bag bar")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Edit Mode and Layout Mode show both, so they can be found and moved ----------------------------------------------

do
	local env, K, ns, world = Boot()
	world.editMode = true
	Fire(world, "EditMode.Enter")
	eq(Alpha(env, ns, "micro"), 1, "Blizzard's Edit Mode shows the micro menu")
	eq(Alpha(env, ns, "bags"), 1, "and the bag bar")
	world.editMode = false
	Fire(world, "EditMode.Exit")
	eq(Alpha(env, ns, "micro") + Alpha(env, ns, "bags"), 0, "leaving Edit Mode, both go")
	assert(K.Layout.Enter(), "Layout Mode opens")
	eq(Alpha(env, ns, "micro"), 1, "Layout Mode shows the micro menu")
	eq(Alpha(env, ns, "bags"), 1, "and the bag bar")
	K.Layout.Exit(true)
	eq(Alpha(env, ns, "micro") + Alpha(env, ns, "bags"), 0, "leaving Layout Mode, both go")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- An open bag keeps the bag bar in sight; the game pointing at a micro button keeps the micro menu in sight ---------

do
	local env, _, ns, world = Boot()
	local marks = Mark(env)
	world.bagOpen = true
	env.FireEvent("BAG_OPEN", 0)
	eq(Alpha(env, ns, "bags"), 1, "an open bag shows the bag bar")
	eq(Alpha(env, ns, "micro"), 0, "but not the micro menu")
	world.bagOpen = false
	env.FireEvent("BAG_CLOSED", 0)
	eq(Alpha(env, ns, "bags"), 0, "the bag closed, the bar goes")
	world.tip = true
	env.HelpTip:Show()
	eq(Alpha(env, ns, "micro"), 1, "a micro button help tip shows the micro menu")
	eq(Alpha(env, ns, "bags"), 0, "but not the bag bar")
	world.tip = false
	env.HelpTip:Hide()
	eq(Alpha(env, ns, "micro"), 0, "the tip gone, the menu goes")
	local target = env.CharacterMicroButton
	target.IsPulsing = function()
		return true
	end
	env.MicroButtonPulse(target)
	eq(Alpha(env, ns, "micro"), 1, "a pulsing micro button shows the micro menu")
	target.IsPulsing = function()
		return false
	end
	env.MicroButtonPulseStop(target)
	eq(Alpha(env, ns, "micro"), 0, "the pulse over, the menu goes")
	Untouched(env, marks, "bags and alerts")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- The pointer resting on a row's padding or a gap between buttons brings the row in too: the row takes mouse motion
-- (set out of combat), not clicks, so the world under it stays clickable ------------------------------------------

do
	local env, _, ns = Boot()
	local content = ns.Menus.Content("bags")
	local motion = W.Calls(content, "SetMouseMotionEnabled")
	assert(#motion == 1 and motion[1][1] == true, "the bag row takes mouse motion")
	eq(#W.Calls(content, "EnableMouse"), 0, "but not clicks")
	content._mouseOver = true
	W.Enter(content)
	eq(Alpha(env, ns, "bags"), 1, "the pointer on the row's padding brings the bag bar in")
	W.Leave(content)
	eq(Alpha(env, ns, "bags"), 1, "still over the row, it stays")
	content._mouseOver = false
	env.RunTickers()
	eq(Alpha(env, ns, "bags"), 0, "off the row, it goes")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- A profile switch recomputes the fade: each profile's own setting decides ------------------------------------------

do
	local env, K, ns = Boot()
	assert(K.Store.CopyProfile("Default", "Plain"), "a second profile with the setting off")
	K.Options.Write("DataBars", "menus.always", true)
	eq(Alpha(env, ns, "micro"), 1, "always shown in this profile")
	K.Store.SetProfile("Plain")
	eq(Alpha(env, ns, "micro"), 0, "the other profile's setting is off, so the micro menu goes")
	eq(Alpha(env, ns, "bags"), 0, "and the bag bar")
	K.Store.SetProfile("Default")
	eq(Alpha(env, ns, "micro"), 1, "back again, both come in")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- KstyleUI's bag window closed by its own button, with no bag toggle: the bag bar still goes -----------------------

do
	local env, K, ns, world = Boot()
	local window = env.CreateFrame("Frame", nil, env.UIParent)
	window:Hide()
	local element = K.Layout.Element
	K.Layout.Element = function(key)
		if key == "bags.inventory" then
			return { frame = window }
		end
		return element(key)
	end
	world.bagOpen = true
	env.FireEvent("BAG_OPEN", 0)
	eq(Alpha(env, ns, "bags"), 1, "a Blizzard bag open shows the bag bar")
	world.bagOpen = false
	-- The stub does not run OnShow and OnHide by itself, so the test runs them as the game would.
	window:Show()
	window:GetScript("OnShow")(window)
	eq(Alpha(env, ns, "bags"), 1, "KstyleUI's bag window open keeps it")
	window:Hide()
	window:GetScript("OnHide")(window)
	eq(Alpha(env, ns, "bags"), 0, "closing the window by its own button takes the bar away")
	K.Layout.Element = element
	eq(#env._errors, 0, tostring(env._errors[1]))
end

print("databars menus fade ok")
