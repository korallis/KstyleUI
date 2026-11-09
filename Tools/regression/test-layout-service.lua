-- test-layout-service.lua: KstyleUI.Layout's registry: Register, Elements, Get, Set, per-profile saving, re-application, shown rules, opacity, undo and Layout Mode sessions.
local W = dofile("Tools/regression/widget_env.lua")
local CoreEnv = W.CoreEnv

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 1e-6)
end

local function whole(units, pixel)
	local n = units / pixel
	return math.abs(n - math.floor(n + 0.5)) < 1e-6
end

local function CreateFrameFor(K)
	return K._env.CreateFrame("Frame", nil, K.Scale.Root())
end

-- Element(K, key, opts, position, w, h) -> a frame on the root registered with Layout.
local function Element(K, key, opts, position, w, h)
	local frame = CreateFrameFor(K)
	frame:SetSize(w or 220, h or 46)
	K.Layout.Register(frame, key, position or { anchor = "BOTTOM", x = -200, y = 260 }, opts or { label = "Player" })
	return frame
end

local function New(opts)
	local env, K = W.New(opts)
	K._env = env
	env._blocked = {}
	return env, K
end

-- Protect(env, frame) makes the frame protected and records each protected call made in combat outside
-- secure code, as the game would block it with ADDON_ACTION_BLOCKED.
local PROTECTED = { "SetPoint", "ClearAllPoints", "SetAllPoints", "SetSize", "SetWidth", "SetHeight", "SetScale", "SetFrameStrata", "Show", "Hide", "SetShown", "SetAttribute", "SetMouseMotionEnabled", "EnableMouse" }
local function Protect(env, frame)
	frame.IsProtected = function()
		return true, true
	end
	for _, method in ipairs(PROTECTED) do
		local original = frame[method]
		frame[method] = function(self, ...)
			if env._combat and not env._secure then
				env._blocked[#env._blocked + 1] = method
			end
			return original(self, ...)
		end
	end
	if not env._driversWrapped then
		env._driversWrapped = true
		for _, name in ipairs({ "RegisterStateDriver", "UnregisterStateDriver" }) do
			local original = env[name]
			env[name] = function(...)
				if env._combat then
					env._blocked[#env._blocked + 1] = name
				end
				return original(...)
			end
		end
	end
	return frame
end

local function Point(frame)
	local p = frame._points[1]
	return p[1], p[2], p[3], p[4], p[5]
end

-- Register, Elements and Get ---------------------------------------------------------------------------

do
	local env, K = New()
	local Layout = K.Layout
	assert(type(Layout.Register) == "function" and type(Layout.Elements) == "function", "the shared Layout API exists")
	local frame = Element(K, "Test.Player", {
		label = "Player", module = "UnitFrames", resizable = true,
		minWidth = 120, maxWidth = 400, minHeight = 30, maxHeight = 90,
	})
	local list = Layout.Elements()
	assert(#list == 1 and list[1].key == "Test.Player" and list[1].label == "Player" and list[1].module == "UnitFrames", "Elements lists the element")
	assert(list[1].opts.resizable == true and list[1].opts.maxWidth == 400, "Elements gives the element's opts")
	list[1].opts.maxWidth = 1
	assert(Layout.Elements()[1].opts.maxWidth == 400, "Elements hands out copies")

	local s = Layout.Get("Test.Player")
	assert(s.anchor == "BOTTOM" and s.x == -200 and s.y == 260, "Get gives the default position")
	assert(s.width == 220 and s.height == 46 and s.scale == 1, "the default size is the frame's size")
	assert(s.shown == "always" and s.alphaCombat == 1 and s.alphaIdle == 1, "shown always at full opacity")
	assert(s.strata == "MEDIUM", "the default strata is the frame's")
	s.x = 999
	assert(Layout.Get("Test.Player").x == -200, "Get hands out a copy")
	assert(Layout.Get("Nope") == nil, "an unknown key gives nil")

	local anchor, relative, relativePoint, x, y = Point(frame)
	assert(anchor == "BOTTOM" and relative == K.Scale.Root() and relativePoint == "BOTTOM", "the frame is anchored to the root")
	assert(near(x, -200) and near(y, 260), "at its default offsets")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Register checks its arguments ------------------------------------------------------------------------

do
	local _, K = New()
	local Layout, Raises = K.Layout, W.Raises
	local frame = CreateFrameFor(K)
	Raises(function() Layout.Register(nil, "A", { anchor = "CENTER" }) end, "frame", "a missing frame")
	Raises(function() Layout.Register(frame, "", { anchor = "CENTER" }) end, "key", "an empty key")
	Raises(function() Layout.Register(frame, string.rep("k", 65), { anchor = "CENTER" }) end, "key", "a key over 64 characters")
	Raises(function() Layout.Register(frame, "A", { anchor = "MIDDLE" }) end, "anchor", "a bad anchor")
	Raises(function() Layout.Register(frame, "A", { anchor = "CENTER", x = "1" }) end, "x", "a bad offset")
	Raises(function() Layout.Register(frame, "A", { anchor = "CENTER" }, { colour = true }) end, "colour", "an unknown option")
	Raises(function() Layout.Register(frame, "A", { anchor = "CENTER" }, { minWidth = -1 }) end, "minWidth", "a bad limit")
	Layout.Register(frame, "A", { anchor = "CENTER" })
	assert(Layout.Get("A").x == 0 and Layout.Get("A").label == nil, "offsets default to 0")
	Layout.Register(frame, "A", { anchor = "TOP", x = 1, y = -2 }, { label = "Again" })
	assert(#Layout.Elements() == 1 and Layout.Elements()[1].label == "Again", "registering a key again updates it")
	assert(Layout.Get("A").anchor == "TOP", "with its new default")
end

-- Set stores, applies and fires LayoutChanged -------------------------------------------------------------

do
	local env, K = New()
	local Layout = K.Layout
	local frame = Element(K, "Test.Player", { label = "Player", resizable = true, minWidth = 120, maxWidth = 400, minHeight = 30, maxHeight = 90 })
	local fired = {}
	K.Callbacks.Register("LayoutChanged", "test", function(_, key)
		fired[#fired + 1] = key
	end)
	assert(Layout.Set("Test.Player", "x", -150) == true)
	assert(fired[1] == "Test.Player", "Set fires LayoutChanged(key)")
	assert(Layout.Get("Test.Player").x == -150)
	assert(near(select(4, Point(frame)), -150), "Set applies at once")
	local saved = K.Store.Layout()["Test.Player"]
	assert(saved and saved.x == -150 and saved.y == nil and saved.anchor == nil, "only the changed field is saved")
	assert(Layout.Set("Test.Player", "x", -200) == true)
	assert(K.Store.Layout()["Test.Player"] == nil, "a value back at its default leaves nothing saved")

	-- Bad values are refused with a reason and change nothing.
	local count = #fired
	for _, case in ipairs({
		{ "anchor", "MIDDLE" }, { "x", "far" }, { "x", 0 / 0 }, { "scale", 1.5 }, { "shown", "sometimes" },
		{ "alphaIdle", 2 }, { "alphaCombat", -1 }, { "strata", "TOOLTIP" }, { "nope", 1 },
	}) do
		local ok, why = Layout.Set("Test.Player", case[1], case[2])
		assert(ok == false and type(why) == "string", "Set refuses " .. case[1] .. " = " .. tostring(case[2]))
	end
	local ok = Layout.Set("Missing", "x", 1)
	assert(ok == false, "an unknown key is refused")
	assert(#fired == count, "a refused Set fires nothing")
	local secret = env.Secret(5)
	assert(Layout.Set("Test.Player", "x", secret) == false, "a secret is refused")

	-- Sizes clamp to the limits and land on whole pixels.
	assert(Layout.Set("Test.Player", "width", 9999))
	assert(Layout.Get("Test.Player").width == 400, "width clamps to maxWidth")
	assert(Layout.Set("Test.Player", "height", 1))
	assert(Layout.Get("Test.Player").height == 30, "height clamps to minHeight")
	assert(Layout.Set("Test.Player", "width", 250.4))
	assert(whole(frame:GetWidth(), K.Scale.Pixel(1)), "the applied width is whole pixels")

	-- Strata, opacity and the shown rule.
	assert(Layout.Set("Test.Player", "strata", "HIGH"))
	assert(W.LastCall(frame, "SetFrameStrata")[1] == "HIGH", "strata applies")
	assert(Layout.Set("Test.Player", "alphaIdle", 0.5))
	W.Settle(env)
	assert(near(frame:GetAlpha(), 0.5), "idle opacity applies")

	-- nil resets one field.
	assert(Layout.Set("Test.Player", "strata", nil))
	assert(Layout.Get("Test.Player").strata == "MEDIUM", "nil resets a field to its default")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Changing the anchor keeps the element where it is ----------------------------------------------------

do
	local _, K = New()
	local Layout, G = K.Layout, K.Layout.Geometry
	local frame = Element(K, "Test.Box", { label = "Box" }, { anchor = "CENTER", x = 300, y = -100 }, 100, 40)
	assert(Layout.Set("Test.Box", "anchor", "TOPLEFT"))
	local s = Layout.Get("Test.Box")
	assert(s.anchor == "TOPLEFT", "the anchor changes")
	local l, b = G.Rect("TOPLEFT", s.x, s.y, 100, 40, 1920, 1080)
	assert(near(l, 960 + 300 - 50) and near(b, 540 - 100 - 20), "the element stays in place")
	assert(Point(frame) == "TOPLEFT")
end

-- Scalable and aspect-locked elements ---------------------------------------------------------------------

do
	local _, K = New()
	local Layout = K.Layout
	local frame = Element(K, "Test.Scaled", { label = "Scaled", scalable = true }, { anchor = "CENTER" }, 100, 40)
	assert(Layout.Set("Test.Scaled", "scale", 1.5))
	assert(frame:GetScale() == 1.5, "scale applies")
	assert(Layout.Set("Test.Scaled", "scale", 9))
	assert(Layout.Get("Test.Scaled").scale == 2, "scale clamps to 2")
	assert(Layout.Set("Test.Scaled", "scale", 0.1))
	assert(Layout.Get("Test.Scaled").scale == 0.5, "and to 0.5")
	assert(Layout.Set("Test.Scaled", "width", 300) == false, "a scalable element that is not resizable refuses a width")
	assert(Layout.Set("Test.Scaled", "x", 40))
	local _, _, _, x = Point(frame)
	assert(near(x * 0.5, 40), "offsets are root units at any scale")

	local box = Element(K, "Test.Aspect", { label = "Aspect", resizable = true, aspect = true, minWidth = 20, maxWidth = 400, minHeight = 10, maxHeight = 200 }, { anchor = "CENTER" }, 100, 50)
	assert(Layout.Set("Test.Aspect", "width", 200))
	assert(Layout.Get("Test.Aspect").height == 100, "aspect locking moves the height with the width")
	assert(Layout.Set("Test.Aspect", "height", 30))
	assert(Layout.Get("Test.Aspect").width == 60, "and the width with the height")
	assert(box:GetWidth() == 60 and box:GetHeight() == 30)
	assert(Layout.Update("Test.Aspect", { height = 40 }))
	assert(Layout.Get("Test.Aspect").width == 80 and Layout.Get("Test.Aspect").height == 40, "Update with a height alone keeps the aspect")
	assert(Layout.Update("Test.Aspect", { anchor = "TOP", bogus = 1 }) == false, "Update refuses an unknown field")
	assert(Layout.Get("Test.Aspect").anchor == "CENTER", "and changes nothing")
	assert(Layout.Rect("Missing") == nil, "Rect of an unknown key is nil")
end

-- Per-profile persistence ------------------------------------------------------------------------------

do
	local env, K = New()
	local Layout, Store = K.Layout, K.Store
	local frame = Element(K, "Test.Player")
	assert(Layout.Set("Test.Player", "y", 300))
	local fired = 0
	K.Callbacks.Register("LayoutChanged", "test", function()
		fired = fired + 1
	end)
	assert(Store.SetProfile("Other"))
	assert(Layout.Get("Test.Player").y == 260, "another profile has its own layout")
	assert(near(select(5, Point(frame)), 260), "a profile change re-applies the layout")
	assert(fired >= 1, "and fires LayoutChanged")
	assert(Store.SetProfile("Default"))
	assert(Layout.Get("Test.Player").y == 300 and near(select(5, Point(frame)), 300), "the first profile kept its position")
	CoreEnv.Logout(env)
	local layouts = env.KstyleUIDB.layouts
	assert(layouts.Default["Test.Player"].y == 300, "positions save per profile")
end

-- Saved positions load, before and after registration --------------------------------------------------------

do
	local saved = {
		version = 1,
		profiles = { Default = {} },
		characters = {},
		layouts = { Default = {
			["Test.Early"] = { anchor = "TOP", x = 5, y = -10 },
			["Test.Late"] = { anchor = "LEFT", x = 30, y = 0 },
			["Test.Bad"] = { anchor = "MIDDLE", x = "far", scale = 99, shown = 7, alphaIdle = 3, width = -5 },
		} },
		account = {},
		devlog = {},
	}
	local env, K = New({ saved = saved, boot = false })
	K._env = env
	local early = Element(K, "Test.Early", { label = "Early" })
	assert(Point(early) == "BOTTOM", "before the saved data loads, the default applies")
	CoreEnv.Boot(env)
	assert(Point(early) == "TOP" and near(select(4, Point(early)), 5), "the saved position applies once the data loads")
	local late = Element(K, "Test.Late", { label = "Late" })
	assert(Point(late) == "LEFT" and near(select(4, Point(late)), 30), "an element registered later gets its saved position")
	local bad = Element(K, "Test.Bad", { label = "Bad", scalable = true, resizable = true })
	local s = K.Layout.Get("Test.Bad")
	assert(s.anchor == "BOTTOM" and s.x == -200 and s.scale == 1 and s.shown == "always" and s.alphaIdle == 1 and s.width == 220, "damaged saved values fall back to the defaults")
	assert(Point(bad) == "BOTTOM")
	local logged = false
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		logged = logged or (entry.module == "Layout" and entry.message:find("Test.Bad", 1, true) ~= nil)
	end
	assert(logged, "a damaged saved value is logged")
end

-- Re-application on ScaleChanged: positions and sizes stay on whole physical pixels ------------------------------

do
	local env, K = New({ width = 2560, height = 1440 })
	local Scale = K.Scale
	local frame = Element(K, "Test.Px", { label = "Px", resizable = true, minWidth = 10, maxWidth = 900, minHeight = 10, maxHeight = 900 }, { anchor = "CENTER", x = 10.4, y = -3.3 }, 221, 47)
	local pixel = Scale.Pixel(1)
	assert(near(pixel, 0.75), "1440p has 0.75 units a pixel")
	local function edgesWhole()
		local p = Scale.Pixel(1)
		local _, _, _, x, y = Point(frame)
		local w, h = frame:GetWidth(), frame:GetHeight()
		local rw, rh = 2560 / 1440 * 1080 / Scale.UserScale(), 1080 / Scale.UserScale()
		return whole(w, p) and whole(h, p) and whole(rw / 2 + x - w / 2, p) and whole(rh / 2 + y - h / 2, p)
	end
	assert(edgesWhole(), "edges and sizes are whole pixels")
	local count = #W.Calls(frame, "SetPoint")
	assert(K.Scale.SetUserScale(1.25))
	assert(#W.Calls(frame, "SetPoint") > count, "ScaleChanged re-applies the layout")
	assert(edgesWhole(), "and keeps whole pixels at the new size")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Shown rules on a Lua frame --------------------------------------------------------------------------------

do
	local env, K = New()
	local Layout = K.Layout
	local frame = Element(K, "Test.Lua", { label = "Lua" })
	assert(Layout.Set("Test.Lua", "shown", "combat"))
	assert(frame:IsShown() == false, "combat only: hidden out of combat")
	env.SetCombat(true)
	assert(frame:IsShown() == true, "shown in combat")
	env.SetCombat(false)
	assert(frame:IsShown() == false, "hidden again after combat")
	assert(Layout.Set("Test.Lua", "shown", "noCombat"))
	assert(frame:IsShown() == true, "out of combat only: shown out of combat")
	env.SetCombat(true)
	assert(frame:IsShown() == false, "hidden in combat")
	env.SetCombat(false)
	assert(Layout.Set("Test.Lua", "shown", "target"))
	assert(frame:IsShown() == false, "with a target: hidden without one")
	env.SetTarget(true)
	assert(frame:IsShown() == true, "shown with a target")
	env.SetTarget(false)
	assert(frame:IsShown() == false)
	assert(Layout.Set("Test.Lua", "shown", "never"))
	frame:Show()
	frame:GetScript("OnShow")(frame)
	assert(frame:IsShown() == false, "never: a Show from the module is undone")
	assert(Layout.Set("Test.Lua", "shown", "always"))
	assert(frame:IsShown() == true, "always: the frame Layout hid shows again")

	-- A frame its module hid stays hidden when the rule allows it again.
	assert(Layout.Set("Test.Lua", "shown", "combat"))
	env.SetCombat(true)
	assert(frame:IsShown() == true)
	frame:Hide()
	env.SetCombat(false)
	assert(Layout.Set("Test.Lua", "shown", "always"))
	assert(frame:IsShown() == false, "Layout shows only frames it hid")

	-- Opacity in and out of combat.
	frame:Show()
	assert(Layout.Set("Test.Lua", "alphaCombat", 0.3) and Layout.Set("Test.Lua", "alphaIdle", 0.8))
	W.Settle(env)
	assert(near(frame:GetAlpha(), 0.8), "idle opacity")
	env.SetCombat(true)
	W.Settle(env)
	assert(near(frame:GetAlpha(), 0.3), "combat opacity")
	env.SetCombat(false)
	W.Settle(env)
	assert(near(frame:GetAlpha(), 0.8))
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Mouseover: hidden until the pointer is over the frame or one of its children --------------------------------------

do
	local env, K = New()
	local Layout = K.Layout
	local frame = Element(K, "Test.Hover", { label = "Hover" })
	local child = env.CreateFrame("Button", nil, frame)
	assert(Layout.Set("Test.Hover", "shown", "mouseover"))
	W.Settle(env)
	assert(frame:IsShown() and frame:GetAlpha() == 0, "mouseover: shown at alpha 0")
	assert(#W.Calls(frame, "SetMouseMotionEnabled") == 1, "a frame without the mouse gets motion events so the pointer finds it")
	W.Enter(frame)
	W.Settle(env)
	assert(near(frame:GetAlpha(), 1), "the pointer over the frame shows it")
	frame._mouseOver = true
	W.Leave(frame)
	env.RunTimers()
	W.Settle(env)
	assert(near(frame:GetAlpha(), 1), "moving onto a child keeps it shown")
	frame._mouseOver = false
	W.Leave(child)
	env.RunTimers()
	W.Settle(env)
	assert(frame:GetAlpha() == 0, "leaving hides it again")
	W.Enter(child)
	W.Settle(env)
	assert(near(frame:GetAlpha(), 1), "a child's OnEnter shows it")
	-- A child that reaches outside the frame keeps it shown while the pointer is on the child.
	child._mouseOver = true
	W.Leave(frame)
	env.RunTimers()
	W.Settle(env)
	assert(near(frame:GetAlpha(), 1), "a hovered child outside the frame keeps it shown")
	child._mouseOver = false
	W.Leave(child)
	env.RunTimers()
	W.Settle(env)
	assert(frame:GetAlpha() == 0, "leaving the child hides it")
	W.Enter(child)
	W.Settle(env)
	assert(Layout.Set("Test.Hover", "shown", "always"))
	W.Settle(env)
	assert(near(frame:GetAlpha(), 1), "leaving the mouseover rule restores the opacity")
end

-- Shown rules on a secure frame: a state driver, and nothing protected in combat ----------------------------------------

do
	local env, K = New()
	local Layout = K.Layout
	local frame = Protect(env, CreateFrameFor(K))
	frame:SetSize(100, 40)
	Layout.Register(frame, "Test.Secure", { anchor = "CENTER" }, { label = "Secure", scalable = true })
	assert(Layout.Set("Test.Secure", "shown", "combat"))
	assert(env.Driver(frame, "visibility") == "[combat] show; hide", "a secure frame gets a visibility state driver")
	assert(frame:IsShown() == false)
	env.SetCombat(true)
	assert(frame:IsShown() == true, "the driver shows it in combat")
	assert(Layout.Set("Test.Secure", "x", 50))
	assert(Layout.Set("Test.Secure", "shown", "never"))
	assert(Layout.Set("Test.Secure", "alphaCombat", 0.5))
	W.Settle(env)
	assert(near(frame:GetAlpha(), 0.5), "opacity applies in combat")
	assert(#env._blocked == 0, "no protected call in combat, got " .. tostring(env._blocked[1]))
	assert(env.Driver(frame, "visibility") == "[combat] show; hide", "the driver waits for the end of combat")
	env.SetCombat(false)
	assert(env.Driver(frame, "visibility") == "hide", "then changes")
	assert(near(select(4, Point(frame)), 50), "and the position applies")
	assert(Layout.Set("Test.Secure", "shown", "always"))
	assert(env.Driver(frame, "visibility") == nil and frame:IsShown(), "always removes the driver and shows the frame")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Layout Mode sessions: Enter, Exit, undo, redo, reset, and combat ----------------------------------------------------

do
	local env, K = New()
	local Layout = K.Layout
	local frame = Protect(env, Element(K, "Test.Player"))
	Element(K, "Test.Other", { label = "Other" }, { anchor = "TOP", x = 0, y = -50 })
	assert(Layout.IsActive() == false)
	assert(Layout.Enter() == true and Layout.IsActive(), "Enter opens Layout Mode")
	assert(Layout.Set("Test.Player", "x", 0) and Layout.Set("Test.Player", "y", 400))
	assert(Layout.CanUndo(), "changes in Layout Mode go on the history")
	assert(Layout.Undo() and Layout.Get("Test.Player").y == 260, "undo restores the last change")
	assert(Layout.Redo() and Layout.Get("Test.Player").y == 400, "redo applies it again")
	assert(Layout.ResetAll() and Layout.Get("Test.Player").x == -200 and Layout.Get("Test.Player").y == 260, "reset reverts every element")
	assert(Layout.Undo() and Layout.Get("Test.Player").y == 400, "a reset is one undoable change")
	assert(Layout.Set("Test.Other", "y", -80))
	assert(Layout.Reset("Test.Other") and Layout.Get("Test.Other").y == -50, "Reset reverts one element")
	Layout.Exit(true)
	assert(not Layout.IsActive() and Layout.Get("Test.Player").y == 400, "Exit(true) keeps the changes")
	assert(not Layout.CanUndo(), "the history belongs to one session")

	assert(Layout.Enter())
	assert(Layout.Set("Test.Player", "y", 500))
	Layout.Exit(false)
	assert(Layout.Get("Test.Player").y == 400 and near(select(5, Point(frame)), 400), "Exit(false) restores the saved positions")

	-- Review Focus 3: combat while Layout Mode is open.
	assert(Layout.Enter())
	assert(Layout.Set("Test.Player", "y", 600) and Layout.Set("Test.Other", "x", 77))
	env.SetCombat(true)
	assert(not Layout.IsActive(), "combat leaves Layout Mode")
	assert(Layout.Get("Test.Player").y == 400 and Layout.Get("Test.Other").x == 0, "and restores the saved positions")
	assert(near(select(5, Point(frame)), 400), "the frames are back")
	assert(#env._blocked == 0, "no protected call in combat, got " .. tostring(env._blocked[1]))
	assert(CoreEnv.Printed(env, "combat"), "the player is told why")
	assert(Layout.Enter() == false and not Layout.IsActive(), "Layout Mode does not open in combat")
	assert(CoreEnv.Printed(env, "after combat"))
	env.SetCombat(false)
	assert(Layout.Toggle() == true and Layout.IsActive(), "Toggle opens it")
	Layout.Toggle()
	assert(not Layout.IsActive(), "and closes it")
	env.SlashCmdList.KSTYLE("layout")
	assert(Layout.IsActive(), "/kstyle layout toggles Layout Mode")
	Layout.Exit(true)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Combat restores a combat rule changed in Layout Mode, and the restored rule reads combat correctly ----------------------

do
	local env, K = New()
	local Layout = K.Layout
	local frame = Element(K, "Test.Fight")
	assert(Layout.Set("Test.Fight", "shown", "combat"))
	assert(frame:IsShown() == false)
	assert(Layout.Enter())
	assert(Layout.Set("Test.Fight", "shown", "always"))
	assert(frame:IsShown() == true)
	env.SetCombat(true)
	assert(Layout.Get("Test.Fight").shown == "combat", "combat restores the saved rule")
	assert(frame:IsShown() == true, "and the restored combat rule shows the frame in combat")
	env.SetCombat(false)
	assert(frame:IsShown() == false, "then hides it after combat")
end

-- Registering a key again with another frame moves the state driver and starts the new frame clean -------------------------

do
	local env, K = New()
	local Layout = K.Layout
	local first = Protect(env, CreateFrameFor(K))
	Layout.Register(first, "Test.Swap", { anchor = "CENTER" }, { label = "Swap" })
	assert(Layout.Set("Test.Swap", "shown", "never") and Layout.Set("Test.Swap", "alphaIdle", 0.5))
	assert(env.Driver(first, "visibility") == "hide")
	local second = Protect(env, CreateFrameFor(K))
	Layout.Register(second, "Test.Swap", { anchor = "CENTER" }, { label = "Swap" })
	assert(env.Driver(first, "visibility") == nil, "the old frame loses its driver")
	assert(env.Driver(second, "visibility") == "hide", "the new frame gets it")
	W.Settle(env)
	assert(math.abs(second:GetAlpha() - 0.5) < 1e-6, "and its opacity")
end

-- A protected frame of a module that is off stays hidden when its rule no longer hides it ----------------------------------

do
	local env, K = New()
	local Layout = K.Layout
	local frame = Protect(env, CreateFrameFor(K))
	Layout.Register(frame, "Test.Off", { anchor = "CENTER" }, { label = "Off", module = "UnitFrames" })
	frame:Hide()
	assert(Layout.Set("Test.Off", "shown", "combat"))
	assert(env.Driver(frame, "visibility") == nil, "an element of a module that is off gets no state driver")
	env.SetCombat(true)
	assert(frame:IsShown() == false, "so combat does not show it")
	env.SetCombat(false)
	assert(Layout.Set("Test.Off", "shown", "always"))
	assert(frame:IsShown() == false, "and Layout never shows a frame of a module that is off")
end

-- A module that stops takes its element's state driver with it, and gets it back when it starts ---------------------------

do
	local env, K = New()
	local Layout = K.Layout
	local frame
	local def = CoreEnv.Module("UnitFrames", {
		onEnable = function()
			if not frame then
				frame = Protect(env, CreateFrameFor(K))
				frame:SetSize(100, 40)
				Layout.Register(frame, "UnitFrames.Test", { anchor = "CENTER" }, { label = "Test", module = "UnitFrames" })
			end
			frame:Show()
		end,
		onDisable = function()
			frame:Hide()
		end,
	})
	K.Modules.Register(def)
	local changes = {}
	K.Callbacks.Register("ModuleChanged", "test", function(_, name, running)
		changes[#changes + 1] = name .. ":" .. tostring(running)
	end)
	K.Modules.Enable("UnitFrames")
	assert(K.Modules.IsRunning("UnitFrames") and frame, "the module runs and registers its element")
	assert(changes[1] == "UnitFrames:true", "ModuleChanged fires when a module starts")
	assert(Layout.Set("UnitFrames.Test", "shown", "combat"))
	assert(env.Driver(frame, "visibility") == "[combat] show; hide")
	K.Modules.Disable("UnitFrames")
	assert(changes[2] == "UnitFrames:false", "and when it stops")
	assert(env.Driver(frame, "visibility") == nil, "a stopped module's element loses its state driver")
	env.SetCombat(true)
	assert(frame:IsShown() == false, "so combat does not show a stopped module's frame")
	env.SetCombat(false)
	K.Modules.Enable("UnitFrames")
	assert(env.Driver(frame, "visibility") == "[combat] show; hide", "the driver returns when the module starts")
end

-- A widget's own restyle keeps the size and scale Layout gave it, and a new scale redraws its chrome in whole pixels --------

do
	local env, K = New()
	local Layout, Widgets, Scale = K.Layout, K.Widgets, K.Scale
	local panel = Widgets.Panel(Scale.Root(), {
		width = 220, height = 100,
		layout = { key = "Test.Panel", position = { anchor = "CENTER" }, options = { label = "Panel", resizable = true, scalable = true, maxWidth = 600 } },
	})
	assert(Layout.Set("Test.Panel", "width", 400))
	assert(panel:GetWidth() == 400)
	Widgets.RestyleAll()
	assert(panel:GetWidth() == 400, "a widget restyle keeps the width Layout owns")
	assert(Layout.Set("Test.Panel", "scale", 1.25))
	env.RunTimers()
	local corner = panel.chrome.rim[1]
	assert(near(corner:GetWidth(), Scale.Snap(panel.chrome:Radius() * 1.25) / 1.25), "a new scale redraws the rounded corners in whole pixels")
	Widgets.RestyleAll()
	assert(panel:GetScale() == 1.25 and panel:GetWidth() == 400, "and a later restyle keeps both")
end

-- A new scale restyles only the widgets inside the scaled element, not every widget in the UI -----------------------------

do
	local env, K = New()
	local Layout, Widgets, Scale = K.Layout, K.Widgets, K.Scale
	local panel = Widgets.Panel(Scale.Root(), {
		width = 220, height = 100,
		layout = { key = "Test.Scaled", position = { anchor = "CENTER" }, options = { label = "Scaled", scalable = true } },
	})
	local inside = Widgets.Button(panel, { text = "Inside" })
	local outside = Widgets.Button(Scale.Root(), { text = "Outside" })
	local counts = {}
	for _, widget in ipairs({ panel, inside, outside }) do
		local restyle = widget.Restyle
		counts[widget] = 0
		widget.Restyle = function(self, ...)
			counts[self] = counts[self] + 1
			return restyle(self, ...)
		end
	end
	assert(Layout.Set("Test.Scaled", "scale", 1.5))
	env.RunTimers()
	assert(counts[panel] == 1 and counts[inside] == 1, "the scaled element and the widgets inside it restyle once")
	assert(counts[outside] == 0, "a widget outside the scaled element does not restyle")
	assert(Layout.Set("Test.Scaled", "scale", 1.25))
	assert(Layout.Set("Test.Scaled", "scale", 1.5))
	env.RunTimers()
	assert(counts[panel] == 2 and counts[inside] == 2, "several scale changes in one frame restyle once")
end

-- A module can switch one of its elements off: no plate in Layout Mode and Live reads false ------------------------------

do
	local env, K = New()
	local Layout = K.Layout
	Element(K, "Test.Live")
	local changed = {}
	K.Callbacks.Register("LayoutChanged", "test", function(_, key)
		changed[#changed + 1] = key
	end)
	assert(Layout.Live("Test.Live"), "an element is live by default")
	assert(Layout.Enter())
	assert(Layout.Mode.Plate("Test.Live"):IsShown(), "a live element has a plate")
	assert(Layout.SetLive("Test.Live", false) == true)
	assert(not Layout.Live("Test.Live"), "SetLive(false) takes it out")
	assert(not Layout.Mode.Plate("Test.Live"):IsShown(), "and hides its plate at once")
	assert(changed[#changed] == "Test.Live", "LayoutChanged tells the settings window")
	local count = #changed
	Layout.SetLive("Test.Live", false)
	assert(#changed == count, "the same state again fires nothing")
	local listed
	for _, el in ipairs(Layout.Elements()) do
		if el.key == "Test.Live" then
			listed = el
		end
	end
	assert(listed and listed.live == false, "Elements reports it")
	Layout.SetLive("Test.Live", true)
	assert(Layout.Live("Test.Live") and Layout.Mode.Plate("Test.Live"):IsShown(), "SetLive(true) brings the plate back")
	Layout.Exit(true)
	assert(Layout.SetLive("Test.Missing", false) == false, "an unknown key is refused")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A profile switch while Layout Mode is open ends the session without restoring the old profile's snapshot ---------------

do
	local _, K = New()
	local Layout = K.Layout
	Element(K, "Test.Player")
	assert(Layout.Enter())
	assert(Layout.Set("Test.Player", "y", 333))
	assert(K.Store.SetProfile("Second"))
	assert(not Layout.IsActive(), "a profile change closes Layout Mode")
	assert(Layout.Get("Test.Player").y == 260, "the new profile's layout applies")
	assert(K.Store.SetProfile("Default"))
	assert(Layout.Get("Test.Player").y == 333, "the old profile kept the change")
end

-- Layout listens for combat and target events only while an element or Layout Mode needs them ----------------------------

do
	local env, K = New()
	local Layout = K.Layout
	local function listeners(event)
		local n = 0
		for _, frame in ipairs(env._frames) do
			if frame:IsEventRegistered(event) then
				n = n + 1
			end
		end
		return n
	end
	Element(K, "Test.Quiet")
	assert(listeners("PLAYER_REGEN_DISABLED") == 0 and listeners("PLAYER_REGEN_ENABLED") == 0, "an element shown always at one opacity needs no combat events")
	assert(listeners("PLAYER_TARGET_CHANGED") == 0, "nor the target event")
	assert(Layout.Enter())
	assert(listeners("PLAYER_REGEN_DISABLED") == 1, "Layout Mode listens for the start of combat")
	Layout.Exit(true)
	assert(listeners("PLAYER_REGEN_DISABLED") == 0, "and stops when it closes")
	assert(Layout.Set("Test.Quiet", "alphaCombat", 0.5))
	assert(listeners("PLAYER_REGEN_DISABLED") == 1 and listeners("PLAYER_REGEN_ENABLED") == 1, "a combat opacity listens for combat")
	assert(Layout.Set("Test.Quiet", "alphaCombat", 1))
	assert(listeners("PLAYER_REGEN_ENABLED") == 0, "and stops when it no longer needs to")
	assert(Layout.Set("Test.Quiet", "shown", "target"))
	assert(listeners("PLAYER_TARGET_CHANGED") == 1, "the target rule listens for target changes")
	env.SetCombat(true)
	assert(Layout.Set("Test.Quiet", "shown", "combat"))
	assert(Layout.Element("Test.Quiet").frame:IsShown() == true, "a combat rule set in combat reads the combat state when it starts listening")
	env.SetCombat(false)
	assert(Layout.Element("Test.Quiet").frame:IsShown() == false, "and follows it after")
end

-- Layout Mode's own settings are declared for the settings window -----------------------------------------------------

do
	local _, K = New()
	local settings = K.Store.Module("Layout")
	assert(settings.grid == false and settings.snap == true and settings.gridSize == 16 and settings.snapDistance == 8, "Layout Mode's settings and defaults")
	local schema = K.Options.Get("Layout")
	assert(type(schema) == "table" and K.Options.Row("Layout", "gridSize").type == "slider", "the settings page is registered")
	assert(type(K.Layout.SHOWN_OPTIONS) == "table" and #K.Layout.SHOWN_OPTIONS == 6, "the shown rule options for the settings window")
	assert(type(K.Layout.STRATA_OPTIONS) == "table" and #K.Layout.STRATA_OPTIONS == 4)
	assert(type(K.Layout.ANCHOR_OPTIONS) == "table" and #K.Layout.ANCHOR_OPTIONS == 9)
end

print("layout service ok")
