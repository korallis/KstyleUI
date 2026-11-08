-- hud.lua: the HUD showcase, one module per stub environment, in the state the owner's mockup shows.
--
--   local Hud = dofile("Tools/render/scenes/hud.lua")
--   local scene = Hud.Build({ layout = "DPS" })            -- every module, merged in screen coordinates
--   local scene = Hud.Module("unitframes", { layout = "DPS" })
--
-- Every environment uses the same screen options, so each module's rects land where the game puts them.
-- The state: a level 38 orc warrior "Valerin" at 82% health with rage, casting Slam with 0.8 s left; a
-- hostile level 38 Riverglade Crocolisk at 56% health, casting; warrior icons on two bars, one on cooldown,
-- one proc, one pressed, one disabled; six essential and four utility cooldowns between the unit frames;
-- Battle Shout and Enrage as buff bars and five tracked buff icons; two quests; five chat lines under four
-- tabs; the minimap; the data strip; the experience bar; a nameplate on the target with the combat numbers;
-- a tooltip. opts.icons picks the custom icon set (A, B or off; RENDER_ICONS, then B, when absent), and
-- the portraits, the minimap's terrain and the backdrop come from Tools/render/standins.py when it has run.
local Common = dofile("Tools/render/scenes/_common.lua")
local Scene = Common.Scene

local Hud = {}

local PLAYER = { name = "Valerin", class = "WARRIOR", level = 38, health = 2750, healthMax = 3350, power = 45, powerMax = 100, powerType = 1, powerToken = "RAGE", isPlayer = true, reaction = 5 }
local TARGET = { name = "Riverglade Crocolisk", level = 38, health = 864, healthMax = 1540, power = 0, powerMax = 0, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true, classification = "normal" }

-- Warrior icons from Tools/data/abilities.json, by file ID.
Hud.ICONS = {
	heroicStrike = 132282, slam = 132340, charge = 132337, rend = 132155, thunderClap = 136105, battleShout = 132333,
	bloodrage = 132277, execute = 135358, overpower = 132223, hamstring = 132316, cleave = 132338, whirlwind = 132369,
	mortalStrike = 132355, shieldBlock = 132110, sunderArmor = 132363, taunt = 136080, demoralizingShout = 132366,
	berserkerRage = 136009, intercept = 132307, pummel = 132938, revenge = 132353, disarm = 132343, victoryRush = 132342,
	bloodFury = 135726, enrage = 136224, shieldBash = 132357, retaliation = 132336, sweepingStrikes = 132306,
}
local I = Hud.ICONS

-- The slots on bar 1 (page 1, slots 1 to 12) and bar 2 (page 6, slots 61 to 72), left to right.
Hud.BAR1 = { I.heroicStrike, I.slam, I.charge, I.rend, I.thunderClap, I.execute, I.overpower, I.hamstring, I.cleave, I.whirlwind, I.mortalStrike, nil }
Hud.BAR2 = { I.battleShout, I.bloodrage, I.demoralizingShout, I.sunderArmor, I.shieldBlock, I.taunt, I.berserkerRage, I.intercept, I.pummel, I.revenge, I.disarm, I.bloodFury }

-- saved(opts, module, settings, more) -> a KstyleUIDB with that module on, the Icons module on the
-- scene's set, and any further modules named in more on too.
local function saved(opts, module, settings, more)
	local section = { enabled = true }
	for k, v in pairs(settings or {}) do
		section[k] = v
	end
	local profile = { [module] = section, Icons = Common.IconsSection(Common.IconSet(opts)) }
	for _, name in ipairs(more or {}) do
		profile[name] = { enabled = true }
	end
	return {
		version = 2,
		profiles = { Default = profile },
		characters = {},
		layouts = {},
		account = { setupSeen = true },
		devlog = {},
	}
end

-- Shared(env) gives every environment the warrior's class colour, the owner's clock and the icon data
-- addons, which the Icons service loads on demand.
local function shared(env)
	Common.ForceScreen(env)
	Common.InstallAddOns(env)
	env.RAID_CLASS_COLORS = env.RAID_CLASS_COLORS or {}
	env.RAID_CLASS_COLORS.WARRIOR = { r = Common.WARRIOR[1], g = Common.WARRIOR[2], b = Common.WARRIOR[3] }
	env.UnitClass = function(unit)
		if unit == "player" or unit == nil then
			return "Warrior", "WARRIOR", 1
		end
	end
end

-- build(env, opts, extra) -> the scene, with icon IDs resolved for the scene's icon set.
local function build(env, opts, extra)
	local sceneOpts = { iconDirs = Common.IconDirs(Common.IconSet(opts)) }
	for k, v in pairs(extra or {}) do
		sceneOpts[k] = v
	end
	return Scene.Build(env, sceneOpts)
end

local function finish(env, K, scene, what)
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = what .. " error: " .. err
	end
	for i, line in ipairs(scene.log) do
		scene.log[i] = what .. ": " .. line
	end
	return scene
