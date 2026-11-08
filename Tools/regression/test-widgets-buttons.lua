-- test-widgets-buttons.lua: the text button, the close button, the icon button's states and the tab strip.
local W = dofile("Tools/regression/widget_env.lua")

-- Button: a chamfered tile on the button body; hover brightens the hairline to the accent and the text to white; press moves the text down.
do
	local env, K = W.New()
	local Tokens, Scale = K.Tokens, K.Scale
	local clicks = {}
	local button = K.Widgets.Button(Scale.Root(), {
		text = "Accept",
		onClick = function(b, mouse)
			clicks[#clicks + 1] = { b, mouse }
		end,
	})
	assert(button:GetObjectType() == "Button" and button.chrome and #button.chrome.fill == 9)
	assert(W.Near(button.chrome.fill[1]:GetWidth(), Scale.Snap(button.chrome:Chamfer())) and W.Near(button.chrome:Chamfer(), math.min(6, 0.3 * button:GetHeight())), "a tile: the shared cut, 30% of its height up to 6")
	assert(button.chrome.shadow[1]:IsShown() == false, "buttons cast no shadow")
	assert(W.SameColor(button.chrome.fill[5], Tokens.Color("buttonFill")), "the button grade's body, the mockup's one dark tone")
	assert(button.label:GetText() == "Accept")
	assert(W.SameColor(button.chrome.inner[7], Tokens.Color("edgeInner")), "the hairline rests at edgeInner (its side piece; the top is lit)")
	assert(W.SameColor({ GetVertexColor = function()
		return button.label:GetTextColor()
	end }, Tokens.Color("text")), "the text rests at the text colour")
	W.Enter(button)
	W.Settle(env)
	assert(W.SameColor(button.chrome.inner[5], Tokens.Color("accent")), "hover brightens the hairline to the accent")
	assert(W.SameColor({ GetVertexColor = function()
		return button.label:GetTextColor()
	end }, Tokens.Color("textHover")), "hover moves the text to textHover")
	W.Down(button)
	W.Settle(env)
	local p = button.label._points[1]
	assert(W.Near(p[5], -Scale.Snap(Tokens.Size("pressOffset"))), "press moves the text down one unit")
	W.Up(button)
	W.Settle(env)
	assert(W.Near(button.label._points[1][5], 0), "release puts it back")
	button:GetScript("OnClick")(button, "LeftButton", false)
	assert(#clicks == 1 and clicks[1][1] == button and clicks[1][2] == "LeftButton", "a click runs onClick with the button")
	W.Leave(button)
	W.Settle(env)
	assert(W.SameColor(button.chrome.inner[7], Tokens.Color("edgeInner")), "leaving rests the hairline")
	button:Disable()
	assert(W.SameColor({ GetVertexColor = function()
		return button.label:GetTextColor()
	end }, Tokens.Color("textDisabled")), "a disabled button greys its text")
	W.Click(button)
	assert(#clicks == 1, "a disabled button does not click")
	button:SetText("Other")
	assert(button.label:GetText() == "Other")
	assert(button:GetHeight() > 0 and button:GetWidth() > 0, "a default size")
end

-- A primary button rests with an accent hairline and follows the accent.
do
	local _, K = W.New()
	local button = K.Widgets.Button(K.Scale.Root(), { text = "Apply", primary = true, width = 120, height = 28 })
	local r, g, b = K.Tokens.Color("accent")
	assert(W.SameColor(button.chrome.inner[5], r, g, b), "a primary button rests on the accent")
	assert(W.Near(button:GetWidth(), K.Scale.Snap(120)))
	K.Theme.SetCustomAccent(0.9, 0.1, 0.1)
	K.Theme.SetAccentSource("custom")
	assert(W.SameColor(button.chrome.inner[5], 0.9, 0.1, 0.1), "and follows the new accent")
end

-- A button on a secure template keeps the template's OnClick: the kit only hooks scripts.
do
	local env, K = W.New()
	local clicked = 0
	local button = K.Widgets.Button(K.Scale.Root(), { text = "Go", template = "SecureActionButtonTemplate", onClick = function()
		clicked = clicked + 1
	end })
	assert(button._template == "SecureActionButtonTemplate")
	assert(#W.Calls(button, "SetScript") == 0, "no SetScript on a templated button")
	button:GetScript("OnClick")(button, "LeftButton", false)
	assert(clicked == 1)
	assert(#env._errors == 0)
end

-- The close button: a cross glyph that lights up under the mouse.
do
	local env, K = W.New()
	local hits = 0
	local close = K.Widgets.CloseButton(K.Scale.Root(), function()
		hits = hits + 1
	end)
	assert(close.glyph and W.LastCall(close.glyph, "SetTexture")[1] == K.Tokens.Texture("glyphClose"), "the cross glyph")
	assert(W.SameColor(close.glyph, K.Tokens.Color("text")))
	W.Enter(close)
	W.Settle(env)
	assert(W.SameColor(close.glyph, K.Tokens.Color("textHover")), "the glyph brightens under the mouse")
	W.Click(close)
	assert(hits == 1)
end

local function iconButton(opts, envOpts)
	local env, K = W.New(envOpts)
	return env, K, K.Widgets.IconButton(K.Scale.Root(), opts or {})
end

-- IconButton: a 34-unit chamfered square, the icon masked to the chamfer, the hairline on the accent.
do
	local env, K, button = iconButton({ icon = 135489 })
	local Tokens, Scale = K.Tokens, K.Scale
	assert(W.Near(button:GetWidth(), Scale.Snap(Tokens.Size("actionButton"))), "an action-button-sized square by default")
	assert(W.LastCall(button.icon, "SetTexture")[1] == 135489, "the icon")
	assert(#W.Calls(button.icon, "AddMaskTexture") == 1, "the icon is masked to the chamfer")
	local r, g, b = Tokens.Color("accent")
	assert(W.SameColor(button.chrome.fill[5], Tokens.Color("buttonFill")), "the body is the design's near-black button fill, not a raised tile")
	local rr, rg, rb = K.Widgets.MixTokens("accent", 1, "textHover", 1, 0.15)
	assert(W.SameColor(button.chrome.inner[5], rr, rg, rb, 1), "at rest: the accent lifted 15% toward white, as the design's normal button")
	assert(W.SameColor(button.chrome.outer[5], rr, rg, rb, 0.45) and W.SameColor(button.chrome.outer[1], rr, rg, rb, 0.45), "the outer line is the rim's soft halo at 45%, so the rim reads as the design's soft 1.5-unit line")
	W.Enter(button)
	W.Settle(env)
	local hr, hg, hb, ha = button.chrome.inner[5]:GetVertexColor()
	local wr, wg, wb = K.Widgets.MixTokens("accent", 1, "textHover", 1, 0.25)
	assert(ha == 1 and W.Near(hr, wr) and W.Near(hg, wg) and W.Near(hb, wb), "hover: the accent lifted 25% toward white")
	assert(hr >= r and hg >= g and hb >= b, "hover: a brighter accent hairline")
	assert(button.hoverGlow.holder:IsShown(), "hover: a soft glow")
	assert(button.hoverGlow.spread == 10 and W.Near(button.hoverGlow.holder:GetAlpha(), 0.3), "the hover glow reaches 10 units; 30% of the shadow falloff lifts the pixels next to the rim as the design's hover does")
	assert(button.hoverGlow.core and button.hoverGlow.core:IsShown() and button.hoverGlow.core:GetParent():GetParent() == button.hoverGlow.holder, "hover: an inner wash over the icon that follows the glow's intensity")
	assert(select(4, button.hoverGlow.core:GetVertexColor()) * 0.3 > 0.15, "the wash reaches about a fifth of the accent at the centre")
	assert(W.SameColor(button.chrome.fill[5], Tokens.Color("buttonFill")), "hover keeps the near-black body")
	W.Down(button)
	W.Settle(env)
	local ir = button.icon:GetVertexColor()
	assert(W.Near(ir, 0.55), "pressed: the icon dims to 55%")
	assert(W.LastCall(button.icon, "SetDesaturated")[1] == true, "pressed: the icon is desaturated, as the design's pressed button")
	local _, _, _, pa = button.chrome.inner[5]:GetVertexColor()
	assert(W.SameRGB(button.chrome.inner[5], Tokens.Color("text")) and pa >= 0.75, "pressed: a light grey hairline")
	assert(W.SameColor(button.chrome.fill[5], K.Widgets.MixTokens("buttonFill", 1, "raised", 1, 0.75)), "pressed: the body lifts three quarters of the way to the raised grey, as the design's pressed button")
	W.Up(button)
	W.Leave(button)
	W.Settle(env)
	assert(button.icon:GetVertexColor() == 1, "released: the icon is bright again")
	assert(W.LastCall(button.icon, "SetDesaturated")[1] == false, "released: the icon has its colour back")
	assert(W.SameColor(button.chrome.fill[5], Tokens.Color("buttonFill")), "released: the near-black body")
	assert(button.hoverGlow.holder:IsShown() == false, "the hover glow fades away")
	button:SetIcon("Interface\\Icons\\INV_Misc_QuestionMark")
	assert(W.LastCall(button.icon, "SetTexture")[1] == "Interface\\Icons\\INV_Misc_QuestionMark")
	assert(#env._errors == 0)
end

-- Cooldown: plain values and duration objects reach the Cooldown widget; secrets never do, because
-- SetCooldown refuses secret arguments from addon code. The hairline greys while a cooldown runs.
do
	local env, K, button = iconButton({})
	local cd = button.cooldown
	assert(cd and cd:GetObjectType() == "Cooldown" and cd._template == "CooldownFrameTemplate")
	assert(W.LastCall(cd, "SetSwipeTexture")[1] == K.Tokens.Texture("iconMask"), "the swipe has the chamfered shape")
	button:SetCooldown(100, 8)
	local call = W.LastCall(cd, "SetCooldown")
	assert(call[1] == 100 and call[2] == 8, "plain start and duration pass through")
	assert(button:SetCooldown(env.Secret(100), 8) == false and #W.Calls(cd, "SetCooldown") == 1, "a secret start is refused")
	assert(button:SetCooldown(100, env.Secret(8)) == false and #W.Calls(cd, "SetCooldown") == 1, "a secret duration is refused")
	local logged = false
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		logged = logged or entry.message:find("duration object", 1, true) ~= nil
	end
	assert(logged, "the refusal says to use a duration object")
	cd:Show()
	cd:GetScript("OnShow")(cd)
	local _, _, _, ca = button.chrome.inner[5]:GetVertexColor()
	assert(W.SameRGB(button.chrome.inner[5], K.Tokens.Color("text")) and W.Near(ca, 0.62), "a running cooldown greys the hairline to text at 62%")
	assert(W.SameColor(button.chrome.fill[5], K.Widgets.MixTokens("buttonFill", 1, "raised", 1, 0.75)), "and lifts the body three quarters of the way to the raised grey, as the design's cooldown button")
	local tr, tg, tb = K.Tokens.Color("text")
	assert(W.SameColor(button.chrome.outer[5], tr, tg, tb, 0.62 * 0.45), "and its halo with it")
	assert(W.Near(button.icon:GetVertexColor(), 0.4), "and dims the icon to 40%")
	cd:GetScript("OnHide")(cd)
	local r, g, b = K.Widgets.MixTokens("accent", 1, "textHover", 1, 0.15)
	assert(W.SameColor(button.chrome.inner[5], r, g, b), "the accent returns when it ends")
	assert(button.icon:GetVertexColor() == 1, "and the icon is bright again")
	local object = {}
	button:SetCooldownFromDuration(object)
	assert(W.LastCall(cd, "SetCooldownFromDurationObject")[1] == object, "a duration object goes to the engine")
	button:ClearCooldown()
	assert(#W.Calls(cd, "Clear") == 1)
	assert(#env._errors == 0)
end

-- Proc and usability: the proc glow pulses; an unusable button is desaturated and dark.
do
	local _, K, button = iconButton({})
	button:SetProc(true)
	assert(button.procGlow and button.procGlow:IsPlaying(), "the proc glow plays")
	assert(W.Near(button.procGlow.alpha, 0.1), "its outer halo is a whisper: the design's proc glows inside the rim, not around it")
	assert(button.procGlow.core and button.procGlow.spark, "the inner radial glow and the star")
	local r, g, b = K.Tokens.Color("accent")
	assert(W.SameColor(button.chrome.inner[5], r, g, b, 1), "a proc lights the hairline fully")
	assert(W.SameColor(button.chrome.fill[5], K.Tokens.Color("buttonFill")), "on the near-black body")
	button:SetProc(false)
	assert(not button.procGlow:IsPlaying(), "and stops")
	button:SetUsable(false)
	assert(W.LastCall(button.icon, "SetDesaturated")[1] == true, "an unusable icon is desaturated")
	assert(W.Near(button.icon:GetVertexColor(), 0.45), "at 45% brightness")
	assert(W.SameColor(button.chrome.inner[5], K.Tokens.Color("textDisabled")), "with a solid grey hairline")
	assert(W.SameColor(button.chrome.fill[5], K.Widgets.MixTokens("buttonFill", 1, "raised", 1, 0.75)), "the body lifts three quarters of the way to the raised grey, as the design's disabled button")
	button:SetUsable(true)
	assert(W.SameColor(button.chrome.fill[5], K.Tokens.Color("buttonFill")), "usable again: the near-black body")
	assert(W.LastCall(button.icon, "SetDesaturated")[1] == false)
	button:Disable()
	assert(W.LastCall(button.icon, "SetDesaturated")[1] == true, "a disabled button looks unusable")
	button:Enable()
	button:SetSelected(true)
	assert(W.SameColor(button.chrome.inner[5], r, g, b, 1), "a selected button keeps the full accent")
end

-- The global cooldown alone never dims an icon or greys its rim: the swipe runs, the button stays ready.
do
	local _, K, button = iconButton({})
	local cd = button.cooldown
	local gcd = {}
	assert(button:SetCooldownFromDuration(gcd, true) == true)
	assert(W.LastCall(cd, "SetCooldownFromDurationObject")[1] == gcd, "the swipe still runs for the GCD")
	cd:Show()
	cd:GetScript("OnShow")(cd)
	local rr, rg, rb = K.Widgets.MixTokens("accent", 1, "textHover", 1, 0.15)
	assert(W.SameColor(button.chrome.inner[5], rr, rg, rb, 1), "the rim stays on the accent during the GCD")
	assert(button.icon:GetVertexColor() == 1, "and the icon stays bright")
	button:SetCooldownFromDuration({})
	assert(W.SameRGB(button.chrome.inner[5], K.Tokens.Color("text")) and W.Near(button.icon:GetVertexColor(), 0.4), "a real cooldown set while the frame shows dims at once")
	button:SetCooldownFromDuration(gcd, true)
	assert(button.icon:GetVertexColor() == 1, "back to the GCD alone: bright again")
	cd:GetScript("OnHide")(cd)
	assert(button:SetCooldown(100, 1.5, true) == true)
	cd:GetScript("OnShow")(cd)
	assert(button.icon:GetVertexColor() == 1 and W.SameColor(button.chrome.inner[5], rr, rg, rb, 1), "SetCooldown takes the flag too")
	button:ClearCooldown()
	cd:GetScript("OnHide")(cd)
	button:SetCooldown(100, 8)
	cd:GetScript("OnShow")(cd)
	assert(W.Near(button.icon:GetVertexColor(), 0.4), "ClearCooldown forgets the flag, so the next real cooldown dims")
end

-- Ready: when a real cooldown runs out, the icon brightens for a moment and settles, the theme's answer to the
-- game's cooldown flash (which the kit turns off with SetDrawBling). It reads the cooldown frame's own
-- OnCooldownDone, so no time is compared and secret durations are fine. The GCD alone, a directly driven frame
-- and a hidden button never flash, so the bar does not sparkle after every press.
do
	local env, K, button = iconButton({})
	local cd = button.cooldown
	local flash = assert(button.ready, "the button has a ready flash")
	assert(flash:GetAlpha() == 0, "it rests invisible")
	assert(W.LastCall(flash, "SetBlendMode")[1] == "ADD", "it adds light")
	button:SetCooldownFromDuration({})
	cd:GetScript("OnShow")(cd)
	cd:GetScript("OnCooldownDone")(cd)
	local peak = 0
	for _, call in ipairs(W.Calls(flash, "SetAlpha")) do
		peak = math.max(peak, call[1])
	end
	assert(peak > 0.2 and peak <= 0.5, "a real cooldown's end lights the icon briefly: " .. peak)
	W.Tick(env, K.Tokens.Duration("castSheen") + 0.1)
	assert(flash:GetAlpha() == 0, "and settles")
	local calls = #W.Calls(flash, "SetAlpha")
	button:SetCooldownFromDuration({}, true)
	cd:GetScript("OnCooldownDone")(cd)
	assert(#W.Calls(flash, "SetAlpha") == calls, "the GCD alone never flashes")
	button:ClearCooldown()
	cd:GetScript("OnCooldownDone")(cd)
	assert(#W.Calls(flash, "SetAlpha") == calls, "nor a frame driven directly")
	button:SetCooldownFromDuration({})
	button:Hide()
	cd:GetScript("OnCooldownDone")(cd)
	assert(#W.Calls(flash, "SetAlpha") == calls, "nor a hidden button")
end

-- A cooldown frame a module drives directly (the Cooldowns mirror's buff timers) never dims or greys the button:
-- only a real cooldown set through the button's own setters does.
do
	local _, K, button = iconButton({})
	local cd = button.cooldown
	cd:Show()
	cd:GetScript("OnShow")(cd)
	local rr, rg, rb = K.Widgets.MixTokens("accent", 1, "textHover", 1, 0.15)
	assert(button.cooling == true, "the kit still notes that the frame shows")
	assert(button.icon:GetVertexColor() == 1 and W.SameColor(button.chrome.inner[5], rr, rg, rb, 1), "but a frame driven directly leaves the button bright on the accent")
	button:SetCooldownFromDuration({})
	assert(W.Near(button.icon:GetVertexColor(), 0.4), "a real cooldown through the setter dims")
	button:ClearCooldown()
	cd:GetScript("OnHide")(cd)
	cd:GetScript("OnShow")(cd)
	assert(button.icon:GetVertexColor() == 1, "after ClearCooldown a directly driven frame is bright again")
end

-- A tiny button (a 12-unit micro button at Layout scale 0.5 is six pixels) keeps a visible icon: the icon inset
-- never eats the whole button.
do
	local _, K, button = iconButton({ size = 6 })
	local p = button.icon._points[1]
	local inset = p[4]
	assert(p[1] == "TOPLEFT" and inset <= K.Scale.Snap(6 * 0.2) + 1e-6 and inset >= K.Scale.Pixel(1) - 1e-6, "the inset shrinks to a fifth of the side on a tiny button, got " .. tostring(inset))
	assert(button:GetWidth() - 2 * inset >= K.Scale.Pixel(4) - 1e-6, "at least four pixels of icon remain")
	local big = select(3, iconButton({ size = 34 }))
	assert(W.Near(big.icon._points[1][4], math.max(3 * K.Scale.Border(), K.Scale.Snap(34 * 0.11))), "a normal button's icon sits 11% of the side in, the mockup's dark band, and never less than three borders")
end

-- The mockup's button sits on a dark bezel: the body colour reaches 3 units outside the rim, a shadow falls beyond
-- it, and a press lifts the body but never the bezel.
do
	local env, K, button = iconButton({ icon = 135489 })
	local Tokens, Scale = K.Tokens, K.Scale
	local chrome = button.chrome
	assert(chrome.bezel and #chrome.bezel == 9, "the bezel is a nine-sliced tile")
	assert(W.SameColor(chrome.bezel[5], Tokens.Color("buttonFill")), "in the button body colour")
	local bezel = Scale.Snap(Tokens.Size("buttonBezel"))
	local p = chrome.bezel[1]._points[1]
	assert(p[1] == "TOPLEFT" and W.Near(p[4], -bezel) and W.Near(p[5], bezel), "reaching 3 units outside the button")
	local _, sub = chrome.bezel[5]:GetDrawLayer()
	local _, fillSub = chrome.fill[5]:GetDrawLayer()
	assert(sub < fillSub, "under the fill")
	assert(chrome.shadow[1]:IsShown(), "a button casts the panel shadow")
	local sp = chrome.shadow[1]._points[1]
	assert(W.Near(sp[4], -(Scale.Snap(Tokens.Size("shadow")) + bezel)), "the shadow starts at the bezel's edge, got " .. tostring(sp[4]))
	W.Down(button)
	W.Settle(env)
	assert(W.SameColor(chrome.bezel[5], Tokens.Color("buttonFill")), "pressed, the bezel keeps the body colour while the fill lifts")
	W.Up(button)
	local plain = K.Widgets.IconChrome(env.CreateFrame("Frame", nil, Scale.Root()))
	assert(plain.bezel == nil and not plain.shadow[1]:IsShown(), "an icon tile with no bezel option has none and no shadow: aura tiles, bag slots and skin rims")
end

-- The button's chamfer is a share of its size, the design's 11% cut, so the ratio holds at 34 and at 38 units.
do
	local _, K, button = iconButton({ size = 34 })
	local Snap = K.Scale.Snap
	assert(W.Near(button.chrome.fill[1]:GetWidth(), Snap(0.12 * 34)), "a 34-unit button cuts 12% of its side, 4.08 units: the mockup's action and cluster buttons")
	button.opts.size = 38
	button:Restyle()
	assert(W.Near(button.chrome.fill[1]:GetWidth(), Snap(0.12 * 38)), "a 38-unit button cuts 4.56 units")
	assert(W.Near(button.chrome.outer[5]:GetHeight(), K.Scale.Border()), "the rim stays one border")
end

-- A button that changes size restyles its glows too, so the proc's inner glow keeps its 60% radius (a micro-menu size change).
do
	local _, K, button = iconButton({ size = 24 })
	button:SetProc(true)
	assert(W.Near(button.procGlow.core:GetWidth(), K.Scale.Snap(1.2 * 24)), "the inner glow is 1.2 times the button")
	button.opts.size = 40
	button:Restyle()
	assert(W.Near(button:GetWidth(), K.Scale.Snap(40)))
	assert(W.Near(button.procGlow.core:GetWidth(), K.Scale.Snap(1.2 * 40)) and W.Near(button.procGlow.core:GetHeight(), K.Scale.Snap(1.2 * 40)), "and follows a resize through the button's own Restyle")
end

-- The cooldown countdown sits low on the button, its centre a quarter of the height above the bottom, as the design's "3.2s".
do
	local _, K, button = iconButton({})
	local countdown = button.countdown
	assert(countdown and countdown == button.cooldown:GetCountdownFontString(), "the countdown is the cooldown's own font string, where the game draws the number")
	local path, size = K.Tokens.Font("number")
	local font = W.LastCall(countdown, "SetFont")
	assert(font and font[1] == path and W.Near(font[2], size), "in the number font at its size, as the design's 3.2s")
	local colour = W.LastCall(countdown, "SetTextColor")
	local tr, tg, tb = K.Tokens.Color("textEmphasis")
	assert(colour and W.Near(colour[1], tr) and W.Near(colour[2], tg) and W.Near(colour[3], tb), "in textEmphasis")
	button:Restyle()
	local p = button.countdown._points[1]
	assert(p and p[1] == "CENTER" and p[2] == button.cooldown and p[3] == "BOTTOM" and W.Near(p[4], 0), "centred over the cooldown's bottom edge")
	assert(W.Near(p[5], K.Scale.Snap(button:GetHeight() * 0.25)), "a quarter of the height up")
end

-- With countdownCorner the countdown sits in the top right corner, as the mockup's centre cluster reads "4s".
do
	local _, K, button = iconButton({ size = 56, countdownCorner = true })
	button:Restyle()
	local p = button.countdown._points[1]
	assert(p and p[1] == "TOPRIGHT" and p[2] == button and p[3] == "TOPRIGHT" and W.Near(p[4], -K.Scale.Snap(56 * 0.2)) and W.Near(p[5], -K.Scale.Snap(56 * 0.1)), "the countdown hangs in the top right corner, a fifth of the side in and a tenth down, as the mockup's 4s sits 12 by 6 units inside a 56-unit icon")
	assert(W.LastCall(button.countdown, "SetJustifyH")[1] == "RIGHT", "right-aligned")
end

-- Hotkey and count text sit on the button.
do
	local _, K, button = iconButton({})
	button:SetHotkey("s1")
	button:SetCount(5)
	assert(button.hotkey:GetText() == "S1" and button.count:GetText() == 5)
	assert(W.LastCall(button.count, "SetFont")[1] == (K.Tokens.Font("number")), "counts use the number face")
end

-- A secure icon button: the kit hooks scripts and never moves the icon of a protected frame in combat.
do
	local env, K, button = iconButton({ template = "SecureActionButtonTemplate" })
	assert(#W.Calls(button, "SetScript") == 0, "no SetScript on a templated button")
	button.IsProtected = function()
		return true
	end
	local before = #W.Calls(button.icon, "SetPoint")
	env.SetCombat(true)
	W.Down(button)
	W.Settle(env)
	assert(#W.Calls(button.icon, "SetPoint") == before, "a protected button's content stays put in combat")
	assert(button.icon:GetVertexColor() < 1, "but it still dims")
	K.Theme.SetCustomAccent(0.3, 0.3, 0.9)
	K.Theme.SetAccentSource("custom")
	assert(#W.Calls(button.icon, "SetPoint") == before, "a restyle in combat does not move it either")
	env.SetCombat(false)
	assert(#env._errors == 0)
end

local TABS = {
	{ value = "character", label = "Character" },
	{ value = "skills", label = "Skills" },
	{ value = "journal", label = "Journal" },
	{ value = "map", label = "Map" },
}

-- Tabs: upper-case labels; the selected tab is bright with an accent underline that slides to the next.
do
	local env, K = W.New()
	local Tokens = K.Tokens
	local picked = {}
	local tabs = K.Widgets.Tabs(K.Scale.Root(), { tabs = TABS, value = "character", onSelect = function(value)
		picked[#picked + 1] = value
	end })
	assert(#tabs.buttons == 4 and tabs.buttons[1].label:GetText() == "CHARACTER", "four tabs with upper-case labels")
	assert(tabs:GetValue() == "character")
	local function textColor(i)
		return { GetVertexColor = function()
			return tabs.buttons[i].label:GetTextColor()
		end }
	end
	assert(W.SameColor(textColor(1), Tokens.Color("textEmphasis")) and W.SameColor(textColor(2), Tokens.Color("text")))
	local ur, ug, ub = K.Widgets.MixTokens("accent", 1, "textHover", 1, 0.6)
	assert(W.SameColor(tabs.underline, ur, ug, ub, 1), "the underline is the accent lifted 60% toward white, the design's hot line")
	local border = K.Scale.Border()
	assert(W.Near(tabs.underline:GetHeight(), border) and W.Near(tabs.underline._points[1][5], border), "one border thick, on the strip's bottom edge")
	local glow = tabs.underGlow
	assert(glow and W.LastCall(glow, "SetBlendMode")[1] == "ADD" and W.SameRGB(glow, Tokens.Color("accent")), "an additive accent glow above the underline")
	assert(W.Near(glow:GetHeight(), K.Scale.Snap(5)) and W.Near(glow:GetWidth(), tabs.underline:GetWidth()), "five units tall, as wide as the line")
	local gp = glow._points[1]
	assert(gp[1] == "BOTTOMLEFT" and gp[2] == tabs.underline and gp[3] == "TOPLEFT", "sitting on the underline")
	local function underlineAt(i)
		local p = tabs.underline._points[1]
		local tab = tabs.buttons[i]
		return W.Near(p[4], tab.x) and W.Near(tabs.underline:GetWidth(), tab.w)
	end
	assert(underlineAt(1), "under the first tab, spanning its full width")
	W.Click(tabs.buttons[2])
	assert(picked[1] == "skills" and tabs:GetValue() == "skills", "a click selects and reports the tab")
	W.Settle(env)
	assert(underlineAt(2), "the underline slides to the new tab")
	assert(W.SameColor(textColor(2), Tokens.Color("textEmphasis")) and W.SameColor(textColor(1), Tokens.Color("text")))
	W.Click(tabs.buttons[2])
	assert(#picked == 1, "clicking the selected tab reports nothing")
	assert(tabs:Select("map", true) == true and #picked == 1 and tabs:GetValue() == "map", "a silent Select reports nothing")
	assert(tabs:Select("nope") == false and tabs:GetValue() == "map", "an unknown value is refused")
	tabs:SetTabEnabled("journal", false)
	W.Click(tabs.buttons[3])
	assert(tabs:GetValue() == "map" and #picked == 1, "a disabled tab cannot be picked")
	assert(W.SameColor(textColor(3), Tokens.Color("textDisabled")))
	W.Enter(tabs.buttons[1])
	W.Settle(env)
	assert(W.SameColor(textColor(1), Tokens.Color("textHover")), "hover whitens a tab's text")
	tabs:SetTabs({ { value = "a", label = "A" }, { value = "b", label = "B" } }, "b")
	assert(#tabs.buttons >= 2 and tabs.buttons[1]:IsShown() and tabs.buttons[3]:IsShown() == false, "SetTabs reuses buttons and hides the rest")
	assert(tabs:GetValue() == "b")
	assert(#env._errors == 0)
end

-- Equal-width tabs fill a given width.
do
	local _, K = W.New()
	local tabs = K.Widgets.Tabs(K.Scale.Root(), { tabs = TABS, value = "map", width = 400 })
	local first, last = tabs.buttons[1], tabs.buttons[4]
	assert(W.Near(first.w, last.w), "equal widths")
	assert(W.Near(tabs:GetWidth(), K.Scale.Snap(400)), "the strip is the given width")
end

print("widgets buttons ok")

-- Reduced motion shows a proc glow steadily at its own strength: an icon button's halo stays at 10%.
do
	local env, K, button = iconButton({})
	button:SetProc(true)
	W.Settle(env)
	assert(W.Near(button.procGlow.holder:GetAlpha(), 0.1), "the halo fades in to its own alpha")
	K.Motion.SetLevel("reduced")
	button.procGlow:Restyle()
	assert(W.Near(button.procGlow.holder:GetAlpha(), 0.1), "reduced motion keeps the halo at its own alpha, not full")
	K.Motion.SetLevel("full")
	button.procGlow:Restyle()
	assert(W.Near(button.procGlow.holder:GetAlpha(), 0.1), "and so does motion coming back")
end

-- The rim strength: an action button (primary) rests on the full accent rim; every other icon button follows
-- Widgets.SECONDARY_RIM, one number the owner can turn down so the micro menu, bag bar, cooldown icons
-- and flyouts tone toward the plain hairline. The default keeps the full rim.
do
	local _, K, button = iconButton({})
	local Widgets = K.Widgets
	assert(Widgets.SECONDARY_RIM == 1, "the secondary rim is at full strength by default")
	local rr, rg, rb = Widgets.MixTokens("accent", 1, "textHover", 1, 0.15)
	assert(W.SameColor(button.chrome.inner[5], rr, rg, rb, 1), "a plain icon button rests on the full accent rim at the default")
	local primary = Widgets.IconButton(K.Scale.Root(), { primary = true })
	Widgets.SECONDARY_RIM = 0.5
	button:Paint()
	primary:Paint()
	local er, eg, eb, ea = Widgets.Rgba("edgeInner")
	local tr, tg, tb, ta = Widgets.Mix(er, eg, eb, ea, rr, rg, rb, 1, 0.5)
	assert(W.SameColor(button.chrome.inner[5], tr, tg, tb, ta), "at half strength a secondary rim sits halfway from the plain hairline to the accent rim")
	assert(W.SameColor(button.chrome.outer[5], tr, tg, tb, ta * 0.45), "with its halo at 45% of that")
	assert(W.SameColor(primary.chrome.inner[5], rr, rg, rb, 1), "a primary button keeps the full accent rim")
	local ir, ig, ib, ia = Widgets.IconRim()
	assert(W.Near(ir, rr) and W.Near(ig, rg) and W.Near(ib, rb) and ia == 1, "IconRim() is the full rim: the theme accent lifted 15% toward white")
	ir, ig, ib, ia = Widgets.IconRim(nil, nil, nil, 0.5)
	assert(W.Near(ir, tr) and W.Near(ig, tg) and W.Near(ib, tb) and W.Near(ia, ta), "IconRim(nil, nil, nil, strength) tones it toward the plain hairline")
	ir, ig, ib = Widgets.IconRim(0.2, 0.4, 0.6)
	local wr, wg, wb, wa = Widgets.Rgba("textHover", 1)
	local cr, cg, cb = Widgets.Mix(0.2, 0.4, 0.6, 1, wr, wg, wb, wa, 0.15)
	assert(W.Near(ir, cr) and W.Near(ig, cg) and W.Near(ib, cb), "IconRim(r, g, b) lifts a given accent")
	Widgets.SECONDARY_RIM = 1
end

-- IconChrome: the one chrome every square icon shares: the near-black button body on a tile with no shadow,
-- a rim setter that paints the hairline and its 45% halo, and an accent rim that follows the theme.
do
	local env, K = W.New()
	local Widgets = K.Widgets
	local owner = env.CreateFrame("Frame", nil, K.Scale.Root())
	owner:SetSize(20, 20)
	local chrome = Widgets.IconChrome(owner)
	assert(chrome.shapeName == "tile" and chrome.shadowOn == false, "a tile with no shadow")
	assert(W.SameColor(chrome.fill[5], K.Tokens.Color("buttonFill")), "the near-black button body")
	assert(W.Near(chrome:Chamfer(), 20 * 0.12), "without a size the cut is 12% of the owner's side, the icon share")
	local sized = Widgets.IconChrome(owner, { size = 40 })
	assert(W.Near(sized:Chamfer(), 40 * 0.12), "a size gives 12% of that size")
	chrome:SetRim(0.2, 0.4, 0.6, 1)
	assert(W.SameColor(chrome.inner[5], 0.2, 0.4, 0.6, 1) and W.SameColor(chrome.outer[5], 0.2, 0.4, 0.6, 0.45), "SetRim paints the hairline and its halo")
	chrome:Restyle()
	assert(W.SameColor(chrome.inner[5], 0.2, 0.4, 0.6, 1) and W.SameColor(chrome.outer[5], 0.2, 0.4, 0.6, 0.45), "a restyle keeps a set rim")
	chrome:SetRimAccent()
	local rr, rg, rb = Widgets.IconRim()
	assert(W.SameColor(chrome.inner[5], rr, rg, rb, 1), "SetRimAccent() rests on the lifted theme accent")
	env.UnitClass = function()
		return "Warrior", "WARRIOR", 1
	end
	K.Theme.SetAccentSource("custom")
	K.Theme.SetCustomAccent(0.6, 0.3, 0.1)
	K.Widgets.RestyleAll()
	rr, rg, rb = Widgets.IconRim()
	assert(W.SameColor(chrome.inner[5], rr, rg, rb, 1), "and follows a theme change through the restyle")
	chrome:SetRimAccent(0.1, 0.2, 0.3)
	rr, rg, rb = Widgets.IconRim(0.1, 0.2, 0.3)
	assert(W.SameColor(chrome.inner[5], rr, rg, rb, 1), "SetRimAccent(r, g, b) lifts a module's own accent")
	assert(#env._errors == 0)
end
