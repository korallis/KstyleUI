-- Notices.lua: large alert lines over the world: entering and leaving combat, a group member's death, a potion ready again (potions share one cooldown, so any potion's ID reads it, and the last one seen in the bags stays known after they run out), unspent talent points and low durability, in the display font with the world outline, registering only the events their switches need. The flash line hangs from a fixed top with the talent line under it, spaced by their measured height, and the durability warning stands on Warning height, so no size overlaps them; a global text size change restyles them at once.
local _, ns = ...

local K, L = ns.K, ns.L
local Widgets, Tokens, Motion, Theme = K.Widgets, K.Tokens, K.Motion, K.Theme

local OWNER = "QoL.notices"
local HOLD = 2
local TOP = 216
local SOUNDS = { warning = "RAID_WARNING", ready = "READY_CHECK" }
local THROWN = 18
local CONSUMABLE, POTION, GCD = 0, 1, 1.5

local holder, potion, potionEnds
local lines, dead = {}, {}
local flashToken, flashKey, fighting, members = 0, nil, false, "^party%d$"

function ns.NoticeColor(prefix)
	if ns.Get(prefix .. "Class") then
		return Theme.ClassColor(select(2, UnitClass("player")))
	end
	local c = ns.Get(prefix .. "Color")
	return c.r, c.g, c.b
end

function ns.PaintNotice(text, value, r, g, b)
	Widgets.ApplyFont(text, (Tokens.Font("display")), ns.Get("alertSize") * Theme.FontScale(), "OUTLINE")
	text:SetTextColor(r, g, b)
	text:SetText(value)
end

function ns.NoticeText(prefix)
	local text = ns.Get(prefix .. "Text")
	if text ~= "" then return text end
	return prefix == "combatEnter" and L["+Combat"] or prefix == "combatLeave" and L["-Combat"] or L["Unspent talent points"]
end

function ns.NoticeSpot(slot, height)
	if slot == "durability" then return "BOTTOM", ns.Get("durabilityY") end
	return "TOP", slot == "talents" and TOP - height - Tokens.Size("gapMedium") or TOP
end

local function Fit(slot, line)
	Widgets.Size(line, Widgets.TextWidth(line.text, 1), Widgets.TextHeight(line.text, Widgets.LineHeight(line.text)))
	local point, y = ns.NoticeSpot(slot, line:GetHeight())
	line:ClearAllPoints()
	Widgets.Point(line, point, holder, "CENTER", 0, Widgets.Snap(holder, y))
end

local function Line(slot)
	if not holder then
		holder = CreateFrame("Frame", nil, K.Scale.Root())
		holder:SetFrameStrata("BACKGROUND")
		holder:SetAllPoints()
		holder.Restyle = function()
			for name, line in pairs(lines) do
				ns.PaintNotice(line.text, line.text:GetText(), line.text:GetTextColor())
				Fit(name, line)
			end
		end
		Widgets.Track(holder)
	end
	local line = lines[slot]
	if not line then
		line = CreateFrame("Frame", nil, holder)
		line.text = Widgets.FontString(line, "OVERLAY")
		Widgets.Point(line.text, "CENTER", line, "CENTER", 0, 0)
		line:Hide()
		lines[slot] = line
	end
	return line
end

local function Show(slot, value, r, g, b)
	local line = Line(slot)
	ns.PaintNotice(line.text, value, r, g, b)
	Fit(slot, line)
	if not line.wanted then
		line.wanted = true
		Motion.FadeIn(line)
	end
end

local function Hide(slot)
	local line = lines[slot]
	if line and line.wanted then
		line.wanted = false
		Motion.FadeOut(line)
	end
end

local function Flash(key, value, r, g, b)
	if not (C_Timer and type(C_Timer.After) == "function") then return end
	flashToken, flashKey = flashToken + 1, key
	local token = flashToken
	Show("flash", value, r, g, b)
	C_Timer.After(HOLD, function()
		if token == flashToken then Hide("flash") end
	end)
end

local function Combat(entering)
	local mode = ns.Get("combatAlertOn")
	if not ns.Get("combatAlert") or mode == (entering and "leave" or "enter") then return end
	local prefix = entering and "combatEnter" or "combatLeave"
	Flash("combatAlert", ns.NoticeText(prefix), ns.NoticeColor(prefix))
end

local function Talents()
	local unspent = ns.running and ns.Get("talentAlert") and not fighting and ns.Ask(C_ClassTalents and C_ClassTalents.HasUnspentTalentPoints) == true
	if unspent then Show("talents", ns.NoticeText("talent"), ns.NoticeColor("talent")) else Hide("talents") end
end

local function Thrown(slot)
	if slot ~= THROWN or not ns.Get("durabilityThrown") then return false end
	local id, info = ns.Number(ns.Ask(GetInventoryItemID, "player", slot)), C_Item and C_Item.GetItemInfoInstant
	return not (id and type(info) == "function") or select(4, info(id)) == "INVTYPE_THROWN"
end

local function Durability()
	local low
	if ns.running and ns.Get("durabilityAlert") and not fighting and type(GetInventoryItemDurability) == "function" then
		for slot = 1, THROWN do
			local now, most = GetInventoryItemDurability(slot)
			now, most = ns.Number(now), ns.Number(most)
			if now and most and most > 0 and now / most * 100 < ns.Get("durabilityPercent") and not Thrown(slot) then
				low = math.min(low or 100, now / most * 100)
			end
		end
	end
	if low then
		local r, g, b = Tokens.Color("neutral")
		Show("durability", string.format(L["Low durability: %d%%"], math.floor(low)), r, g, b)
	else
		Hide("durability")
	end