end

-- standIn(texture, name, r, g, b) paints a stand-in cut from the mockup on the texture, or a flat tone
-- when standins.py has not made it; returns the log line that says which.
local function standIn(texture, name, r, g, b, what)
	local file = Common.StandIn(name)
	if file then
		texture:SetTexture(file)
		return what .. " is a crop of the mockup (" .. file .. "); the game draws it itself"
	end
	texture:SetColorTexture(r, g, b, 1)
	return what .. " is a flat stand-in; run Tools/render/standins.py for the mockup's crop"
end

local modules = {}

-- Unit frames: player, target, both cast bars, the target of target, and the class resource ----------------

function modules.unitframes(opts)
	local U = dofile("Tools/regression/unitframes_env.lua")
	local player, target = {}, {}
	for k, v in pairs(PLAYER) do
		player[k] = v
	end
	for k, v in pairs(TARGET) do
		target[k] = v
	end
	player.cast = { name = "Slam", texture = I.slam, start = 9300, finish = 10800, spellID = 1464 }
	target.cast = { name = "Snap", texture = 132200, start = 9000, finish = 11500, spellID = 999 }
	-- Round portraits: the owner chose the mockup's round shape as the default on 2026-11-08.
	local env, K, ns = U.New(Common.ScreenOpts({
		saved = saved(opts, "UnitFrames", { player = { portraitShape = "round" }, target = { portraitShape = "round" } }),
		setup = function(env)
			shared(env)
			env._units.player = player
			env._units.target = target
			env.UnitClass = function(token)
				local u = env._units[token]
				if u and u.class then
					return u.class:sub(1, 1) .. u.class:sub(2):lower(), u.class, 1
				end
			end
		end,
	}))
	env._time = 10
	env.SetTarget(true)
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 1464)
	env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", 999)
	env.RunTimers()
	-- The cast bars fade in over a tween; run the frames with the clock held, so the bars read as mid-cast.
	for _ = 1, 40 do
		U.W.Tick(env, 0.05)
	end
	-- The stub draws no portraits: the mockup's faces, or a flat tone, stand in for the unit's model.
	local notes = {}
	for texture, token in pairs(env._portraits) do
		notes[#notes + 1] = standIn(texture, "portrait-" .. tostring(token) .. ".png", 0.33, 0.28, 0.22, "the " .. tostring(token) .. " portrait")
	end
	table.sort(notes)
	local scene = build(env, opts, { time = env._time })
	for _, note in ipairs(notes) do
		scene.log[#scene.log + 1] = note
	end
	return finish(env, K, scene, "unitframes"), ns
end

-- Action bars: bar 1 and bar 2 filled with warrior icons, one on cooldown, one proc, one pressed, one disabled.

function modules.actionbars(opts)
	local AB = dofile("Tools/regression/actionbars_env.lua")
	local env, K, ns = AB.New({
		class = "WARRIOR",
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		saved = saved(opts, "ActionBars"),
		setup = function(env)
			shared(env)
			local keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }
			local keys2 = { "Q", "W", "E", "R", "T", "Y", "V", "I", "O", "P", "L", "1" }
			for i = 1, 12 do
				env._game.bindings["ACTIONBUTTON" .. i] = { keys[i] }
				env._game.bindings["MULTIACTIONBAR1BUTTON" .. i] = { keys2[i] }
			end
			env.GetBindingText = function(key)
				return key
			end
		end,
	})
	env._time = 10
	env.GetTime = function()
		return env._time
	end
	AB.Enable(env, K)
	for i, icon in ipairs(Hud.BAR1) do
		if icon then
			env._game.slots[i] = { texture = icon, type = "spell", id = 1000 + i }
		end
	end
	for i, icon in ipairs(Hud.BAR2) do
		env._game.slots[60 + i] = { texture = icon, type = "spell", id = 2000 + i }
	end
	-- States: Charge on an 8 s cooldown with 4 s left, Overpower procs, Execute disabled, Slam pressed.
	env._game.slots[3].cooldown = { start = 6, finish = 14, remaining = 4, total = 8 }
	env._game.procs[1007] = true
	env._game.slots[6].usable = false
	env._game.slots[12] = nil
	for i = 1, 12 do
		env.FireEvent("ACTIONBAR_SLOT_CHANGED", i)
		env.FireEvent("ACTIONBAR_SLOT_CHANGED", 60 + i)
	end
	env.FireEvent("ACTIONBAR_UPDATE_COOLDOWN")
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 1007)
	env.FireEvent("ACTION_USABLE_CHANGED", { { slot = 6, usable = false, noMana = false } })
	local pressed = AB.Button(ns, "bar1", 2)
	AB.W.Down(pressed)
	-- The game runs a cooldown frame's OnShow when its swipe starts; the stub leaves that to the scene.
	local charging = AB.Button(ns, "bar1", 3)
	charging.cooldown:Show()
	charging.cooldown:GetScript("OnShow")(charging.cooldown)
	env.RunTimers()
	AB.W.Settle(env)
	local scene = build(env, opts, { time = env._time })
	return finish(env, K, scene, "actionbars"), ns
