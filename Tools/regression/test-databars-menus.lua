-- test-databars-menus.lua: KstyleUI's micro menu and bag bar: Blizzard's two bars hidden through Safe, secure buttons in Layout holders that click Blizzard's own buttons, and the settings.
local D = dofile("Tools/regression/databars_env.lua")
local W = D.W

local KEYRING = -2

-- Forever's micro buttons in the order Camelot's GenerateButtonInfos adds them. Help starts hidden.
local MICRO = {
	{ "CharacterMicroButton" }, { "ProfessionMicroButton", "Professions" }, { "SpellbookMicroButton", "SpellbookAbilities" },
	{ "TalentMicroButton", "SpecTalents" }, { "LegacyMicroButton", "Legacy" }, { "QuestLogMicroButton", "Questlog" },
	{ "HousingMicroButton", "Housing" }, { "GuildMicroButton", "GuildCommunities" }, { "LFDMicroButton", "Groupfinder" },
	{ "CollectionsMicroButton", "Collections" }, { "EJMicroButton", "AdventureGuide" }, { "HelpMicroButton", "Help" },
	{ "StoreMicroButton", "Shop" }, { "MainMenuMicroButton", "MainMenu" },
}
-- Built by the XML but never added to Forever's menu.
local LOOSE = { "PlayerSpellsMicroButton", "AchievementMicroButton" }

-- The bag bar from left to right, as Forever's bar grows left from the backpack.
local BAGS = {
	{ "KeyRingButton", KEYRING }, { "CharacterReagentBag0Slot", 5 }, { "CharacterBag3Slot", 4 }, { "CharacterBag2Slot", 3 },
	{ "CharacterBag1Slot", 2 }, { "CharacterBag0Slot", 1 }, { "MainMenuBarBackpackButton", 0 },
}

local SECURE_CALLS = {
	Show = true, Hide = true, SetShown = true, SetPoint = true, ClearAllPoints = true, SetAllPoints = true,
	SetSize = true, SetWidth = true, SetHeight = true, SetAttribute = true, SetParent = true,
}

local function eq(got, want, what)
	assert(got == want, string.format("%s: expected %s, got %s", what, tostring(want), tostring(got)))
