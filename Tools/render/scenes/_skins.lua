-- _skins.lua: the gallery of Blizzard windows KstyleUI_Skins restyles: each gallery_skins_<window>.lua scene builds one
-- stand-in window from Tools/regression/skins_windows.lua, lets the skin apply as it does in the game (the module
-- enabled, the window's Blizzard addon loaded, the window shown), and lists the window as one gallery frame
-- (_gallery.lua), named skins_<window>, with the grade it wears and the mockup crop that shares that grade.
--
--   local Skins = dofile("Tools/render/scenes/_skins.lua")
--   local scene = Skins.Scene("mail")     -- scene.frames[1].name == "skins_mail"
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Windows = dofile("Tools/regression/skins_windows.lua")
local S = Windows.S

local Skins = { Windows = Windows, Gallery = Gallery }

-- Units around the window's frames in the crop, for the window grade's shadow and the side tabs.
Skins.PAD = 28

-- Each window's gallery entry: the grade its frame wears, the mockup crop with that grade, what the parts use, and
-- what matches. The references are _gallery.lua's: chat and tracker (window), player (panel), actionbars (button),
-- buffbars (bar).
Skins.WINDOWS = {
	character = { grade = "window", reference = "chat",
		caption = "CharacterFrame: window glass; equipment slots and side tabs on the button body (IconChrome rims); stat rows on the glass with captions over accent lines.",
		match = "Window chamfer, two-line edge and drop shadow as the chat panel; slot rims as the action buttons' dark body with the quality colour where the mockup has the class colour." },
	reputation = { grade = "window", reference = "chat",
		caption = "CharacterFrame, reputation tab: window glass; standing bars in the bar grade (surface fill, faint edgeBar line); the filter dropdown and check boxes on the button body.",
		match = "Bars read as the mockup's buff bars: the panel fill under a faint one-border line, the tile chamfer, no shadow." },
	spellbook = { grade = "window", reference = "chat",
		caption = "PlayerSpellsFrame, spellbook: window glass; spell icons and category tabs on button-body rims; headers as display text over an accent line.",
		match = "Window grade as the chat panel; icon rims as the mockup's buttons, without the bezel since the icons sit in a list." },
	talents = { grade = "window", reference = "chat",
		caption = "PlayerSpellsFrame, talents: window glass; the search box, tabs and buttons on the button body. Talent nodes keep Blizzard's art (stand-ins here).",
		match = "Window grade as the chat panel; controls as the design kit's dark input." },
	worldmap = { grade = "window", reference = "chat",
		caption = "WorldMapFrame with QuestMapFrame docked: window glass behind the map; the navigation bar and the quest list body on surface tiles; the search box on the button body.",
		match = "Window grade as the chat panel; the quest list reads as the tracker's glass. The map canvas is a flat stand-in." },
	gamemenu = { grade = "window", reference = "chat",
		caption = "GameMenuFrame: window glass; each pooled button on the button body with the accent edge under the mouse.",
		match = "Window grade as the chat panel (12-unit chamfer, shadow); buttons as the design kit's dark controls." },
	groupfinder = { grade = "window", reference = "chat",
		caption = "LFGParentFrame, browse page: window glass; result rows on surface tiles whose edge lights for the selection; dropdowns, the refresh square and buttons on the button body; the bottom tabs on the button-body strip.",
		match = "Window grade as the chat panel; rows as the mockup's glass with the one light line; the tab strip as the design kit's tab bar." },
	mail = { grade = "window", reference = "chat",
		caption = "MailFrame and OpenMailFrame: window glass; inbox items and attachments on button-body rims by quality; inputs, buttons and the tab strip on the button body. Inbox texts keep Blizzard's font and colour.",
		match = "Window grade as the chat panel; item rims as the mockup's buttons." },
	merchant = { grade = "window", reference = "chat",
		caption = "MerchantFrame: window glass; item rows on surface tiles with quality-rimmed icons on the button body; repair buttons, the filter dropdown and page arrows restyled.",
		match = "Window grade as the chat panel; rows as the mockup's glass, icons as its buttons." },
	professions = { grade = "window", reference = "chat",
		caption = "ProfessionsFrame: window glass; the recipe list and schematic form on surface tiles; the rank bar in the bar grade; tool slots and reagents on button-body rims. Recipe rows keep Blizzard's tree.",
		match = "Window grade as the chat panel; the rank bar as the buff bars; slots as the action buttons." },
	trainer = { grade = "window", reference = "chat",
		caption = "ClassTrainerFrame: window glass; the skill bar in the bar grade; category and skill rows on surface tiles that light while selected; the train button on the button body.",
		match = "Window grade as the chat panel; the skill bar as the buff bars, in Blizzard's colour lifted for the glass." },
	addonlist = { grade = "window", reference = "chat",
		caption = "AddonList: window glass; the character dropdown, search box, check boxes and buttons on the button body; rows with an accent highlight and captions over accent lines.",
		match = "Window grade as the chat panel; controls as the design kit's dark input." },
	communities = { grade = "window", reference = "chat",
		caption = "CommunitiesFrame: window glass; side tabs and community icons on button-body rims; dropdowns, the check box and buttons on the button body; member rows with an accent highlight.",
		match = "Window grade as the chat panel; the selected community's wash is the accent at 12%, as the tracker's hover." },
	friends = { grade = "window", reference = "chat",
		caption = "FriendsFrame: window glass; the battle tag bar on a surface tile; the status dropdown, buttons and the tab strip on the button body; friend rows keep Blizzard's tints under an accent highlight.",
		match = "Window grade as the chat panel; the tag bar as the mockup's glass tiles." },
	legacy = { grade = "window", reference = "chat",
		caption = "LegacySystemFrame: window glass; the three side tabs on button-body rims; the reward progress bar in the bar grade. Reward cards keep Blizzard's art (stand-ins here).",
		match = "Window grade as the chat panel; the progress bar as the buff bars." },
	loot = { grade = "window", reference = "chat",
		caption = "LootFrame: window glass; each row on a surface tile with its icon on a button-body rim in the quality colour and the quality label in that colour.",
		match = "Window grade as the chat panel; rows as the mockup's buff bars' glass; icons as its buttons." },
	lootrolls = { grade = "panel", reference = "player",
		caption = "GroupLootFrame1 and 2: panel glass (8-unit chamfer, as the unit frames); the item icon on a button-body rim by quality; the timer as a KstyleUI bar in the bar grade.",
		match = "Panel grade as the player frame: 8-unit chamfer, two-line edge, drop shadow; the timer as the cast bar's track." },
	popups = { grade = "window", reference = "chat",
		caption = "StaticPopup1: window glass; the item on a button-body rim in the colour Blizzard gives its name; Yes and No on the button body. The text keeps the game's scaled font.",
		match = "Window grade as the chat panel; buttons as the design kit's dark controls." },
	readycheck = { grade = "window", reference = "chat",
		caption = "ReadyCheckListenerFrame: window glass with the heading; Ready and Not Ready on the button body.",
		match = "Window grade as the chat panel; buttons as the design kit's dark controls." },
}

function Skins.Scene(key)
	local spec = Windows.Spec(key)
	local entry = assert(Skins.WINDOWS[key], "no gallery entry for " .. key)
	local B, parts
	local env, K, ns = S.New(Common.ScreenOpts({
		saved = Gallery.Saved({ "Skins" }),
		setup = Gallery.Setup,
		before = function(env)
			B = S.Blizzard(env)
			parts = select(2, Windows.Build(key, env, B))
		end,
	}))
	K.Modules.Enable("Skins")
	if spec.addon then
		S.LoadAddOn(env, spec.addon)
	end
	for _, shown in ipairs(parts.show) do
		S.Show(shown)
	end
	env.RunTimers()
	S.W.Settle(env)
	local scene = Gallery.Build(env)
	for _, skin in ipairs(spec.skins) do
		if not ns.Skins.IsApplied(skin) then
			scene.log[#scene.log + 1] = "error: the " .. skin .. " skin did not apply to " .. key
		end
	end
	local frames = Gallery.Frames()
	frames:Add(env, nil, {
		name = "skins_" .. key, title = spec.title, grade = entry.grade, reference = entry.reference,
		caption = entry.caption, match = entry.match, pad = Skins.PAD, rect = Gallery.Union(env, parts.bounds),
	})
	scene.log[#scene.log + 1] = key .. " is laid out by the stand-in builder; Blizzard's own layout is not modelled"
	return frames:Finish(scene, env, K, "gallery skins")
end

return Skins
