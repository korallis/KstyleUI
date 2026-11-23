-- test-skins-item-levels.lua: the character sheet skin writes each worn item's level in its slot's top-left
-- corner in the refined quality colour the bag labels wear, skips the shirt, tabard and ammo, reads a slot only
-- when it shows or its item changes (PLAYER_EQUIPMENT_CHANGED; never Blizzard's cooldown or alert updates,
-- Camelot/PaperDollFrame.lua:2073 and :2081), asks for a level once per new item link, waits for item data
-- through Item:ContinueOnItemLoad (Blizzard_ObjectAPI/Mainline/Item.lua:330) once and never paints a closed
-- window, labels the inspect window's slots once Blizzard_InspectUI loads (InspectFrame_LoadUI from its
-- bootstrap, then InspectPaperDollItemSlotButton_Update, Blizzard_InspectUI/Mainline/InspectPaperDollFrame.lua:245)
-- with no event frame made at load, skips a secret slot ID or unit, and Window Skins > Character > Item levels
-- off removes every number, on the inspect window too before the character window has opened.
local S = dofile("Tools/regression/skins_env.lua")
local Windows = dofile("Tools/regression/skins_windows.lua")

local function Level(slot)
	for _, region in ipairs({ slot:GetRegions() }) do
		if region:GetObjectType() == "FontString" then
			return region
		end
	end
	return nil
end

local function Shown(slot)
	local text = Level(slot)
	return text ~= nil and text:IsShown() and tostring(text:GetText()) or nil
end

local function Event(slot, event, ...)
	slot:GetScript("OnEvent")(slot, event, ...)
end

local function Open(saved, closed)
	local B
	local env, K, ns = S.New({
		saved = saved,
		setup = function(env)
			env.InspectFrame_LoadUI = function()
				env._loaded.Blizzard_InspectUI = true
				return true
			end
		end,
		before = function(env)
			B = S.Blizzard(env)
			Windows.Build("character", env, B)
			if closed then
				env.CharacterFrame:Hide()
			end
		end,
	})
	local asked, reads = {}, 0
	local levelOf, linkOf = env.C_Item.GetDetailedItemLevelInfo, env.GetInventoryItemLink
	env.C_Item.GetDetailedItemLevelInfo = function(link)
		asked[link] = (asked[link] or 0) + 1
		return levelOf(link)
	end
	env.GetInventoryItemLink = function(unit, id)
		reads = reads + 1
		return linkOf(unit, id)
	end
	K.Modules.Enable("Skins")
	if not closed then
		S.Show(env.CharacterFrame)
		assert(ns.Skins.IsApplied("character"), "the character sheet skin applies")
	end
	return env, K, ns, B, asked, function() return reads end
end

local env, K, ns, B, asked, Reads = Open()
assert(K.Options.Row("Skins", "character.itemLevels"), "Window Skins > Character has an Item levels row")
assert(ns.Skins.Setting("character", "itemLevels") == true, "on by default")

assert(Shown(env.CharacterHeadSlot) == "45", "the head slot shows its item level")
assert(Shown(env.CharacterMainHandSlot) == "42", "and the main hand its own")
assert(Shown(env.CharacterRangedSlot) == "36", "and the ranged slot")
assert(Level(env.CharacterShirtSlot) == nil and Level(env.CharacterTabardSlot) == nil, "the shirt and tabard carry no level")

local text = Level(env.CharacterHeadSlot)
local r, g, b = text:GetTextColor()
local er, eg, eb = K.Theme.QualityColor(4, true)
assert(r == er and g == eg and b == eb, "the number wears the item's quality colour")
r, g, b = Level(env.CharacterShoulderSlot):GetTextColor()
er, eg, eb = K.Theme.QualityColor(2, true)
assert(r == er and g == eg and b == eb, "an uncommon item's number wears the bag labels' refined green, got " .. r .. " " .. g .. " " .. b)
local point, anchor, relative = text:GetPoint(1)
assert(point == "TOPLEFT" and anchor == env.CharacterHeadSlot and relative == "TOPLEFT", "in the slot's top-left corner")

local before = asked["item:133127"]
assert(before == 1, "the level is asked once when the window opens, got " .. tostring(before))
before = Reads()
for _ = 1, 3 do
	Event(env.CharacterHeadSlot, "BAG_UPDATE_COOLDOWN")
	Event(env.CharacterHeadSlot, "UPDATE_INVENTORY_ALERTS")
end
assert(Reads() == before, "cooldown and alert updates read no item link, got " .. Reads() - before)
assert(asked["item:133127"] == 1, "and ask no level")

local link, level = env.GetInventoryItemLink, env.C_Item.GetDetailedItemLevelInfo
local loaded, waiting = false, {}
env.GetInventoryItemLink = function(unit, id)
	return id == 1 and "item:900" or link(unit, id)
end
env.C_Item.GetDetailedItemLevelInfo = function(itemLink)
	if itemLink == "item:900" then
		asked[itemLink] = (asked[itemLink] or 0) + 1
		return loaded and 52 or nil
	end
	return level(itemLink)
