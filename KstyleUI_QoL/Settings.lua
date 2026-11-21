-- Settings.lua: KstyleUI_QoL's defaults, its settings page, checked reads of each setting, and ns.Ask, which answers nil when a game API is missing or its first answer is secret.
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
	skipMode = { cinematics = true, movies = true, both = true }, cursorTexture = { ring = true, ringBevel = true },
	statsValue = { percent = true, rating = true, both = true }, hideToasts = { none = true, loot = true, achievements = true, both = true },
}
ns.LIMITS = {
	skipDelay = { 0, 30 }, alertSize = { 14, 64 }, durabilityPercent = { 5, 100 }, durabilityY = { -500, 500 },
	crosshairHLength = { 1, 500 }, crosshairVLength = { 1, 500 }, crosshairHWidth = { 0, 20 }, crosshairVWidth = { 0, 20 },
	crosshairBorder = { 0, 5 }, crosshairX = { -200, 200 }, crosshairY = { -200, 200 }, cursorScale = { 50, 200 }, cursorOpacity = { 10, 100 },
	rollsClose = { 0, 60 }, statsScale = { 50, 200 },
}

ns.defaults = {
	enabled = false,
	fastLoot = true,
	lootFeed = true,
	coinIcons = false,
	rollsClose = 0,
	autoRepair = true,
	guildRepair = false,
	autoQuests = false,
	autoGossip = false,
	ignoreTrivial = true,
	questInstances = true,
	skipCinematics = false,
	skipDelay = 0,
	skipMode = "cinematics",
	skipAuto = true,
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
	cursorTexture = "ring",
	cursorDot = false,
	cursorHidden = false,
	cursorTrail = false,
	castRing = false,
	castSpark = true,
	castAttach = true,
	stats = false,
	statsValue = "percent",
	statsColored = false,
	statsShort = false,
	statsScale = 100,
	dialogKeys = false,
	numberKeys = false,
	confirmPopups = false,
	hideToasts = "none",
	trainAll = false,
	autoOpen = false,
	openSkipWarbound = true,
	autoUnwrap = false,
	hideScreenshot = false,
	announceReset = false,
	autoLog = false,
	autoLogWhere = "raid",
	autoLogNotice = true,
	autoLogDelay = false,
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

function ns.Ask(api, ...)
	if type(api) ~= "function" then return nil end
	local value = api(...)
	if not ns.IsSecret(value) then return value end
end

function ns.Schema()
	local function isOff(settings)
		return not settings.enabled
	end

	local function when(key)
		return function(settings) return not (settings.enabled and settings[key] and settings[key] ~= "none") end
	end
	local combatOff, talentOff, durabilityOff, crossOff, ringOff, logOff = when("combatAlert"), when("talentAlert"), when("durabilityAlert"), when("crosshair"), when("cursorRing"), when("autoLog")
	local castOff, statsOff, skipOff = when("castRing"), when("stats"), when("skipCinematics")
	local function aidsOff(s) return ringOff(s) and castOff(s) end
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
		slider("rollsClose", L["Close loot rolls after"], L["Seconds before the loot rolls window closes once you open it; zero leaves it open."], 1, isOff),
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
		}, disableWhen = skipOff },
		{ type = "toggle", key = "skipAuto", label = L["Skip at once"], help = L["Skip as it starts. Off, Escape skips without asking."], disableWhen = skipOff },
		{ type = "slider", key = "skipDelay", label = L["Skip after"], help = L["Seconds before skipping a cancellable cinematic; zero skips now. Hold Shift to watch."], min = 0, max = 30, step = 1, disableWhen = function(s) return not (s.enabled and s.skipCinematics) end },
		{ type = "toggle", key = "maxCamera", label = L["Max camera distance"], help = L["Let the camera zoom out as far as the game allows."], disableWhen = isOff },
		{ type = "header", label = L["On-screen alerts"] },
		slider("alertSize", L["Alert text size"], L["The size of the combat, talent, death and durability alerts."], 1, isOff),
		{ type = "toggle", key = "combatAlert", label = L["Combat alert"], help = L["Show large text as you enter or leave combat."], disableWhen = isOff },
		{ type = "dropdown", key = "combatAlertOn", label = L["Show on"], help = L["Show the alert as you enter combat, as you leave it, or both."], options = {
			{ value = "both", label = L["Both"] }, { value = "enter", label = L["Entering"] }, { value = "leave", label = L["Leaving"] },
		}, disableWhen = combatOff },
		{ type = "text", key = "combatEnterText", label = L["Entering text"], help = L["Blank shows +Combat."], maxLetters = 40, disableWhen = combatOff },
		{ type = "color", key = "combatEnterColor", label = L["Entering colour"], help = L["The colour of the alert as you enter combat."], disableWhen = function(s) return combatOff(s) or s.combatEnterClass end },
		{ type = "toggle", key = "combatEnterClass", label = L["Entering in class colour"], help = L["Use your class colour as you enter combat."], disableWhen = combatOff },
		{ type = "text", key = "combatLeaveText", label = L["Leaving text"], help = L["Blank shows -Combat."], maxLetters = 40, disableWhen = combatOff },
		{ type = "color", key = "combatLeaveColor", label = L["Leaving colour"], help = L["The colour of the alert as you leave combat."], disableWhen = function(s) return combatOff(s) or s.combatLeaveClass end },
		{ type = "toggle", key = "combatLeaveClass", label = L["Leaving in class colour"], help = L["Use your class colour as you leave combat."], disableWhen = combatOff },
		{ type = "toggle", key = "talentAlert", label = L["Unspent talents alert"], help = L["Show text out of combat while you have talent points to spend."], disableWhen = isOff },
		{ type = "text", key = "talentText", label = L["Talent alert text"], help = L["Blank shows Unspent talent points."], maxLetters = 40, disableWhen = talentOff },
		{ type = "color", key = "talentColor", label = L["Talent alert colour"], help = L["The colour of the unspent talents alert."], disableWhen = function(s) return talentOff(s) or s.talentClass end },
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
		{ type = "toggle", key = "cursorHidden", label = L["Only while looking around"], help = L["Show the ring only while you hold a mouse button to turn the camera."], disableWhen = ringOff },
		{ type = "toggle", key = "cursorDot", label = L["Centre dot"], help = L["A small dot at the centre of the ring."], disableWhen = ringOff },
		{ type = "toggle", key = "cursorTrail", label = L["Cursor trail"], help = L["Dots that follow the ring as the pointer moves."], disableWhen = ringOff },
		{ type = "toggle", key = "castRing", label = L["Cast circle"], help = L["A ring that fills as you cast, in the ring's colour."], disableWhen = isOff },
		{ type = "toggle", key = "castSpark", label = L["Cast spark"], help = L["A bright edge on the filling cast circle."], disableWhen = castOff },
		{ type = "toggle", key = "castAttach", label = L["Cast circle on the pointer"], help = L["Off puts the cast circle at the screen centre."], disableWhen = castOff },
		{ type = "dropdown", key = "cursorTexture", label = L["Ring style"], help = L["The look of the cursor ring and the cast circle."], options = {
			{ value = "ring", label = L["Plain"] }, { value = "ringBevel", label = L["Bevelled"] },
		}, disableWhen = aidsOff },
		slider("cursorScale", L["Ring size"], L["The size of the cursor ring and the cast circle, in percent."], 5, aidsOff),
		slider("cursorOpacity", L["Ring opacity"], L["How solid the cursor ring and the cast circle are, in percent."], 5, aidsOff),
		{ type = "toggle", key = "cursorClass", label = L["Ring in class colour"], help = L["Use your class colour for the cursor ring and the cast circle."], disableWhen = aidsOff },
		{ type = "color", key = "cursorColor", label = L["Ring colour"], help = L["The colour of the cursor ring and the cast circle."], disableWhen = function(s) return aidsOff(s) or s.cursorClass end },
		{ type = "header", label = L["Character stats"] },
		{ type = "toggle", key = "stats", label = L["Show character stats"], help = L["Your stats as text at the top left of the screen. Move them in Layout Mode."], disableWhen = isOff },
		{ type = "order", key = "statsList", label = L["Stats"], help = L["Switch stats on and move them up or down."], options = ns.StatOptions(), disableWhen = statsOff },
		{ type = "dropdown", key = "statsValue", label = L["Show ratings as"], help = L["Crit, haste, dodge, parry and block as a percentage, the rating, or both."], options = {
			{ value = "percent", label = L["Percent"] }, { value = "rating", label = L["Rating"] }, { value = "both", label = L["Percent and rating"] },
		}, disableWhen = statsOff },
		{ type = "toggle", key = "statsColored", label = L["Coloured values"], help = L["Draw the values in the accent colour."], disableWhen = statsOff },
		{ type = "toggle", key = "statsShort", label = L["Short labels"], help = L["Abbreviate the stat names."], disableWhen = statsOff },
		slider("statsScale", L["Stats size"], L["The size of the stats text, in percent."], 5, statsOff),
		{ type = "header", label = L["Dialog keys"] },
		{ type = "toggle", key = "dialogKeys", label = L["Space continues dialogs"], help = L["Space accepts, continues or hands in a quest and picks the first choice. Out of combat."], disableWhen = isOff },
		{ type = "toggle", key = "numberKeys", label = L["Number keys pick choices"], help = L["Keys 1 to 9 pick the matching gossip or quest choice. Out of combat."], disableWhen = isOff },
		{ type = "toggle", key = "confirmPopups", label = L["Space confirms popups"], help = L["Space clicks the first button of a popup. Out of combat."], disableWhen = isOff },
		{ type = "header", label = L["Tools"] },
		{ type = "toggle", key = "hideScreenshot", label = L["Hide screenshot notice"], help = L["Hide the message that says a screenshot was saved."], disableWhen = isOff },
		{ type = "toggle", key = "announceReset", label = L["Announce instance resets"], help = L["Tell your party or raid when you reset instances."], disableWhen = isOff },
		{ type = "toggle", key = "autoLog", label = L["Combat log in instances"], help = L["Start the combat log as you enter an instance and stop it as you leave."], disableWhen = isOff },
		{ type = "dropdown", key = "autoLogWhere", label = L["Log in"], help = L["The instances that start the combat log."], options = {
			{ value = "raid", label = L["Raids"] }, { value = "party", label = L["Dungeons"] }, { value = "all", label = L["All instances"] },
		}, disableWhen = logOff },
		{ type = "toggle", key = "autoLogNotice", label = L["Combat log notice"], help = L["Say in chat when the combat log starts or stops."], disableWhen = logOff },
		{ type = "toggle", key = "autoLogDelay", label = L["Keep logging 30 seconds"], help = L["Stop the combat log 30 seconds after you leave, for recording tools that read it."], disableWhen = logOff },
		{ type = "dropdown", key = "hideToasts", label = L["Hide toasts"], help = L["Hide the loot or achievement toasts that pop up on screen."], options = {
			{ value = "none", label = L["None"] }, { value = "loot", label = L["Loot"] }, { value = "achievements", label = L["Achievements"] }, { value = "both", label = L["Both"] },
		}, disableWhen = isOff },
		{ type = "toggle", key = "trainAll", label = L["Train all button"], help = L["A Train all button at trainers that learns everything you can afford."], disableWhen = isOff },
		{ type = "toggle", key = "autoOpen", label = L["Open containers"], help = L["Open boxes and bags in your bags, out of combat and away from merchants, mail, banks and trades."], disableWhen = isOff },
		{ type = "toggle", key = "openSkipWarbound", label = L["Leave warbound containers"], help = L["Leave containers bound to your account for your other characters."], disableWhen = when("autoOpen") },
		{ type = "toggle", key = "autoUnwrap", label = L["Unwrap new mounts and toys"], help = L["Clear the gift wrap from new mounts and toys in the collections."], disableWhen = isOff },
		{ type = "header", label = L["Alerts"] },
		{ type = "toggle", key = "quietErrors", label = L["Quiet error text"], help = L["Hide the red cooldown, range and resource errors that flood the screen in combat."], disableWhen = isOff },
		{ type = "toggle", key = "autoDelete", label = L["Fill in the delete word"], help = L["Type the confirmation word when you delete a good item. You still click Yes."], disableWhen = isOff },
		{ type = "header", label = L["Resurrection"] },
		{ type = "toggle", key = "autoResurrect", label = L["Accept resurrection"], help = L["Accept a resurrection out of combat the moment it is offered, unless the game makes you wait."], disableWhen = isOff },
	}
	ns.schema.preview = ns.Preview
	return ns.schema
end
