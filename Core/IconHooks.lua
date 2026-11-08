-- IconHooks.lua: shows the custom icon set on Blizzard's spellbook, talent, item-button and loot icons by watching their textures with Icons.Watch.
local _, ns = ...

local MODULE, ADDON = "Icons", "Blizzard_PlayerSpells"
local hooked, itemsHooked = false, false
local lootOwner = {}

local function log(message)
	ns.DevTest.Log(MODULE, message)
end

local function watchItem(item)
	local button = type(item) == "table" and item.Button
	if type(button) == "table" then
		ns.Icons.Watch(button.Icon)
	end
end

local function watchPage(paged)
	paged:ForEachFrame(watchItem)
end

local function watchTalent(_, button)
	if type(button) == "table" then
		ns.Icons.Watch(button.Icon)
		ns.Icons.Watch(button.Icon2)
	end
end

local function hookTalents(frame)
	local talents = type(frame) == "table" and frame.TalentsFrame
	local events = type(TalentFrameBaseMixin) == "table" and TalentFrameBaseMixin.Event
	local acquired = type(events) == "table" and events.TalentButtonAcquired
	if type(talents) ~= "table" or type(talents.RegisterCallback) ~= "function" or type(talents.EnumerateAllTalentButtons) ~= "function" or not acquired then
		log("talents: the talent buttons are missing; Blizzard's icons stay")
		return
	end
	for button in talents:EnumerateAllTalentButtons() do
		watchTalent(nil, button)
	end
	talents:RegisterCallback(acquired, watchTalent, MODULE)
	log("talents: watching its talent icons")
end

local function hookSpellbook(frame)
	local book = type(frame) == "table" and frame.SpellBookFrame
	local paged = type(book) == "table" and book.PagedSpellsFrame
	if type(paged) ~= "table" or type(paged.ForEachFrame) ~= "function" or type(paged.DisplayViewsForCurrentPage) ~= "function" or type(hooksecurefunc) ~= "function" then
		log("spellbook: its spell pages are missing; Blizzard's icons stay")
		return
	end
	watchPage(paged)
	hooksecurefunc(paged, "DisplayViewsForCurrentPage", watchPage)
	log("spellbook: watching its spell icons")
end

local function hook()
	hooked = true
	local frame = _G.PlayerSpellsFrame
	hookSpellbook(frame)
	hookTalents(frame)
end

local function watchItemButton(button)
	local icon
	if type(GetItemButtonIconTexture) == "function" then
		icon = GetItemButtonIconTexture(button)
	end
	if type(icon) ~= "table" and type(button) == "table" then
		icon = button.icon or button.Icon
	end
	if type(icon) == "table" then
		ns.Icons.Watch(icon)
	end
end

local function hookItemButtons()
	if type(SetItemButtonTexture) ~= "function" or type(hooksecurefunc) ~= "function" then
		log("item buttons: SetItemButtonTexture is missing; Blizzard's item icons stay")
		return
	end
	hooksecurefunc("SetItemButtonTexture", watchItemButton)
	log("item buttons: watching every item button Blizzard draws")
end

local function watchLootRow(row)
	local item = type(row) == "table" and row.Item
	if type(item) == "table" and type(item.icon) == "table" then
		ns.Icons.Watch(item.icon)
	end
end

local function hookLoot()
	local frame = _G.LootFrame
	local box = type(frame) == "table" and frame.ScrollBox
	local util = ScrollUtil
	if type(box) ~= "table" or type(box.ForEachFrame) ~= "function" or type(util) ~= "table" or type(util.AddInitializedFrameCallback) ~= "function" then
		log("loot: the loot list is missing; Blizzard's loot icons stay")
		return
	end
	box:ForEachFrame(watchLootRow)
	util.AddInitializedFrameCallback(box, function(_, row)
		watchLootRow(row)
	end, lootOwner, false)
	log("loot: watching its item icons")
end

local function hookItems()
	itemsHooked = true
	hookItemButtons()
	hookLoot()
end

local function onAddonLoaded(_, name)
	if name == ADDON then
		ns.Events.Unregister(MODULE, "ADDON_LOADED")
		hook()
	end
end

ns.Callbacks.Register("ModuleChanged", "IconHooks", function(_, name, running)
	if name ~= MODULE or not running then
		return
	end
	if not itemsHooked then
		hookItems()
	end
	if hooked then
		return
	end
	local AddOns = C_AddOns
	if AddOns and type(AddOns.IsAddOnLoaded) == "function" and AddOns.IsAddOnLoaded(ADDON) then
		hook()
	else
		ns.Events.Register(MODULE, "ADDON_LOADED", onAddonLoaded)
		log("spellbook: waits for Blizzard_PlayerSpells to load")
	end
end)
