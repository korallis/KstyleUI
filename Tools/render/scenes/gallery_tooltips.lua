-- gallery_tooltips.lua: KstyleUI_Tooltips' frames in a filled state, each cropped as one frame of the gallery: a
-- friendly player's tooltip with its health bar, a hostile elite's, a spell tooltip with its icon tile, a quest
-- tooltip with an embedded item, a shopping tooltip under its compare header, and the settings window's live
-- preview. GameTooltip and its health bar are one per environment, so each tooltip is built in its own stub
-- environment and the scenes are merged; the lines are laid out by scenes/tooltip.lua as the game lays them.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Tooltip = dofile("Tools/render/scenes/tooltip.lua")
local Scene = Common.Scene
local I = Hud.ICONS

local WHITE = { 1, 1, 1 }
local GOLD = { 1, 0.82, 0 }
local GREY = { 0.5, 0.5, 0.5 }
local RARE = { 0, 0.44, 0.87 }
local UNCOMMON = { 0.12, 1, 0 }
local SWORD, BOOTS, MORTAL_STRIKE = 19019, 4232, 12294
local EMBEDDED_ICON = 32
local EMBEDDED_GAP = 6
local HEADER_HEIGHT = 22

-- Units(env) gives a stub environment the unit API the module reads: a warrior player in a guild whose
-- target is you, and a hostile crocolisk whose target is Thargor.
local function Units(env)
	env.RAID_CLASS_COLORS.PRIEST = { r = 1, g = 1, b = 1 }
	env._units = {
		mouseover = { guid = "Player-1-0001", name = "Valerin", player = true, class = "WARRIOR", reaction = 5, guild = { "Kstyle", "Officer", 1 }, myGuild = true },
		mouseovertarget = { guid = "Player-1-0002", name = "Tester", player = true, class = "PRIEST", reaction = 5, isPlayer = true },
		nameplate1 = { guid = "Creature-0-1-1-1-299-0001", name = "Riverglade Crocolisk", reaction = 2 },
		nameplate1target = { guid = "Player-1-0003", name = "Thargor", player = true, class = "WARRIOR", reaction = 5 },
	}
	local byGuid = {}
	for unit, info in pairs(env._units) do
		byGuid[info.guid] = byGuid[info.guid] or unit
	end
	env.UnitTokenFromGUID = function(guid)
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
		if unit == "player" or unit == nil then
			return "Warrior", "WARRIOR", 1
		end
		local info = env._units[unit]
		if info and info.class then
			return info.class, info.class, 1
		end
	end
	env.UnitReaction = function(unit)
		local info = env._units[unit]
		return info and info.reaction
	end
	env.UnitName = function(unit)
		local info = env._units[unit]
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
			if id == MORTAL_STRIKE then
				return I.mortalStrike, I.mortalStrike
			end
		end,
	}
	env._items[SWORD] = { quality = 3, icon = I.mortalStrike }
	env._items[BOOTS] = { quality = 2, icon = I.shieldBlock }
end

-- newEnv() -> env, K, ns with the module running.
local function newEnv()
	local T = dofile("Tools/regression/tooltips_env.lua")
	local env, K, ns = T.New({
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		saved = Gallery.Saved({ "Tooltips" }),
		setup = function(env)
			Gallery.Setup(env)
			Units(env)
		end,
	})
	if not K.Modules.IsRunning("Tooltips") then
		K.Modules.Enable("Tooltips")
	end
	env.RunTimers()
	return T, env, K, ns
end

-- lines(tip, list) adds each { left, right, colour } line as Blizzard would.
local function lines(tip, list)
	for _, line in ipairs(list) do
		local c = line[3] or WHITE
		if line[2] then
			tip:AddDoubleLine(line[1], line[2], c[1], c[2], c[3], 1, 1, 1)
		else
			tip:AddLine(line[1], c[1], c[2], c[3])
		end
	end
end

local function at(env, tip, x, y)
	tip:SetOwner(env.UIParent, "ANCHOR_NONE")
	tip:ClearAllPoints()
	tip:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", x, -y)
end

-- unit(T, env, tip, token, list, health) shows a unit tooltip with its health bar at the given fraction.
local function unit(T, env, tip, token, list, health)
	local info = env._units[token]
	lines(tip, list)
	T.BlizzardShow(tip, true)
	T.PostCall(env, tip, { type = env.Enum.TooltipDataType.Unit, guid = info.guid, healthGUID = info.guid })
	Tooltip.Layout(env, tip)
	T.BlizzardShow(tip.StatusBar, true)
	tip.StatusBar:SetValue(health)
end

local function settle(T, env)
	env.RunTimers()
	T.W.Settle(env)
end

