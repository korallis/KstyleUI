-- hud.lua: the HUD showcase, one module per stub environment, in the state the owner's mockup shows.
--
--   local Hud = dofile("Tools/render/scenes/hud.lua")
--   local scene = Hud.Build({ layout = "DPS" })            -- every module, merged in screen coordinates
--   local scene = Hud.Module("unitframes", { layout = "DPS" })
--
-- Every environment uses the same screen options, so each module's rects land where the game puts them.
-- The state: a level 38 character at 82% health, mid-cast with 0.8 s left; a hostile level 38 Riverglade
-- Crocolisk at 56% health, casting; the class's icons on two bars, one on cooldown, one proc, one pressed, one
-- disabled; six essential and four utility cooldowns between the unit frames; two buff bars and five tracked
-- buff icons; two quests; five chat lines under four tabs; the minimap; the data strip; the experience bar; a
-- nameplate on the target with the combat numbers; a tooltip. opts.class picks the class (RENDER_CLASS, then the
-- mockup's orc warrior, when absent): _classes.lua holds what varies, and the class colour, the power type, the
-- cast, the spells, the buffs, the stance bar, the pet frame and the pet bar follow from the addon's own code
-- paths. Icons draw as the installed icon pack shows them (Common.IconDirs), and the portraits, the minimap's
-- terrain and the backdrop come from Tools/render/standins.py when it has run.
local Common = dofile("Tools/render/scenes/_common.lua")
local Scene = Common.Scene
local Tooltip = dofile("Tools/render/scenes/tooltip.lua")
local Classes = dofile("Tools/render/scenes/_classes.lua")

local Hud = {}
Hud.Classes = Classes

-- Class(opts) -> the scene's class token and its _classes.lua entry.
function Hud.Class(opts)
	return Classes.Get(opts and opts.class)
end

local TARGET = { name = "Riverglade Crocolisk", level = 38, health = 864, healthMax = 1540, power = 0, powerMax = 0, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true, classification = "normal" }

-- Player(opts) -> the player unit for the scene's class, as unitframes_env takes it.
function Hud.Player(opts)
	local class, spec = Hud.Class(opts)
	return {
		name = spec.name, class = class, level = 38, health = 2750, healthMax = 3350,
		power = spec.power.value, powerMax = spec.power.max, powerType = spec.power.type, powerToken = spec.power.token,
		isPlayer = true, reaction = 5,
	}
end

-- Slots(list) -> the icons of a bar's spells by slot, left to right (a short list leaves the last slots empty).
local function slots(list)
	local out = {}
	for i, spell in ipairs(list) do
		out[i] = spell[2]
	end
	return out
end

-- The warrior's icons by camel-cased spell name (Hud.ICONS.mortalStrike), and its two bars by slot, for the
-- gallery, component and button scenes, which draw the mockup's warrior whatever class the HUD renders.
Hud.ICONS = { shieldBash = 132357 }
do
	local function key(name)
		local words = {}
		for word in name:gmatch("%a+") do
			words[#words + 1] = #words == 0 and word:lower() or (word:sub(1, 1):upper() .. word:sub(2):lower())
		end
		return table.concat(words)
	end
	local W = Classes.WARRIOR
	for _, list in ipairs({ W.bar1, W.bar2, W.essential, W.utility, W.buffs, W.bars, W.buffRow, W.forms }) do
		for _, spell in ipairs(list) do
			Hud.ICONS[key(spell[1])] = spell[2]
		end
	end
end
Hud.BAR1, Hud.BAR2 = slots(Classes.WARRIOR.bar1), slots(Classes.WARRIOR.bar2)

-- saved(opts, module, settings, more) -> a KstyleUIDB with that module on, and any further modules named in
-- more on too.
local function saved(opts, module, settings, more)
	local section = { enabled = true }
	for k, v in pairs(settings or {}) do
		section[k] = v
	end
	local profile = { [module] = section }
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

-- Shared(env, opts) gives every environment the game's class colours (RAID_CLASS_COLORS, which Theme reads for
-- the accent), the scene's class as UnitClass("player") gives it, and the owner's screen.
local function shared(env, opts)
	Common.ForceScreen(env)
	local class, spec = Hud.Class(opts)
	env.RAID_CLASS_COLORS = env.RAID_CLASS_COLORS or {}
	for _, name in ipairs(Classes.ORDER) do
		local c = Classes[name].colour
		env.RAID_CLASS_COLORS[name] = { r = c[1], g = c[2], b = c[3] }
	end
	env.UnitClass = function(unit)
		if unit == "player" or unit == nil then
			return spec.title, class, 1
		end
	end
end

-- build(env, opts, extra) -> the scene, with icon IDs resolved as the installed pack shows them.
local function build(env, opts, extra)
	local sceneOpts = { iconDirs = Common.IconDirs() }
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

-- Unit frames: player, target, both cast bars, the target of target, the pet and the class resource ----------

-- The player's cast ends 0.8 s from the scene's clock (10 s), as the mockup's Slam does; each class's cast
-- started its own cast time earlier.
local CAST_END = 10800

function modules.unitframes(opts)
	local U = dofile("Tools/regression/unitframes_env.lua")
	local class, spec = Hud.Class(opts)
	local player, target = Hud.Player(opts), {}
	for k, v in pairs(TARGET) do
		target[k] = v
	end
	if spec.cast then
		player.cast = { name = spec.cast[1], texture = spec.cast[2], start = CAST_END - spec.cast[4] * 1000, finish = CAST_END, spellID = spec.cast[3] }
	end
	target.cast = { name = "Snap", texture = 132200, start = 9000, finish = 11500, spellID = 999 }
	local pet
	if spec.pet then
		pet = { name = spec.pet.name, level = spec.pet.level, health = spec.pet.health, healthMax = spec.pet.healthMax, power = spec.pet.power, powerMax = spec.pet.powerMax, powerType = spec.pet.powerType, powerToken = spec.pet.powerToken, reaction = 5 }
	end
	-- Round portraits: the owner chose the mockup's round shape as the default on 2026-11-08.
	local env, K, ns = U.New(Common.ScreenOpts({
		saved = saved(opts, "UnitFrames", { player = { portraitShape = "round" }, target = { portraitShape = "round" } }),
		setup = function(env)
			shared(env, opts)
			env._units.player = player
			env._units.target = target
			env._units.pet = pet
			env._comboPoints = spec.combo or 0
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
	if player.cast then
		env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", player.cast.spellID)
	end
	env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", 999)
	env.RunTimers()
	-- The cast bars fade in over a tween; run the frames with the clock held, so the bars read as mid-cast.
	for _ = 1, 40 do
		U.W.Tick(env, 0.05)
	end
	-- The stub draws no portraits: the class's portrait (standins.py copies scenery/portraits/<class>.png), the
	-- mockup's faces, or a flat tone, stand in for the unit's model.
	local notes = {}
	for texture, token in pairs(env._portraits) do
		local name = "portrait-" .. tostring(token) .. ".png"
		if token == "player" and Common.StandIn("portrait-player-" .. class:lower() .. ".png") then
			name = "portrait-player-" .. class:lower() .. ".png"
		end
		notes[#notes + 1] = standIn(texture, name, 0.33, 0.28, 0.22, "the " .. tostring(token) .. " portrait")
	end
	table.sort(notes)
	local scene = build(env, opts, { time = env._time })
	for _, note in ipairs(notes) do
		scene.log[#scene.log + 1] = note
	end
	return finish(env, K, scene, "unitframes"), ns
end

-- Action bars: bar 1 and bar 2 filled with the class's icons, one on cooldown, one proc, one pressed, one
-- disabled; the stance bar when the class has forms; the pet bar when it has a pet.

function modules.actionbars(opts)
	local AB = dofile("Tools/regression/actionbars_env.lua")
	local class, spec = Hud.Class(opts)
	local bar1, bar2 = slots(spec.bar1), slots(spec.bar2)
	local env, K, ns = AB.New({
		class = class,
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		saved = saved(opts, "ActionBars"),
		setup = function(env)
			shared(env, opts)
			local keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }
			local keys2 = { "Q", "W", "E", "R", "T", "Y", "V", "I", "O", "P", "L", "1" }
			for i = 1, 12 do
				env._game.bindings["ACTIONBUTTON" .. i] = { keys[i] }
				env._game.bindings["MULTIACTIONBAR1BUTTON" .. i] = { keys2[i] }
			end
			env.GetBindingText = function(key)
				return key
			end
			-- The game lists the class's forms (GetNumShapeshiftForms); the bar shows one button per form.
			for i, form in ipairs(spec.forms or {}) do
				env._game.forms[i] = { texture = form[2], isActive = form[3] == true, spellID = 7000 + i }
			end
			-- A pet's actions fill the pet bar, which the [@pet,exists] driver shows.
			if spec.pet then
				env._game.petExists = true
				for i, action in ipairs(spec.pet.actions) do
					env._game.pet[i] = { name = action[1], texture = action[2], spellID = 8000 + i, autoCastAllowed = true, autoCastEnabled = i <= 2 }
				end
			end
		end,
	})
	env._time = 10
	env.GetTime = function()
		return env._time
	end
	AB.Enable(env, K)
	for i = 1, 12 do
		if bar1[i] then
			env._game.slots[i] = { texture = bar1[i], type = "spell", id = 1000 + i }
		end
		if bar2[i] then
			env._game.slots[60 + i] = { texture = bar2[i], type = "spell", id = 2000 + i }
		end
	end
	-- States: slot 3 on an 8 s cooldown with 4 s left, slot 7 procs, slot 6 disabled, slot 2 pressed (for the
	-- warrior: Charge, Overpower, Execute and Slam).
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

-- The class's groups in _classes.lua (essential, utility, buffs, bars) become Cooldown Manager entries: group
-- g's entry i is cooldown ID BASE[g] + i with spell ID BASE[g] * 10 + i; its state is a cooldown or a buff as
-- { total, left }, "proc" for the activation glow, nil when ready.
local COOLDOWN_BASE = { essential = 500, utility = 600, buffs = 300, bars = 400 }
local COOLDOWN_GROUPS = { "essential", "utility", "buffs", "bars" }

-- Cooldowns(spec) -> the class's entries as { group, id, spell, icon, name, state }, in group order.
function Hud.Cooldowns(spec)
	local out = {}
	for _, group in ipairs(COOLDOWN_GROUPS) do
		for i, entry in ipairs(spec[group]) do
			out[#out + 1] = { group = group, id = COOLDOWN_BASE[group] + i, spell = COOLDOWN_BASE[group] * 10 + i, icon = entry[2], name = entry[1], state = entry[3] }
		end
	end
	return out
end

function modules.cooldowns(opts)
	local C = dofile("Tools/regression/cooldowns_env.lua")
	local _, spec = Hud.Class(opts)
	local entries = Hud.Cooldowns(spec)
	local CAT = { essential = C.CATEGORY.Essential, utility = C.CATEGORY.Utility, buffs = C.CATEGORY.TrackedBuff, bars = C.CATEGORY.TrackedBar }
	local cooldowns, names, textures, procs = {}, {}, {}, {}
	for _, entry in ipairs(entries) do
		local aura = entry.group == "buffs" or entry.group == "bars"
		cooldowns[entry.id] = { spellID = entry.spell, category = CAT[entry.group], selfAura = aura, hasAura = aura }
		names[entry.spell], textures[entry.spell] = entry.name, entry.icon
		if entry.state == "proc" then
			procs[#procs + 1] = entry.spell
		end
	end
	local env, K, ns = C.New({
		saved = saved(opts, "Cooldowns", { path = "mirror" }),
		cooldowns = cooldowns,
		setup = function(env)
			shared(env, opts)
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
	for _, entry in ipairs(entries) do
		local spell, state = entry.spell, entry.state
		if entry.group == "buffs" or entry.group == "bars" then
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
	C.Enable(env, K)
	env.FireEvent("PLAYER_ENTERING_WORLD", true, false)
	for _, spell in ipairs(procs) do
		env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", spell)
	end
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

-- The docked windows, as the player named them in the mockup. C.Dock lays their tabs out as FCFDock_UpdateTabs
-- does; KstyleUI_Chat then skins each tab: upper case, the kit font, an accent underline on the selected one.
local CHAT_TABS = { "General", "Combat", "Loot", "Trade" }

function modules.chat(opts)
	local C = dofile("Tools/regression/chat_env.lua")
	local env, K, ns = C.New({
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		saved = saved(opts, "Chat"),
		install = { frames = #CHAT_TABS },
		setup = function(env)
			shared(env, opts)
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
	C.Dock(env, Scene.TextWidth)
	env.RunTimers()
	C.W.Settle(env)
	-- The stub ScrollingMessageFrame keeps a history but draws nothing; the scene lays its lines out as the
	-- game does, newest at the bottom, wrapped to the window in its font, one font string per row, pitched
	-- by the font and the window's spacing.
	local path, size, flags = chat:GetFont()
	path, size, flags = path or "Fonts\\ARIALN.TTF", size or 14, flags or ""
	-- The window's width comes from its anchors in the panel, in its own units.
	local _, _, screenWidth, screenHeight = Scene.Rect(env, chat)
	local toOwn = 768 / 1080 / chat:GetEffectiveScale()
	local width = (screenWidth or 300 * 1080 / 768) * toOwn
	local height = (screenHeight or 120 * 1080 / 768) * toOwn
	local entries = C.Entries(chat)
	local spacing = chat:GetSpacing()
	local lineHeight = size * 1.2 + (type(spacing) == "number" and spacing or 0)
	local rows = {}
	for _, entry in ipairs(entries) do
		local line = tostring(entry[1])
		local plainWord = function(word)
			return (word:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", ""))
		end
		local row, rowWidth = "", 0
		local space = Scene.TextWidth(" ", size, path)
		for word in line:gmatch("%S+") do
			local w = Scene.TextWidth(plainWord(word), size, path)
			if row ~= "" and rowWidth + space + w > width then
				rows[#rows + 1] = { row, entry }
				row, rowWidth = "", 0
			end
			row = row == "" and word or (row .. " " .. word)
			rowWidth = rowWidth + (rowWidth > 0 and space or 0) + w
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
			shared(env, opts)
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
			shared(env, opts)
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
-- five buff buttons with the class's buff row (_classes.lua) and lays them out as the container's flow layout
-- would: from the top left, rightwards, the shortest time left first, the container centred under the map as
-- the module anchors it.

function modules.auras(opts)
	local A = dofile("Tools/regression/auras_env.lua")
	local _, spec = Hud.Class(opts)
	local row = spec.buffRow
	local env, K, ns = A.New(Common.ScreenOpts({
		saved = saved(opts, "Auras"),
		setup = function(env)
			shared(env, opts)
		end,
	}))
	if not K.Modules.IsRunning("Auras") then
		K.Modules.Enable("Auras")
	end
	env.RunTimers()
	local buffs, group = A.Container(env, "HELPFUL")
	if buffs then
		local layout = group.layout or {}
		local width, height, spacing = layout.elementWidth or 38, layout.elementHeight or 51, layout.elementSpacing or 8
		-- The engine sizes the container to its content; the stub leaves it unsized.
		buffs:SetSize(#row * width + (#row - 1) * spacing, height)
		for _, container in ipairs(env._containers) do
			for _, button in ipairs(A.Buttons(container)) do
				button:Hide()
			end
		end
		for i, buff in ipairs(row) do
			local button = group.frames[i]
			if button then
				local aura = button._aura
				button:ClearAllPoints()
				button:SetSize(width, height)
				button:SetPoint("TOPLEFT", buffs, "TOPLEFT", (i - 1) * (width + spacing), 0)
				if aura.icon then
					aura.icon:SetTexture(env.Secret(buff[2]))
				end
				if aura.timer then
					aura.timer:SetText(buff[3])
				end
				button:Show()
			end
		end
	end
	A.W.Settle(env)
	local scene = build(env, opts)
	scene.log[#scene.log + 1] = "the buffs are laid out by the scene as the AuraContainer engine would; the game binds each icon (as a secret, so the tiles show Blizzard's art) and timer itself"
	return finish(env, K, scene, "auras"), ns
end

-- Quest tracker: Blizzard's objective tracker with two quests, wearing the Skins glass -------------------------

local Tracker = dofile("Tools/render/scenes/_tracker.lua")

function modules.tracker(opts)
	local S = dofile("Tools/regression/skins_env.lua")
	local tracker
	local env, K, ns = S.New({
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		saved = saved(opts, "Skins"),
		setup = function(env)
			shared(env, opts)
		end,
		before = function(env)
			tracker = Tracker.StandIn(env, S.Blizzard(env), Tracker.QUESTS)
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
	scene.log[#scene.log + 1] = "the quest tracker is a stand-in laid out as Blizzard_ObjectiveTracker does; Edit Mode places the real one"
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
			shared(env, opts)
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
			shared(env, opts)
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
	-- Blizzard sizes its tooltip to its lines and its padding; the stand-in leaves that to tooltip.lua's layout.
	T.BlizzardShow(tip, true)
	T.PostCall(env, tip, { type = env.Enum.TooltipDataType.Item, id = 4232 })
	Tooltip.Layout(env, tip)
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
	local class, spec = Hud.Class(opts)
	-- The class the scene drew, for Tools/render/classes.py's manifest.
	merged.class = { class = class, title = spec.title, name = spec.name, colour = { spec.colour[1], spec.colour[2], spec.colour[3] }, power = spec.power.token, cast = spec.cast and spec.cast[1] or nil }
	merged.log[#merged.log + 1] = "class: " .. class .. " (" .. spec.name .. ", " .. spec.power.token:lower() .. ", " .. (spec.cast and ("casting " .. spec.cast[1]) or "no cast") .. ")"
	merged.log[#merged.log + 1] = "icons: set B's repaint for every file ID the pack has, else Blizzard's icon, as the installed pack shows them"
	return merged
end

return Hud
