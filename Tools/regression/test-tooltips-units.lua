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
	assert(Colored(tip:GetLeftLine(1), K.Tokens.Color("textEmphasis")), "names keep Blizzard's colour, softened, with the switch off")
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
	assert(not glass.icon:IsShown(), "a comparison tooltip beside it hides the icon, so they never overlap")
	tip:ClearLines()
	tip:AddLine("Thunderfury", 1, 1, 1)
	T.PostCall(env, tip, { type = Item, id = 19019 })
	assert(not glass.icon:IsShown(), "and keeps it hidden while the comparison shows")
	T.BlizzardShow(env.ShoppingTooltip1, false)

	local shopping = env.ShoppingTooltip1
	shopping:AddLine("Thunderfury", 1, 1, 1)
	T.PostCall(env, shopping, { type = Item, id = 19019 })
	assert(ns.Style.Glass(shopping).icon == nil, "comparison tooltips show no icon")

	K.Options.Write("Tooltips", "icon", false)
	tip:ClearLines()
	tip:AddLine("Fireball", 1, 1, 1)
	T.PostCall(env, tip, { type = Spell, id = 133 })
	assert(not glass.icon:IsShown(), "the switch turns the icon off")
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