end

-- Cooldowns: the centre cluster (six essential, four utility), five tracked buff icons and two buff bars ----

-- Each entry: cooldown ID, spell ID, the icon, the name, and its state: a cooldown as { total, left } or a
-- buff as { total, left }, "proc" for the activation glow, nil when ready.
Hud.COOLDOWNS = {
	essential = {
		{ 501, 5001, "mortalStrike", "Mortal Strike", { 6, 4 } },
		{ 502, 5002, "whirlwind", "Whirlwind", { 10, 8 } },
		{ 503, 5003, "overpower", "Overpower", { 5, 3 } },
		{ 504, 5004, "execute", "Execute" },
		{ 505, 5005, "retaliation", "Retaliation", { 300, 118 } },
		{ 506, 5006, "sweepingStrikes", "Sweeping Strikes", "proc" },
	},
	utility = {
		{ 601, 6001, "intercept", "Intercept" },
		{ 602, 6002, "hamstring", "Hamstring" },
		{ 603, 6003, "pummel", "Pummel" },
		{ 604, 6004, "berserkerRage", "Berserker Rage" },
	},
	buffs = {
		{ 301, 3001, "bloodrage", "Bloodrage", { 30, 24 } },
		{ 302, 3002, "bloodFury", "Blood Fury", { 25, 17 } },
		{ 303, 3003, "victoryRush", "Victory Rush", { 20, 12 } },
		{ 304, 3004, "shieldBlock", "Shield Block", { 600, 480 } },
		{ 305, 3005, "demoralizingShout", "Demoralizing Shout", { 300, 180 } },
	},
	bars = {
		{ 401, 4001, "battleShout", "Battle Shout", { 120, 24 } },
		{ 402, 4002, "enrage", "Enrage", { 12, 12 } },
	},
}

function modules.cooldowns(opts)
	local C = dofile("Tools/regression/cooldowns_env.lua")
	local CAT = { essential = C.CATEGORY.Essential, utility = C.CATEGORY.Utility, buffs = C.CATEGORY.TrackedBuff, bars = C.CATEGORY.TrackedBar }
	local cooldowns, names, textures = {}, {}, {}
	for group, list in pairs(Hud.COOLDOWNS) do
		for _, entry in ipairs(list) do
			local id, spell, icon, name = entry[1], entry[2], entry[3], entry[4]
			local aura = group == "buffs" or group == "bars"
			cooldowns[id] = { spellID = spell, category = CAT[group], selfAura = aura, hasAura = aura }
			names[spell], textures[spell] = name, I[icon]
		end
	end
	local env, K, ns = C.New({
		saved = saved(opts, "Cooldowns", { path = "mirror" }),
		cooldowns = cooldowns,
		setup = function(env)
			shared(env)
			C.Game(env)
			Common.ForceScreen(env)
			env.C_Spell.GetSpellName = function(spell)
				return names[spell] or ("Spell " .. spell)
			end
			for spell, texture in pairs(textures) do
				env._cdm.textures[spell] = texture
			end
		end,
	})
	local cdm = env._cdm
	local now = 10
	env._time = now
	local instance = 80
	for group, list in pairs(Hud.COOLDOWNS) do
		for _, entry in ipairs(list) do
			local spell, state = entry[2], entry[5]
			if group == "buffs" or group == "bars" then
				instance = instance + 1
				cdm.auras[spell] = { auraInstanceID = instance }
				cdm.auraDurations[instance] = { kind = "aura", start = now - (state[1] - state[2]), finish = now + state[2], remaining = state[2], total = state[1] }
			elseif type(state) == "table" then
				cdm.cooldown[spell] = { active = true }
				cdm.durations[spell] = { kind = "cooldown", start = now - (state[1] - state[2]), finish = now + state[2] }
			elseif state == "proc" then
				cdm.overlay[spell] = true
			end
		end
	end
	C.Enable(env, K)
	env.FireEvent("PLAYER_ENTERING_WORLD", true, false)
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 5006)
	env.RunTimers()
	C.W.Settle(env)
	local scene = build(env, opts, { time = env._time })
	return finish(env, K, scene, "cooldowns"), ns
end


-- Chat: the glass panel with five lines in the general tab ---------------------------------------------------

local CHAT_LINES = {
	{ "CHAT_MSG_LOOT", "You receive loot: |cff1eff00|Hitem:4232::::::::38:::::|h[Crocolisk Hide]|h|r x2." },
	{ "CHAT_MSG_COMBAT_XP_GAIN", "You gain 168 experience." },
	{ "CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:4304::::::::38:::::|h[Rugged Hide]|h|r." },
	{ "CHAT_MSG_CHANNEL", "Anyone for croc hunt?", { sender = "Riverglades", channel = "1. General - Riverglades", guid = "Player-1-0001" } },
	{ "CHAT_MSG_CHANNEL", "LFM tank for Razorfen Kraul", { sender = "Thargor", channel = "1. General - Riverglades", guid = "Player-1-0002" } },
}

