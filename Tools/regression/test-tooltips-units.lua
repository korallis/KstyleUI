-- test-tooltips-units.lua: KstyleUI_Tooltips' unit lines, health bar, IDs, icon and embedded item border, with secrets passed through untouched.
local T = dofile("Tools/regression/tooltips_env.lua")
local W = T.W
local Near = T.Near

local Unit, Item, Spell, Aura

local function Enabled(opts)
	local env, K, ns = T.New(opts)
	Unit, Item = env.Enum.TooltipDataType.Unit, env.Enum.TooltipDataType.Item
	Spell, Aura = env.Enum.TooltipDataType.Spell, env.Enum.TooltipDataType.UnitAura
	local snap = T.Snapshot(env)
	assert(K.Modules.Enable("Tooltips") and K.Modules.IsRunning("Tooltips"), "Enable ran: " .. tostring(env._errors[1]))
	return env, K, ns, snap
end

local function SameRGB(r1, g1, b1, r2, g2, b2)
	return Near(r1, r2) and Near(g1, g2) and Near(b1, b2)
end

-- Colored(region, r, g, b): the font string's text colour is r, g, b.
local function Colored(region, r, g, b)
	local cr, cg, cb = region:GetTextColor()
	return SameRGB(cr, cg, cb, r, g, b)
end

-- Filled(bar, r, g, b): the status bar's fill colour is r, g, b.
local function Filled(bar, r, g, b)
	local cr, cg, cb = bar:GetStatusBarColor()
	return SameRGB(cr, cg, cb, r, g, b)
end

-- Units: a hunter player with a guild and a target, and a hostile NPC ----------------------------------

local function Units(env)
	local function color(r, g, b)
		return { r = r, g = g, b = b }
	end
	env.RAID_CLASS_COLORS = { HUNTER = color(0.67, 0.83, 0.45), PRIEST = color(1, 1, 1), WARRIOR = color(0.78, 0.61, 0.43) }
	env._units = {
		mouseover = { guid = "Player-1-0001", name = "Valerin", player = true, class = "HUNTER", reaction = 5, guild = { "Kstyle", "Officer", 1 } },
		mouseovertarget = { guid = "Player-1-0002", name = "Tester", player = true, class = "PRIEST", reaction = 5, isPlayer = true },
		nameplate1 = { guid = "Creature-0-1-1-1-299-0001", name = "Riverglade Crocolisk", reaction = 2 },
		nameplate1target = { guid = "Player-1-0003", name = "Thargor", player = true, class = "WARRIOR", reaction = 5 },
	}
	local byGuid = {}
	for unit, info in pairs(env._units) do
		byGuid[info.guid] = byGuid[info.guid] or unit
	end
	env.UnitTokenFromGUID = function(guid)
		if env.issecretvalue(guid) then
			return env.Secret("mouseover")
		end
		return byGuid[guid]
	end
	env.UnitExists = function(unit)
		return unit == "player" or env._units[unit] ~= nil
	end
	env.UnitIsPlayer = function(unit)
		local info = env._units[unit]
		return info ~= nil and info.player == true
	end
	env.UnitClass = function(unit)
		if unit == "player" then
			return "Hunter", "HUNTER", 3
		end
		local info = env._units[unit]
		if info and info.secretClass then
			return env.Secret("Hunter"), env.Secret(info.class), env.Secret(3)
		end
		if info and info.class then
			return info.class, info.class, 1
		end
	end
	env.UnitReaction = function(unit)
		local info = env._units[unit]
		return info and info.reaction
	end
	env.UnitName = function(unit)
		if unit == "player" then
			return "Tester"
		end
		local info = env._units[unit]
		if info and info.secretName then
			return env.Secret(info.name)
		end
		return info and info.name
	end
	env.UnitIsUnit = function(a, b)
		local ia, ib = env._units[a], env._units[b]
		if b == "player" then
			return ia ~= nil and ia.isPlayer == true
		end
		return ia ~= nil and ia == ib
	end
	env.GetGuildInfo = function(unit)
		local info = env._units[unit]
		if info and info.guild then
			return info.guild[1], info.guild[2], info.guild[3]
		end
	end
	env.UnitIsInMyGuild = function(unit)
		local info = env._units[unit]
		return info ~= nil and info.myGuild == true
	end
	env.C_Spell = {
		GetSpellTexture = function(id)
			if id == 133 then
				return 135812, 135812
			end
		end,
	}
