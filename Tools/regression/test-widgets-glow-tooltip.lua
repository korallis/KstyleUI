-- test-widgets-glow-tooltip.lua: proc and selection glows, and the glass tooltip for KstyleUI's own controls.
local W = dofile("Tools/regression/widget_env.lua")

local THIN = "\226\128\137"

-- Tracked(text): the text with a thin space between its letters, as the kit tracks tooltip titles and captions.
local function Tracked(text)
	return (text:gsub("([\1-\127\194-\244][\128-\191]*)", "%1" .. THIN):sub(1, -#THIN - 1))
end

-- A proc glow sits behind its frame, pulses on an AnimationGroup and fades away when stopped.
do
	local env, K = W.New()
	local frame = env.CreateFrame("Button", nil, K.Scale.Root())
	frame:SetFrameLevel(5)
	frame:SetSize(34, 34)
	local glow = K.Widgets.Glow(frame, { kind = "proc" })
	assert(glow.holder:GetFrameLevel() == 4, "the glow sits behind its frame")
	assert(glow.holder:IsShown() == false and not glow:IsPlaying(), "a glow starts stopped")
	assert(#glow.slice == 9 and W.LastCall(glow.slice[1], "SetBlendMode")[1] == "ADD", "an additive nine-sliced falloff")
	local r, g, b = K.Tokens.Color("accent")
	assert(W.SameRGB(glow.slice[5], r, g, b), "in the accent")
	glow:Start()
	assert(glow:IsPlaying() and glow.holder:IsShown(), "Start shows the glow")
	assert(#W.Calls(glow.pulse, "Play") == 1 and W.LastCall(glow.pulse, "SetLooping")[1] == "BOUNCE", "the pulse plays and bounces")
	assert(glow.top:IsShown() and #W.Calls(glow.sparkPulse, "Play") == 1, "the corner spark pulses above the frame")
	local across, down = glow.spark, glow.sparkCross
	assert(down and across:GetWidth() >= 4 * across:GetHeight() and W.Near(down:GetHeight(), across:GetWidth()), "the kit's spark: a four-point star of two streaks")
	local Snap = K.Scale.Snap
	assert(W.Near(across:GetWidth(), Snap(6)) and W.Near(across:GetHeight(), Snap(1)), "the design's 6-unit star")
	local a, d = across._points[1], down._points[1]
	assert(a[1] == "CENTER" and a[2] == frame and a[3] == "TOPRIGHT" and W.Near(a[4], d[4]) and W.Near(a[5], d[5]), "crossed at the top right corner")
	assert(W.Near(a[4], -Snap(3)) and W.Near(a[5], -Snap(2.5)), "3 units in from the right edge and 2.5 below the top, over the hairline")
	local core = glow.core
	assert(core and core:GetParent() == glow.top and W.LastCall(core, "SetBlendMode")[1] == "ADD", "an additive glow over the icon")
	assert(W.Near(core:GetWidth(), Snap(1.2 * 34)) and W.Near(core:GetHeight(), core:GetWidth()), "its radius is 60% of the frame")
	assert(W.SameColor(core, r, g, b, 0.35) and core._points[1][1] == "CENTER", "the accent at 35%, centred")
	assert(W.SameRGB(across, r, g, b) and W.SameRGB(down, r, g, b), "the spark is the accent, like the rest of the theme")
	glow:Start()
	assert(#W.Calls(glow.pulse, "Play") == 1, "Start twice plays once")
	W.Settle(env)
	glow:Stop()
	assert(not glow:IsPlaying())
	W.Settle(env)
	assert(glow.holder:IsShown() == false and #W.Calls(glow.pulse, "Stop") >= 1, "Stop fades the glow out and stops the pulse")
	K.Theme.SetCustomAccent(0.1, 0.8, 0.9)
	K.Theme.SetAccentSource("custom")
	assert(W.SameRGB(glow.slice[5], 0.1, 0.8, 0.9), "the glow follows the accent")
	assert(W.SameRGB(glow.spark, 0.1, 0.8, 0.9) and W.SameRGB(glow.sparkCross, 0.1, 0.8, 0.9), "and so does its spark")
	assert(W.SameRGB(glow.core, 0.1, 0.8, 0.9), "and its inner glow")
	glow:SetColor("epic")
	assert(W.SameRGB(glow.slice[5], K.Tokens.Color("epic")), "or a colour token")
	W.Raises(function()
		K.Widgets.Glow(frame, { kind = "sparkles" })
	end, "kind must be proc or selection")
end

-- Turning reduced motion on stops the pulse of a glow that is already running; turning it off starts it again.
do
	local env, K = W.New()
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	local glow = K.Widgets.Glow(frame)
	glow:Start()
	W.Settle(env)
	local stops = #W.Calls(glow.pulse, "Stop")
	K.Options.Write("Appearance", "motion", "off")
	assert(#W.Calls(glow.pulse, "Stop") > stops and #W.Calls(glow.sparkPulse, "Stop") >= 1, "the running pulse stops")
	assert(glow.holder:IsShown() and glow:IsPlaying(), "the glow stays, steady")
	local plays = #W.Calls(glow.pulse, "Play")
	K.Options.Write("Appearance", "motion", "full")
	assert(#W.Calls(glow.pulse, "Play") == plays + 1, "the pulse starts again")
end

-- Under reduced motion a proc glow shows steadily without the pulse.
do
	local env, K = W.New()
	K.Motion.SetReducedMotion(true)
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	local glow = K.Widgets.Glow(frame)
	glow:Start()
	assert(glow.holder:IsShown() and glow.holder:GetAlpha() == 1, "a steady glow")
	assert(#W.Calls(glow.pulse, "Play") == 0, "no pulse")
	glow:Stop()
	assert(glow.holder:IsShown() == false, "and it hides at once")
end

-- A selection glow is steady and follows an intensity from 0 to 1.
do
	local env, K = W.New()
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	local glow = K.Widgets.Glow(frame, { kind = "selection" })
	assert(glow.pulse == nil, "no pulse")
	glow:SetIntensity(0.5)
	assert(glow.holder:IsShown() and glow.holder:GetAlpha() > 0 and glow.holder:GetAlpha() < 1)
	glow:SetIntensity(0)
	assert(glow.holder:IsShown() == false)
end

-- The tooltip: one shared glass panel with a rarity-lit icon tile, a tracked upper-case title in body size,
-- a tracked caption, lines pitched as the design, the 56-unit accent rule and the fading divider.
do
	local env, K = W.New()
	local Widgets, Tokens = K.Widgets, K.Tokens
	env.CreateColor = function(r, g, b, a)
		return { r = r, g = g, b = b, a = a }
	end
	local tip = Widgets.Tooltip()
	assert(tip == Widgets.Tooltip(), "one shared tooltip")
	assert(tip:GetFrameStrata() == "TOOLTIP" and tip.chrome and tip.chrome.shadow[1]:IsShown(), "a glass panel in the tooltip strata")
	assert(tip.chrome:Chamfer() == Tokens.Size("chamferPanel"), "with the kit's panel chamfer")
	local owner = env.CreateFrame("Button", nil, K.Scale.Root())
	tip:SetOwner(owner, "ANCHOR_RIGHT")
	assert(tip:IsOwned(owner))
	tip:SetIcon(135489, "friendly")
	tip:AddTitle("Ranger's Long Bow", "friendly")
	tip:AddCaption("Uncommon")
	tip:AddLine("Level 38")
	tip:AddDoubleLine("Physical Damage", "142 - 198")
	tip:AddRule()
	tip:AddLine("+24 Agility", 0.2, 0.9, 0.3)
	tip:AddDivider()
	tip:AddLine("Durability 96 / 100")
	tip:Show()
	assert(tip:IsShown(), "Show shows it")
	local texts = {}
	for _, line in ipairs(tip.used) do
		texts[#texts + 1] = line.left:GetText()
	end
	assert(texts[1] == Tracked("RANGER'S LONG BOW") and texts[2] == Tracked("UNCOMMON") and texts[3] == "Level 38", "lines in order, the title and caption tracked capitals")
	assert(select(2, tip.used[1].left:GetFont()) == select(2, Tokens.Font("body")), "the title is body size")
	assert(select(2, tip.used[2].left:GetFont()) == select(2, Tokens.Font("caption")), "the caption is caption size")
	assert(tip.used[4].right:GetText() == "142 - 198" and tip.used[4].right:IsShown(), "a double line")
	assert(W.SameRGB({ GetVertexColor = function()
		return tip.used[1].left:GetTextColor()
	end }, Tokens.Color("friendly")), "the title takes a colour token")
	assert(W.SameRGB({ GetVertexColor = function()
		return tip.used[6].left:GetTextColor()
	end }, 0.2, 0.9, 0.3), "a line takes r, g and b")
	local rule = tip.used[5].divider
	assert(rule and rule:IsShown() and W.Near(rule:GetWidth(), Widgets.Snap(tip, 56)), "the rule runs 56 units")
	local ar, ag, ab = Tokens.Color("accent")
	local stops = W.LastCall(rule, "SetGradient")
	assert(stops and stops[1] == "HORIZONTAL" and W.Near(stops[2].r, ar) and W.Near(stops[2].g, ag) and W.Near(stops[2].b, ab) and stops[2].a == 1 and stops[3].a == 0, "from the accent to transparent")
	local divider = tip.used[7].divider
	assert(divider and divider:IsShown(), "a divider line")
	assert(W.SameColor(divider, K.Tokens.Color("edgeFaint")), "as faint as the kit's divider, below the bevel line")
	local pad = tip.chrome:Inset()
	assert(W.Near(divider:GetWidth(), tip:GetWidth() - 2 * pad), "the divider spans the panel inside its padding, fading at both ends")
	local icon = tip.icon
	assert(W.LastCall(icon.texture, "SetTexture")[1] == 135489 and icon:IsShown(), "the icon")
	assert(icon.chrome and icon.chrome.shapeName == "tile" and icon.chrome.frost == nil, "on the kit's rounded tile")
	assert(W.Near(icon:GetWidth(), Widgets.Snap(tip, 50)) and W.Near(icon:GetHeight(), icon:GetWidth()), "50 units square")
	local ip = icon._points[1]
	assert(ip[1] == "TOPLEFT" and ip[2] == tip and W.Near(ip[4], Widgets.Snap(tip, 9.5)) and W.Near(ip[5], -Widgets.Snap(tip, 9.5)), "9.5 units inside the top left corner")
	local fr, fg, fb = Tokens.Color("friendly")
	local e = icon.chrome.edge
	assert(W.Near(e[1], fr) and W.Near(e[2], fg) and W.Near(e[3], fb) and e[4] == 1, "its hairline takes the icon's colour")
	assert(icon.glow.holder:IsShown(), "and glows in it")
	local tp = tip.used[1].left._points[1]
	assert(W.Near(tp[4], Widgets.Snap(tip, 9.5 + 50 + 11)), "the text column starts 11 units right of the icon")
	local y3, y4 = tip.used[3].left._points[1][5], tip.used[4].left._points[1][5]
	assert(W.Near(y3 - y4, Widgets.TextHeight(tip.used[3].left, Tokens.Size("body") * 1.2) + 0.5), "body lines are pitched half a unit apart")
	assert(tip:GetHeight() > 0 and tip:GetWidth() >= Widgets.TOOLTIP_MIN_WIDTH, "the tooltip has a size")
	local p = tip._points[1]
	assert(p[1] == "LEFT" and p[2] == owner and p[3] == "RIGHT", "ANCHOR_RIGHT puts it right of the owner")
	-- A line's width never falls under its measured text, whatever the pixel grid rounds the panel to, so the
	-- widest line's last word never wraps onto a line the height did not count (round 4: a Spanish meter line).
	do
		local measure = env._textWidth
		env._textWidth = function(text)
			return #text * 4.37
		end
		tip:ClearLines()
		tip:AddLine("Haz clic para ver todos los hechizos")
		tip:AddDoubleLine("Golpe mortal", "92.4k  33%")
		tip:Layout()
		local widest = tip.used[1].left
		assert(widest:GetWidth() >= widest:GetUnboundedStringWidth() - 0.001, "the widest line keeps its full width: " .. tostring(widest:GetWidth()) .. " for " .. tostring(widest:GetUnboundedStringWidth()))
		assert(widest:GetWidth() <= tip:GetWidth(), "and stays inside the panel")
		env._textWidth = measure
		tip:ClearLines()
	end
	local made = #W.Regions(tip, "FontString")
	tip:ClearLines()
	assert(#tip.used == 0 and tip.icon:IsShown() == false, "ClearLines empties it")
	tip:SetIcon(135489)
	e = icon.chrome.edge
	local er, eg, eb = Tokens.Color("edgeInner")
	assert(W.Near(e[1], er) and W.Near(e[2], eg) and W.Near(e[3], eb) and not icon.glow.holder:IsShown(), "an icon with no colour keeps the glass hairline and no glow")
	tip:ClearLines()
	local link = "|cff1eff00|Hitem:4500::::::::38:::::|h[Traveler's Backpack]|h|r"
	tip:AddTitle(link)
	assert(tip.used[1].left:GetText() == link, "a title with escape codes keeps Blizzard's text: no capitals and no thin spaces inside the codes")
	tip:ClearLines()
	tip:AddLine("One")
	tip:Show()
	assert(#W.Regions(tip, "FontString") == made, "lines are pooled, not made again")
	tip:Hide()
	W.Settle(env)
	assert(tip:IsShown() == false and not tip:IsOwned(owner), "Hide hides it and drops the owner")
	local secret = env.Secret("Hogger")
	tip:SetOwner(owner, "ANCHOR_TOP")
	tip:AddLine(secret)
	tip:Show()
	assert(tip.used[1].left:GetText() == secret, "a secret line passes through")
	assert(tip._points[1][1] == "BOTTOM" and tip._points[1][3] == "TOP", "ANCHOR_TOP puts it above")
	tip:ClearLines()
	tip:AddLine("A single line")
	tip:Show()
	tip:ClearLines()
	tip:AddDoubleLine("Left", "Right")
	tip:Show()
	assert(W.LastCall(tip.used[1].left, "SetWidth")[1] == 0, "a reused row drops the single line's width for a double line")
	tip:ClearLines()
	tip:AddLine("No wrap", "textHover", false)
	tip:AddLine("Wraps", "textHover")
	tip:AddLine("Plain no wrap", 1, 1, 1, false)
	tip:Show()
	assert(W.LastCall(tip.used[1].left, "SetWordWrap")[1] == false, "a token colour then false turns wrapping off")
	assert(W.LastCall(tip.used[2].left, "SetWordWrap")[1] == true, "lines wrap by default")
	assert(W.LastCall(tip.used[3].left, "SetWordWrap")[1] == false, "r, g, b then false turns wrapping off")
	assert(#env._errors == 0)
end

-- AttachTooltip shows a text or a builder on hover and hides on leave; the size setting scales it.
do
	local env, K = W.New()
	local Widgets = K.Widgets
	local frame = env.CreateFrame("Button", nil, K.Scale.Root())
	Widgets.AttachTooltip(frame, "Reload the interface")
	W.Enter(frame)
	local tip = Widgets.Tooltip()
	assert(tip:IsShown() and tip:IsOwned(frame) and tip.used[1].left:GetText() == "Reload the interface")
	W.Leave(frame)
	W.Settle(env)
	assert(tip:IsShown() == false)
	local other = env.CreateFrame("Button", nil, K.Scale.Root())
	Widgets.AttachTooltip(other, function(t, owner)
		assert(owner == other)
		t:AddTitle("Built")
		t:AddLine("By a function")
	end)
	W.Enter(other)
	assert(tip.used[1].left:GetText() == Tracked("BUILT") and tip.used[2].left:GetText() == "By a function", "a builder adds a tracked title and a line")
	K.Options.Write("Widgets", "tooltipScale", 1.25)
	assert(W.LastCall(tip, "SetScale")[1] == 1.25, "the size setting scales the tooltip")
	local corner = tip.chrome.fill[1]:GetWidth() * 1.25 / K.Scale.Pixel(1)
	assert(W.Near(corner, math.floor(corner + 0.5)), "and its corners, got " .. corner .. " px")
	local button = Widgets.Button(K.Scale.Root(), { text = "Hi", tooltip = "A button" })
	W.Enter(button)
	assert(tip:IsOwned(button) and tip.used[1].left:GetText() == "A button", "Button opts.tooltip attaches one")
	assert(#env._errors == 0)
end

print("widgets glow and tooltip ok")