return Common.Run(function()
	local frames = Gallery.Frames()
	local scenes, extra = {}, {}

	-- A friendly player: class-coloured name, guild and rank, the target line, the health bar.
	local T1, env1, K1, ns1 = newEnv()
	K1.Options.Write("Tooltips", "guildRank", true)
	local player = env1.GameTooltip
	at(env1, player, 60, 80)
	unit(T1, env1, player, "mouseover", { { "Valerin" }, { "Kstyle" }, { "Level 38 Orc Warrior (Player)" } }, 0.82)
	settle(T1, env1)
	frames:Add(env1, player, {
		name = "tooltips_unit_player", title = "Player tooltip", grade = "panel", reference = "player",
		caption = "GameTooltip restyled by Style.lua: a panel-grade glass with the two-line edge and shadow; the name in the class colour, the guild in angle brackets with the rank, the Target line, and Health.lua's bar below on the bar grade in the class colour.",
		match = "Fill, edge lines, 8-unit chamfer and drop shadow as the mockup's unit frame glass; the health bar's track and faint edgeBar line match its buff bars. The mockup shows no tooltip.",
		rect = Gallery.Union(env1, { player, ns1.Health.Bar() }),
	})

	-- A hostile elite: reaction-coloured name, level and classification, its target, the bar in the reaction colour.
	local T2, env2, K2, ns2 = newEnv()
	local hostile = env2.GameTooltip
	at(env2, hostile, 60, 330)
	unit(T2, env2, hostile, "nameplate1", { { "Riverglade Crocolisk" }, { "Level 38 (Elite) Beast" } }, 0.56)
	settle(T2, env2)
	frames:Add(env2, hostile, {
		name = "tooltips_unit_hostile", title = "Hostile tooltip", grade = "panel", reference = "target",
		caption = "GameTooltip on a hostile elite: the name in the hostile reaction colour, the level and classification line, the Target line naming Thargor in his class colour, and the health bar filled in the reaction colour.",
		match = "Glass as the mockup's target frame: fill, two-line edge, 8-unit chamfer, shadow; the bar on the bar grade.",
		rect = Gallery.Union(env2, { hostile, ns2.Health.Bar() }),
	})

	-- A spell: rank, cost and range, cast time, description, the icon tile with the accent rim.
	local T3, env3, K3 = newEnv()
	local spell = env3.GameTooltip
	at(env3, spell, 360, 80)
	lines(spell, {
		{ "Mortal Strike", "Rank 4", GOLD },
		{ "30 Rage", "Melee Range" },
		{ "Instant" },
		{ "A vicious strike that deals weapon damage plus 160", nil, GOLD },
		{ "and wounds the target, reducing the effectiveness", nil, GOLD },
		{ "of any healing by 50% for 10 sec.", nil, GOLD },
	})
	T3.BlizzardShow(spell, true)
	T3.PostCall(env3, spell, { type = env3.Enum.TooltipDataType.Spell, id = MORTAL_STRIKE })
	Tooltip.Layout(env3, spell)
	settle(T3, env3)
	frames:Add(env3, spell, {
		name = "tooltips_spell", title = "Spell tooltip", grade = "panel", reference = "player",
		caption = "GameTooltip on a spell: the title line with its rank, cost and range, cast time and description, the accent rule under the title, and Style.IconTile's icon on a buttonFill tile with the accent rim at half strength.",
		match = "Glass as the mockup's unit frames; the icon tile is the mockup's button body with a one-border rim and no bezel, as its buff icons.",
	})

	-- A quest tooltip with an embedded reward item: the item's icon on the module's border tile.
	local T4, env4, K4 = newEnv()
	local quest = env4.GameTooltip
	at(env4, quest, 360, 330)
	lines(quest, { { "Crocolisk Hunt", nil, GOLD }, { "Riverglades", nil, GREY }, { "Collect 8 Crocolisk Hides for Riverglades." }, { "Rewards:" } })
	T4.BlizzardShow(quest, true)
	T4.PostCall(env4, quest, { type = env4.Enum.TooltipDataType.Object })
	Tooltip.Layout(env4, quest)
	local item = quest.ItemTooltip
	local last = quest:GetLeftLine(quest:NumLines())
	item:ClearAllPoints()
	item:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -EMBEDDED_GAP)
	item:SetSize(EMBEDDED_ICON, EMBEDDED_ICON)
	item.Icon:SetAllPoints(item)
	item.Icon:SetTexture(I.shieldBlock)
	item.IconBorder:SetAllPoints(item)
	item.IconBorder:SetVertexColor(UNCOMMON[1], UNCOMMON[2], UNCOMMON[3])
	local reward = item:CreateFontString(nil, "ARTWORK", "GameTooltipText")
	reward:SetPoint("LEFT", item, "RIGHT", EMBEDDED_GAP, 0)
	reward:SetText("Crocolisk Hide Boots")
	reward:SetTextColor(UNCOMMON[1], UNCOMMON[2], UNCOMMON[3])
	T4.BlizzardShow(item, true)
	quest:SetHeight(quest:GetHeight() + EMBEDDED_ICON + EMBEDDED_GAP)
	settle(T4, env4)
	frames:Add(env4, quest, {
		name = "tooltips_item_embedded", title = "Embedded item", grade = "button", reference = "bufficons",
		caption = "GameTooltip's embedded ItemTooltip for a quest reward: Blizzard's icon and border stripped, and Style.ItemBorder's frame (Style.lua:464) around the icon on a buttonFill tile with its edge in the item's quality colour.",
		match = "Tile body and one-border rim as the mockup's buff icons, the rim in the uncommon green; the tooltip behind it is the panel glass.",
	})
	extra[#extra + 1] = "the embedded item frame is placed by the scene; the game's GameTooltip_InsertFrame places and sizes it"

	-- A shopping tooltip under its compare header.
	local compare = env1.ShoppingTooltip1
	at(env1, compare, 720, 80 + HEADER_HEIGHT)
	lines(compare, {
		{ "Vanquisher's Blade", nil, RARE },
		{ "Item Level 42", nil, GOLD },
		{ "Binds when picked up" },
		{ "Two-Hand", "Sword" },
		{ "142 - 198 Damage", "Speed 3.40" },
		{ "(50.0 damage per second)" },
		{ "+24 Strength" },
		{ "+18 Stamina" },
		{ "Durability 96 / 100" },
		{ "Requires Level 38" },
	})
	local header = compare.CompareHeader
	header:ClearAllPoints()
	header:SetPoint("BOTTOMLEFT", compare, "TOPLEFT", 0, 0)
	header:SetPoint("BOTTOMRIGHT", compare, "TOPRIGHT", 0, 0)
	header:SetHeight(HEADER_HEIGHT)
	header.Label:SetPoint("CENTER", header, "CENTER")
	header.Label:SetText("Currently Equipped")
	T1.BlizzardShow(compare, true)
	T1.BlizzardShow(header, true)
	T1.PostCall(env1, compare, { type = env1.Enum.TooltipDataType.Item, id = SWORD })
	Tooltip.Layout(env1, compare)
	settle(T1, env1)
	frames:Add(env1, compare, {
		name = "tooltips_compare", title = "Compare tooltip", grade = "panel", reference = "player",
		caption = "ShoppingTooltip1 under its CompareHeader: the glass on the panel grade, the header's Blizzard art stripped and replaced by a buttonFill tile (Style.lua:112) with the caption Currently Equipped, the item's icon tile and the rare quality caption.",
		match = "Glass fill, edge and chamfer as the mockup's unit frames; the header tile is the button body with the plain hairline. The shopping glass draws no shadow (Style.lua:135 turns it off for tooltips with a compare header), unlike the mockup's panels.",
		rect = Gallery.Union(env1, { compare, header }),
	})
	extra[#extra + 1] = "the compare header is placed by the scene above its tooltip; Blizzard's ShoppingTooltipTemplate anchors it"

	-- The preview, on a plain frame the settings window's size.
	local parent = env1.CreateFrame("Frame", nil, K1.Scale.Root())
	parent:SetSize(260, 430)
	parent:SetPoint("TOPLEFT", K1.Scale.Root(), "TOPLEFT", 1020, -80)
	local preview = K1.Options.Preview("Tooltips")(parent)
	preview:Refresh()
	settle(T1, env1)
	frames:Add(env1, parent, {
		name = "tooltips_preview", title = "Tooltips preview", grade = "panel", reference = "player",
		caption = "Preview.lua in the settings window: an item sample with the icon tile, rare caption and accent rule, and a unit sample with the guild line, the Target line and the health bar, both on panel-grade glass (Preview.lua:84).",
		match = "Both glasses match the mockup's unit frame glass: surface fill, two-line edge, 8-unit chamfer, shadow; the bar on the bar grade.",
	})

	for _, pair in ipairs({ { env1, K1 }, { env2, K2 }, { env3, K3 }, { env4, K4 } }) do
		scenes[#scenes + 1] = Scene.Build(pair[1])
	end
	local scene = Scene.Merge(scenes)
	for _, pair in ipairs({ { env2, K2 }, { env3, K3 }, { env4, K4 } }) do
		local err = Common.Errors(pair[1], pair[2])
		if err then
			scene.log[#scene.log + 1] = "error: " .. err
		end
	end
	for _, line in ipairs(extra) do
		scene.log[#scene.log + 1] = line
	end
	scene.log[#scene.log + 1] = "the tooltips' lines are laid out by the scene; the game's GameTooltip sizes and places its own text"
	return frames:Finish(scene, env1, K1, "gallery tooltips")
end)