end
env.Item = {
	CreateFromItemLink = function(_, itemLink)
		return {
			ContinueOnItemLoad = function(_, callback)
				waiting[#waiting + 1] = { itemLink, callback }
			end,
		}
	end,
}
Event(env.CharacterHeadSlot, "PLAYER_EQUIPMENT_CHANGED", 1)
assert(Shown(env.CharacterHeadSlot) == nil, "a new item without data hides the old number")
assert(#waiting == 1 and waiting[1][1] == "item:900", "and waits for the item's data")
Event(env.CharacterHeadSlot, "PLAYER_EQUIPMENT_CHANGED", 1)
assert(#waiting == 1 and asked["item:900"] == 1, "a second update while the data loads asks nothing more")
K.Callbacks.Fire("ProfileChanged", "Default", "Default")
assert(#waiting == 1, "a profile refresh waits on the same item once, got " .. #waiting .. " waits")
env.CharacterFrame:Hide()
loaded = true
waiting[1][2]()
assert(asked["item:900"] == 1, "data arriving for a closed window asks no level")
assert(not Level(env.CharacterHeadSlot):IsShown(), "and shows no number")
S.Show(env.CharacterFrame)
assert(Shown(env.CharacterHeadSlot) == "52", "the level appears when the window opens again")

K.Options.Write("Skins", "character.itemLevels", false)
for _, name in ipairs({ "CharacterHeadSlot", "CharacterMainHandSlot", "CharacterRangedSlot" }) do
	assert(Shown(env[name]) == nil, name .. ": Item levels off hides the number")
end
K.Options.Write("Skins", "character.itemLevels", true)
assert(Shown(env.CharacterHeadSlot) == "52" and Shown(env.CharacterMainHandSlot) == "42", "and on shows them again")
env.CharacterFrame:Hide()
before = Reads()
K.Options.Write("Skins", "character.itemLevels", false)
K.Options.Write("Skins", "character.itemLevels", true)
assert(Reads() == before, "switching Item levels with the window closed reads no item, got " .. Reads() - before)
S.Show(env.CharacterFrame)
assert(Shown(env.CharacterHeadSlot) == "52" and Shown(env.CharacterMainHandSlot) == "42", "and the window shows them when it opens")

assert(env.InspectPaperDollItemSlotButton_Update == nil, "the inspect window is load on demand")
local inspect = B.frame("Frame", nil, "InspectFrame")
local slot = B.frame("Button", inspect, "InspectHeadSlot")
slot:SetID(1)
local tabard = B.frame("Button", inspect, "InspectTabardSlot")
tabard:SetID(19)
env.InspectPaperDollItemSlotButton_Update = function() end
local reads = 0
env.GetInventoryItemLink = function(unit, id)
	reads = reads + 1
	assert(unit == "target", "the inspect window reads the inspected unit")
	return id == 1 and "item:700" or id == 19 and "item:701" or nil
end
env.C_Item.GetDetailedItemLevelInfo = function(itemLink)
	return itemLink == "item:700" and 60 or 1
end
assert(env.InspectFrame_LoadUI() == true and env.InspectFrame_LoadUI() == true, "loading the inspect window keeps Blizzard's answer")
inspect.unit = "target"
env.InspectPaperDollItemSlotButton_Update(slot)
assert(reads == 1, "two loads still hook the slot update once, got " .. reads .. " reads")
env.InspectPaperDollItemSlotButton_Update(tabard)
assert(Shown(slot) == "60", "an inspected player's slot shows the item level")
assert(Level(tabard) == nil, "but not on the tabard")
inspect.unit = env.Secret("target")
env.InspectPaperDollItemSlotButton_Update(slot)
assert(reads == 1 and Shown(slot) == nil, "a secret inspect unit reads nothing and keeps no number")
inspect.unit = "target"
local secret = B.frame("Button", inspect, "InspectNeckSlot")
secret:SetID(env.Secret(2))
env.InspectPaperDollItemSlotButton_Update(secret)
assert(reads == 1 and Level(secret) == nil, "a secret slot ID reads nothing")
inspect.unit = nil
env.InspectPaperDollItemSlotButton_Update(slot)
assert(Shown(slot) == nil, "a closed inspect window keeps no number")
assert(#env._errors == 0, tostring(env._errors[1]))

env, K, ns, B = Open(nil, true)
inspect = B.frame("Frame", nil, "InspectFrame")
slot = B.frame("Button", inspect, "InspectHeadSlot")
slot:SetID(1)
inspect.unit = "target"
env.InspectPaperDollItemSlotButton_Update = function() end
env.InspectFrame_LoadUI()
env.InspectPaperDollItemSlotButton_Update(slot)
assert(not ns.Skins.IsApplied("character") and Shown(slot) == "45", "inspect labels before the character window first opens")
K.Options.Write("Skins", "character.itemLevels", false)
assert(Shown(slot) == nil, "and Item levels off hides them")
K.Options.Write("Skins", "character.itemLevels", true)
assert(Shown(slot) == "45", "and on shows them again")
assert(#env._errors == 0, tostring(env._errors[1]))

local off = { version = 2, profiles = { Default = { Skins = { enabled = true, character = { enabled = true, itemLevels = false } } } }, characters = {}, layouts = {}, account = { setupSeen = true } }
env = Open(off)
for _, name in ipairs({ "CharacterHeadSlot", "CharacterMainHandSlot", "CharacterRangedSlot" }) do
	assert(Level(env[name]) == nil, name .. ": with Item levels off the slot gets no font string at all")
end
assert(#env._errors == 0, tostring(env._errors[1]))
print("skins item levels ok")
