-- test-skins-item-levels.lua: the character sheet skin writes each worn item's level in its slot's top-left
-- corner in the quality colour, skips the shirt, tabard and ammo, asks for a level once per new item link,
-- waits for item data through Item:ContinueOnItemLoad (Blizzard_ObjectAPI/Mainline/Item.lua:330) without
-- polling, labels the inspect window's slots once Blizzard_InspectUI loads (InspectPaperDollItemSlotButton_Update,
-- Blizzard_InspectUI/Mainline/InspectPaperDollFrame.lua:245), and Window Skins > Character > Item levels off
-- removes every number.
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

local function Open(saved)
	local B
	local env, K, ns = S.New({
		saved = saved,
		before = function(env)
			B = S.Blizzard(env)
			Windows.Build("character", env, B)
		end,
	})
	local asked = {}
	local levelOf = env.C_Item.GetDetailedItemLevelInfo
	env.C_Item.GetDetailedItemLevelInfo = function(link)
		asked[link] = (asked[link] or 0) + 1
		return levelOf(link)
	end
	K.Modules.Enable("Skins")
	S.Show(env.CharacterFrame)
	assert(ns.Skins.IsApplied("character"), "the character sheet skin applies")
	return env, K, ns, B, asked
end

local env, K, ns, B, asked = Open()
assert(K.Options.Row("Skins", "character.itemLevels"), "Window Skins > Character has an Item levels row")
assert(ns.Skins.Setting("character", "itemLevels") == true, "on by default")

assert(Shown(env.CharacterHeadSlot) == "45", "the head slot shows its item level")
assert(Shown(env.CharacterMainHandSlot) == "42", "and the main hand its own")
assert(Shown(env.CharacterRangedSlot) == "36", "and the ranged slot")
assert(Level(env.CharacterShirtSlot) == nil and Level(env.CharacterTabardSlot) == nil, "the shirt and tabard carry no level")

local text = Level(env.CharacterHeadSlot)
local r, g, b = text:GetTextColor()
local er, eg, eb = K.Theme.QualityColor(4)
assert(r == er and g == eg and b == eb, "the number wears the item's quality colour")
local point, anchor, relative = text:GetPoint(1)
assert(point == "TOPLEFT" and anchor == env.CharacterHeadSlot and relative == "TOPLEFT", "in the slot's top-left corner")

local before = asked["item:133127"]
assert(before == 1, "the level is asked once when the window opens, got " .. tostring(before))
for _ = 1, 3 do
	env.PaperDollItemSlotButton_Update(env.CharacterHeadSlot)
end
assert(asked["item:133127"] == 1, "bag and cooldown updates of an unchanged item ask nothing")

local link, level = env.GetInventoryItemLink, env.C_Item.GetDetailedItemLevelInfo
local loaded, waiting = false, {}
env.GetInventoryItemLink = function(unit, id)
	if id == 1 then
		return "item:900"
	end
	return link(unit, id)
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
env.PaperDollItemSlotButton_Update(env.CharacterHeadSlot)
assert(Shown(env.CharacterHeadSlot) == nil, "a new item without data hides the old number")
assert(#waiting == 1 and waiting[1][1] == "item:900", "and waits for the item's data")
env.PaperDollItemSlotButton_Update(env.CharacterHeadSlot)
assert(#waiting == 1 and asked["item:900"] == 1, "a second update while the data loads asks nothing more")
loaded = true
waiting[1][2]()
assert(Shown(env.CharacterHeadSlot) == "52", "the level appears when the data arrives")

K.Options.Write("Skins", "character.itemLevels", false)
for _, name in ipairs({ "CharacterHeadSlot", "CharacterMainHandSlot", "CharacterRangedSlot" }) do
	assert(Shown(env[name]) == nil, name .. ": Item levels off hides the number")
end
K.Options.Write("Skins", "character.itemLevels", true)
assert(Shown(env.CharacterHeadSlot) == "52" and Shown(env.CharacterMainHandSlot) == "42", "and on shows them again")

assert(env.InspectPaperDollItemSlotButton_Update == nil, "the inspect window is load on demand")
local inspect = B.frame("Frame", nil, "InspectFrame")
local slot = B.frame("Button", inspect, "InspectHeadSlot")
slot:SetID(1)
local tabard = B.frame("Button", inspect, "InspectTabardSlot")
tabard:SetID(19)
env.InspectPaperDollItemSlotButton_Update = function() end
env.GetInventoryItemLink = function(unit, id)
	assert(unit == "target", "the inspect window reads the inspected unit")
	return id == 1 and "item:700" or id == 19 and "item:701" or nil
end
env.C_Item.GetDetailedItemLevelInfo = function(itemLink)
	return itemLink == "item:700" and 60 or 1
end
S.LoadAddOn(env, "Blizzard_InspectUI")
inspect.unit = "target"
env.InspectPaperDollItemSlotButton_Update(slot)
env.InspectPaperDollItemSlotButton_Update(tabard)
assert(Shown(slot) == "60", "an inspected player's slot shows the item level")
assert(Level(tabard) == nil, "but not on the tabard")
inspect.unit = nil
env.InspectPaperDollItemSlotButton_Update(slot)
assert(Shown(slot) == nil, "a closed inspect window keeps no number")
assert(#env._errors == 0, tostring(env._errors[1]))

local off = { version = 2, profiles = { Default = { Skins = { enabled = true, character = { enabled = true, itemLevels = false } } } }, characters = {}, layouts = {}, account = { setupSeen = true } }
env = Open(off)
for _, name in ipairs({ "CharacterHeadSlot", "CharacterMainHandSlot", "CharacterRangedSlot" }) do
	assert(Level(env[name]) == nil, name .. ": with Item levels off the slot gets no font string at all")
end
assert(#env._errors == 0, tostring(env._errors[1]))
print("skins item levels ok")
