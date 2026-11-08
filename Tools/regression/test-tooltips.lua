-- test-tooltips.lua: KstyleUI_Tooltips restyles Blizzard's tooltips through hooks and its own child frames: glass, fonts, scale, anchoring, quality edges and settings.
local T = dofile("Tools/regression/tooltips_env.lua")
local W = T.W
local Near = T.Near

local KEY = "tooltips.anchor"

local function Enabled(opts)
	local env, K, ns = T.New(opts)
	local snap = T.Snapshot(env)
	assert(K.Modules.Enable("Tooltips"), "the switch turns on")
	assert(K.Modules.IsRunning("Tooltips"), "Enable ran without an error: " .. tostring(env._errors[1]))
	return env, K, ns, snap
end

local function Font(object)
	return object:GetFont()
end

local function Edge(glass)
	local e = glass.chrome.edge
	return e[1], e[2], e[3], e[4]
end

local function SameEdge(glass, r, g, b)
	local er, eg, eb = Edge(glass)
	return Near(er, r) and Near(eg, g) and Near(eb, b)
end

-- At load the module registers itself, switched off, and touches nothing ----------------------------

do
	local env, K, ns = T.New()
	local listed = false
	for _, name in ipairs(K.Modules.List()) do
		listed = listed or name == "Tooltips"
	end
	assert(listed, "Tooltips registers with Modules")
	assert(K.Modules.IsEnabled("Tooltips") == false and not K.Modules.IsRunning("Tooltips"), "off by default")
	local schema = K.Options.Get("Tooltips")
	assert(type(schema) == "table" and #schema > 0, "the module declares its settings")
	assert(type(K.Options.Preview("Tooltips")) == "function", "the module has a live preview builder")
	assert(next(env._postCalls) == nil, "no tooltip post-calls before Enable")
	assert(ns.Style.Glass(env.GameTooltip) == nil, "no glass before Enable")
	assert(env.GameTooltipText:GetFont() == "Fonts\\FRIZQT__.TTF", "fonts untouched before Enable")
	assert(K.Layout.Element(KEY) == nil, "the anchor element is built in Enable")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Enable: glass on every tooltip, Blizzard's border art hidden by alpha, no writes onto Blizzard frames --

do
	local env, K, ns, snap = Enabled()
	for name in pairs(T.TOOLTIPS) do
		local tip = env[name]
		local glass = ns.Style.Glass(tip)
		assert(glass and glass:GetParent() == tip, name .. " wears a glass frame of KstyleUI's own")
		assert(glass.chrome and #glass.chrome.fill == 9 and #glass.chrome.shadow == 9, name .. ": a chamfered panel with a shadow")
		assert(W.Calls(glass, "SetUsingParentLevel")[1] and W.Calls(glass, "SetUsingParentLevel")[1][1] == true, name .. ": the glass draws at the tooltip's own level, behind its text")
		for _, piece in ipairs(W.Regions(tip.NineSlice, "Texture")) do
			assert(piece:GetAlpha() == 0, name .. ": Blizzard's border art is hidden by alpha")
			piece:SetAlpha(1)
			assert(piece:GetAlpha() == 0, name .. ": Blizzard cannot bring its border back")
		end
		assert(SameEdge(glass, K.Tokens.Color("edgeInner")), name .. ": the edge rests on the glass hairline")
	end
	for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" }) do
		local header = env[name].CompareHeader
		local art = W.Regions(header, "Texture")[1]
		assert(art:GetAlpha() == 0, name .. ": the compare label's art is hidden")
		assert(K.Skin.IsSkinned(header, "Backdrop"), name .. ": the compare label sits on a KstyleUI tile")
		assert(ns.Style.Glass(env[name]).chrome.shadowOn == false, name .. ": no shadow over the compare label")
	end
	assert(ns.Style.Glass(env.GameTooltip).chrome.shadowOn == true, "GameTooltip casts the panel shadow")
	assert(K.Skin.IsSkinned(env.ItemRefTooltip.CloseButton, "CloseButton"), "the item link tooltip's close button is restyled")
	assert(ns.Style.Glass(env.GameTooltip) == ns.Style.Glass(env.GameTooltip), "one glass per tooltip")
	T.Check(env, snap)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Fonts: the tooltip font objects take KstyleUI's font at the configured sizes; Disable restores them --

do
	local env, K = Enabled()
	local face = K.Tokens.FontPath(K.Tokens.DEFAULT_FONT_FACE)
	local scale = K.Theme.FontScale()
	local path, size, flags = Font(env.GameTooltipHeaderText)
	assert(path == face and Near(size, 11 * scale) and flags == "", "titles: KstyleUI's font at 11 units, no outline, got " .. tostring(path) .. " " .. tostring(size))
	path, size = Font(env.GameTooltipText)
	assert(path == face and Near(size, 11 * scale), "body lines at 11 units")
	path, size = Font(env.GameTooltipTextSmall)
	assert(path == face and Near(size, 9 * scale), "small lines at 9 units")
	local ox, oy = env.GameTooltipText:GetShadowOffset()
	local offset = K.Tokens.Size("textShadowOffset")
	assert(Near(ox, offset) and Near(oy, -offset), "text without an outline gets KstyleUI's soft shadow")

	K.Options.Write("Tooltips", "body.size", 15)
	size = select(2, Font(env.GameTooltipText))
	assert(Near(size, 15 * scale), "a size change applies at once")
	K.Options.Write("Tooltips", "title.outline", "OUTLINE")
	local _, _, titleFlags = Font(env.GameTooltipHeaderText)
	assert(titleFlags == "OUTLINE", "the outline setting reaches the font")
	ox, oy = env.GameTooltipHeaderText:GetShadowOffset()
	assert(ox == 0 and oy == 0, "outlined text drops the shadow")

	local custom = "Interface\\AddOns\\SharedMedia\\Fonts\\Custom.ttf"
	K.Options.Write("Tooltips", "body.font", custom)
	assert(Font(env.GameTooltipText) == face, "the KstyleUI font wins while Use KstyleUI's font is on")
	K.Options.Write("Tooltips", "followFont", false)
	assert(Font(env.GameTooltipText) == custom, "the picked font applies once the switch is off")

	K.Theme.SetFontScale(1.2)
	size = select(2, Font(env.GameTooltipText))
	assert(Near(size, 15 * 1.2), "Appearance's text size scales tooltip text")

	K.Modules.Disable("Tooltips")
	path, size, flags = Font(env.GameTooltipText)
	assert(path == "Fonts\\FRIZQT__.TTF" and size == 12 and flags == "", "Disable restores Blizzard's font")
	ox, oy = env.GameTooltipText:GetShadowOffset()
	assert(ox == 1 and oy == -1, "and its shadow")
	assert(K.Modules.NeedsReload(), "a reskin asks for a reload when turned off")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- /kstyle test reports the module's state ---------------------------------------------------------

do
	local env, K = Enabled()
	K.DevTest.Run()
	local line
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.message:find("tooltips", 1, true) == 6 then
			line = entry.message
		end
	end
	assert(line and line:find("^PASS tooltips: 7 tooltips restyled, position fixed"), "the smoke check passes: " .. tostring(line))
	K.Modules.Disable("Tooltips")
	K.DevTest.Run()
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.message:find("tooltips", 1, true) == 6 then
			line = entry.message
		end
	end
	assert(line == "PASS tooltips: off: Blizzard tooltips", "off, the check says so: " .. tostring(line))
end

-- A profile switch applies the new profile's fonts while the module keeps running ------------------

do
	local env, K = Enabled()
	K.Options.Write("Tooltips", "body.size", 20)
	assert(K.Store.CreateProfile("Other"))
	K.Store.SetProfile("Other")
	K.Modules.Enable("Tooltips")
	assert(select(2, env.GameTooltipText:GetFont()) == 11 * K.Theme.FontScale(), "the other profile's default size")
	K.Store.SetProfile("Default")
	assert(K.Modules.IsRunning("Tooltips"), "the module stays on")
	assert(select(2, env.GameTooltipText:GetFont()) == 20 * K.Theme.FontScale(), "switching back applies the first profile's size")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A saved value that is not allowed gives the default ----------------------------------------------

do
	local env, K, ns = Enabled()
	local saved = K.Store.Module("Tooltips")
	saved.body.size = 400
	saved.anchor = "nowhere"
	assert(ns.Settings.Get("body.size") == 11, "an out-of-range size gives the default")
	assert(ns.Settings.Get("anchor") == "fixed", "an unknown anchor gives the default")
	local logged = false
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		logged = logged or (entry.module == "Tooltips" and entry.message:find("body.size", 1, true) ~= nil)
	end
	assert(logged, "the bad value is logged once")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Anchoring: a Layout element the player moves and scales; fixed or at the cursor -------------------

do
	local env, K, ns = Enabled()
	local element = K.Layout.Element(KEY)
	assert(element and element.frame == ns.Anchor.Frame(), "the anchor registers with Layout")
	assert(element.label == K.Setup.Layouts.Element(KEY).label and element.module == "Tooltips", "with the setup's label and the module's name")
	assert(element.opts.scalable == true, "the anchor is scalable, and its scale sizes every tooltip")
	local holder = ns.Anchor.Frame()
	local footprint = K.Setup.Layouts.Element(KEY)
	assert(Near(holder:GetWidth(), footprint.width) and Near(holder:GetHeight(), footprint.height), "built at its footprint")
	local default = K.Setup.Layouts.Default(KEY)
	local point, relative, relativePoint = holder:GetPoint(1)
	assert(point == default.anchor and relative == K.Scale.Root() and relativePoint == default.anchor, "placed at the DPS position")

	local tip = env.GameTooltip
	env.GameTooltip_SetDefaultAnchor(tip, env.UIParent)
	assert(tip:GetNumPoints() == 1, "one point")
	point, relative, relativePoint = tip:GetPoint(1)
	assert(point == "BOTTOMRIGHT" and relative == holder and relativePoint == "BOTTOMRIGHT", "a fixed tooltip grows up and left from the anchor's bottom right")

	assert(K.Layout.Set(KEY, "anchor", "TOPLEFT"))
	assert(K.Layout.Set(KEY, "x", 40) and K.Layout.Set(KEY, "y", -60))
	env.GameTooltip_SetDefaultAnchor(tip, env.UIParent)
	point, relative = tip:GetPoint(1)
	assert(point == "TOPLEFT" and relative == holder, "near the top left it grows down and right")

	K.Options.Write("Tooltips", "anchor", "cursor")
	K.Options.Write("Tooltips", "cursorX", 12)
	K.Options.Write("Tooltips", "cursorY", -4)
	env.GameTooltip_SetDefaultAnchor(tip, env.UIParent)
	assert(tip._anchor[1] == "ANCHOR_CURSOR_RIGHT" and tip._anchor[2] == 12 and tip._anchor[3] == -4, "the cursor setting follows the pointer with its offsets")
	assert(tip:GetOwner() == env.UIParent, "the owner stays the caller's")

	local other = env.ShoppingTooltip1
	env.GameTooltip_SetDefaultAnchor(other, env.UIParent)
	relative = select(2, other:GetPoint(1))
	assert(other._anchor[1] == "ANCHOR_NONE" and relative == env.GameTooltipDefaultContainer, "only GameTooltip follows the cursor setting")
	K.Options.Write("Tooltips", "anchor", "fixed")
	env.GameTooltip_SetDefaultAnchor(other, env.UIParent)
	relative = select(2, other:GetPoint(1))
	assert(relative == env.GameTooltipDefaultContainer, "and only GameTooltip moves to the anchor")

	K.Modules.Disable("Tooltips")
	env.GameTooltip_SetDefaultAnchor(tip, env.UIParent)
	relative = select(2, tip:GetPoint(1))
	assert(tip._anchor[1] == "ANCHOR_NONE" and relative == env.GameTooltipDefaultContainer, "off, Blizzard's default anchor stands")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Scale: one tooltip unit is one root unit, times the anchor element's scale ------------------------

do
	local env, K, ns = Enabled()
	local function expected()
		return ns.Logic.TooltipScale(K.Scale.Root():GetEffectiveScale(), env.UIParent:GetEffectiveScale(), ns.Anchor.Frame():GetScale())
	end
	for name in pairs(T.TOOLTIPS) do
		assert(Near(env[name]:GetScale(), expected()), name .. " is scaled to root units")
	end
	local tip = env.GameTooltip
	tip:AddLine("Title", 1, 1, 1)
	tip:AddLine("Line", 1, 1, 1)
	T.PostCall(env, tip, { type = env.Enum.TooltipDataType.Spell, id = 133 })
	local divider = ns.Style.Glass(tip).divider
	assert(divider:IsShown() and Near(divider:GetHeight(), K.Widgets.Border(ns.Style.Glass(tip))), "the divider is one border thick")
	assert(K.Layout.Set(KEY, "scale", 1.5))
	assert(Near(ns.Anchor.Frame():GetScale(), 1.5), "Layout scales the anchor")
	assert(Near(env.GameTooltip:GetScale(), expected()), "and every tooltip follows")
	assert(Near(divider:GetHeight(), K.Widgets.Border(ns.Style.Glass(tip))), "a shown divider stays one whole border thick at the new scale")
	K.Modules.Disable("Tooltips")
	assert(env.GameTooltip:GetScale() == 1, "Disable gives Blizzard its scale back")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The kit's type: the title is body-size upper case, the rarity a caption, lines pitched half a unit apart
-- (the design's 13.5-unit pitch for 11-unit lines) --

do
	local env, K, ns = Enabled()
	assert(ns.Style.KIT_ROLES.title == "body" and ns.Style.KIT_ROLES.small == "caption", "the title takes the body role, the rarity the caption role")
	for name in pairs(T.TOOLTIPS) do
		assert(env[name]._lineSpacing == 0.5, name .. ": lines sit half a unit apart")
	end
	assert(ns.Settings.Get("iconSize") == 50, "the icon tile is the design's 50 units")
	assert(ns.Style.Glass(env.GameTooltip).chrome:Chamfer() == K.Tokens.Size("chamferPanel"), "the glass keeps the kit's panel chamfer")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Post-calls: item quality edges, the title divider and softened line colours ------------------------

do
	local env, K, ns, snap = Enabled()
	local Item = env.Enum.TooltipDataType.Item
	assert(env._postCalls[Item] == nil and #(env._postCalls.ALL or {}) == 1, "one post-call serves every tooltip type")
	local tip = env.GameTooltip
	local glass = ns.Style.Glass(tip)
	env._items[19019] = { quality = 3, icon = 135349 }
	tip:SetOwner(env.UIParent, "ANCHOR_NONE")
	tip:AddLine("Thunderfury", 1, 1, 1)
	tip:AddLine("Binds when picked up", 1, 1, 1)
	tip:AddLine("Chance on hit", 1, 0.82, 0)
	tip:AddLine("Crafting Reagent", 0.4, 0.7, 1)
	tip:AddLine("+5 Agility", 1, 1, 1)
	tip:AddLine("Durability 100 / 100", 1, 1, 1)
	T.PostCall(env, tip, { type = Item, id = 19019 })
	assert(SameEdge(glass, K.Tokens.Color("edgeInner")), "by default the panel keeps the kit's faint hairline")
	K.Options.Write("Tooltips", "qualityEdge", true)
	T.PostCall(env, tip, { type = Item, id = 19019 })
	assert(SameEdge(glass, K.Theme.QualityColor(3)), "a rare item lights the edge in the rare colour")
	assert(glass.divider:IsShown(), "an item with stats shows the accent rule")
	local _, relative = glass.divider:GetPoint(1)
	assert(relative == tip:GetLeftLine(4), "the rule sits under the last base line, above the first stat")
	assert(Near(glass.divider:GetWidth(), K.Widgets.Snap(glass, 56)), "and runs 56 units")
	assert(W.SameColor(glass.divider, K.Theme.Accent()), "the divider follows the class colour")
	assert(glass.footer:IsShown(), "a durability line gets the faint divider before it")
	local fpoint, frelative, frelativePoint, fx = glass.footer:GetPoint(1)
	assert(fpoint == "BOTTOMLEFT" and frelative == tip:GetLeftLine(6) and frelativePoint == "TOPLEFT", "the footer divider sits above the durability line")
	local padLeft = select(3, tip:GetPadding())
	assert(Near(10 + padLeft + fx, K.Widgets.Snap(glass, 13)), "it starts 13 units inside the panel's left edge, whatever the icon's column")
	local rpoint, rrelative, rrelativePoint, rx = glass.footer:GetPoint(2)
	assert(rpoint == "RIGHT" and rrelative == glass and rrelativePoint == "RIGHT" and Near(rx, -K.Widgets.Snap(glass, 13)), "and ends 13 units short of the right edge, the design's fading divider")
	assert(W.LastCall(glass.footer, "SetTexture")[1] == K.Tokens.Texture("divider"), "the kit's divider texture, which fades at both ends")
	assert(W.SameColor(glass.footer, K.Tokens.Color("edgeFaint")), "in the faint edge colour")
	assert(Near(glass.footer:GetHeight(), K.Widgets.Border(glass)), "one border thick")
	local r, g, b = tip:GetLeftLine(3):GetTextColor()
	local tr, tg, tb = K.Tokens.Color("text")
	assert(Near(r, tr) and Near(g, tg) and Near(b, tb), "gold lines soften to KstyleUI's body grey")
	r, g, b = tip:GetLeftLine(2):GetTextColor()
	assert(Near(r, tr) and Near(g, tg) and Near(b, tb), "white lines soften to the same body grey")
	r, g, b = tip:GetLeftLine(5):GetTextColor()
	local ar, ag, ab = K.Theme.Accent()
	assert(Near(r, ar) and Near(g, ag) and Near(b, ab), "stat lines take the accent")
	r, g, b = tip:GetLeftLine(4):GetTextColor()
	assert(Near(r, 0.4) and Near(g, 0.7) and Near(b, 1), "coloured lines keep their colour")

	ns.Style.ApplyScale(1.2)
	assert(select(2, glass.divider:GetPoint(1)) == tip:GetLeftLine(4) and Near(glass.divider:GetWidth(), K.Widgets.Snap(glass, 56)), "a rescale keeps the rule under the base lines at 56 units")
	assert(glass.footer:IsShown() and select(2, glass.footer:GetPoint(1)) == tip:GetLeftLine(6) and Near(glass.footer:GetHeight(), K.Widgets.Border(glass)), "and redraws the footer divider one border thick")
	ns.Style.ApplyScale(1)

	tip:ClearLines()
	tip:AddLine("Thunderfury", 1, 1, 1)
	tip:AddLine(env.Secret("Binds when picked up"), 1, 1, 1)
	tip:AddLine("+5 Agility", 1, 1, 1)
	tip:AddLine(env.Secret("Durability 100 / 100"), 1, 1, 1)
	T.PostCall(env, tip, { type = Item, id = 19019 })
	assert(#env._errors == 0, "secret lines never reach a comparison: " .. tostring(env._errors[1]))
	assert(glass.divider:IsShown() and select(2, glass.divider:GetPoint(1)) == tip:GetLeftLine(2), "a secret line is skipped; the rule still sits above the stats")
	assert(not glass.footer:IsShown(), "a secret durability line gets no footer divider")

	tip:ClearLines()
	assert(SameEdge(glass, K.Tokens.Color("edgeInner")), "clearing the tooltip returns the edge to the glass hairline")
	assert(not glass.divider:IsShown(), "and hides the divider")
	assert(not glass.footer:IsShown(), "and the footer divider")

	env._items[2589] = { quality = 1 }
	tip:AddLine("Linen Cloth", 1, 1, 1)
	tip:AddLine("Crafting Reagent", 0.4, 0.7, 1)
	T.PostCall(env, tip, { type = Item, id = 2589 })
	assert(SameEdge(glass, K.Tokens.Color("edgeInner")), "a common item keeps the glass edge")
	assert(glass.divider:IsShown() and select(2, glass.divider:GetPoint(1)) == tip.TextLeft1, "an item without stats keeps the rule under its title")
	assert(not glass.footer:IsShown(), "and shows no footer divider")

	tip:ClearLines()
	tip:AddLine("Fireball", 1, 1, 1)
	tip:AddLine("40 yd range", 1, 1, 1)
	T.PostCall(env, tip, { type = env.Enum.TooltipDataType.Spell, id = 133 })
	assert(glass.divider:IsShown() and select(2, glass.divider:GetPoint(1)) == tip.TextLeft1, "a spell keeps the rule under its title")

	tip:ClearLines()
	tip:AddLine("Single line", 1, 1, 1)
	T.PostCall(env, tip, { type = env.Enum.TooltipDataType.Object })
	assert(not glass.divider:IsShown(), "a one-line tooltip has no divider")

	tip:ClearLines()
	tip:AddLine("Secret", 1, 1, 1)
	tip:AddLine("Data", 1, 1, 1)
	T.PostCall(env, tip, { type = Item, id = env.Secret(19019), hyperlink = env.Secret("|Hitem:19019|h") })
	assert(SameEdge(glass, K.Tokens.Color("edgeInner")), "a secret item is left alone")

	K.Options.Write("Tooltips", "qualityEdge", false)
	K.Options.Write("Tooltips", "divider", false)
	K.Options.Write("Tooltips", "softColors", false)
	tip:ClearLines()
	tip:AddLine("Thunderfury", 1, 1, 1)
	tip:AddLine("Chance on hit", 1, 0.82, 0)
	T.PostCall(env, tip, { type = Item, id = 19019 })
	assert(SameEdge(glass, K.Tokens.Color("edgeInner")) and not glass.divider:IsShown(), "each switch turns its part off")
	r, g = tip:GetLeftLine(2):GetTextColor()
	assert(Near(r, 1) and Near(g, 0.82), "lines keep Blizzard's colours with softening off")

	local stranger = T.Tooltip(env, "AddonTooltip")
	stranger:AddLine("Not ours", 1, 0.82, 0)
	stranger:AddLine("Not ours", 1, 0.82, 0)
	T.PostCall(env, stranger, { type = Item, id = 19019 })
	assert(ns.Style.Glass(stranger) == nil, "another addon's tooltip is left alone")

	K.Modules.Disable("Tooltips")
	tip:ClearLines()
	tip:AddLine("Thunderfury", 1, 1, 1)
	tip:AddLine("Chance on hit", 1, 0.82, 0)
	K.Options.Write("Tooltips", "qualityEdge", true)
	T.PostCall(env, tip, { type = Item, id = 19019 })
	assert(SameEdge(glass, K.Tokens.Color("edgeInner")), "off, the post-calls do nothing")
	assert(K.Modules.Enable("Tooltips") and #env._postCalls.ALL == 1, "turning it on again adds no second post-call")
	T.Check(env, snap)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Accent: the divider follows the class colour or a custom colour ------------------------------------

do
	local env, K, ns = Enabled()
	local tip = env.GameTooltip
	local glass = ns.Style.Glass(tip)
	K.Options.Write("Tooltips", "accentSource", "custom")
	K.Options.Write("Tooltips", "accentColor", { r = 0.2, g = 0.4, b = 0.6 })
	tip:AddLine("Title", 1, 1, 1)
	tip:AddLine("Line", 1, 1, 1)
	T.PostCall(env, tip, { type = env.Enum.TooltipDataType.Spell, id = 133 })
	assert(W.SameColor(glass.divider, 0.2, 0.4, 0.6), "a custom accent colours the divider")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Preview: the settings window's live sample follows the settings -------------------------------------

do
	local env, K = Enabled()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	local frame = K.Options.Preview("Tooltips")(parent)
	assert(type(frame) == "table" and frame:GetParent() == parent and type(frame.Refresh) == "function", "the preview builds a frame with Refresh")
	frame:Refresh()
	local _, size = frame.title:GetFont()
	assert(Near(size, 11 * K.Theme.FontScale()), "the sample title uses the title size")
	K.Options.Write("Tooltips", "title.size", 20)
	frame:Refresh()
	_, size = frame.title:GetFont()
	assert(Near(size, 20 * K.Theme.FontScale()), "a size change shows in the sample")
	assert(frame.title:GetText() == "RANGER'S LONG BOW" and frame.caption:GetText() == "RARE", "the sample name in capitals over its rarity caption")
	assert(select(2, frame.icon:GetPoint(1)) == frame.glass, "the sample icon sits inside the sample panel")
	assert(SameEdge(frame.glass, K.Tokens.Color("edgeInner")), "the sample keeps the kit's faint hairline")
	K.Options.Write("Tooltips", "qualityEdge", true)
	frame:Refresh()
	assert(SameEdge(frame.glass, K.Theme.QualityColor(3)), "the sample item lights its edge")
	K.Options.Write("Tooltips", "qualityEdge", false)
	frame:Refresh()
	assert(SameEdge(frame.glass, K.Tokens.Color("edgeInner")), "and stops when the switch is off")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A client without the tooltip data processor or a tooltip still enables, and logs what it skipped ----

do
	local env, K = T.New({
		setup = function(env)
			env.TooltipDataProcessor = nil
			env.ItemRefTooltip = nil
		end,
	})
	assert(K.Modules.Enable("Tooltips") and K.Modules.IsRunning("Tooltips"), "the module still runs")
	local logged = {}
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.module == "Tooltips" then
			logged[#logged + 1] = entry.message
		end
	end
	local text = table.concat(logged, "\n")
	assert(text:find("TooltipDataProcessor", 1, true) and text:find("ItemRefTooltip", 1, true), "both gaps are logged: " .. text)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("tooltips ok")
