-- test-skins-style.lua: skinned text, bars and accents follow the module's font, size, outline, bar and accent settings, and the preview shows them live.
local S = dofile("Tools/regression/skins_env.lua")
local W = S.W

local function FontOf(text)
	return text:GetFont()
end

-- Text: the interface face by default, the chosen font, size and outline once set ---------------------

do
	local env, K, ns = S.New()
	K.Modules.Enable("Skins")
	local Style = ns.Style
	local text = env.UIParent:CreateFontString(nil, "OVERLAY")
	Style.Text(text, "heading", "textEmphasis")
	local kitPath, kitSize = K.Tokens.Font("heading")
	local path, size, flags = FontOf(text)
	assert(path == kitPath and W.Near(size, kitSize) and flags == "", "the interface font at the role's size, with no outline")
	local ox, oy = text:GetShadowOffset()
	assert(ox > 0 and oy < 0, "a soft shadow instead of an outline")
	assert(W.SameRGB({ GetVertexColor = function() return text:GetTextColor() end }, K.Tokens.Color("textEmphasis")), "the token colour")

	local face = K.Tokens.FontPath("InterSemiBold")
	K.Options.Write("Skins", "text.font", face)
	K.Options.Write("Skins", "text.size", 1.2)
	K.Options.Write("Skins", "text.outline", "outline")
	path, size, flags = FontOf(text)
	assert(path == face, "a font change restyles every skinned text, got " .. tostring(path))
	assert(W.Near(size, kitSize * 1.2), "the size multiplies the role's size")
	assert(flags == "OUTLINE", "the outline flag")
	assert(select(1, text:GetShadowOffset()) == 0, "an outline replaces the shadow")

	K.Options.Write("Skins", "text.font", "appearance")
	assert(FontOf(text) == kitPath, "back to the interface font")
end

-- A saved value the setting does not allow gives the default -----------------------------------------

do
	local _, K, ns = S.New()
	local section = K.Store.Module("Skins")
	section.text.size = 9
	section.text.outline = "glow"
	section.bars.color = 4
	section.accent.color = { r = 2, g = 0, b = 0 }
	assert(ns.Style.Setting("text", "size") == 1)
	assert(ns.Style.Setting("text", "outline") == "shadow")
	assert(ns.Style.Setting("bars", "color") == "reaction")
	assert(ns.Style.Setting("accent", "color").r <= 1)
	assert(not pcall(ns.Style.Setting, "text", "nope"), "an unknown setting raises an error")
end

-- Bars: Blizzard's own colour brightened for the glass, or the class colour, or a custom colour ----------

