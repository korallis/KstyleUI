-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
	{ "v0.3.5.6 (2026-11-28)", {
		L["Restore brings back every Edit Mode layout you had before setup, even one you deleted to free a slot."],
		L["Setup's summary asks for a reload only once Reload shows, and updates at once when you turn the replacement off."],
	} },
	{ "v0.3.5.5 (2026-11-28)", {
		L["Setup keeps Replace this one and Apply on screen when every Edit Mode layout is in use, so you can pick one to replace."],
		L["Setup's Your addons step draws its switches and dropdowns whole the first time it opens."],
	} },
	{ "v0.3.5.4 (2026-11-28)", {
		L["Cooldown viewers an older setup placed follow the HUD again when you change its width or switch Centred and Spread."],
	} },
}