-- The docked windows, as the player named them in the mockup. Blizzard's dock lays their tabs along
-- the top of ChatFrame1: a 26-unit dock 3 units above the window, each tab 32 tall and as wide as its
-- text plus 20, one unit apart, the text centred 5 units below the tab's centre (FloatingChatFrame.xml
-- and PanelTemplates_TabResize). KstyleUI_Chat then skins each tab: upper case, the kit font, an accent
-- underline on the selected one.
local CHAT_TABS = { "General", "Combat", "Loot", "Trade" }
local TAB_HEIGHT, TAB_PADDING, TAB_GAP, TAB_TEXT_DROP = 32, 20, 1, 5
local DOCK_HEIGHT, DOCK_RISE = 26, 3

local function layoutTabs(env)
	local chat, dock = env.ChatFrame1, env.GENERAL_CHAT_DOCK
	dock:ClearAllPoints()
	dock:SetHeight(DOCK_HEIGHT)
	dock:SetPoint("BOTTOMLEFT", chat, "TOPLEFT", 0, DOCK_RISE)
	dock:SetPoint("BOTTOMRIGHT", chat, "TOPRIGHT", 0, DOCK_RISE)
	local previous
	for _, frame in ipairs(dock.DOCKED_CHAT_FRAMES) do
		local tab = env[frame:GetName() .. "Tab"]
		local text = tab.Text
		local fontPath, size = text:GetFont()
		local width = Scene.TextWidth(text:GetText() or "", size or 10, fontPath)
		text:ClearAllPoints()
		text:SetSize(width, 8)
		text:SetPoint("CENTER", tab, "CENTER", 0, -TAB_TEXT_DROP)
		tab:SetParent(dock)
		tab:SetSize(width + TAB_PADDING, TAB_HEIGHT)
		tab:ClearAllPoints()
		if previous then
			tab:SetPoint("LEFT", previous, "RIGHT", TAB_GAP, 0)
		else
			tab:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 0, 0)
		end
		tab:Show()
		previous = tab
	end
end