do
	local env, K, ns = S.New()
	K.Modules.Enable("Skins")
	local Style = ns.Style
	local r, g, b = Style.BarColor(0, 0, 0.1)
	local br, bg, bb = K.Theme.Brighten(0, 0, 0.1)
	assert(W.Near(r, br) and W.Near(g, bg) and W.Near(b, bb), "reaction keeps Blizzard's colour, brightened")
	K.Options.Write("Skins", "bars.color", "class")
	r, g, b = Style.BarColor(0, 0, 0.1)
	local cr, cg, cb = K.Theme.ClassColor("HUNTER")
	assert(W.Near(r, cr) and W.Near(g, cg) and W.Near(b, cb), "class colour")
	K.Options.Write("Skins", "bars.color", "custom")
	K.Options.Write("Skins", "bars.customColor", { r = 0.25, g = 0.5, b = 0.75 })
	r, g, b = Style.BarColor(0, 0, 0.1)
	assert(W.Near(r, 0.25) and W.Near(g, 0.5) and W.Near(b, 0.75), "custom colour")
	local secret = env.Secret(0.5)
	K.Options.Write("Skins", "bars.color", "reaction")
	assert(Style.BarColor(secret, secret, secret) == secret, "a secret colour passes through untouched")
	local sr, sg, sb = Style.BarColor(secret, 0.2, 0.3)
	assert(sr == secret and sg == 0.2 and sb == 0.3, "one secret component passes the colour through untouched")

	local bar = env.CreateFrame("StatusBar", nil, env.UIParent)
	bar:SetStatusBarColor(0, 0, 0.1, 0.5)
	Style.StatusBar(bar)
	assert(W.LastCall(bar, "SetStatusBarColor")[4] == 0.5, "styling keeps the bar's alpha")
	assert(W.LastCall(bar, "SetStatusBarTexture")[1] == Style.BarTexture(), "the bar texture")
	assert(W.LastCall(bar, "SetReverseFill")[1] == false, "fills from the left by default")
	bar:SetStatusBarColor(0, 0.2, 0)
	local last = W.LastCall(bar, "SetStatusBarColor")
	local er, eg, eb = K.Theme.Brighten(0, 0.2, 0)
	assert(W.Near(last[1], er) and W.Near(last[2], eg) and W.Near(last[3], eb), "Blizzard's later colour is restyled too")
	assert(W.LastCall(bar, "SetStatusBarColor")[4] == nil, "a later colour without alpha stays opaque")
	bar:SetStatusBarColor(0, 0.2, 0, 0.25)
	assert(W.LastCall(bar, "SetStatusBarColor")[4] == 0.25, "a later colour keeps its alpha")
	bar:SetStatusBarColor(secret, 0.2, 0)
	assert(W.LastCall(bar, "SetStatusBarColor")[1] == secret, "a secret colour from Blizzard reaches the bar untouched")
	bar:SetStatusBarColor(0, 0.4, 0)
	assert(W.Near(W.LastCall(bar, "SetStatusBarColor")[2], select(2, K.Theme.Brighten(0, 0.4, 0))), "the hook still restyles after a secret colour")
	K.Options.Write("Skins", "bars.fill", "right")
	assert(W.LastCall(bar, "SetReverseFill")[1] == true, "a fill change restyles tracked bars")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Accent: the interface accent, the class colour or a custom colour -----------------------------------

do
	local env, K, ns = S.New()
	K.Modules.Enable("Skins")
	local Style = ns.Style
	local ar, ag, ab = Style.Accent()
	local tr, tg, tb = K.Theme.Accent()
	assert(W.Near(ar, tr) and W.Near(ag, tg) and W.Near(ab, tb), "the interface accent by default")
	K.Options.Write("Skins", "accent.source", "custom")
	K.Options.Write("Skins", "accent.color", { r = 0.1, g = 0.2, b = 0.3 })
	ar = Style.Accent()
	assert(W.Near(ar, 0.1), "a custom accent")
	local line = ns.Parts.AccentLine(env.CreateFrame("Frame", nil, env.UIParent))
	assert(W.SameRGB(line, 0.1, 0.2, 0.3), "accent lines use the module's accent")
	K.Options.Write("Skins", "accent.color", { r = 0.4, g = 0.5, b = 0.6 })
	assert(W.SameRGB(line, 0.4, 0.5, 0.6), "an accent change repaints accent lines")
end

-- The preview shows the settings at once ---------------------------------------------------------------