end

local function ShowUnit(env, tip, unit, lines)
	local info = env._units[unit]
	tip:SetOwner(env.UIParent, "ANCHOR_NONE")
	for _, line in ipairs(lines) do
		tip:AddLine(line, 1, 1, 1)
	end
	T.PostCall(env, tip, { type = Unit, guid = info.guid, healthGUID = info.guid })
end

do
	local env, K, ns, snap = Enabled({ setup = Units })
	local tip = env.GameTooltip
	local glass = ns.Style.Glass(tip)
	ShowUnit(env, tip, "mouseover", { "Valerin", "Kstyle", "Level 38 Night Elf Hunter (Player)" })
	assert(Colored(tip:GetLeftLine(1), K.Theme.ClassColor("HUNTER")), "a player's name is class-coloured")
	assert(tip:GetLeftLine(2):GetText() == "<Kstyle>", "the guild line wears angle brackets, got " .. tostring(tip:GetLeftLine(2):GetText()))
	assert(Colored(tip:GetLeftLine(2), K.Tokens.Color("textEmphasis")), "another guild is emphasis white")
	local lines = T.Lines(tip)
	local last = lines[#lines]
	assert(last[1] == "Target" and last[2] == "You", "the target line names you")
	assert(Colored(tip:GetRightLine(#lines), K.Theme.Accent()), "you are in the accent colour")
	assert(Filled(ns.Health.Bar(), K.Theme.ClassColor("HUNTER")), "the bar takes the class colour")

	K.Options.Write("Tooltips", "guildRank", true)
	env._units.mouseover.myGuild = true
	ShowUnit(env, tip, "mouseover", { "Valerin", "<Kstyle>", "Level 38" })
	assert(tip:GetLeftLine(2):GetText() == "<Kstyle> Officer", "the rank follows the guild with the switch on")
	assert(Colored(tip:GetLeftLine(2), K.Tokens.Color("friendly")), "your own guild is friendly green")

	ShowUnit(env, tip, "nameplate1", { "Riverglade Crocolisk", "Level 38 Beast" })
	assert(Colored(tip:GetLeftLine(1), K.Theme.ReactionColor(2)), "an NPC's name takes its reaction colour")
	lines = T.Lines(tip)
	assert(lines[#lines][1] == "Target" and lines[#lines][2] == "Thargor", "the NPC's target is named")
	assert(Colored(tip:GetRightLine(#lines), K.Theme.ClassColor("WARRIOR")), "in its class colour")
	assert(Filled(ns.Health.Bar(), K.Theme.ReactionColor(2)), "an NPC's bar falls back to its reaction colour")

	K.Options.Write("Tooltips", "bar.color", "reaction")
	ShowUnit(env, tip, "mouseover", { "Valerin", "Kstyle" })
	assert(Filled(ns.Health.Bar(), K.Theme.ReactionColor(5)), "the reaction source colours players by reaction")
	K.Options.Write("Tooltips", "bar.color", "custom")
	K.Options.Write("Tooltips", "bar.custom", { r = 0.3, g = 0.6, b = 0.9 })
	ShowUnit(env, tip, "mouseover", { "Valerin", "Kstyle" })
	assert(Filled(ns.Health.Bar(), 0.3, 0.6, 0.9), "a custom bar colour")

	local e = glass.chrome.edge
	assert(SameRGB(e[1], e[2], e[3], K.Tokens.Color("edgeInner")), "units keep the glass edge by default")
	K.Options.Write("Tooltips", "unitEdge", true)
	ShowUnit(env, tip, "nameplate1", { "Riverglade Crocolisk" })
	e = glass.chrome.edge
	assert(SameRGB(e[1], e[2], e[3], K.Theme.ReactionColor(2)), "the unit edge takes the name's colour")

	K.Options.Write("Tooltips", "classNames", false)
	K.Options.Write("Tooltips", "guildLine", false)
	K.Options.Write("Tooltips", "targetLine", false)
	ShowUnit(env, tip, "mouseover", { "Valerin", "Kstyle", "Level 38" })
	assert(Colored(tip:GetLeftLine(1), K.Tokens.Color("text")), "names keep Blizzard's colour, softened to the body grey, with the switch off")
	assert(tip:GetLeftLine(2):GetText() == "Kstyle" and tip:NumLines() == 3, "no guild brackets and no target line")
	T.Check(env, snap)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Secrets: a secret GUID, class or target name is never compared, and never breaks the tooltip ------

do
	local env, K, ns = Enabled({ setup = Units })
	local tip = env.GameTooltip
	tip:SetOwner(env.UIParent, "ANCHOR_NONE")
	tip:AddLine("Someone", 1, 1, 1)
	T.PostCall(env, tip, { type = Unit, guid = env.Secret("Player-1-0001"), healthGUID = env.Secret("Player-1-0001") })
	assert(tip:NumLines() == 1, "a secret unit gets no extra lines")
	env._units.mouseover.secretClass = true
	env._units.mouseovertarget.secretName = true
	ShowUnit(env, tip, "mouseover", { "Valerin", "Kstyle" })
	local lines = T.Lines(tip)
	assert(lines[#lines][1] ~= "Target", "a secret target name adds no line")
	assert(Colored(tip:GetLeftLine(1), K.Theme.ReactionColor(5)), "a secret class falls back to the reaction colour")
	assert(#env._errors == 0, tostring(env._errors[1]))
	assert(ns ~= nil)
end

-- Health bar: Blizzard's values pass straight to KstyleUI's bar, secrets included ----------------------

do
	local env, K, ns, snap = Enabled({ setup = Units })
	local tip = env.GameTooltip
	local blizzard = tip.StatusBar
	local bar = ns.Health.Bar()
	assert(bar and bar:GetParent() == ns.Style.Glass(tip), "KstyleUI's bar lives on the glass")
	assert(bar.borderFrame and bar.chrome.owner == bar.borderFrame and bar.chrome.shapeName == "bar", "framed by the kit's pill track")
	assert(bar.backgroundName == "track" and W.SameColor(bar.background, K.Tokens.Color("track")), "over the kit's track")
	assert(not bar:IsShown(), "hidden until Blizzard shows a unit's health")
	assert(blizzard:GetStatusBarTexture():GetAlpha() == 0, "Blizzard's bar art is hidden by alpha")
	ShowUnit(env, tip, "mouseover", { "Valerin" })
	T.BlizzardShow(blizzard, true)
	assert(bar:IsShown(), "KstyleUI's bar shows with Blizzard's")
	local health = env.Secret(0.42)
	blizzard:SetValue(health)
	local passed = W.LastCall(bar, "SetValue")
	assert(passed and passed[1] == health, "the secret reaches KstyleUI's bar untouched")
	blizzard:SetValue(0.75)
	assert(W.LastCall(bar, "SetValue")[1] == 0.75, "plain values pass too")
	local p1 = { bar:GetPoint(1) }
	assert(p1[1] == "TOPLEFT" and p1[2] == tip and p1[3] == "BOTTOMLEFT", "under the tooltip")
	T.BlizzardShow(blizzard, false)
	assert(not bar:IsShown(), "and hides with it")

	K.Options.Write("Tooltips", "bar.orientation", "VERTICAL")
	K.Options.Write("Tooltips", "bar.reverse", true)
	K.Options.Write("Tooltips", "bar.size", 10)
	assert(W.LastCall(bar, "SetOrientation")[1] == "VERTICAL" and W.LastCall(bar, "SetReverseFill")[1] == true, "orientation and fill direction apply")
	p1 = { bar:GetPoint(1) }
	assert(p1[1] == "TOPLEFT" and p1[2] == tip and p1[3] == "TOPRIGHT", "a vertical bar stands beside the tooltip")
	local texture = "Interface\\AddOns\\SharedMedia\\Statusbar\\Smooth.tga"
	K.Options.Write("Tooltips", "bar.texture", texture)
	assert(bar:GetStatusBarTexture():GetTexture() == texture, "the texture setting applies")

	K.Options.Write("Tooltips", "healthBar", false)
	T.BlizzardShow(blizzard, true)
	assert(not bar:IsShown(), "the switch keeps it hidden")
	K.Modules.Disable("Tooltips")
	K.Options.Write("Tooltips", "healthBar", true)
	T.BlizzardShow(blizzard, true)
	assert(not bar:IsShown(), "off, KstyleUI's bar stays hidden")
	T.Check(env, snap)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- IDs and the icon ------------------------------------------------------------------------------------

do
	local env, K, ns = Enabled({ setup = Units })
	local tip = env.GameTooltip
	local glass = ns.Style.Glass(tip)
	env._items[19019] = { quality = 4, icon = 135349 }
	tip:AddLine("Thunderfury", 1, 1, 1)
	T.PostCall(env, tip, { type = Item, id = 19019 })
	assert(tip:NumLines() == 1, "no ID lines by default")
	assert(glass.icon:IsShown(), "the icon shows beside an item tooltip")
	assert(W.LastCall(glass.icon.texture, "SetTexture")[1] == 135349, "with the item's icon")

	K.Options.Write("Tooltips", "itemID", true)
	K.Options.Write("Tooltips", "iconID", true)
	K.Options.Write("Tooltips", "spellID", true)
	tip:ClearLines()
	assert(not glass.icon:IsShown(), "clearing the tooltip hides the icon")
	tip:AddLine("Thunderfury", 1, 1, 1)
	T.PostCall(env, tip, { type = Item, id = 19019 })
	local lines = T.Lines(tip)
	assert(lines[2][1] == "Item ID" and lines[2][2] == "19019", "the item ID")
	assert(lines[3][1] == "Icon ID" and lines[3][2] == "135349", "the icon ID")

	tip:ClearLines()
	tip:AddLine("Fireball", 1, 1, 1)
	T.PostCall(env, tip, { type = Spell, id = 133 })
	lines = T.Lines(tip)
	assert(lines[2][1] == "Spell ID" and lines[2][2] == "133" and lines[3][2] == "135812", "the spell and icon IDs")

	tip:ClearLines()
	tip:AddLine("Arcane Intellect", 1, 1, 1)
	T.PostCall(env, tip, { type = Aura, id = env.Secret(1459) })
	assert(tip:NumLines() == 1, "a secret aura ID adds nothing")

	tip:ClearLines()
	tip:AddLine("Thunderfury", 1, 1, 1)
	T.PostCall(env, tip, { type = Item, id = 19019 })
	assert(glass.icon:IsShown(), "the icon is back for the next item")
	T.BlizzardShow(env.ShoppingTooltip1, true)
	local shopping = env.ShoppingTooltip1
	shopping:AddLine("Thunderfury", 1, 1, 1)
	T.PostCall(env, shopping, { type = Item, id = 19019 })
	local other = ns.Style.Glass(shopping).icon
	assert(glass.icon:IsShown() and other and other:IsShown(), "a comparison tooltip shows its own icon and keeps GameTooltip's")
	assert(select(2, glass.icon:GetPoint(1)) == tip and select(2, other:GetPoint(1)) == shopping, "each inside its own panel, so they never overlap")
	T.BlizzardShow(env.ShoppingTooltip1, false)

	K.Options.Write("Tooltips", "icon", false)
	tip:ClearLines()
	tip:AddLine("Fireball", 1, 1, 1)
	T.PostCall(env, tip, { type = Spell, id = 133 })
	assert(not glass.icon:IsShown(), "the switch turns the icon off")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The kit's item tooltip: a rarity-lit icon square inside the top left corner, every line in a column
-- right of it, the name in tracked capitals in its rarity colour and a rarity caption under it -------

local TEXT_INSET = 10

local function Show(env, tip, kind, id, lines)
	tip:SetOwner(env.UIParent, "ANCHOR_NONE")
	for _, line in ipairs(lines) do
		tip:AddLine(line[1], line[2], line[3], line[4])
	end
	T.PostCall(env, tip, { type = kind, id = id })
end

do
	local env, K, ns, snap = Enabled({ setup = Units })
	local tip = env.GameTooltip
	local glass = ns.Style.Glass(tip)
	env._items[19019] = { quality = 3, icon = 135349, level = 60 }
	env._items[2589] = { quality = 1, icon = 132889 }
	Show(env, tip, Item, 19019, { { "Ranger's Long Bow", 0, 0.44, 0.87 }, { "Two-Hand", 1, 1, 1 }, { "+24 Agility", 0.1, 1, 0.1 } })
	local icon, title, caption = glass.icon, tip:GetLeftLine(1), glass.caption
	local point, relative, relativePoint, x, y = icon:GetPoint(1)
	assert(icon:IsShown() and point == "TOPLEFT" and relative == tip and relativePoint == "TOPLEFT", "the icon sits at the panel's top left")
	assert(Near(x, K.Widgets.Snap(icon, 9.5)) and Near(-y, K.Widgets.Snap(icon, 9.5)), "inset 9.5 units inside the panel")
	assert(Near(icon:GetWidth(), ns.Settings.Get("iconSize")) and Near(icon:GetHeight(), icon:GetWidth()), "a square")
	assert(icon.chrome.shapeName == "socket", "in the kit's rounded socket")
	local fr, fg, fb = icon.chrome.fill[5]:GetVertexColor()
	assert(SameRGB(fr, fg, fb, K.Tokens.Color("buttonFill")), "on the near-black button body every square icon shares")
	local left = select(3, tip:GetPadding())
	assert(x + icon:GetWidth() < TEXT_INSET + left, "Blizzard's lines start right of the icon")
	assert(Near(TEXT_INSET + left, x + icon:GetWidth() + 11), "the text column starts 11 units right of the icon, as in the design")
	tip:ClearPadding()
	assert(select(3, tip:GetPadding()) == left, "GameTooltip_OnShow clears the padding; the icon's column comes back")
	tip:SetPadding(16, 0)
	local right, _, kept = tip:GetPadding()
	assert(right == 16 and kept == left, "a close button's right padding keeps the icon's column")
	local e = icon.chrome.edge
	assert(SameRGB(e[1], e[2], e[3], K.Tokens.Color("rare")) and e[4] == 1, "its border is the rarity colour")
	local hr, hg, hb = icon.chrome.rim[1]:GetVertexColor()
	assert(SameRGB(hr, hg, hb, K.Tokens.Color("rare")) and icon.chrome.outer == nil, "drawn by the socket's one rim, as an action button")
	local glow = icon.glow
	assert(glow.holder:IsShown() and SameRGB(glow.colorRGB[1], glow.colorRGB[2], glow.colorRGB[3], K.Tokens.Color("rare")), "and it glows in it")
	assert(title:GetText() == "Ranger's Long Bow\n ", "the name in title case, as the heading face sets its own capitals, with a line kept for the caption")
	assert(Colored(title, K.Tokens.Color("rare")), "in the kit's rare colour")
	assert(caption:IsShown() and caption:GetText() == "Item level 60 \194\183 Rare" and Colored(caption, K.Tokens.Color("text")), "the item level and rarity as a muted caption")
	point, relative, relativePoint = caption:GetPoint(1)
	assert(point == "BOTTOMLEFT" and relative == title and relativePoint == "BOTTOMLEFT", "on the title's second line")
	assert(select(2, caption:GetFont()) == select(2, ns.Style.FontSpec("small")), "in the small line size")
	assert(glass.divider:IsShown() and select(2, glass.divider:GetPoint(1)) == tip:GetLeftLine(1), "the gilt rule runs under the header")
	e = glass.chrome.edge
	assert(SameRGB(e[1], e[2], e[3], K.Tokens.Color("edgeInner")), "the panel keeps its faint hairline")

	Show(env, tip, Item, 19019, { { "Ranger's Long Bow", 0, 0.44, 0.87 }, { "Item Level 60", 1, 0.82, 0 }, { "Two-Hand", 1, 1, 1 } })
	assert(caption:GetText() == "Rare", "when Blizzard's tooltip already carries an Item Level line, the caption reads the rarity alone, so the level never shows twice")
	Show(env, tip, Item, 2589, { { "Linen Cloth", 1, 1, 1 }, { "Crafting Reagent", 0.4, 0.7, 1 } })
	assert(caption:GetText() == "Common" and Colored(caption, K.Tokens.Color("text")), "a common item with no item level reads its rarity alone, body grey")
	assert(not glow.holder:IsShown(), "and its icon does not glow")

	ShowUnit(env, tip, "mouseover", { "Valerin", "Kstyle" })
	assert(not icon:IsShown() and not caption:IsShown(), "a unit after the item shows no icon and no caption")
	assert(select(3, tip:GetPadding()) == 0, "and gives Blizzard's lines their place back")
	assert(tip:GetLeftLine(1):GetText() == "Valerin", "unit names keep their case; the heading face carries the capitals")

	Show(env, tip, Spell, 133, { { "Fireball", 1, 1, 1 }, { "Hurls a fiery ball.", 1, 0.82, 0 } })
	assert(icon:IsShown() and not caption:IsShown() and tip:GetLeftLine(1):GetText() == "Fireball", "a spell: its icon and name, no caption")
	e = icon.chrome.edge
	assert(SameRGB(e[1], e[2], e[3], K.Theme.Accent()) and not glow.holder:IsShown(), "its border rests on the accent, unlit")
	tip:GetLeftLine(1)._state.StringHeight, tip:GetLeftLine(2)._state.StringHeight = { n = 1, 14 }, { n = 1, 14 }
	Show(env, tip, Spell, 133, { { "Auto Attack", 1, 1, 1 }, { "Toggles auto attack.", 1, 1, 1 } })
	assert(Near(icon:GetHeight(), K.Widgets.Snap(icon, 28.5), 0.01), "a two-line tooltip's icon shrinks to its lines (two 14-unit lines half a unit apart), so it never hangs below the panel")
	tip:GetLeftLine(1)._state.StringHeight, tip:GetLeftLine(2)._state.StringHeight = nil, nil

	local secret = env.Secret("Ranger's Long Bow")
	Show(env, tip, Item, 19019, { { secret, 1, 1, 1 }, { "Two-Hand", 1, 1, 1 } })
	assert(tip:GetLeftLine(1):GetText() == secret and not caption:IsShown(), "a secret name reaches the game untouched")

	K.Options.Write("Tooltips", "title.size", 10)
	K.Options.Write("Tooltips", "small.size", 20)
	Show(env, tip, Item, 19019, { { "Ranger's Long Bow", 1, 1, 1 } })
	assert(select(2, caption:GetFont()) <= select(2, ns.Style.FontSpec("title")), "the caption never outgrows the line the title keeps for it")

	K.Options.Write("Tooltips", "icon", false)
	Show(env, tip, Item, 19019, { { "Ranger's Long Bow", 1, 1, 1 } })
	assert(not icon:IsShown() and select(3, tip:GetPadding()) == 0, "with the icon off, lines keep Blizzard's place")
	T.Check(env, snap)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Embedded items: Blizzard's icon border hides, a KstyleUI tile edge takes its quality colour ------------

do
	local env, K, ns, snap = Enabled()
	local item = env.GameTooltip.ItemTooltip
	assert(item.IconBorder:GetAlpha() == 0, "Blizzard's icon border is hidden by alpha")
	assert(item.Icon:GetAlpha() == 1, "the icon itself stays")
	local frame = ns.Style.ItemBorder(item)
	assert(frame and frame:GetParent() == item, "a KstyleUI tile frames the icon")
	item.IconBorder:SetVertexColor(0.64, 0.21, 0.93)
	T.BlizzardShow(item.IconBorder, true)
	T.BlizzardShow(item, true)
	local e = frame.chrome.edge
	assert(SameRGB(e[1], e[2], e[3], 0.64, 0.21, 0.93), "the tile edge follows the quality colour Blizzard sets")
	T.BlizzardShow(item.IconBorder, false)
	T.BlizzardShow(item, true)
	e = frame.chrome.edge
	assert(SameRGB(e[1], e[2], e[3], K.Tokens.Color("edgeInner")), "a common item keeps the glass edge")
	T.Check(env, snap)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Preview: the unit sample follows the unit, bar and icon settings -----------------------------------

do
	local env, K = Enabled()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	local frame = K.Options.Preview("Tooltips")(parent)
	assert(frame.unit and frame.bar and frame.icon, "the preview has a unit sample, a bar and an icon")
	assert(frame.bar:IsShown() and frame.icon:IsShown(), "both show by default")
	local guild = frame.unit.rows[2].left
	assert(guild:GetText() == "<Kstyle>" and guild:IsShown(), "the sample guild line")
	K.Options.Write("Tooltips", "guildRank", true)
	K.Options.Write("Tooltips", "healthBar", false)
	K.Options.Write("Tooltips", "icon", false)
	K.Options.Write("Tooltips", "targetLine", false)
	frame:Refresh()
	assert(guild:GetText() == "<Kstyle> Officer", "the rank shows in the sample")
	assert(not frame.bar:IsShown() and not frame.icon:IsShown(), "the switches hide the bar and the icon")
	assert(not frame.unit.rows[4].left:IsShown(), "and the target line")
	K.Options.Write("Tooltips", "healthBar", true)
	K.Options.Write("Tooltips", "bar.color", "custom")
	K.Options.Write("Tooltips", "bar.custom", { r = 0.3, g = 0.6, b = 0.9 })
	frame:Refresh()
	assert(Filled(frame.bar, 0.3, 0.6, 0.9), "the sample bar takes the custom colour")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("tooltips units ok")