end

local function Fight(event)
	fighting = event == "PLAYER_REGEN_DISABLED"
	Combat(fighting)
	Talents()
	Durability()
end

local function Gone(unit)
	return ns.True(UnitIsDeadOrGhost(unit)) and not (type(UnitIsFeignDeath) == "function" and ns.True(UnitIsFeignDeath(unit)))
end

local function Roster()
	local raid = ns.Ask(IsInRaid) == true
	members, dead = raid and "^raid%d+$" or "^party%d$", {}
	for i = 1, raid and 40 or 4 do
		local unit = (raid and "raid" or "party") .. i
		dead[unit] = Gone(unit) or nil
	end
end

local function Health(_, unit)
	if type(unit) ~= "string" or not unit:find(members) or ns.Ask(UnitIsUnit, unit, "player") ~= false then return end
	if not Gone(unit) then dead[unit] = nil; return end
	if dead[unit] then return end
	dead[unit] = true
	local name = UnitName(unit)
	local r, g, b = Tokens.Color("hostile")
	Flash("deathAlert", type(name) == "string" and not ns.IsSecret(name) and string.format(L["%s died"], name) or L["A group member died"], r, g, b)
	ns.AlertSound(ns.Get("deathSound"))
end

function ns.AlertSound(choice)
	local kit = SOUNDKIT and SOUNDKIT[SOUNDS[choice]]
	if kit and type(PlaySound) == "function" then PlaySound(kit, "Master") end
end

local function Potions()
	local bags, info = C_Container, C_Item and C_Item.GetItemInfoInstant
	if not (bags and type(bags.GetContainerNumSlots) == "function" and type(info) == "function") then return end
	for bag = 0, ns.Number(NUM_BAG_SLOTS) or 4 do
		for slot = 1, ns.Number(ns.Ask(bags.GetContainerNumSlots, bag)) or 0 do
			local item = ns.Ask(bags.GetContainerItemInfo, bag, slot)
			local id = type(item) == "table" and ns.Number(item.itemID)
			local class, sub = select(6, info(id or 0))
			if id and class == CONSUMABLE and sub == POTION then
				potion = id
				return
			end
		end
	end
end

local function Potion()
	local api = C_Container and C_Container.GetItemCooldown
	if not potion or type(api) ~= "function" then return end
	local start, length, enabled = api(potion)
	start, length, enabled = ns.Number(start), ns.Number(length), ns.Number(enabled)
	if not (start and length and enabled ~= 0 and length > GCD and C_Timer and type(C_Timer.After) == "function") then return end
	local ends = start + length
	if ends == potionEnds then return end
	potionEnds = ends
	C_Timer.After(math.max(0, ends - GetTime()), function()
		if ends == potionEnds and ns.running and ns.Get("potionAlert") then
			potionEnds = nil
			local r, g, b = Tokens.Color("friendly")
			Flash("potionAlert", L["Potion ready"], r, g, b)
		end
	end)
end

local EVENTS = {
	{ "combat", { PLAYER_REGEN_DISABLED = Fight, PLAYER_REGEN_ENABLED = Fight } },
	{ "talentAlert", { PLAYER_LEVEL_UP = Talents, TRAIT_CONFIG_UPDATED = Talents, PLAYER_TALENT_UPDATE = Talents } },
	{ "durabilityAlert", { UPDATE_INVENTORY_DURABILITY = Durability, PLAYER_EQUIPMENT_CHANGED = Durability } },
	{ "deathAlert", { UNIT_HEALTH = Health, GROUP_ROSTER_UPDATE = Roster } },
	{ "potionAlert", { BAG_UPDATE_DELAYED = Potions, BAG_UPDATE_COOLDOWN = Potion } },
}

local function Wanted(key)
	if key == "combat" then return ns.Get("combatAlert") or ns.Get("talentAlert") or ns.Get("durabilityAlert") end
	return ns.Get(key)
end

local function Sync()
	local any = false
	for _, entry in ipairs(EVENTS) do
		local on = ns.running and Wanted(entry[1])
		any = any or on
		for event, fn in pairs(entry[2]) do
			if on then K.Events.Register(OWNER, event, fn) else K.Events.Unregister(OWNER, event) end
		end
	end
	if not (any or holder) then return end
	fighting = ns.Ask(InCombatLockdown) ~= false
	if ns.running and ns.Get("deathAlert") then Roster() end
	if ns.running and ns.Get("potionAlert") then
		if not potion then Potions() end
		Potion()
	else
		potionEnds = nil
	end
	if not (ns.running and flashKey and ns.Get(flashKey)) then flashToken = flashToken + 1; Hide("flash") end
	Talents()
	Durability()
end

ns.noticeLines = lines

local KEYS = { alertSize = true, combatAlert = true, talentAlert = true, talentText = true, talentColor = true, talentClass = true, deathAlert = true,
	durabilityAlert = true, durabilityPercent = true, durabilityY = true, durabilityThrown = true, potionAlert = true }

ns.AddPart({
	name = "notices",
	Start = Sync,
	Stop = Sync,
	Setting = function(key)
		if key == nil or KEYS[key] then Sync() end
	end,
})