do
	local env, K = S.New()
	local build = K.Options.Preview("Skins")
	local pane = env.CreateFrame("Frame", nil, env.UIParent)
	local frame = build(pane)
	assert(frame and type(frame.Refresh) == "function", "the preview has a Refresh")
	assert(#frame.slots == 3, "three quality slots")
	local qr, qg, qb = K.Theme.QualityColor(4)
	assert(W.SameRGB(frame.slots[3].rim.rim[1], qr, qg, qb), "the epic slot wears the epic rim")
	K.Options.Write("Skins", "bars.color", "custom")
	K.Options.Write("Skins", "bars.customColor", { r = 0.3, g = 0.6, b = 0.9 })
	frame:Refresh()
	local color = W.LastCall(frame.bar, "SetStatusBarColor")
	assert(W.Near(color[1], 0.3) and W.Near(color[2], 0.6) and W.Near(color[3], 0.9), "the bar shows the custom colour after Refresh")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Sweep: every Blizzard font string under a window takes the body face at no less than the body size ---------

do
	local env, K, ns = S.New()
	K.Modules.Enable("Skins")
	local Style = ns.Style
	local B = S.Blizzard(env)
	local window = B.frame("Frame", env.UIParent, "SweptWindow")
	local inner = B.frame("Frame", window)
	local deep = B.frame("Button", inner)
	local label = B.text(window)
	local small = B.text(inner)
	small:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
	small:SetTextColor(1, 0.82, 0)
	local large = B.text(deep)
	large:SetFont("Fonts\\FRIZQT__.TTF", 16, "")
	large:SetTextColor(1, 1, 1)
	local grey = B.text(deep)
	grey:SetTextColor(0.5, 0.5, 0.5)
	local styled = B.text(window)
	Style.Text(styled, "heading", "textEmphasis")
	local kit = B.text(window)
	kit:SetFont(K.Tokens.FontPath("InterSemiBold"), 20, "")
	local skipped = B.frame("Frame", window)
	local left = B.text(skipped)
	local denied = B.text(window)
	denied.IsForbidden = function() return true end
	local deniedFrame = B.frame("Frame", window)
	deniedFrame.IsForbidden = function() return true end
	local under = B.text(deniedFrame)
	local after = B.text(window)
	local snap = B.snapshot()

	local count = Style.Sweep(window, { skip = { [skipped] = true } })
	assert(count == 5, "the five unstyled Blizzard strings are swept, got " .. tostring(count))
	assert(denied:GetFont() == nil and under:GetFont() == nil, "a forbidden string, and one under a forbidden frame, are left alone")
	assert(after:GetFont() ~= nil, "a forbidden string does not stop the strings after it")
	local bodyPath, bodySize = Style.Font("body")
	local path, size = label:GetFont()
	assert(path == bodyPath and W.Near(size, bodySize), "a string with no font of its own takes the body face at the body size")
	assert(W.SameRGB({ GetVertexColor = function() return label:GetTextColor() end }, K.Tokens.Color("text")), "Blizzard's default text reads in the text token")
	path, size = small:GetFont()
	assert(path == bodyPath and W.Near(size, bodySize), "a smaller string rises to the body size")
	assert(W.SameRGB({ GetVertexColor = function() return small:GetTextColor() end }, K.Tokens.Color("text")), "Blizzard's yellow becomes the text token")
	path, size = large:GetFont()
	assert(path == bodyPath and W.Near(size, 16), "a larger string keeps its size, got " .. tostring(size))
	assert(W.SameRGB({ GetVertexColor = function() return large:GetTextColor() end }, 1, 1, 1), "white text keeps its colour")
	assert(W.SameRGB({ GetVertexColor = function() return grey:GetTextColor() end }, 0.5, 0.5, 0.5), "grey text keeps its colour")
	local headingPath, headingSize = Style.Font("heading")
	path, size = styled:GetFont()
	assert(path == headingPath and W.Near(size, headingSize), "a string a skin styled is left alone")
	path, size = kit:GetFont()
	assert(path == K.Tokens.FontPath("InterSemiBold") and size == 20, "a string in a kit face is left alone")
	assert(left:GetFont() == nil, "a skipped subtree is left alone")
	assert(Style.Sweep(window) == 1, "a second sweep styles only what the first skipped, got " .. tostring(Style.Sweep(window)))
	B.check(snap, { SetFontObject = true, SetTextColor = true, IsForbidden = true })

	-- Blizzard setting a font object or its yellow again keeps the skin's face and colour.
	label:SetFontObject("GameFontNormalSmall")
	path, size = label:GetFont()
	assert(path == bodyPath and W.Near(size, bodySize), "after SetFontObject the body face and size return")
	small:SetTextColor(1, 0.82, 0)
	assert(W.SameRGB({ GetVertexColor = function() return small:GetTextColor() end }, K.Tokens.Color("text")), "a later yellow is mapped again")
	small:SetTextColor(0, 1, 0)
	assert(W.SameRGB({ GetVertexColor = function() return small:GetTextColor() end }, 0, 1, 0), "a later green stays")

	-- The text size setting rescales swept text, and the face setting refaces it.
	K.Options.Write("Skins", "text.size", 1.5)
	size = select(2, small:GetFont())
	assert(W.Near(size, bodySize * 1.5), "the text size reaches swept text, got " .. tostring(size))
	size = select(2, large:GetFont())
	assert(W.Near(size, 16 * 1.5), "the text size multiplies a larger string's own size, got " .. tostring(size))
	local face = K.Tokens.FontPath("InterSemiBold")
	K.Options.Write("Skins", "text.font", face)
	assert(label:GetFont() == face, "the face setting reaches swept text")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("skins style ok")
