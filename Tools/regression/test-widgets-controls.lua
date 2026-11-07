-- test-widgets-controls.lua: the toggle, the slider and its value maths, the edit box and the colour swatch.
local W = dofile("Tools/regression/widget_env.lua")

local function rgbOf(text)
	return { GetVertexColor = function()
		return text:GetTextColor()
	end }
end

-- Toggle: a pill track and a round knob that slides right and lights the track with the accent when on.
do
	local env, K = W.New()
	local Tokens = K.Tokens
	local changes = {}
	local toggle = K.Widgets.Toggle(K.Scale.Root(), { value = false, label = "Show portraits", onChange = function(value, t)
		changes[#changes + 1] = value
		assert(t ~= nil)
	end })
	assert(toggle:GetValue() == false and #toggle.track == 3 and #toggle.fill == 3, "a three-piece pill border and fill")
	assert(W.LastCall(toggle.track[1], "SetTexCoord")[2] == 0.25, "the left cap is the pill's first quarter")
	assert(W.LastCall(toggle.knob, "SetTexture")[1] == Tokens.Texture("dot"), "a round knob")
	assert(toggle.label:GetText() == "Show portraits")
	local Snap = K.Scale.Snap
	assert(W.Near(toggle.trackBox:GetWidth(), Snap(58)) and W.Near(toggle.trackBox:GetHeight(), Snap(28)), "the design's 58 by 28 pill")
	assert(W.Near(toggle.knob:GetWidth(), Snap(18)), "an 18-unit knob")
	local offX = toggle.knob._points[1][4]
	assert(W.Near(offX, Snap(5)), "inset 5 units from the left when off")
	assert(W.SameColor(toggle.track[2], K.Widgets.Rgba("white", 0.4)), "off: a white 40% edge")
	W.Click(toggle)
	assert(toggle:GetValue() == true and changes[1] == true, "a click turns it on and reports it")
	W.Settle(env)
	local onX = toggle.knob._points[1][4]
	assert(onX > offX, "the knob slides right")
	assert(W.Near(onX, Snap(58 - 5 - 18)), "to 5 units from the right")
	assert(W.SameRGB(toggle.track[2], Tokens.Color("accent")), "the border lights with the accent")
	assert(W.SameColor(toggle.fill[2], K.Widgets.MixTokens("surface", 1, "accent", 1, 0.3)), "on: the accent at 30% over the surface")
	assert(W.SameRGB(toggle.knob, Tokens.Color("textHover")), "the knob is white when on")
	toggle:SetValue(false, true)
	W.Settle(env)
	assert(#changes == 1 and toggle:GetValue() == false, "a silent SetValue reports nothing")
	assert(W.Near(toggle.knob._points[1][4], offX), "and slides back")
	assert(W.SameRGB(toggle.knob, K.Widgets.MixTokens("text", 1, "textHover", 1, 0.63)), "the knob is light grey (#e0e0e0) when off")
	toggle:SetValue(false)
	assert(#changes == 1, "setting the same value reports nothing")
	toggle:SetEnabled(false)
	W.Click(toggle)
	assert(toggle:GetValue() == false and #changes == 1, "a disabled toggle ignores clicks")
	assert(W.SameRGB(rgbOf(toggle.label), Tokens.Color("textDisabled")))
	assert(#env._errors == 0)
end

-- The slider's value maths: clamp to the range, snap to the step from the minimum, and refuse what is not a plain number.
do
	local env, K = W.New()
	local Q = K.Widgets.Quantize
	assert(Q(68.4, 0, 100, 1) == 68 and Q(68.5, 0, 100, 1) == 69, "rounds to the nearest step")
	assert(Q(-5, 0, 100, 1) == 0 and Q(500, 0, 100, 1) == 100, "clamps to the range")
	assert(Q(0.83, 0.75, 1.5, 0.05) == 0.85, "steps count from the minimum, without float noise")
	assert(Q(1.2999999, 0.75, 1.5, 0.05) == 1.3)
	assert(Q(10, 0, 10, 3) == 10 and Q(8, 0, 10, 3) == 9, "a range that is not a whole number of steps still reaches its maximum")
	assert(Q(0.333, 0, 1, nil) == 0.333, "no step keeps the value")
	assert(Q(0.05, 0.05, 1.05, 0.1) == 0.05 and Q(Q(0.05, 0.05, 1.05, 0.1), 0.05, 1.05, 0.1) == 0.05, "a minimum finer than the step keeps its precision")
	assert(Q(0.17, 0.05, 1.05, 0.1) == 0.15, "steps count from that minimum")
	assert(Q(0.00003, 0, 1, 0.00001) == 0.00003, "a step written in exponent form still snaps")
	assert(Q(0 / 0, 0, 1, 0.1) == nil and Q("5", 0, 10, 1) == nil and Q(env.Secret(5), 0, 10, 1) == nil, "NaN, text and secrets are refused")
end

-- Slider: a pill track with an accent fill to the knob, a value readout above, the range below; drag, wheel and SetValue.
do
	local env, K = W.New()
	local Tokens = K.Tokens
	local changes = {}
	local slider = K.Widgets.Slider(K.Scale.Root(), { min = 0, max = 100, step = 1, value = 68, width = 200, onChange = function(v)
		changes[#changes + 1] = v
	end })
	assert(slider:GetValue() == 68 and slider.readout:GetText() == "68", "the value and its readout")
	assert(slider.minText:GetText() == "0" and slider.maxText:GetText() == "100", "the range labels")
	assert(W.SameRGB(slider.fill[2], Tokens.Color("accent")), "an accent fill")
	assert(W.LastCall(slider.ring, "SetTexture")[1] == Tokens.Texture("ring"), "a ringed knob")
	assert(W.Near(slider.knob:GetWidth(), K.Scale.Snap(12)) and W.Near(slider.trackBox:GetHeight(), K.Scale.Snap(4)), "the design's 12-unit knob on a 4-unit track")
	local trackWidth = slider.trackBox:GetWidth()
	assert(W.Near(slider.fillBox:GetWidth(), K.Scale.Snap(trackWidth * 0.68)), "the fill reaches 68% of the track")
	slider:SetValue(25.4)
	assert(slider:GetValue() == 25 and changes[1] == 25 and slider.readout:GetText() == "25", "SetValue snaps and reports")
	slider:SetValue(25)
	assert(#changes == 1, "the same value reports nothing")
	slider:SetValue(70, true)
	assert(#changes == 1 and slider:GetValue() == 70, "a silent SetValue")
	slider:GetScript("OnMouseWheel")(slider, 1)
	assert(slider:GetValue() == 71 and changes[2] == 71, "the wheel steps up")
	slider:GetScript("OnMouseWheel")(slider, -1)
	assert(slider:GetValue() == 70)
	local scale = slider.trackBox:GetEffectiveScale()
	slider.trackBox.GetLeft = function()
		return 100
	end
	env.GetCursorPosition = function()
		return (100 + trackWidth * 0.4) * scale, 0
	end
	W.Down(slider)
	assert(slider:GetValue() == 40, "pressing on the track jumps to the cursor")
	env.GetCursorPosition = function()
		return (100 + trackWidth * 2) * scale, 0
	end
	slider:GetScript("OnUpdate")(slider, 0.016)
	assert(slider:GetValue() == 100, "dragging past the end clamps")
	W.Up(slider)
	assert(slider:GetScript("OnUpdate") == nil, "the drag ends on release")
	slider:SetRange(0, 1, 0.05)
	assert(slider:GetValue() == 1 and slider.readout:GetText() == "1.00", "a new range clamps and reformats")
	local custom = K.Widgets.Slider(K.Scale.Root(), { min = 0.5, max = 1, step = 0.01, value = 0.88, format = function(v)
		return math.floor(v * 100 + 0.5) .. "%"
	end })
	assert(custom.readout:GetText() == "88%", "a format function writes the readout")
	local free = K.Widgets.Slider(K.Scale.Root(), { value = 0.42 })
	assert(free:GetValue() == 0.42 and free.readout:GetText() == "0.42", "without a step the readout shows hundredths of the range")
	free:GetScript("OnMouseWheel")(free, 1)
	assert(free.readout:GetText() == "0.43", "and moves with the wheel")
	slider:SetRange(0, 100, 1)
	env.GetCursorPosition = function()
		return (100 + trackWidth * 0.5) * scale, 0
	end
	W.Down(slider)
	assert(slider:GetValue() == 50)
	slider:SetEnabled(false)
	assert(slider:GetScript("OnUpdate") == nil, "disabling ends a drag")
	env.GetCursorPosition = function()
		return (100 + trackWidth * 0.9) * scale, 0
	end
	W.Down(slider)
	assert(slider:GetValue() == 50, "a disabled slider ignores presses")
	slider:GetScript("OnMouseWheel")(slider, 1)
	assert(slider:GetValue() == 50 and not slider:IsEnabled(), "a disabled slider ignores the wheel")
	assert(#env._errors == 0)
end

-- EditBox: a raised tile with a placeholder, an accent hairline while focused, and callbacks for enter, escape and changes.
do
	local env, K = W.New()
	local Tokens = K.Tokens
	local got = {}
	local box = K.Widgets.EditBox(K.Scale.Root(), {
		placeholder = "Search settings",
		maxLetters = 32,
		onEnter = function(text)
			got.enter = text
		end,
		onEscape = function()
			got.escape = true
		end,
		onChange = function(text, _, user)
			got.change = text
			got.user = user
		end,
	})
	assert(box:GetObjectType() == "EditBox" and box.chrome, "an EditBox on a tile")
	assert(W.LastCall(box, "SetAutoFocus")[1] == false, "it never takes focus by itself")
	assert(W.LastCall(box, "SetMaxLetters")[1] == 32)
	assert(W.LastCall(box, "SetFont")[1] == (Tokens.Font("body")), "the body font")
	assert(box.placeholder:GetText() == "Search settings" and box.placeholder:IsShown(), "the placeholder shows while empty")
	box:GetScript("OnEditFocusGained")(box)
	assert(W.SameRGB(box.chrome.inner[5], Tokens.Color("accent")), "focus lights the hairline")
	assert(box.placeholder:IsShown() == false, "focus hides the placeholder")
	box:SetText("frost")
	box:GetScript("OnTextChanged")(box, true)
	assert(got.change == "frost" and got.user == true, "changes report the text")
	box:GetScript("OnEnterPressed")(box)
	assert(got.enter == "frost" and #W.Calls(box, "ClearFocus") >= 1, "Enter reports and drops focus")
	box:GetScript("OnEscapePressed")(box)
	assert(got.escape == true, "Escape reports")
	box:GetScript("OnEditFocusLost")(box)
	assert(W.SameRGB(box.chrome.inner[5], Tokens.Color("edgeInner")), "the hairline rests without focus")
	assert(box.placeholder:IsShown() == false, "no placeholder over text")
	box:SetText("")
	box:GetScript("OnTextChanged")(box, false)
	assert(box.placeholder:IsShown() == true, "the placeholder returns when empty")
	local numeric = K.Widgets.EditBox(K.Scale.Root(), { numeric = true, text = "42" })
	assert(W.LastCall(numeric, "SetNumeric")[1] == true and numeric:GetText() == "42")
	assert(#env._errors == 0)
end

-- ColorSwatch: a chamfered tile filled with the colour that opens Blizzard's colour picker through its public setup function.
do
	local setups = {}
	local picker
	local env, K = W.New({ setup = function(e)
		picker = { rgb = { 0.1, 0.2, 0.3 }, alpha = 0.4 }
		function picker:SetupColorPickerAndShow(info)
			setups[#setups + 1] = info
		end
		function picker:GetColorRGB()
			return self.rgb[1], self.rgb[2], self.rgb[3]
		end
		function picker:GetColorAlpha()
			return self.alpha
		end
		e.ColorPickerFrame = picker
	end })
	local changes = {}
	local swatch = K.Widgets.ColorSwatch(K.Scale.Root(), { color = { r = 0.5, g = 0.6, b = 0.7 }, onChange = function(r, g, b, a)
		changes[#changes + 1] = { r, g, b, a }
	end })
	assert(W.SameColor(swatch.chrome.fill[5], 0.5, 0.6, 0.7, 1), "the tile shows the colour")
	W.Click(swatch)
	local info = setups[1]
	assert(info and info.r == 0.5 and info.g == 0.6 and info.b == 0.7 and not info.hasOpacity, "the picker opens on the colour")
	assert(type(info.swatchFunc) == "function" and type(info.cancelFunc) == "function")
	info.swatchFunc()
	assert(changes[1][1] == 0.1 and changes[1][3] == 0.3 and changes[1][4] == 1, "picking reports the new colour")
	assert(W.SameColor(swatch.chrome.fill[5], 0.1, 0.2, 0.3, 1), "and shows it")
	info.cancelFunc({ r = 0.5, g = 0.6, b = 0.7, a = 1 })
	assert(changes[2][1] == 0.5 and select(1, swatch:GetColor()) == 0.5, "cancel restores the first colour")
	local alpha = K.Widgets.ColorSwatch(K.Scale.Root(), { color = { r = 1, g = 1, b = 1, a = 0.5 }, hasAlpha = true, onChange = function(r, g, b, a)
		changes[#changes + 1] = { r, g, b, a }
	end })
	W.Click(alpha)
	assert(setups[2].hasOpacity == true and setups[2].opacity == 0.5, "an alpha swatch passes its opacity")
	setups[2].opacityFunc()
	assert(changes[3][4] == 0.4, "and reports the picked alpha")
	picker.rgb = { env.Secret(1), 0, 0 }
	setups[2].swatchFunc()
	assert(#changes == 3, "a secret from the picker is ignored")
	assert(#env._errors == 0)
end

-- Without the colour picker the swatch logs and does nothing.
do
	local env, K = W.New()
	local swatch = K.Widgets.ColorSwatch(K.Scale.Root(), { color = { r = 1, g = 0, b = 0 } })
	assert(swatch:Open() == false)
	local logged = false
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		logged = logged or entry.message:find("ColorPickerFrame", 1, true) ~= nil
	end
	assert(logged, "the missing picker is logged")
end

print("widgets controls ok")
