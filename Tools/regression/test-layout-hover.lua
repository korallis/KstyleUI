-- test-layout-hover.lua: the mouseover rule finds the pointer over content Layout cannot hook: children made after the rule applied, frames mirrored over the element from outside its tree, and frames that deny access.
local W = dofile("Tools/regression/widget_env.lua")

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 1e-6)
end

-- Element(env, K, key, opts) -> a frame on the root registered with Layout under the mouseover rule, faded out.
local function Element(env, K, key, opts)
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	frame:SetSize(220, 46)
	K.Layout.Register(frame, key, { anchor = "CENTER" }, opts or { label = key })
	assert(K.Layout.Set(key, "shown", "mouseover"))
	W.Settle(env)
	assert(frame:GetAlpha() == 0, key .. " starts faded out")
	return frame
end

-- Poll(env) runs one tick of every ticker, then the tweens to their end.
local function Poll(env)
	env.RunTickers()
	W.Settle(env)
end

local function Enter(env, frame)
	W.Enter(frame)
	W.Settle(env)
end

-- Leave(env, frame) moves the pointer off the frame and runs the next frame's hover check.
local function Leave(env, frame)
	frame._mouseOver = false
	W.Leave(frame)
	env.RunTimers()
	W.Settle(env)
end

-- A child made after the rule applied keeps the mouse focus, so only the element's rect sees the pointer ---------------

do
	local env, K = W.New()
	local frame = Element(env, K, "Test.Late")
	local content = env.CreateFrame("Frame", nil, frame)
	local icon = env.CreateFrame("Button", nil, content)
	icon:EnableMouse(true)
	frame._mouseOver = true
	Poll(env)
	assert(near(frame:GetAlpha(), 1), "the pointer over a late child, inside the element's rect, shows the element")
	frame._mouseOver = false
	Poll(env)
	assert(frame:GetAlpha() == 0, "and the element hides once the pointer leaves its rect")
	Enter(env, icon)
	assert(near(frame:GetAlpha(), 1), "the start of that hover hooked the late child, so its OnEnter now shows the element at once")
	Leave(env, icon)
	assert(frame:GetAlpha() == 0, "and its OnLeave hides it")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A late child hooked while the pointer is already on it missed its OnEnter, so the hook pass counts it as hovered ---------

do
	local env, K = W.New()
	local frame = Element(env, K, "Test.Reach")
	local flyout = env.CreateFrame("Button", nil, frame)
	frame._mouseOver, flyout._mouseOver = true, true
	Poll(env)
	assert(near(frame:GetAlpha(), 1))
	frame._mouseOver = false
	Poll(env)
	assert(near(frame:GetAlpha(), 1), "the pointer on the part of the child outside the element keeps it shown")
	Leave(env, flyout)
	assert(frame:GetAlpha() == 0, "and leaving the child hides it")
end

-- A frame mirrored over the element from outside its tree, as the Auras host is, shows it and is never touched -----------

do
	local env, K = W.New()
	local holder = Element(env, K, "Test.Host")
	local host = env.CreateFrame("Frame", nil, K.Scale.Root())
	host:SetFrameLevel(holder:GetFrameLevel() + 2)
	local container = env.CreateFrame("Frame", nil, host)
	local button = env.CreateFrame("Button", nil, container)
	button:EnableMouse(true)
	holder._mouseOver = true
	Poll(env)
	assert(near(holder:GetAlpha(), 1), "the pointer on a button of the mirrored frame shows the element")
	holder._mouseOver = false
	Poll(env)
	assert(holder:GetAlpha() == 0)
	for _, frame in ipairs({ host, container, button }) do
		assert(#W.Calls(frame, "HookScript") == 0, "Layout never hooks a frame outside the element's tree")
		assert(#W.Calls(frame, "IsMouseOver") == 0, "nor reads one")
	end
end

-- The poll runs only while an element uses the mouseover rule, and skips an element whose module is off -------------------

do
	local env, K = W.New()
	local Layout = K.Layout
	local base = env.LiveTickers()
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	frame:SetSize(100, 40)
	Layout.Register(frame, "Test.Poll", { anchor = "CENTER" }, { label = "Poll" })
	assert(env.LiveTickers() == base, "no poll while every element is shown always")
	assert(Layout.Set("Test.Poll", "shown", "mouseover"))
	assert(env.LiveTickers() == base + 1, "the mouseover rule starts one poll")
	local off = Element(env, K, "Test.Off", { label = "Off", module = "UnitFrames" })
	assert(env.LiveTickers() == base + 1, "a second element shares the poll")
	off._mouseOver = true
	Poll(env)
	assert(off:GetAlpha() == 0, "an element whose module is off is not polled")
	assert(Layout.Set("Test.Off", "shown", "always"))
	assert(Layout.Set("Test.Poll", "shown", "always"))
	assert(env.LiveTickers() == base, "the poll stops when no element needs it")
end

-- The element's OnShow hooks children made while it was hidden ----------------------------------------------------------

do
	local env, K = W.New()
	local frame = Element(env, K, "Test.Shown")
	frame:Hide()
	local icon = env.CreateFrame("Button", nil, frame)
	frame:Show()
	frame:GetScript("OnShow")(frame)
	Enter(env, icon)
	assert(near(frame:GetAlpha(), 1), "a child made while the element was hidden shows it once the element shows")
	Leave(env, icon)
	assert(frame:GetAlpha() == 0)
end

-- The start of a hover through a hooked frame hooks children made since --------------------------------------------------

do
	local env, K = W.New()
	local frame = Element(env, K, "Test.Start")
	local icon = env.CreateFrame("Button", nil, frame)
	Enter(env, frame)
	assert(near(frame:GetAlpha(), 1))
	Leave(env, frame)
	assert(frame:GetAlpha() == 0)
	Enter(env, icon)
	assert(near(frame:GetAlpha(), 1), "a child made before the last hover started is hooked")
	Leave(env, icon)
	assert(frame:GetAlpha() == 0, "and its OnLeave ends the hover")
end

-- A frame that denies access, such as an aura button while auras are secret, never raises an error -------------------------
-- W.Settle reads every frame's OnUpdate, so each test lifts the denial before it settles.

do
	local env, K = W.New()
	local frame = Element(env, K, "Test.Denied")
	local open = env.CreateFrame("Button", nil, frame)
	local locked = env.CreateFrame("Button", nil, frame)
	env.CreateFrame("Frame", nil, locked)
	locked._denied = true
	frame:GetScript("OnShow")(frame)
	assert(open:GetScript("OnEnter") ~= nil, "hooking skips a frame that denies access and goes on to the others")
	locked._denied = false
	frame:GetScript("OnShow")(frame)
	Enter(env, locked)
	assert(near(frame:GetAlpha(), 1), "a skipped frame is hooked once it allows access again")
	locked._denied = true
	frame._mouseOver = false
	env.RunTickers()
	locked._denied = false
	W.Settle(env)
	assert(frame:GetAlpha() == 0, "a hovered frame that now denies access counts as not under the pointer")

	local odd = env.CreateFrame("Frame", nil, frame)
	odd.GetChildren = function()
		return env.Secret(true)
	end
	frame:GetScript("OnShow")(frame)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("layout hover ok")