end

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local function noErrors(env, K)
	assert(#env._errors == 0, "errors were raised: " .. tostring(env._errors[1]))
	eq(K.ErrorCount(), 0, "errors caught by KstyleUI.Call")
end

local function element(K, key)
	for _, el in ipairs(K.Layout.Elements()) do
		if el.key == key then
			return el
		end
	end
end

-- Stand-ins for Blizzard's micro menu and bag bar, built as Forever's XML and Lua build them.
local function Blizzard(env)
	local game = {
		free = { [0] = 4, [1] = 10, [2] = 0, [3] = 2, [4] = 6, [5] = 0, [KEYRING] = 0 }, slots = 16, cursor = false, calls = {},
		textures = { [31] = 1001, [32] = 1002, [33] = 1003 },
	}
	env._menus = game
	local container = env.CreateFrame("Frame", "MicroMenuContainer", env.UIParent)
	local menu = env.CreateFrame("Frame", "MicroMenu", container)
	for i, def in ipairs(MICRO) do
		local button = env._G[def[1]] or env.CreateFrame("Button", def[1], menu)
		button:SetParent(menu)
		button.layoutIndex = i
		button.callbacks = {}
		-- CallbackRegistryMixin, as MainMenuBarMicroButton_OnLoad generates it.
		function button.RegisterCallback(self, event, fn, owner)
			self.callbacks[#self.callbacks + 1] = { event, fn, owner }
		end
		function button.TriggerEvent(self, event, ...)
			for _, callback in ipairs(self.callbacks) do
				if callback[1] == event then
					callback[2](callback[3], ...)
				end
			end
		end
		if def[2] then
			local normal = button:CreateTexture(nil, "ARTWORK")
			normal:SetAtlas("UI-HUD-MicroMenu-" .. def[2] .. "-Up")
			button:SetNormalTexture(normal)
		end
	end
	env.HelpMicroButton:Hide()
	for _, name in ipairs(LOOSE) do
		local button = env.CreateFrame("Button", name, nil)
		local normal = button:CreateTexture(nil, "ARTWORK")
		normal:SetAtlas("UI-HUD-MicroMenu-Loose-Up")
		button:SetNormalTexture(normal)
	end
	local bags = env.CreateFrame("Frame", "BagsBar", env.UIParent)
	local cluster = env.CreateFrame("Frame", "BagSlotCluster", bags)
	for _, def in ipairs(BAGS) do
		local name, bag = def[1], def[2]
		local button = env._G[name] or env.CreateFrame("Button", name, bags)
		button:SetParent(name:match("^Character") and cluster or bags)
		button:SetID(bag == KEYRING and KEYRING or 30 + bag)
		button.icon = button:CreateTexture(nil, "BORDER")
		if name == "KeyRingButton" then
			button.icon:SetAtlas("UI-HUD-ActionBar-Keyring-Small")
		elseif name == "MainMenuBarBackpackButton" then
			button.icon:SetTexture("Interface\\Icons\\ui-hud-actionbar-bag")
		else
			button.icon:SetTexture(game.textures[30 + bag] and 9000 + bag or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
		end
	end
	env.CharacterReagentBag0Slot:Hide()

	env.KEYRING_CONTAINER = KEYRING
	env.C_Container = {
		ContainerIDToInventoryID = function(bag)
			return 30 + bag
		end,
		GetContainerNumFreeSlots = function(bag)
			return game.free[bag] or 0
		end,
		GetContainerNumSlots = function()
			return game.slots
		end,
		CalculateTotalNumberOfFreeBagSlots = function()
			local total = 0
			for bag = 0, 5 do
				total = total + (game.free[bag] or 0)
			end
			return total
		end,
	}
	function env.GetInventoryItemTexture(_, slot)
		return game.textures[slot]
	end
	function env.GetInventoryItemLink(_, slot)
		if slot > 30 and slot <= 35 then
			return "[Bag " .. slot .. "]"
		end
	end
	function env.CursorHasItem()
		return game.cursor
	end
	function env.PutItemInBag(slot)
		game.calls[#game.calls + 1] = "PutItemInBag(" .. slot .. ")"
	end
	function env.PutItemInBackpack()
		game.calls[#game.calls + 1] = "PutItemInBackpack()"
	end
	function env.PutKeyInKeyRing()
		game.calls[#game.calls + 1] = "PutKeyInKeyRing()"
	end
	function env.PickupBagFromSlot(slot)
		game.calls[#game.calls + 1] = "PickupBagFromSlot(" .. slot .. ")"
	end
	function env.SetPortraitTexture(texture, unit)
		game.portraits = (game.portraits or 0) + 1
		texture._portrait = unit
	end
	function env.UpdateMicroButtons() end
	function env.MicroButtonPulse() end
	function env.MicroButtonPulseStop() end
	function env.LoadMicroButtonTextures(button, name)
		button:GetNormalTexture():SetAtlas("UI-HUD-MicroMenu-" .. name .. "-Up")
	end
	function env.PaperDollItemSlotButton_Update() end
	function env.MainActionBar_InitializeGamepad()
		env.MicroMenu:Hide()
		env.BagsBar:Hide()
	end
	function env.MainActionBar_InitializeMKB()
		env.MicroMenu:Show()
		env.BagsBar:Show()
	end
	return game
end

local function Snapshot(env)
	local names = { "MicroMenuContainer", "MicroMenu", "BagsBar", "BagSlotCluster" }
	for _, def in ipairs(MICRO) do
		names[#names + 1] = def[1]
	end
	for _, def in ipairs(BAGS) do
		names[#names + 1] = def[1]
	end
	local out = {}
	for _, name in ipairs(names) do
		local frame = env[name]
		local keys = {}
		for key in pairs(frame) do
			keys[key] = true
		end
		out[name] = { frame = frame, keys = keys, calls = #frame._calls }
	end
	return out
end

-- DataBars may reparent the two bars it hides, through Safe. It never moves, hides, scripts or
-- writes a field onto any Blizzard frame.
local FORBIDDEN = { Hide = true, Show = true, SetShown = true, SetParent = true, SetScript = true, ClearAllPoints = true, SetPoint = true, SetAllPoints = true, SetSize = true, SetScale = true, SetAlpha = true }
local HIDDEN_BY_SAFE = { MicroMenuContainer = true, BagsBar = true }

local function CheckUntouched(env, before)
	for name, entry in pairs(before) do
		local frame = entry.frame
		for i = entry.calls + 1, #frame._calls do
			local method = frame._calls[i].method
			if not (method == "SetParent" and HIDDEN_BY_SAFE[name]) then
				assert(not FORBIDDEN[method], "DataBars called " .. method .. " on " .. name)
			end
		end
		for key in pairs(frame) do
			assert(entry.keys[key], "DataBars wrote the field " .. tostring(key) .. " onto " .. name)
		end
	end
end

local function New(opts)
	opts = opts or {}
	local userSetup = opts.setup
	local game
	opts.setup = function(env, g)
		game = Blizzard(env)
		if userSetup then
			userSetup(env, g)
		end
	end
	local enable = opts.enable
	opts.enable = false
	local env, K, ns = D.New(opts)
	local before = Snapshot(env)
	if enable ~= false then
		K.Modules.Enable("DataBars")
		env.RunTimers()
	end
	return env, K, ns, game, before
end

local function Names(ns, id)
	local out = {}
	for _, button in ipairs(ns.Menus.Shown(id)) do
		local target = button:GetAttribute("clickbutton")
		out[#out + 1] = target and target:GetName() or "?"
	end
	return table.concat(out, ",")
end

local function Button(ns, id, name)
	for _, button in ipairs(ns.Menus.Shown(id)) do
		local target = button:GetAttribute("clickbutton")
		if target and target:GetName() == name then
			return button
		end
	end
	error("no shown KstyleUI button clicks " .. name)
end

-- The left offset of a button from its holder's TOPLEFT.
local function Left(button)
	local point, _, _, x = button:GetPoint(1)
	eq(point, "TOPLEFT", "buttons sit from the holder's top left")
	return x
end

-- Blizzard's bars hidden through Safe; KstyleUI's bars registered with Layout -------------------------

do
	local env, K, _, _, before = New()
	assert(K.Safe.IsHidden(env.MicroMenuContainer), "the micro menu's container is hidden through Safe")
	assert(K.Safe.IsHidden(env.BagsBar), "the bag bar is hidden through Safe")
	assert(env.MicroMenuContainer:GetParent() ~= env.UIParent and env.MicroMenuContainer:GetParent():IsShown() == false, "by reparenting to a hidden frame")
	eq(env.MicroMenu:GetParent(), env.MicroMenuContainer, "MicroMenu stays in its container, so Blizzard's own resets keep it hidden")
	for _, key in ipairs({ "databars.micro", "databars.bags" }) do
		local el = assert(element(K, key), key .. " registers with Layout")
		eq(el.module, "DataBars", key .. " belongs to the module")
		eq(el.opts.scalable, true, key .. " is scalable")
		eq(el.label, K.Setup.Layouts.Element(key).label, key .. " uses the setup's label")
		local default, got = K.Setup.Layouts.Default(key), K.Layout.Get(key)
		eq(got.anchor .. got.x .. "," .. got.y, default.anchor .. default.x .. "," .. default.y, key .. " starts at the setup's position")
	end
	CheckUntouched(env, before)
	noErrors(env, K)
end

-- One secure button per Blizzard micro button in the menu, in Blizzard's order ---------------------------

do
	local env, K, ns = New()
	eq(Names(ns, "micro"), "CharacterMicroButton,ProfessionMicroButton,SpellbookMicroButton,TalentMicroButton,LegacyMicroButton,"
		.. "QuestLogMicroButton,HousingMicroButton,GuildMicroButton,LFDMicroButton,CollectionsMicroButton,EJMicroButton,"
		.. "StoreMicroButton,MainMenuMicroButton", "the shown micro buttons, without Help and the buttons Forever never adds")
	for _, button in ipairs(ns.Menus.Shown("micro")) do
		local target = button:GetAttribute("clickbutton")
		eq(button._template, "SecureActionButtonTemplate", "a KstyleUI secure action button")
		if target ~= env.MainMenuMicroButton then
			eq(button:GetAttribute("type"), "click", target:GetName() .. " clicks Blizzard's button")
		end
		eq(button:GetAttribute("useOnKeyDown"), false, "on the release")
		assert(button:GetParent() ~= target:GetParent(), "a KstyleUI frame, not Blizzard's")
	end
	local quest = Button(ns, "micro", "QuestLogMicroButton")
	eq(quest.icon:GetAtlas(), "UI-HUD-MicroMenu-Questlog-Up", "the icon is Blizzard's own glyph")
	eq(Button(ns, "micro", "CharacterMicroButton").icon._portrait, "player", "the character button shows your portrait")
	local holder = ns.Menus.Holder("micro")
	local footprint = K.Setup.Layouts.Element("databars.micro")
	assert(holder:GetWidth() <= footprint.width and holder:GetHeight() <= footprint.height, string.format("the micro menu fits its footprint: %sx%s", holder:GetWidth(), holder:GetHeight()))
	local first, second = ns.Menus.Shown("micro")[1], ns.Menus.Shown("micro")[2]
	assert(Left(second) > Left(first), "buttons run left to right")
	assert(first:GetHeight() > first:GetWidth(), "micro buttons stand upright, like Blizzard's glyphs")
	local moves = #W.Calls(first, "SetPoint")
	env.UpdateMicroButtons()
	eq(#W.Calls(first, "SetPoint"), moves, "Blizzard's frequent updates move nothing when nothing changed")
	K.DevTest.Run()
	local reported = false
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		reported = reported or entry.message:find("micro 13 buttons, Blizzard's hidden; bags 6 buttons, Blizzard's hidden", 1, true) ~= nil
	end
	assert(reported, "/kstyle test reports both bars and whether Blizzard's are hidden")
	noErrors(env, K)
end

-- The game menu: Blizzard's handler opens it only under its own pointer, so KstyleUI's button opens it out of combat

do
	local env, K, ns = New({ setup = function(env)
		env.CreateFrame("Frame", "GameMenuFrame", env.UIParent):Hide()
		env._panels = {}
		function env.ShowUIPanel(frame)
			env._panels[#env._panels + 1] = "show"
			frame:Show()
		end
		function env.HideUIPanel(frame)
			env._panels[#env._panels + 1] = "hide"
			frame:Hide()
		end
	end })
	local menu = Button(ns, "micro", "MainMenuMicroButton")
	eq(menu:GetAttribute("type"), nil, "the game menu button runs no secure click")
	W.Click(menu)
	eq(env.GameMenuFrame:IsShown(), true, "a click opens the game menu")
	W.Click(menu)
	eq(env.GameMenuFrame:IsShown(), false, "and closes it")
	env.SetCombat(true)
	W.Click(menu)
	eq(table.concat(env._panels, ","), "show,hide", "in combat it leaves the panels alone")
	W.Enter(menu)
	local lines = {}
	for _, line in ipairs(K.Widgets.Tooltip().used) do
		lines[#lines + 1] = line.left:GetText()
	end
	assert(table.concat(lines, "|"):find("Escape opens the game menu", 1, true), "and its tooltip points to Escape")
	env.SetCombat(false)
	noErrors(env, K)
end

-- Blizzard's buttons drive what shows: hidden, disabled, pushed, pulsing and new glyphs ---------------

do
	local env, K, ns = New()
	local width = ns.Menus.Holder("micro"):GetWidth()
	env.HelpMicroButton:Show()
	env.UpdateMicroButtons()
	assert(Names(ns, "micro"):find("EJMicroButton,HelpMicroButton,StoreMicroButton", 1, true), "Help shows in its place once Blizzard shows it")
	assert(ns.Menus.Holder("micro"):GetWidth() > width, "and the bar grows")
	env.StoreMicroButton:Hide()
	env.UpdateMicroButtons()
	assert(not Names(ns, "micro"):find("StoreMicroButton", 1, true), "a hidden Blizzard button leaves the bar")

	env.LFDMicroButton:Disable()
	env.QuestLogMicroButton:SetButtonState("PUSHED", true)
	env.UpdateMicroButtons()
	eq(Button(ns, "micro", "LFDMicroButton").usable, false, "a disabled Blizzard button shows disabled")
	eq(Button(ns, "micro", "QuestLogMicroButton").selected, true, "a pushed one, whose window is open, shows selected")
	env.QuestLogMicroButton:SetButtonState("NORMAL")
	env.LFDMicroButton:Enable()
	env.UpdateMicroButtons()
	eq(Button(ns, "micro", "LFDMicroButton").usable, true, "enabled again")
	eq(Button(ns, "micro", "QuestLogMicroButton").selected, false, "and closed again")

	env.TalentMicroButton.IsPulsing = function()
		return true
	end
	env.MicroButtonPulse(env.TalentMicroButton)
	eq(Button(ns, "micro", "TalentMicroButton").proc, true, "a pulsing alert glows")
	env.TalentMicroButton.IsPulsing = function()
		return false
	end
	env.MicroButtonPulseStop(env.TalentMicroButton)
	eq(Button(ns, "micro", "TalentMicroButton").proc, false, "and stops")

	local guild = env.GuildMicroButton
	guild.HasNotification = function()
		return true
	end
	guild:TriggerEvent("OnNewNotification", guild)
	eq(Button(ns, "micro", "GuildMicroButton").proc, true, "a notification glows as soon as Blizzard raises it")
	guild.HasNotification = function()
		return false
	end
	guild:TriggerEvent("OnDismissedNotification", guild)
	eq(Button(ns, "micro", "GuildMicroButton").proc, false, "and stops when it is dismissed")
	guild:Disable()
	guild:TriggerEvent("OnDisable", guild)
	eq(Button(ns, "micro", "GuildMicroButton").usable, false, "a button Blizzard disables between updates shows disabled")
	guild:Enable()
	guild:TriggerEvent("OnEnable", guild)

	env.LoadMicroButtonTextures(env.GuildMicroButton, "GuildCommunities-GuildColor")
	eq(Button(ns, "micro", "GuildMicroButton").icon:GetAtlas(), "UI-HUD-MicroMenu-GuildCommunities-GuildColor-Up", "a new glyph follows Blizzard's")
	noErrors(env, K)
end

-- The bag bar: one secure button per shown bag button, icons, free slots, drag and drop ---------------

do
	local env, K, ns, game = New()
	eq(Names(ns, "bags"), "KeyRingButton,CharacterBag3Slot,CharacterBag2Slot,CharacterBag1Slot,CharacterBag0Slot,MainMenuBarBackpackButton", "left to right, the backpack last, without the hidden reagent slot")
	local backpack, bag = Button(ns, "bags", "MainMenuBarBackpackButton"), Button(ns, "bags", "CharacterBag1Slot")
	eq(backpack:GetAttribute("type"), "click", "the backpack clicks Blizzard's backpack button")
	eq(bag.icon:GetTexture(), 1002, "a bag shows the equipped bag's icon")
	eq(Button(ns, "bags", "CharacterBag3Slot").icon:GetTexture(), "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag", "an empty slot shows Blizzard's empty-slot art")
	eq(backpack.icon:GetTexture(), "Interface\\Icons\\ui-hud-actionbar-bag", "the backpack shows Blizzard's backpack icon")
	eq(Button(ns, "bags", "KeyRingButton").icon:GetAtlas(), "UI-HUD-ActionBar-Keyring-Small", "the key ring shows its atlas")
	eq(backpack.count:GetText(), "22", "the backpack counts free slots in every bag")
	local footprint = K.Setup.Layouts.Element("databars.bags")
	env.CharacterReagentBag0Slot:Show()
	env.FireEvent("BAG_UPDATE_DELAYED")
	env.RunTimers()
	eq(#ns.Menus.Shown("bags"), 7, "the reagent slot shows once Blizzard shows it")
	local holder = ns.Menus.Holder("bags")
	assert(holder:GetWidth() <= footprint.width and holder:GetHeight() <= footprint.height, string.format("seven bag buttons fit the footprint: %sx%s", holder:GetWidth(), holder:GetHeight()))

	game.textures[32] = 2222
	game.free[2] = 5
	env.FireEvent("PLAYER_EQUIPMENT_CHANGED", 32, true)
	env.RunTimers()
	eq(bag.icon:GetTexture(), 2222, "a new bag shows its icon")
	eq(backpack.count:GetText(), "27", "the count follows")

	local keyring = Button(ns, "bags", "KeyRingButton")
	game.cursor = true
	bag._scripts.OnReceiveDrag(bag)
	backpack._scripts.OnReceiveDrag(backpack)
	keyring._scripts.OnReceiveDrag(keyring)
	game.cursor = false
	bag._scripts.OnReceiveDrag(bag)
	bag._scripts.OnDragStart(bag, "LeftButton")
	backpack._scripts.OnDragStart(backpack, "LeftButton")
	eq(table.concat(game.calls, " "), "PutItemInBag(32) PutItemInBackpack() PutKeyInKeyRing() PickupBagFromSlot(32)", "drops go into the bag or the key ring, and a bag lifts off its slot")

	K.Options.Write("DataBars", "bags.freeSlots", false)
	eq(backpack.count:GetText(), "", "the free-slot count can be turned off")
	noErrors(env, K)
end

-- Settings: size, spacing, rows, glass and icon colour ------------------------------------------------

do
	local env, K, ns = New()
	local first = ns.Menus.Shown("micro")[1]
	local height = first:GetHeight()
	K.Options.Write("DataBars", "micro.size", 32)
	assert(first:GetHeight() > height, "the size setting grows the buttons")
	local second = ns.Menus.Shown("micro")[2]
	local gap = Left(second) - Left(first) - first:GetWidth()
	K.Options.Write("DataBars", "micro.spacing", 8)
	assert(Left(second) - Left(first) - first:GetWidth() > gap, "the spacing setting widens the gaps")
	local wide = ns.Menus.Holder("micro"):GetWidth()
	K.Options.Write("DataBars", "micro.rows", 2)
	assert(ns.Menus.Holder("micro"):GetWidth() < wide, "two rows make the bar narrower")
	assert(ns.Menus.Holder("micro"):GetHeight() > first:GetHeight() * 2, "and taller")

	local glass = ns.Menus.Glass("micro")
	eq(glass:IsShown(), true, "the bar sits on glass")
	K.Options.Write("DataBars", "micro.backdrop", false)
	eq(glass:IsShown(), false, "the glass can be turned off")

	local quest = Button(ns, "micro", "QuestLogMicroButton")
	K.Options.Write("DataBars", "micro.tint", "accent")
	local r, g, b = K.Theme.Accent()
	assert(near(quest.tint[1], r) and near(quest.tint[2], g) and near(quest.tint[3], b), "accent tints the glyphs")
	eq(W.LastCall(quest.icon, "SetDesaturated")[1], true, "after taking their colour out")
	K.Options.Write("DataBars", "micro.tint", "none")
	assert(near(quest.tint[1], 1) and near(quest.tint[2], 1) and near(quest.tint[3], 1), "none keeps Blizzard's colours")
	eq(W.LastCall(quest.icon, "SetDesaturated")[1], false, "and their colour")
	noErrors(env, K)
end

-- Turning a bar off gives Blizzard's back; turning the module off gives both back ---------------------

do
	local env, K, ns = New()
	local width = ns.Menus.Holder("micro"):GetWidth()
	K.Options.Write("DataBars", "micro.enabled", false)
	env.RunTimers()
	eq(ns.Menus.Holder("micro"):GetWidth(), width, "the holder keeps its size, so Layout Mode's plate does not jump")
	eq(env.MicroMenuContainer:GetParent(), env.UIParent, "Blizzard's micro menu returns where Edit Mode puts it")
	eq(ns.Menus.Content("micro"):IsShown(), false, "and KstyleUI's hides")
	assert(K.Safe.IsHidden(env.BagsBar), "the bag bar is not affected")
	K.Options.Write("DataBars", "micro.enabled", true)
	env.RunTimers()
	assert(K.Safe.IsHidden(env.MicroMenuContainer), "turning it on hides Blizzard's again")
	eq(ns.Menus.Content("micro"):IsShown(), true, "and shows KstyleUI's")

	K.Modules.Disable("DataBars")
	env.RunTimers()
	eq(env.MicroMenuContainer:GetParent(), env.UIParent, "the module off gives back the micro menu")
	eq(env.BagsBar:GetParent(), env.UIParent, "and the bag bar")
	eq(K.Modules.NeedsReload(), false, "with no reload")
	K.Modules.Enable("DataBars")
	env.RunTimers()
	assert(K.Safe.IsHidden(env.MicroMenuContainer) and K.Safe.IsHidden(env.BagsBar), "on again, both hide again")
	noErrors(env, K)
end

do
	local env, K, ns, _, before = New({ enable = false })
	K.Options.Write("DataBars", "micro.enabled", false)
	K.Options.Write("DataBars", "bags.enabled", false)
	K.Modules.Enable("DataBars")
	env.RunTimers()
	eq(env.MicroMenuContainer:GetParent(), env.UIParent, "both off before the module starts: Blizzard's micro menu stays")
	eq(env.BagsBar:GetParent(), env.UIParent, "and its bag bar")
	eq(ns.Menus.Content("bags"):IsShown(), false, "KstyleUI's bag bar stays hidden")
	CheckUntouched(env, before)
	noErrors(env, K)
end

-- The gamepad interface hides Blizzard's bars; KstyleUI's follow ---------------------------------------

do
	local env, K, ns = New()
	env.MainActionBar_InitializeGamepad()
	eq(ns.Menus.Content("micro"):IsShown(), false, "the micro menu hides with Blizzard's in gamepad mode")
	eq(ns.Menus.Content("bags"):IsShown(), false, "and the bag bar")
	env.MainActionBar_InitializeMKB()
	eq(ns.Menus.Content("micro"):IsShown(), true, "both return with mouse and keyboard")
	eq(ns.Menus.Content("bags"):IsShown(), true, "both")
	noErrors(env, K)
end

-- Vehicles and pet battles: Blizzard shows its own micro menu on its override bar, so KstyleUI's steps aside

do
	local env, K, ns = New()
	local vehicle = env.CreateFrame("Frame", "OverrideActionBar", env.UIParent)
	env.MicroMenu:SetParent(vehicle)
	env.UpdateMicroButtons()
	eq(ns.Menus.Content("micro"):IsShown(), false, "the micro menu hides while Blizzard shows its own on the vehicle bar")
	eq(ns.Menus.Content("bags"):IsShown(), true, "the bag bar stays")
	env.MicroMenu:SetParent(env.MicroMenuContainer)
	env.UpdateMicroButtons()
	eq(ns.Menus.Content("micro"):IsShown(), true, "and returns when Blizzard puts its menu back")
	noErrors(env, K)
end

-- Combat: protected changes wait for combat to end ------------------------------------------------------

do
	local env, K, ns = New()
	local frames = { ns.Menus.Holder("micro"), ns.Menus.Content("micro") }
	for _, button in ipairs(ns.Menus.All("micro")) do
		frames[#frames + 1] = button
	end
	for _, frame in ipairs(frames) do
		rawset(frame, "IsProtected", function()
			return true, true
		end)
	end
	local marks = {}
	for i, frame in ipairs(frames) do
		marks[i] = #frame._calls
	end
	env.SetCombat(true)
	env.HelpMicroButton:Show()
	env.UpdateMicroButtons()
	env.LFDMicroButton:Disable()
	env.UpdateMicroButtons()
	K.Options.Write("DataBars", "micro.size", 30)
	for i, frame in ipairs(frames) do
		for n = marks[i] + 1, #frame._calls do
			assert(not SECURE_CALLS[frame._calls[n].method], "a protected " .. frame._calls[n].method .. " in combat")
		end
	end
	eq(Button(ns, "micro", "LFDMicroButton").usable, false, "paint-only changes still apply in combat")
	assert(not Names(ns, "micro"):find("HelpMicroButton", 1, true), "Help waits for combat to end")
	env.SetCombat(false)
	assert(Names(ns, "micro"):find("HelpMicroButton", 1, true), "then shows")
	eq(Button(ns, "micro", "HelpMicroButton"):GetHeight(), 30, "with the new size")
	noErrors(env, K)
end

-- Tooltips -----------------------------------------------------------------------------------------------

do
	local env, K, ns = New()
	env.QuestLogMicroButton.tooltipText = "Quest Log (L)"
	local quest = Button(ns, "micro", "QuestLogMicroButton")
	W.Enter(quest)
	local tip = K.Widgets.Tooltip()
	assert(tip:IsOwned(quest), "a micro button shows a KstyleUI tooltip")
	eq((tip.used[1].left:GetText():gsub("\226\128\137", "")), "QUEST LOG (L)", "titled with Blizzard's own name and key, in the kit's tracked capitals")
	W.Leave(quest)
	local bag = Button(ns, "bags", "CharacterBag2Slot")
	W.Enter(bag)
	assert(tip:IsOwned(bag), "a bag button shows one too")
	eq((tip.used[1].left:GetText():gsub("\226\128\137", "")), "[BAG 33]", "with the bag's name, in the kit's tracked capitals")
	W.Leave(bag)
	noErrors(env, K)
end

-- A client without the micro menu or bag bar runs the module without errors ----------------------------

do
	local env, K, ns = D.New()
	env.RunTimers()
	eq(K.Modules.IsRunning("DataBars"), true, "no micro menu or bag bar, no problem")
	eq(#ns.Menus.Shown("micro"), 0, "and no micro buttons")
	noErrors(env, K)
end

print("databars menus ok")

-- The micro menu and bag bar are secondary icon buttons: their rims follow Widgets.SECONDARY_RIM, the one
-- number that tones them toward the plain hairline. The default keeps the full accent rim.
do
	local env, K, ns = New()
	local button = ns.Menus.Shown("micro")[2]
	local rr, rg, rb = K.Widgets.IconRim()
	assert(W.SameColor(button.chrome.inner[5], rr, rg, rb, 1), "at the default the micro menu's rim is the full accent rim, as the action buttons")
	K.Widgets.SECONDARY_RIM = 0.5
	button:Paint()
	local tr, tg, tb, ta = K.Widgets.IconRim(nil, nil, nil, 0.5)
	assert(W.SameColor(button.chrome.inner[5], tr, tg, tb, ta), "at half strength the micro menu's rim tones toward the plain hairline")
	local bag = ns.Menus.Shown("bags")[1]
	bag:Paint()
	assert(W.SameColor(bag.chrome.inner[5], tr, tg, tb, ta), "and so does the bag bar's")
	K.Widgets.SECONDARY_RIM = 1
	noErrors(env, K)
end
