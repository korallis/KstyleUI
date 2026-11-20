-- Settings.lua: KstyleUI_QoL's defaults, its settings page and checked reads of each setting.
local _, ns = ...

local K, L = ns.K, ns.L

ns.PAUSE_KEYS = { SHIFT = "IsShiftKeyDown", CTRL = "IsControlKeyDown", ALT = "IsAltKeyDown" }

local function Color(name)
	local r, g, b = K.Tokens.Color(name)
	return { r = r, g = g, b = b }
end

local SHOWN = { always = true, combat = true, instances = true, instancesCombat = true }
local CHOICES = {
	questModifier = ns.PAUSE_KEYS, combatAlertOn = { both = true, enter = true, leave = true },
	deathSound = { none = true, warning = true, ready = true }, crosshair = { none = true, thin = true, normal = true, thick = true },
	crosshairShow = SHOWN, cursorShow = SHOWN, autoLogWhere = { raid = true, party = true, all = true },
	skipMode = { cinematics = true, movies = true, both = true },
}
ns.LIMITS = {
	skipDelay = { 0, 30 }, alertSize = { 14, 64 }, durabilityPercent = { 5, 100 }, durabilityY = { -500, 500 },
	crosshairHLength = { 1, 500 }, crosshairVLength = { 1, 500 }, crosshairHWidth = { 0, 20 }, crosshairVWidth = { 0, 20 },
	crosshairBorder = { 0, 5 }, crosshairX = { -200, 200 }, crosshairY = { -200, 200 }, cursorScale = { 50, 200 }, cursorOpacity = { 10, 100 },
}

ns.defaults = {
	enabled = false,
	fastLoot = true,
	lootFeed = true,
	coinIcons = false,
	autoRepair = true,
	guildRepair = false,
	autoQuests = false,
	autoGossip = false,
	ignoreTrivial = true,
	questInstances = true,
	skipCinematics = false,
	skipDelay = 0,
	skipMode = "cinematics",
	alertSize = 28,
	combatAlert = false,
	combatAlertOn = "both",
	combatEnterText = "",
	combatEnterColor = Color("hostile"),
	combatEnterClass = false,
	combatLeaveText = "",
	combatLeaveColor = Color("friendly"),
	combatLeaveClass = false,
	talentAlert = false,
	talentText = "",
	talentColor = Color("neutral"),
	talentClass = false,
	deathAlert = false,
	deathSound = "warning",
	durabilityAlert = false,
	durabilityPercent = 40,
	durabilityY = 250,
	durabilityThrown = true,
	crosshair = "none",
	crosshairShow = "always",
	crosshairHLength = 40,
	crosshairHWidth = 0,
	crosshairVLength = 40,
	crosshairVWidth = 0,
	crosshairBorder = 0,
	crosshairX = 0,
	crosshairY = 0,
	cursorRing = false,
	cursorShow = "always",
	cursorScale = 100,
	cursorOpacity = 70,
	cursorClass = false,
	cursorColor = Color("gilt"),
	hideScreenshot = false,
	announceReset = false,
	autoLog = false,
	autoLogWhere = "raid",
	autoLogNotice = true,
	questModifier = "SHIFT",
	maxCamera = true,
	quietErrors = false,
	autoDelete = false,
	autoResurrect = false,
}

function ns.Get(key)
	local default = ns.defaults[key]
	local value = K.Store.Module(ns.MODULE)[key]
	if type(value) ~= type(default) or ns.IsSecret(value) then
		return default
	end
	local limit, choices = ns.LIMITS[key], CHOICES[key]
	if limit and (value ~= value or value < limit[1] or value > limit[2]) or choices and not choices[value] then return default end
	if type(value) == "table" and not (type(value.r) == "number" and type(value.g) == "number" and type(value.b) == "number") then return default end
	return value
end

