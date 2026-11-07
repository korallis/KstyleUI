-- test-widgets-buttons.lua: the text button, the close button, the icon button's states and the tab strip.
local W = dofile("Tools/regression/widget_env.lua")

-- Button: a raised chamfered tile; hover brightens the hairline to the accent and the text to white; press moves the text down.
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
	assert(W.Near(button.chrome.fill[1]:GetWidth(), Scale.Snap(Tokens.Size("chamferTile"))), "a tile: 3-unit chamfers")
	assert(button.chrome.shadow[1]:IsShown() == false, "buttons cast no shadow")
	assert(W.SameColor(button.chrome.fill[5], Tokens.Color("raised")), "the raised fill")
	assert(button.label:GetText() == "Accept")
	assert(W.SameColor(button.chrome.inner[5], Tokens.Color("edgeInner")), "the hairline rests at edgeInner")
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
	assert(W.SameColor(button.chrome.inner[5], Tokens.Color("edgeInner")), "leaving rests the hairline")
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
	assert(button.hoverGlow.spread == 10 and W.Near(button.hoverGlow.holder:GetAlpha(), 0.12), "the hover glow reaches 10 units at 12% alpha")
	W.Down(button)
	W.Settle(env)
	local ir = button.icon:GetVertexColor()
	assert(ir < 1, "pressed: the icon dims")
	local _, _, _, pa = button.chrome.inner[5]:GetVertexColor()
	assert(W.SameRGB(button.chrome.inner[5], Tokens.Color("text")) and pa >= 0.75, "pressed: a light grey hairline")
	W.Up(button)
	W.Leave(button)
	W.Settle(env)
	assert(button.icon:GetVertexColor() == 1, "released: the icon is bright again")
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
	local r, g, b = K.Tokens.Color("accent")
	assert(W.SameColor(button.chrome.inner[5], r, g, b, 1), "a proc lights the hairline fully")
	button:SetProc(false)
	assert(not button.procGlow:IsPlaying(), "and stops")
	button:SetUsable(false)
	assert(W.LastCall(button.icon, "SetDesaturated")[1] == true, "an unusable icon is desaturated")
	assert(W.Near(button.icon:GetVertexColor(), 0.45), "at 45% brightness")
	assert(W.SameColor(button.chrome.inner[5], K.Tokens.Color("textDisabled")), "with a solid grey hairline")
	button:SetUsable(true)
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
	assert(W.Near(big.icon._points[1][4], 3 * K.Scale.Border()), "a normal button keeps the three-border inset")
end

-- The button's chamfer is a share of its size, the design's 11% cut, so the ratio holds at 34 and at 38 units.
do
	local _, K, button = iconButton({ size = 34 })
	local Snap = K.Scale.Snap
	assert(W.Near(button.chrome.fill[1]:GetWidth(), Snap(0.105 * 34)), "a 34-unit button cuts 3.6 units")
	button.opts.size = 38
	button:Restyle()
	assert(W.Near(button.chrome.fill[1]:GetWidth(), Snap(0.105 * 38)), "a 38-unit button cuts 4 units")
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
	assert(button.countdown == nil, "the stub cooldown reports no countdown font string")
	button.countdown = K.Widgets.FontString(button)
	button:Restyle()
	local p = button.countdown._points[1]
	assert(p and p[1] == "CENTER" and p[2] == button.cooldown and p[3] == "BOTTOM" and W.Near(p[4], 0), "centred over the cooldown's bottom edge")
	assert(W.Near(p[5], K.Scale.Snap(button:GetHeight() * 0.25)), "a quarter of the height up")
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
