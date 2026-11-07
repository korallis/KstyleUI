-- test-widgets-textarea.lua: the multi-line text area: a raised tile with a scrolling edit box, the kit's slim scroll bar, a read-only mode and select-all for copying.
local W = dofile("Tools/regression/widget_env.lua")

local function called(object, method)
	for _, call in ipairs(object._calls) do
		if call.method == method then
			return true
		end
	end
	return false
end

local function newArea(K, opts, range)
	local area = K.Widgets.TextArea(K.Scale.Root(), opts)
	rawset(area.scroll, "GetVerticalScrollRange", function()
		return range or 0
	end)
	area.scroll:SetHeight(100)
	return area
end

-- Build: a raised tile, a clipped scroll frame and a multi-line edit box in the body font.
do
	local env, K = W.New()
	local area = newArea(K, { width = 300, height = 120, text = "line one\nline two" })
	assert(area.chrome and #area.chrome.fill == 9, "a chamfered raised tile")
	assert(W.LastCall(area.box, "SetMultiLine")[1] == true, "a multi-line box")
	assert(W.LastCall(area.box, "SetAutoFocus")[1] == false, "it never takes focus by itself")
	assert(W.LastCall(area.scroll, "SetScrollChild")[1] == area.box, "the box scrolls")
	assert(W.LastCall(area.scroll, "SetClipsChildren")[1] == true, "and is clipped")
	local c = W.LastCall(area.box, "SetTextColor")
	local r, g, b = K.Tokens.Color("textEmphasis")
	assert(c and W.Near(c[1], r) and W.Near(c[2], g) and W.Near(c[3], b), "text in textEmphasis")
	assert(area:GetText() == "line one\nline two", "the starting text")
	area:SetText("other")
	assert(area:GetText() == "other" and area.box:GetText() == "other", "SetText")
	assert(type(area.Restyle) == "function", "it restyles with the kit")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The scroll bar shows while the text overflows; the wheel scrolls three lines, eased and clamped.
do
	local env, K = W.New()
	local area = newArea(K, { width = 300, height = 120 }, 300)
	area:Refresh()
	assert(area.bar:IsShown(), "a scroll bar while the text overflows")
	assert(area:GetMaxOffset() == 300, "the range comes from the scroll frame")
	area:Scroll(-1)
	W.Settle(env)
	local step = area:GetOffset()
	assert(step > 0 and step < 300, "one wheel step scrolls down part of the way: " .. step)
	assert(W.LastCall(area.scroll, "SetVerticalScroll")[1] == step, "through SetVerticalScroll")
	area:ScrollToBottom(true)
	assert(area:GetOffset() == 300, "to the bottom")
	area:Scroll(-1)
	W.Settle(env)
	assert(area:GetOffset() == 300, "never past the bottom")
	area:ScrollTo(-50, true)
	assert(area:GetOffset() == 0, "never above the top")
	local short = newArea(K, { width = 300, height = 120 }, 0)
	short:Refresh()
	assert(not short.bar:IsShown(), "no bar when everything fits")
end

-- The caret stays in view while it moves.
do
	local env, K = W.New()
	local area = newArea(K, { width = 300, height = 120 }, 1000)
	local view = area.scroll:GetHeight()
	area.box:GetScript("OnCursorChanged")(area.box, 0, -500, 2, 14)
	W.Settle(env)
	assert(math.abs(area:GetOffset() - (514 - view)) < 1e-6, "scrolled so the caret's line shows: " .. area:GetOffset())
	area.box:GetScript("OnCursorChanged")(area.box, 0, -10, 2, 14)
	W.Settle(env)
	assert(area:GetOffset() == 10, "and back up")
end

-- Read only: typing does nothing, SetText still works, and SelectAll selects everything for Ctrl+C.
do
	local _, K = W.New()
	local changes = {}
	local area = newArea(K, {
		text = "copy me",
		readOnly = true,
		onChange = function(text, _, userInput)
			changes[#changes + 1] = { text = text, user = userInput }
		end,
	})
	area.box:SetText("copy me!")
	area.box:GetScript("OnTextChanged")(area.box, true)
	assert(area.box:GetText() == "copy me", "a typed change is undone")
	area:SetText("new text")
	assert(area:GetText() == "new text", "SetText still sets the text")
	area:SelectAll()
	assert(called(area.box, "SetFocus") and called(area.box, "HighlightText"), "select all focuses and highlights")
	area.box:GetScript("OnEscapePressed")(area.box)
	assert(called(area.box, "ClearFocus"), "Escape leaves the box")
	area:SetReadOnly(false)
	area.box:SetText("typed")
	area.box:GetScript("OnTextChanged")(area.box, true)
	assert(area:GetText() == "typed" and changes[#changes].user == true, "an editable area reports typing")
end

-- Sizes: the defaults when the frame has none, even a zero size from the game; a range that shrinks mid-scroll clamps.
do
	local env, K = W.New()
	local area = K.Widgets.TextArea(K.Scale.Root(), {})
	area:SetSize(0, 0)
	area:Restyle()
	assert(area:GetWidth() == 300 and area:GetHeight() == 160, "300 by 160 by default, got " .. tostring(area:GetWidth()))
	local range = 300
	rawset(area.scroll, "GetVerticalScrollRange", function()
		return range
	end)
	area.scroll:SetHeight(100)
	area:ScrollTo(300)
	W.Tick(env, 0.016)
	range = 0
	area:Refresh()
	W.Settle(env)
	assert(area:GetOffset() == 0, "the running scroll stops at the new end, got " .. area:GetOffset())
end

-- Edits the player made stay when the area turns read only.
do
	local _, K = W.New()
	local area = newArea(K, { text = "start" })
	area.box:SetText("typed")
	area.box:GetScript("OnTextChanged")(area.box, true)
	area:SetReadOnly(true)
	area.box:SetText("typed!")
	area.box:GetScript("OnTextChanged")(area.box, true)
	assert(area:GetText() == "typed", "the accepted edit stays, got " .. tostring(area:GetText()))
end

-- A secret text reaches the box untouched.
do
	local env, K = W.New()
	local area = newArea(K, {})
	local secret = env.Secret("hidden")
	area:SetText(secret)
	assert(area.box:GetText() == secret, "the secret is in the box")
	area.box:GetScript("OnTextChanged")(area.box, false)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("widgets text area ok")
