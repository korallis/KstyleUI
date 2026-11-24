-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
	{ "v0.3.4.4 (2026-11-24)", {
		L["Aura timers and stack counts on your Medallions player, target and focus frames sit clear of the portrait rim."],
		L["The Options preview matches, and Frames looks just as it did."],
		L["The store pages and README have fresh pictures of the crest on every class."],
	} },
	{ "v0.3.4.3 (2026-11-24)", {
		L["With Motion on, setup's HUD style and Layout cards show their title, text, edge and your pick again."],
		L["Setup's Your addons page draws its switches and dropdowns on first open, and every setup step shows at once."],
		L["The world map search sits in the map's top bar next to the zone path, so it never covers the map."],
		L["The search's Nearest list closes when you click away, press Escape, click the map or close it."],
		L["Thanks to Baine for finding and testing these."],
	} },
	{ "v0.3.4.2 (2026-11-24)", {
		L["The world map keeps its terrain art after you view another zone, close the map and open it again."],
		L["The /kstyle setup window no longer shows a Lua error when you press Next on the first page."],
		L["Setup's Welcome, Modules and Your addons lists draw every row straight away, no scroll needed."],
		L["Thanks to Baine for finding and testing these."],
	} },
}