function modules.chat(opts)
	local C = dofile("Tools/regression/chat_env.lua")
	local env, K, ns = C.New({
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		saved = saved(opts, "Chat"),
		install = { frames = #CHAT_TABS },
		setup = function(env)
			shared(env)
			env._now = os.time({ year = 2026, month = 11, day = 7, hour = 14, min = 31, sec = 0 })
			local dock = env.GENERAL_CHAT_DOCK
			for i, name in ipairs(CHAT_TABS) do
				local frame = env["ChatFrame" .. i]
				env["ChatFrame" .. i .. "Tab"]:SetText(name)
				if not frame.isDocked then
					frame.isDocked = 1
					table.insert(dock.DOCKED_CHAT_FRAMES, frame)
				end
			end
		end,
	})
	if not K.Modules.IsRunning("Chat") then
		C.Enable(env, K)
	end
	layoutTabs(env)
	local chat = env.ChatFrame1
	local stamp = env._cvars.showTimestamps
	local function stamped(text)
		if type(stamp) == "string" and stamp ~= "none" then
			return os.date(stamp, env.time()) .. text
		end
		return text
	end
	for _, line in ipairs(CHAT_LINES) do
		if line[1] == "CHAT_MSG_CHANNEL" then
			env._now = env._now + 60
			C.Say(env, chat, line[1], line[2], line[3])
		else
			-- The game formats system lines itself; loot is green and experience is blue.
			local r, g, b = 0, 0.67, 0
			if line[1] == "CHAT_MSG_COMBAT_XP_GAIN" then
				r, g, b = 0.44, 0.44, 1
			end
			chat:AddMessage(stamped(line[2]), r, g, b, 7, 1, 1, line[1])
		end
	end
	env.RunTimers()
	C.W.Settle(env)
	-- The stub ScrollingMessageFrame keeps a history but draws nothing; the scene lays its lines out as the
	-- game does, newest at the bottom, wrapped to the window in its font, one font string per row.
	local path, size, flags = chat:GetFont()
	path, size, flags = path or "Fonts\\ARIALN.TTF", size or 14, flags or ""
	-- The window's width comes from its anchors in the panel, in its own units.
	local _, _, screenWidth, screenHeight = Scene.Rect(env, chat)
	local toOwn = 768 / 1080 / chat:GetEffectiveScale()
	local width = (screenWidth or 300 * 1080 / 768) * toOwn
	local height = (screenHeight or 120 * 1080 / 768) * toOwn
	local entries = C.Entries(chat)
	local lineHeight = size * 1.2
	local rows = {}
	for _, entry in ipairs(entries) do
		local line = tostring(entry[1])
		local plainWord = function(word)
			return (word:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", ""))
		end
		local row, rowWidth = "", 0
		for word in line:gmatch("%S+") do
			local w = Scene.TextWidth(plainWord(word) .. " ", size, path)
			if row ~= "" and rowWidth + w > width then
				rows[#rows + 1] = { row, entry }
				row, rowWidth = "", 0
			end
			row = row == "" and word or (row .. " " .. word)
			rowWidth = rowWidth + w
		end
		rows[#rows + 1] = { row, entry }
	end
	-- Rows that scroll past the window's top are not drawn, as the game clips them.
	local y = 0
	for i = #rows, 1, -1 do
		if y + lineHeight > height then
			break
		end
		local row, entry = rows[i][1], rows[i][2]
		local text = chat:CreateFontString(nil, "ARTWORK")
		text:SetFont(path, size, flags)
		text:SetJustifyH("LEFT")
		text:SetWordWrap(false)
		text:SetPoint("BOTTOMLEFT", chat, "BOTTOMLEFT", 0, y)
		text:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", 0, y)
		text:SetHeight(lineHeight)
		text:SetTextColor(entry[2] or 1, entry[3] or 1, entry[4] or 1)
		text:SetText(row)
		y = y + lineHeight
	end
	local scene = build(env, opts)
	scene.log[#scene.log + 1] = "chat lines are laid out by the scene; the game's ScrollingMessageFrame wraps and spaces them itself"
	scene.log[#scene.log + 1] = "chat tabs are laid out by the scene as Blizzard's dock lays them; the game fades them when the pointer is away"
	return finish(env, K, scene, "chat"), ns
end

-- Minimap: the square map with the zone strip, the clock and the button column ------------------------------

function modules.minimap(opts)
	local M = dofile("Tools/regression/minimap_env.lua")
	local env, K, ns = M.New({
		enabled = true,
		zone = "Riverglades",
		setup = function(env)
			shared(env)
			Common.ForceScreen(env)
			env._clock = { hour = 14, minute = 32, realmHour = 9, realmMinute = 5 }
		end,
	})
	M.Settle(env)
	-- The Minimap frame draws the world in the game; the mockup's map, or a flat tone, stands in.
	local map = env.Minimap:CreateTexture(nil, "BACKGROUND")
	map:SetAllPoints(env.Minimap)
	local note = standIn(map, "minimap.png", 0.22, 0.30, 0.20, "the minimap's terrain")
	local scene = build(env, opts)
	scene.log[#scene.log + 1] = note
	return finish(env, K, scene, "minimap"), ns
end

-- Data bars: the experience bar and the data strip ----------------------------------------------------------

function modules.databars(opts)
	local D = dofile("Tools/regression/databars_env.lua")
	local env, K, ns = D.New({
		saved = saved(opts, "DataBars"),
		-- No watched faction: the mockup shows no reputation bar under the action bars.
		game = { xp = 16000, xpMax = 50000, rested = 6000, level = 38, faction = false },
		setup = function(env)
			shared(env)
			Common.ForceScreen(env)
		end,
	})
	env.RunTimers()
	D.W.Settle(env)
	local scene = build(env, opts)
	return finish(env, K, scene, "databars"), ns
end

-- Auras: the player's buffs under the minimap, five with their time left -------------------------------------

-- The engine binds each button's icon and timer itself; the stub does not, so the scene fills the first
-- five buff buttons and lays them out as the container's flow layout would: from the top right, leftwards.
Hud.BUFFS = {
	{ "battleShout", "24s" },
	{ "berserkerRage", "17s" },
	{ "bloodrage", "12s" },
	{ "shieldBlock", "8m" },
	{ "bloodFury", "3m" },
}

function modules.auras(opts)
	local A = dofile("Tools/regression/auras_env.lua")
	local env, K, ns = A.New(Common.ScreenOpts({
		saved = saved(opts, "Auras"),
		setup = function(env)
			shared(env)
		end,
	}))
	if not K.Modules.IsRunning("Auras") then
		K.Modules.Enable("Auras")
	end
	env.RunTimers()
	local buffs, group = A.Container(env, "HELPFUL")
	if buffs then
		local layout = group.layout or {}
		local width, height, spacing = layout.elementWidth or 28, layout.elementHeight or 38, layout.elementSpacing or 6
		-- The engine sizes the container to its content; the stub leaves it unsized.
		buffs:SetSize(#Hud.BUFFS * width + (#Hud.BUFFS - 1) * spacing, height)
		for _, container in ipairs(env._containers) do
			for _, button in ipairs(A.Buttons(container)) do
				button:Hide()
			end
		end
		for i, buff in ipairs(Hud.BUFFS) do
			local button = group.frames[i]
			if button then
				local aura = button._aura
				button:ClearAllPoints()
				button:SetSize(width, height)
				button:SetPoint("TOPRIGHT", buffs, "TOPRIGHT", -(i - 1) * (width + spacing), 0)
				if aura.icon then
					aura.icon:SetTexture(I[buff[1]])
				end
				if aura.timer then
					aura.timer:SetText(buff[2])
				end
				button:Show()
			end
		end
	end
	A.W.Settle(env)
	local scene = build(env, opts)
	scene.log[#scene.log + 1] = "the buffs are laid out by the scene as the AuraContainer engine would; the game binds each icon and timer itself"
	return finish(env, K, scene, "auras"), ns
end

-- Quest tracker: Blizzard's objective tracker with two quests, wearing the Skins glass -------------------------

local QUESTS = {
	{ title = "Riverglade Crocolisks", objective = "- Crocolisk Hide 3/8" },
	{ title = "The Lost Patrol", objective = "- Speak to Ranger Kalanna 0/1" },
}

local function trackerStandIn(env, B)
	local tracker = B.frame("Frame", nil, "ObjectiveTrackerFrame")
	tracker.isCollapsed = false
	tracker:SetSize(235, 160)
	-- Edit Mode places Blizzard's tracker; the mockup puts it 16 units from the right edge, under the buffs.
	tracker:SetPoint("TOPRIGHT", env.UIParent, "TOPRIGHT", -16, -312)
	tracker.NineSlice = B.frame("Frame", tracker)
	tracker.NineSlice:SetPoint("TOPLEFT", tracker, "TOPLEFT")
	tracker.NineSlice:SetPoint("TOPRIGHT", tracker, "TOPRIGHT")
	tracker.Header = B.frame("Frame", tracker)
	tracker.Header:SetSize(235, 25)
	tracker.Header:SetPoint("TOPLEFT", tracker, "TOPLEFT", 0, 0)
	tracker.Header.Background = B.texture(tracker.Header, "BACKGROUND")
	tracker.Header.Background:SetAllPoints(tracker.Header)
	tracker.Header.Text = B.text(tracker.Header)
	tracker.Header.Text:SetFontObject("ObjectiveTrackerHeaderFont")
	tracker.Header.Text:SetPoint("LEFT", tracker.Header, "LEFT", 20, 0)
	tracker.Header.Text:SetText("Quests")
	tracker.Header.MinimizeButton = B.frame("Button", tracker.Header)
	tracker.Header.MinimizeButton:SetSize(16, 16)
	tracker.Header.MinimizeButton:SetPoint("LEFT", tracker.Header, "LEFT", 0, 0)
	tracker.Header.MinimizeButton.Art = B.texture(tracker.Header.MinimizeButton)
	tracker.Header.MinimizeButton.Art:SetAllPoints(tracker.Header.MinimizeButton)
	function tracker.Header.SetCollapsed() end
	local module = B.frame("Frame", tracker)
	module:SetPoint("TOPLEFT", tracker.Header, "BOTTOMLEFT", 0, 0)
	module:SetPoint("TOPRIGHT", tracker.Header, "BOTTOMRIGHT", 0, 0)
	module.Header = B.frame("Frame", module)
	module.Header:SetSize(235, 1)
	module.Header:SetPoint("TOPLEFT", module, "TOPLEFT")
	module.Header.Background = B.texture(module.Header, "BACKGROUND")
	module.Header.Background:SetAllPoints(module.Header)
	module.Header.Text = B.text(module.Header)
	module.Header.Text:SetPoint("LEFT", module.Header, "LEFT")
	module.Header.MinimizeButton = B.frame("Button", module.Header)
	module.Header.MinimizeButton:SetSize(1, 1)
	module.Header.MinimizeButton:SetPoint("LEFT", module.Header, "LEFT")
	module.Header.MinimizeButton.Art = B.texture(module.Header.MinimizeButton)
	module.Header.MinimizeButton.Art:SetAllPoints(module.Header.MinimizeButton)
	module.Header:Hide()
	function module.Header.SetCollapsed() end
	module.usedProgressBars, module.usedTimerBars = {}, {}
	local y = -4
	for _, quest in ipairs(QUESTS) do
		local block = B.frame("Frame", module)
		block:SetPoint("TOPLEFT", module, "TOPLEFT", 20, y)
		block:SetPoint("TOPRIGHT", module, "TOPRIGHT", 0, y)
		block:SetHeight(44)
		block.HeaderText = B.text(block)
		block.HeaderText:SetFontObject("ObjectiveTrackerHeaderFont")
		block.HeaderText:SetPoint("TOPLEFT", block, "TOPLEFT", 10, -2)
		block.HeaderText:SetJustifyH("LEFT")
		block.HeaderText:SetText(quest.title)
		local line = B.text(block)
		line:SetFontObject("ObjectiveTrackerLineFont")
		line:SetPoint("TOPLEFT", block.HeaderText, "BOTTOMLEFT", 2, -4)
		line:SetJustifyH("LEFT")
		line:SetText(quest.objective)
		y = y - 50
	end
	module.contentsHeight = -y
	module:SetHeight(-y)
	function module.GetContentsHeight(self)
		return self.contentsHeight
	end
	function module.GetProgressBar() end
	function module.GetTimerBar() end
	function tracker.ForEachModule(_, fn)
		fn(module)
	end
	function tracker.IsCollapsed(self)
		return self.isCollapsed
	end
	function tracker.UpdateHeaderPosition() end
	function tracker.Update(self)
		self.NineSlice:SetPoint("BOTTOM", module, "TOP", 0, -module.contentsHeight - 10)
		self:UpdateHeaderPosition()
	end
	function tracker.SetCollapsed(self, collapsed)
		self.isCollapsed = collapsed
		self:Update()
	end
	tracker:Update()
	env.GameFontHighlight = B.text(env.UIParent)
	env.GameFontHighlight:SetFont("Fonts\\ARIALN.TTF", 12, "")
	env.ObjectiveTrackerLineFont, env.ObjectiveTrackerHeaderFont = B.text(env.UIParent), B.text(env.UIParent)
	env.ObjectiveTrackerLineFont:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
	env.ObjectiveTrackerHeaderFont:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
	return tracker
end

function modules.tracker(opts)
	local S = dofile("Tools/regression/skins_env.lua")
	local tracker
	local env, K, ns = S.New({
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		saved = saved(opts, "Skins"),
		setup = function(env)
			shared(env)
		end,
		before = function(env)
			tracker = trackerStandIn(env, S.Blizzard(env))
		end,
	})
	if not K.Modules.IsRunning("Skins") then
		K.Modules.Enable("Skins")
	end
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	env.RunTimers()
	S.W.Settle(env)
	-- Blizzard's objective text is yellow for titles and white for lines, under the tracker's fonts.
	local scene = build(env, opts)
	scene.log[#scene.log + 1] = "the quest tracker's blocks are stand-ins the scene lays out; Blizzard's POI buttons are not drawn"
	return finish(env, K, scene, "tracker"), ns, tracker
end

-- Nameplate: the target's plate over the crocolisk, mid-cast, with the combat numbers -----------------------

-- The plate's base sits where the game puts it over the target: in screen units, 984 across and 396 down.
local PLATE_X, PLATE_Y = 984, 396
-- Blizzard's world numbers (the damage you deal) float above the target in DAMAGE_TEXT_FONT, which
-- KstyleUI_CombatText sets to the kit font; the game sizes them itself. A crit reads larger and gold.
local WORLD_NUMBERS = {
	{ "142", 26, { 1, 0.82, 0.2 }, 0, 72 },
	{ "87", 19, { 1, 1, 1 }, 18, 42 },
}

function modules.nameplates(opts)
	local N = dofile("Tools/regression/nameplates_env.lua")
	local CT = dofile("Tools/regression/combattext_env.lua")
	local Load = dofile("Tools/regression/load_files.lua")
	local env, K, ns = N.New({
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		login = false,
		saved = saved(opts, "Nameplates", nil, { "CombatText" }),
		setup = function(env)
			shared(env)
			-- The combat text stub labels its formatters; the scene wants the plain number.
			env.AbbreviateNumbers = function(n)
				return tostring(n)
			end
			env.BreakUpLargeNumbers = env.AbbreviateNumbers
			CT.Fakes(env)
			CT.CVars(env)
		end,
	})
	Load(CT.Files(), env)
	N.CoreEnv.Login(env)
	env.RunTimers()
	env.WorldFrame:SetPoint("TOPLEFT")
	env.WorldFrame:SetPoint("BOTTOMRIGHT")
	env._time = 10
	env._now = 10
	local base = N.Add(env, "nameplate1", { name = "Riverglade Crocolisk", health = 864, maxHealth = 1540, level = 38, reaction = 2, canAttack = true })
	local k = 768 / 1080
	base:ClearAllPoints()
	base:SetPoint("CENTER", env.WorldFrame, "BOTTOMLEFT", PLATE_X * k, (1080 - PLATE_Y) * k)
	N.Target(env, "nameplate1")
	N.Cast(env, "nameplate1", { name = "Snap", text = "Snap", texture = 132200, notInterruptible = false })
	for _ = 1, 20 do
		N.Tick(env, 0.05)
	end
	-- The heal on the player shows in KstyleUI's own field above the character; the numbers sit at
	-- the start of their travel, since the stub runs no animations.
	local combatText = K.Modules.IsRunning("CombatText")
	if combatText then
		CT.Hit(env, "player", "HEAL", "", 168, 2)
	end
	local font = env.DAMAGE_TEXT_FONT
	for _, number in ipairs(WORLD_NUMBERS) do
		local text = env.WorldFrame:CreateFontString(nil, "OVERLAY")
		if type(font) == "string" then
			text:SetFont(font, number[2], "OUTLINE")
		end
		text:SetTextColor(number[3][1], number[3][2], number[3][3])
		text:SetPoint("CENTER", base, "CENTER", number[4] * k, number[5] * k)
		text:SetText(number[1])
	end
	local scene = build(env, opts, { time = env._time })
	scene.log[#scene.log + 1] = "the world numbers over the target are stand-ins in DAMAGE_TEXT_FONT; the game draws and sizes them itself"
	if not combatText then
		scene.log[#scene.log + 1] = "error: CombatText did not start"
	end
	return finish(env, K, scene, "nameplates"), ns
end

-- Tooltip: an item tooltip at the tooltip anchor, wearing the Tooltips glass -----------------------------------

local ITEM_LINES = {
	{ "Vanquisher's Sword", nil, 0.12, 1, 0 },
	{ "Item Level 42", nil, 1, 0.82, 0 },
	{ "Binds when equipped", nil, 1, 1, 1 },
	{ "Two-Hand", "Sword", 1, 1, 1 },
	{ "142 - 198 Damage", "Speed 3.40", 1, 1, 1 },
	{ "(50.0 damage per second)", nil, 1, 1, 1 },
	{ "+24 Strength", nil, 1, 1, 1 },
	{ "+18 Stamina", nil, 1, 1, 1 },
	{ "Durability 96 / 100", nil, 1, 1, 1 },
	{ "Requires Level 38", nil, 1, 1, 1 },
	{ "Sell Price: 1g 42s 17c", nil, 1, 1, 1 },
}

function modules.tooltips(opts)
	local T = dofile("Tools/regression/tooltips_env.lua")
	local env, K, ns = T.New({
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		saved = saved(opts, "Tooltips"),
		setup = function(env)
			shared(env)
		end,
	})
	if not K.Modules.IsRunning("Tooltips") then
		K.Modules.Enable("Tooltips")
	end
	env.RunTimers()
	local tip = env.GameTooltip
	env._items[4232] = { quality = 2, icon = 135349 }
	env.GameTooltip_SetDefaultAnchor(tip, env.UIParent)
	for _, line in ipairs(ITEM_LINES) do
		if line[2] then
			tip:AddDoubleLine(line[1], line[2], line[3], line[4], line[5], 1, 1, 1)
		else
			tip:AddLine(line[1], line[3], line[4], line[5])
		end
	end
	-- Blizzard sizes its tooltip to its lines and its padding; the stand-in leaves that to the scene: 10-unit
	-- margins, 2 between lines, and the skin's padding (right, bottom, left, top) pushes the text inward.
	T.BlizzardShow(tip, true)
	T.PostCall(env, tip, { type = env.Enum.TooltipDataType.Item, id = 4232 })
	local padding = tip._state.Padding or { 0, 0, 0, 0 }
	local padRight, padBottom, padLeft, padTop = padding[1] or 0, padding[2] or 0, padding[3] or 0, padding[4] or 0
	local pad, gap = 10, 2
	local y = -pad - padTop
	local width = 0
	for i = 1, tip:NumLines() do
		local left, right = tip:GetLeftLine(i), tip:GetRightLine(i)
		local fontPath, size = left:GetFont()
		size = size or 12
		local height = size * 1.2
		left:ClearAllPoints()
		left:SetPoint("TOPLEFT", tip, "TOPLEFT", pad + padLeft, y)
		local chars = Scene.TextWidth(left:GetText() or "", size, fontPath)
		if right:IsShown() then
			right:ClearAllPoints()
			right:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -pad - padRight, y)
			chars = chars + Scene.TextWidth(right:GetText() or "", size, fontPath) + 4 * size
		end
		width = math.max(width, chars)
		y = y - height - gap
	end
	tip:SetSize(math.max(180, width + pad * 2 + padLeft + padRight), -y + pad - gap + padBottom)
	env.RunTimers()
	T.W.Settle(env)
	local scene = build(env, opts)
	scene.log[#scene.log + 1] = "the tooltip's lines are laid out by the scene; the game's GameTooltip sizes and places its own text"
	return finish(env, K, scene, "tooltips"), ns
end

Hud.modules = modules

-- Order(opts) -> the module names a HUD draws, in draw order.
function Hud.Order()
	return { "nameplates", "chat", "minimap", "auras", "databars", "tracker", "unitframes", "actionbars", "cooldowns", "tooltips" }
end

function Hud.Module(name, opts)
	local builder = modules[name]
	if not builder then
		error("no HUD module " .. tostring(name))
	end
	return builder(opts or {})
end

function Hud.Build(opts)
	opts = opts or {}
	local scenes = {}
	for _, name in ipairs(opts.modules or Hud.Order()) do
		scenes[#scenes + 1] = (Hud.Module(name, opts))
	end
	local merged = Scene.Merge(scenes)
	local set = Common.IconSet(opts)
	merged.log[#merged.log + 1] = "icons: " .. (set and ("custom set " .. set) or "Blizzard's, with the sets standing in for icons the folder lacks")
	return merged
end

return Hud
