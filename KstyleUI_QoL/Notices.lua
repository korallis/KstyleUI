-- Notices.lua: large alert lines over the world: entering and leaving combat, a group member's death, unspent talent points and low durability, in the display font with the world outline, registering only the events their switches need.
local _, ns = ...

local K, L = ns.K, ns.L
local Widgets, Tokens, Motion, Theme = K.Widgets, K.Tokens, K.Motion, K.Theme

local OWNER = "QoL.notices"
local HOLD = 2
local SLOTS = { flash = 200, talents = 160 }
local SOUNDS = { warning = "RAID_WARNING", ready = "READY_CHECK" }
local THROWN = 18

local holder
local lines, dead = {}, {}
local flashToken, fighting, members = 0, false, "^party%d$"

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

local function Line(slot, y)
	if not holder then
		holder = CreateFrame("Frame", nil, K.Scale.Root())
		holder:SetFrameStrata("BACKGROUND")
		holder:SetAllPoints()
	end
	local line = lines[slot]
	if not line then
		line = CreateFrame("Frame", nil, holder)
		line.text = Widgets.FontString(line, "OVERLAY")
		Widgets.Point(line.text, "CENTER", line, "CENTER", 0, 0)
		line:Hide()
		lines[slot] = line
	end
	line:ClearAllPoints()
	Widgets.Point(line, "CENTER", holder, "CENTER", 0, Widgets.Snap(holder, y or SLOTS[slot]))
	return line
end

local function Show(slot, value, r, g, b, y)
	local line = Line(slot, y)
	ns.PaintNotice(line.text, value, r, g, b)
	Widgets.Size(line, Widgets.TextWidth(line.text, 1), Widgets.TextHeight(line.text, Widgets.LineHeight(line.text)))
	if not line:IsShown() or line:GetAlpha() < 1 then Motion.FadeIn(line, Tokens.Duration("panelOpen")) end
end

local function Hide(slot)
	local line = lines[slot]
	if line and line:IsShown() then Motion.FadeOut(line) end
end

local function Flash(value, r, g, b)
	flashToken = flashToken + 1
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
	Flash(ns.NoticeText(prefix), ns.NoticeColor(prefix))
end

local function Talents()
	local api = C_ClassTalents
	local unspent = ns.running and ns.Get("talentAlert") and not fighting and type(api) == "table"
		and type(api.HasUnspentTalentPoints) == "function" and ns.True((api.HasUnspentTalentPoints()))
	if unspent then Show("talents", ns.NoticeText("talent"), ns.NoticeColor("talent")) else Hide("talents") end
end

local function Thrown(slot)
	if slot ~= THROWN or not ns.Get("durabilityThrown") or type(GetInventoryItemID) ~= "function" then return false end
	local id = ns.Number(GetInventoryItemID("player", slot))
	return id ~= nil and select(4, C_Item.GetItemInfoInstant(id)) == "INVTYPE_THROWN"
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
		Show("durability", string.format(L["Low durability: %d%%"], math.floor(low)), r, g, b, ns.Get("durabilityY"))
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
	local raid = ns.True(IsInRaid())
	members, dead = raid and "^raid%d+$" or "^party%d$", {}
	for i = 1, raid and 40 or 4 do
		local unit = (raid and "raid" or "party") .. i
		dead[unit] = Gone(unit) or nil
	end
end

local function Health(_, unit)
	if type(unit) ~= "string" or not unit:find(members) or ns.True(UnitIsUnit(unit, "player")) then return end
	if not Gone(unit) then dead[unit] = nil; return end
	if dead[unit] then return end
	dead[unit] = true
	local name = UnitName(unit)
	local r, g, b = Tokens.Color("hostile")
	Flash(type(name) == "string" and not ns.IsSecret(name) and string.format(L["%s died"], name) or L["A group member died"], r, g, b)
	local kit = SOUNDKIT and SOUNDKIT[SOUNDS[ns.Get("deathSound")]]
	if kit and type(PlaySound) == "function" then PlaySound(kit, "Master") end
end

local EVENTS = {
	{ "combat", { PLAYER_REGEN_DISABLED = Fight, PLAYER_REGEN_ENABLED = Fight } },
	{ "talentAlert", { PLAYER_LEVEL_UP = Talents, TRAIT_CONFIG_UPDATED = Talents, PLAYER_TALENT_UPDATE = Talents } },
	{ "durabilityAlert", { UPDATE_INVENTORY_DURABILITY = Durability, PLAYER_EQUIPMENT_CHANGED = Durability } },
	{ "deathAlert", { UNIT_HEALTH = Health, GROUP_ROSTER_UPDATE = Roster } },
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
	local fight = InCombatLockdown()
	fighting = not ns.IsSecret(fight) and fight == true
	if ns.running and ns.Get("deathAlert") then Roster() end
	if not (ns.running and (ns.Get("combatAlert") or ns.Get("deathAlert"))) then flashToken = flashToken + 1; Hide("flash") end
	Talents()
	Durability()
end

function ns.NoticeLine(slot)
	return lines[slot]
end

local KEYS = { alertSize = true, combatAlert = true, talentAlert = true, talentText = true, talentColor = true, talentClass = true, deathAlert = true,
	durabilityAlert = true, durabilityPercent = true, durabilityY = true, durabilityThrown = true }

ns.AddPart({
	name = "notices",
	Start = Sync,
	Stop = Sync,
	Setting = function(key)
		if key == nil or KEYS[key] then Sync() end
	end,
})