function ns.Schema()
	local function isOff(settings)
		return not settings.enabled
	end

	local function when(key)
		return function(settings) return not (settings.enabled and settings[key] and settings[key] ~= "none") end
	end
	local combatOff, talentOff, durabilityOff, crossOff, ringOff, logOff = when("combatAlert"), when("talentAlert"), when("durabilityAlert"), when("crosshair"), when("cursorRing"), when("autoLog")
	local function slider(key, label, help, step, off)
		local limit = ns.LIMITS[key]
		return { type = "slider", key = key, label = label, help = help, min = limit[1], max = limit[2], step = step, disableWhen = off }
	end
	local SHOW_OPTIONS = {
		{ value = "always", label = L["Always"] }, { value = "combat", label = L["In combat"] },
		{ value = "instances", label = L["In instances"] }, { value = "instancesCombat", label = L["In instance combat"] },
	}

	local PAUSE_OPTIONS = {
		{ value = "SHIFT", label = L["Shift"] },
		{ value = "CTRL", label = L["Ctrl"] },
		{ value = "ALT", label = L["Alt"] },
	}

	ns.schema = {
		{ type = "header", label = L["Quality of Life"] },
		{ type = "toggle", key = "enabled", label = L["KstyleUI quality of life"], help = L["Small helpers for looting, merchants, quests, the camera and error text."] },
		{ type = "header", label = L["Loot"] },
		{ type = "toggle", key = "fastLoot", label = L["Faster auto loot"], help = L["When the game auto loots, take every item the moment the window opens."], disableWhen = isOff },
		{ type = "toggle", key = "lootFeed", label = L["Loot feed"], help = L["Short lines above the chat for what you loot, with icons, quality colours and coin colours."], disableWhen = isOff },
		{ type = "toggle", key = "coinIcons", label = L["Coin icons"], help = L["Show coin icons instead of gold, silver and copper letters in the loot feed."], disableWhen = function(s) return not (s.enabled and s.lootFeed) end },
		{ type = "header", label = L["Merchants"] },
		{ type = "toggle", key = "autoRepair", label = L["Repair by itself"], help = L["Repair your gear at merchants and print the cost."], disableWhen = isOff },
		{ type = "toggle", key = "guildRepair", label = L["Guild funds first"], help = L["Pay from the guild bank when your rank allows it."], disableWhen = when("autoRepair") },
		{ type = "note", label = L["Junk selling lives on the Bags page, as Sell junk by itself."] },
		{ type = "header", label = L["Quests"] },
		{ type = "toggle", key = "autoQuests", label = L["Accept and turn in quests"], help = L["Accept quests and hand in finished ones. A choice of rewards stays yours."], disableWhen = isOff },
		{ type = "toggle", key = "autoGossip", label = L["Select single gossip"], help = L["Choose a lone gossip option when the NPC offers no quests. The pause key still works."], disableWhen = isOff },
		{ type = "toggle", key = "ignoreTrivial", label = L["Ignore low-level quests"], help = L["Leave low-level quest offers for you to choose."], disableWhen = when("autoQuests") },
		{ type = "toggle", key = "questInstances", label = L["Quest helpers in instances"], help = L["Allow automatic quests and single gossip inside instances."], disableWhen = function(settings) return not (settings.enabled and (settings.autoQuests or settings.autoGossip)) end },
		{
			type = "dropdown", key = "questModifier", label = L["Pause key"], help = L["Hold this key as you talk to a quest giver to do it yourself."],
			options = PAUSE_OPTIONS, disableWhen = function(settings) return not (settings.enabled and (settings.autoQuests or settings.autoGossip)) end,
		},
		{ type = "header", label = L["Camera"] },
		{ type = "toggle", key = "skipCinematics", label = L["Skip cinematics"], help = L["Skip cancellable cinematics. Hold Shift to watch them."], disableWhen = isOff },
		{ type = "dropdown", key = "skipMode", label = L["Skip which"], help = L["Skip in-game cinematics, movies, or both."], options = {
			{ value = "cinematics", label = L["Cinematics"] }, { value = "movies", label = L["Movies"] }, { value = "both", label = L["Both"] },
		}, disableWhen = function(s) return not (s.enabled and s.skipCinematics) end },
		{ type = "slider", key = "skipDelay", label = L["Skip after"], help = L["Seconds before skipping a cancellable cinematic; zero skips now. Hold Shift to watch."], min = 0, max = 30, step = 1, disableWhen = function(s) return not (s.enabled and s.skipCinematics) end },
		{ type = "toggle", key = "maxCamera", label = L["Max camera distance"], help = L["Let the camera zoom out as far as the game allows."], disableWhen = isOff },
		{ type = "header", label = L["On-screen alerts"] },
		slider("alertSize", L["Alert text size"], L["The size of the combat, talent, death and durability alerts."], 1, isOff),
		{ type = "toggle", key = "combatAlert", label = L["Combat alert"], help = L["Show large text as you enter or leave combat."], disableWhen = isOff },
		{ type = "dropdown", key = "combatAlertOn", label = L["Show on"], help = L["Show the alert as you enter combat, as you leave it, or both."], options = {
			{ value = "both", label = L["Both"] }, { value = "enter", label = L["Entering"] }, { value = "leave", label = L["Leaving"] },
		}, disableWhen = combatOff },
		{ type = "text", key = "combatEnterText", label = L["Entering text"], help = L["Blank shows +Combat."], maxLetters = 40, disableWhen = combatOff },
		{ type = "color", key = "combatEnterColor", label = L["Entering colour"], help = L["The colour of the alert as you enter combat."], disableWhen = combatOff },
		{ type = "toggle", key = "combatEnterClass", label = L["Entering in class colour"], help = L["Use your class colour as you enter combat."], disableWhen = combatOff },
		{ type = "text", key = "combatLeaveText", label = L["Leaving text"], help = L["Blank shows -Combat."], maxLetters = 40, disableWhen = combatOff },
		{ type = "color", key = "combatLeaveColor", label = L["Leaving colour"], help = L["The colour of the alert as you leave combat."], disableWhen = combatOff },
		{ type = "toggle", key = "combatLeaveClass", label = L["Leaving in class colour"], help = L["Use your class colour as you leave combat."], disableWhen = combatOff },
		{ type = "toggle", key = "talentAlert", label = L["Unspent talents alert"], help = L["Show text out of combat while you have talent points to spend."], disableWhen = isOff },
		{ type = "text", key = "talentText", label = L["Talent alert text"], help = L["Blank shows Unspent talent points."], maxLetters = 40, disableWhen = talentOff },
		{ type = "color", key = "talentColor", label = L["Talent alert colour"], help = L["The colour of the unspent talents alert."], disableWhen = talentOff },
		{ type = "toggle", key = "talentClass", label = L["Talent alert in class colour"], help = L["Use your class colour for the unspent talents alert."], disableWhen = talentOff },
		{ type = "toggle", key = "deathAlert", label = L["Group death alert"], help = L["Show large text when a party or raid member dies."], disableWhen = isOff },
		{ type = "dropdown", key = "deathSound", label = L["Death sound"], help = L["The sound that plays with a group death alert."], options = {
			{ value = "none", label = L["None"] }, { value = "warning", label = L["Raid warning"] }, { value = "ready", label = L["Ready check"] },
		}, disableWhen = when("deathAlert") },
		{ type = "toggle", key = "durabilityAlert", label = L["Low durability warning"], help = L["Warn out of combat when worn gear wears down."], disableWhen = isOff },
		slider("durabilityPercent", L["Warn below"], L["Warn when any worn item falls below this durability, in percent."], 1, durabilityOff),
		slider("durabilityY", L["Warning height"], L["Moves the durability warning up or down from the screen centre."], 1, durabilityOff),
		{ type = "toggle", key = "durabilityThrown", label = L["Ignore thrown weapons"], help = L["Leave out thrown weapons, which wear down with every throw."], disableWhen = durabilityOff },
		{ type = "header", label = L["Crosshair"] },
		{ type = "dropdown", key = "crosshair", label = L["Crosshair"], help = L["A crosshair at the centre of the screen, over your character."], options = {
			{ value = "none", label = L["None"] }, { value = "thin", label = L["Thin"] }, { value = "normal", label = L["Normal"] }, { value = "thick", label = L["Thick"] },
		}, disableWhen = isOff },
		{ type = "dropdown", key = "crosshairShow", label = L["Show crosshair"], help = L["When the crosshair shows."], options = SHOW_OPTIONS, disableWhen = crossOff },
		slider("crosshairHLength", L["Horizontal length"], L["The length of the horizontal line."], 1, crossOff),
		slider("crosshairHWidth", L["Horizontal thickness"], L["The horizontal line's thickness in pixels; zero follows the style."], 1, crossOff),
		slider("crosshairVLength", L["Vertical length"], L["The length of the vertical line."], 1, crossOff),
		slider("crosshairVWidth", L["Vertical thickness"], L["The vertical line's thickness in pixels; zero follows the style."], 1, crossOff),
		slider("crosshairBorder", L["Outline"], L["A dark outline around the lines, in pixels."], 1, crossOff),
		slider("crosshairX", L["Horizontal offset"], L["Moves the crosshair left or right."], 1, crossOff),
		slider("crosshairY", L["Vertical offset"], L["Moves the crosshair up or down."], 1, crossOff),
		{ type = "header", label = L["Cursor"] },
		{ type = "toggle", key = "cursorRing", label = L["Cursor ring"], help = L["A ring around the mouse pointer, so you can find it."], disableWhen = isOff },
		{ type = "dropdown", key = "cursorShow", label = L["Show cursor ring"], help = L["When the cursor ring shows."], options = SHOW_OPTIONS, disableWhen = ringOff },
		slider("cursorScale", L["Ring size"], L["The size of the cursor ring, in percent."], 5, ringOff),
		slider("cursorOpacity", L["Ring opacity"], L["How solid the cursor ring is, in percent."], 5, ringOff),
		{ type = "toggle", key = "cursorClass", label = L["Ring in class colour"], help = L["Use your class colour for the cursor ring."], disableWhen = ringOff },
		{ type = "color", key = "cursorColor", label = L["Ring colour"], help = L["The colour of the cursor ring."], disableWhen = function(s) return ringOff(s) or s.cursorClass end },
		{ type = "header", label = L["Tools"] },
		{ type = "toggle", key = "hideScreenshot", label = L["Hide screenshot notice"], help = L["Hide the message that says a screenshot was saved."], disableWhen = isOff },
		{ type = "toggle", key = "announceReset", label = L["Announce instance resets"], help = L["Tell your party or raid when you reset instances."], disableWhen = isOff },
		{ type = "toggle", key = "autoLog", label = L["Combat log in instances"], help = L["Start the combat log as you enter an instance and stop it as you leave."], disableWhen = isOff },
		{ type = "dropdown", key = "autoLogWhere", label = L["Log in"], help = L["The instances that start the combat log."], options = {
			{ value = "raid", label = L["Raids"] }, { value = "party", label = L["Dungeons"] }, { value = "all", label = L["All instances"] },
		}, disableWhen = logOff },
		{ type = "toggle", key = "autoLogNotice", label = L["Combat log notice"], help = L["Say in chat when the combat log starts or stops."], disableWhen = logOff },
		{ type = "header", label = L["Alerts"] },
		{ type = "toggle", key = "quietErrors", label = L["Quiet error text"], help = L["Hide the red cooldown, range and resource errors that flood the screen in combat."], disableWhen = isOff },
		{ type = "toggle", key = "autoDelete", label = L["Fill in the delete word"], help = L["Type the confirmation word when you delete a good item. You still click Yes."], disableWhen = isOff },
		{ type = "header", label = L["Resurrection"] },
		{ type = "toggle", key = "autoResurrect", label = L["Accept resurrection"], help = L["Accept a resurrection out of combat the moment it is offered, unless the game makes you wait."], disableWhen = isOff },
	}
	ns.schema.preview = ns.Preview
	return ns.schema
end
