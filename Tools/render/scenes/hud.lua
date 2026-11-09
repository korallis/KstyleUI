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
-- Hud.envs[scene] -> the environment a module scene was built in, for scenes that measure frames after the build.
Hud.envs = setmetatable({}, { __mode = "k" })

-- Class(opts) -> the scene's class token and its _classes.lua entry.
function Hud.Class(opts)
	return Classes.Get(opts and opts.class)
end

local TARGET = { name = "Riverglade Crocolisk", level = 38, health = 864, healthMax = 1540, power = 0, powerMax = 0, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true, classification = "normal", creature = "Beast" }

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
local function merge(into, from)
	for k, v in pairs(from or {}) do
		if type(v) == "table" and type(into[k]) == "table" then
			merge(into[k], v)
		elseif type(v) == "table" then
			into[k] = merge({}, v)
		else
			into[k] = v
		end
	end
	return into
end

local function saved(opts, module, settings, more)
	local section = { enabled = true }
	merge(section, opts.settings and opts.settings[module])
	merge(section, settings)
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
Hud.Saved = saved

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

local function tick(env, seconds)
	for _ = 1, math.floor(seconds / 0.016 + 0.5) do
		for _, frame in ipairs(env._frames) do
			local update = frame:GetScript("OnUpdate")
			if update then
				update(frame, 0.016)
			end
		end
	end
end
Hud.Tick = tick

-- build(env, opts, extra) -> the scene, with icon IDs resolved as the installed pack shows them. opts.sizes
-- ({ [key] = { w, h } }) resizes a free-sized element as Layout > Apply does for the layout (the Tank meters).
-- With opts.combat the environment enters combat first and runs half a second, so the combat calm has faded the
-- slow cards.
local function build(env, opts, extra)
	local K = env.KstyleUI
	local previewed = {}
	for key, size in pairs(opts.sizes or {}) do
		local el = K and K.Layout and K.Layout.Element and K.Layout.Element(key)
		if el and el.opts.resizable and not el.opts.aspect then
			K.Layout.Update(key, { width = size[1], height = size[2] })
			env.RunTimers()
			previewed[#previewed + 1] = key .. " at " .. size[1] .. " by " .. size[2]
		end
	end
	table.sort(previewed)
	if opts.combat and type(env.SetCombat) == "function" and not env._combat then
		env.SetCombat(true)
		env.RunTimers()
		tick(env, 0.5)
	end
	local sceneOpts = { iconDirs = Common.IconDirs() }
	for k, v in pairs(extra or {}) do
		sceneOpts[k] = v
	end
	local scene = Scene.Build(env, sceneOpts)
	for _, line in ipairs(previewed) do
		scene.log[#scene.log + 1] = "sizes " .. line .. ", as Layout > Apply writes it for the layout"
	end
	return scene
end

local function finish(env, K, scene, what)
	Hud.envs[scene] = env
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

-- Terrain(env) -> the minimap's terrain stand-in on env.Minimap and the log line that says which. The game
-- clips the Minimap frame to the mask the module set with Minimap:SetMaskTexture; the stub records that call,
-- and the stand-in draws through the same file anchored over the frame, so the render shows the clip at the
-- frame's cut corners as the game makes it.
function Hud.Terrain(env)
	local minimap = env.Minimap
	local map = minimap:CreateTexture(nil, "BACKGROUND")
	map:SetAllPoints(minimap)
	local note = standIn(map, "minimap.png", 0.22, 0.30, 0.20, "the minimap's terrain")
	local set = minimap._state and minimap._state.MaskTexture
	local path = set and set[1]
	if type(path) == "string" then
		local mask = minimap:CreateMaskTexture()
		mask:SetTexture(path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetAllPoints(minimap)
		map:AddMaskTexture(mask)
		note = note .. "; it draws through the module's mask (" .. path .. "), as the game clips the Minimap frame"
	else
		note = note .. "; the module set no mask, so it draws square"
	end
	return map, note
end

-- PlaceAuras(container, group, buttons, columns) lays aura buttons out as the AuraContainer engine's flow layout
-- would, from the corner the container grows from (its flow anchor), along its growth directions, wrapping after
-- the group's columns, and sizes the container to the rows it holds. The fake engine lays out no buttons.
function Hud.PlaceAuras(container, group, buttons, columns)
	local layout = group.layout or {}
	local width, height, spacing = layout.elementWidth or 38, layout.elementHeight or 51, layout.elementSpacing or 8
	local flow = container._flow or {}
	local corner, dx, dy = flow.anchor or "TOPLEFT", flow.horizontal or 1, flow.vertical or -1
	local rows = math.ceil(#buttons / columns)
	local across = math.min(#buttons, columns)
	container:SetSize(math.max(0, across * width + (across - 1) * spacing), rows * height)
	for i, button in ipairs(buttons) do
		local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
		button:ClearAllPoints()
		button:SetSize(width, height)
		button:SetPoint(corner, container, corner, dx * col * (width + spacing), dy * row * height)
		button:Show()
	end
end

-- PlateCasts(env, K, ns, class) readies the player's interrupt for the scene's class and stands in for the target
-- sigil's cast settings, so the plates read them as they would beside KstyleUI_UnitFrames.
function Hud.PlateCasts(env, K, ns, class)
	for _, id in ipairs(ns.Logic.INTERRUPTS[class] or {}) do
		env._known[id] = true
	end
	env._playerClass = class
	ns.Interrupt.Resolve()
	if not K.Modules.IsRunning("UnitFrames") then
		K.Modules.Register({ name = "UnitFrames", defaults = { target = { enabled = true, castbar = true } }, Enable = function() end, Disable = function() end })
		K.Modules.Enable("UnitFrames")
	end
end

-- FillCast(plate, share) fills a running plate cast bar to share of its length: the engine fills it from the cast's
-- duration object, which the stub does not run.
function Hud.FillCast(plate, share)
	if plate.casting then
		plate.castBar:SetBarRange(0, 1)
		plate.castBar:SetValue(share)
	end
end

local modules = {}

-- Unit frames: player, target, both cast bars, the target of target, the pet and the class resource ----------

-- The player's cast ends 0.8 s from the scene's clock (10 s), as the mockup's Slam does; each class's cast
-- started its own cast time earlier.
local CAST_END = 10800

-- The boss's debuffs as sockets under the sigil, as the mockup's combat board draws them: the fake engine's buttons
-- placed where the AuraContainer would, centred, with their timers.
local SIGIL_DEBUFFS = { { 132155, "18s" }, { 132363, "9s", "3" }, { 132316, "4s" } }

local function sigilSockets(env, K, ns, view)
	local a = view.auras
	local group = a and a.container and a.container._groups and a.container._groups.debuffs
	if not (group and group.buttons) then
		return "the sigil's debuff sockets: no aura engine stand-in"
	end
	local Widgets = K.Widgets
	local size, spacing = Widgets.Snap(a.host, ns.Settings.Value("target", "auraSize")), Widgets.Snap(a.host, ns.Settings.Value("target", "auraSpacing"))
	local count = math.min(#group.buttons, #SIGIL_DEBUFFS)
	a.container:SetSize(count * size + (count - 1) * spacing, size)
	for i = 1, count do
		local button = group.buttons[i]
		for _, entry in ipairs(a.buttons) do
			if entry.button == button then
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", a.container, "TOPLEFT", (i - 1) * (size + spacing), 0)
				button:SetSize(size, size)
				entry.icon:SetTexture(env.Secret(SIGIL_DEBUFFS[i][1]))
				Widgets.SetText(entry.timer, SIGIL_DEBUFFS[i][2])
				Widgets.SetText(entry.count, SIGIL_DEBUFFS[i][3] or "")
			end
		end
	end
	return "the sigil's debuff sockets: " .. count .. " of yours on the boss"
end

function modules.unitframes(opts)
	local U = dofile("Tools/regression/unitframes_env.lua")
	local class, spec = Hud.Class(opts)
	local player, target = Hud.Player(opts), {}
	for k, v in pairs(TARGET) do
		target[k] = v
	end
	-- opts.playerCast == false: the player casts nothing (the questing HUD is out of combat; round 6, Opus).
	if spec.cast and opts.playerCast ~= false then
		player.cast = { name = spec.cast[1], texture = spec.cast[2], start = CAST_END - spec.cast[4] * 1000, finish = CAST_END, spellID = spec.cast[3] }
	end
	for k, v in pairs(type(opts.target) == "table" and opts.target or {}) do
		target[k] = v
	end
	target.cast = target.cast or { name = "Snap", texture = 132200, start = 9000, finish = 11500, spellID = 999 }
	if opts.target == false then
		target = nil
	end
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
			-- The boss you target is one unit under both tokens, as in the game, so the boss card marks it. In a fight
			-- the boss targets you, so the target of target shows beside the sigil.
			env._units.boss1 = opts.boss and opts.target == opts.boss and target or opts.boss
			env._units.targettarget = opts.boss and target and player or nil
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
	env.SetTarget(target ~= nil)
	if player.cast then
		env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", player.cast.spellID)
	end
	if target then
		env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", target.cast.spellID)
		env.FireEvent("UNIT_TARGET", "target")
	end
	if opts.boss then
		env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
		if opts.boss.cast then
			env.FireEvent("UNIT_SPELLCAST_START", "boss1", "Cast-1", opts.boss.cast.spellID)
		end
	end
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
	if opts.boss and target then
		notes[#notes + 1] = sigilSockets(env, K, ns, ns.Frames.Get("target").views[1])
	end
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
			-- The client's seconds formatter, which the sockets put on their cooldown numbers ("4s").
			dofile("Tools/regression/cooldowns_env.lua").StringUtil(env)
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
	-- Each bar's shape as Layout > Apply writes it for the layout (rows and growth), so the pet and stance bars draw
	-- the footprint the layout reserves for them.
	for _, entry in ipairs(K.Setup.Layouts.Settings(opts.layout or "DPS")) do
		if entry.module == "ActionBars" and (entry.key:find("%.rows$") or entry.key:find("%.growth$")) then
			K.Options.Write("ActionBars", entry.key, entry.value)
		end
	end
	env.RunTimers()
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

-- Tracked(spec, counts) -> the class's spec with its tracked buffs and bars repeated up to counts ({ buffs, bars }),
-- each repeat a little further from expiring, for scenes that show Apply's placement at a high load.
local function Tracked(spec, counts)
	if not counts then
		return spec
	end
	local out = {}
	for k, v in pairs(spec) do
		out[k] = v
	end
	for _, group in ipairs({ "buffs", "bars" }) do
		local list, n = {}, counts[group] or #spec[group]
		for i = 1, n do
			local entry = spec[group][(i - 1) % #spec[group] + 1]
			local state = entry[3]
			list[i] = { entry[1], entry[2], { state[1], math.min(state[1], state[2] + math.floor((i - 1) / #spec[group]) * 3) } }
		end
		out[group] = list
	end
	return out
end

function modules.cooldowns(opts)
	local C = dofile("Tools/regression/cooldowns_env.lua")
	local _, spec = Hud.Class(opts)
	spec = Tracked(spec, opts.tracked)
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
		saved = saved(opts, "Cooldowns"),
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
	-- The automatic path, as on Forever: the cooldown rows mirror, while aura data that can turn secret in combat
	-- sends the tracked buffs to Blizzard's own viewers, restyled, where Apply's Edit Mode write placed them.
	local items = { buffs = {}, bars = {} }
	for _, entry in ipairs(entries) do
		local list = items[entry.group]
		if list then
			list[#list + 1] = { id = entry.id, icon = entry.icon, name = entry.name, left = entry.state[2], total = entry.state[1] }
		end
	end
	local _, told = Hud.NativeViewers(env, C, opts.layout or "DPS", items)
	C.Enable(env, K)
	env.FireEvent("PLAYER_ENTERING_WORLD", true, false)
	for _, spell in ipairs(procs) do
		env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", spell)
	end
	env.RunTimers()
	C.W.Settle(env)
	local scene = build(env, opts, { time = env._time })
	scene.log[#scene.log + 1] = "cooldowns: " .. ns.Mirror.Report() .. "; Blizzard's tracked buff viewers at Apply's Edit Mode anchors" .. (#told > 0 and (", and Apply said: " .. table.concat(told, " ")) or "")
	return finish(env, K, scene, "cooldowns"), ns
end


-- Chat: the glass panel with the general tab's lines, as a session fills it: the login lines, guild and party
-- talk, then the loot, experience and zone lines of the mockup ---------------------------------------------------

local SYSTEM = { 1, 1, 0 }
local CHAT_LINES = {
	{ "CHAT_MSG_SYSTEM", "Welcome to World of Warcraft: Forever.", SYSTEM },
	{ "CHAT_MSG_SYSTEM", "Leduc has come online.", SYSTEM },
	{ "CHAT_MSG_GUILD", "Raid at 8 tonight, bring flasks.", { sender = "Thargor", guid = "Player-1-0002", color = { 0.25, 1, 0.25 } } },
	{ "CHAT_MSG_PARTY", "ready when you are", { sender = "Leduc", guid = "Player-1-0003", color = { 0.67, 0.67, 1 } } },
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
		if type(line[3]) == "table" and line[3].sender then
			env._now = env._now + 60
			C.Say(env, chat, line[1], line[2], line[3])
		else
			-- The game formats system lines itself: system yellow, loot green and experience blue.
			local r, g, b = 0, 0.67, 0
			if line[1] == "CHAT_MSG_COMBAT_XP_GAIN" then
				r, g, b = 0.44, 0.44, 1
			elseif line[3] then
				r, g, b = line[3][1], line[3][2], line[3][3]
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
	-- The Minimap frame draws the world in the game; the mockup's map, or a flat tone, stands in, clipped as the
	-- game clips the frame.
	local _, note = Hud.Terrain(env)
	local scene = build(env, opts)
	scene.log[#scene.log + 1] = note
	return finish(env, K, scene, "minimap"), ns
end

-- Data bars: the experience bar and the data strip ----------------------------------------------------------

-- The bag bar's icons and the character button's portrait, as gallery_databars draws them: the engine
-- binds both itself, so the scene gives the stub the bags the player wears and the mockup's portrait.
local BAG_ICONS = { [31] = 133634, [32] = 133635, [33] = 133636, [34] = 133637 }
local BACKPACK, KEYRING = 133633, 134237

function modules.databars(opts)
	local D = dofile("Tools/regression/databars_env.lua")
	local portraitNote
	local class = Hud.Class(opts)
	local env, K, ns = D.New({
		saved = saved(opts, "DataBars"),
		-- No watched faction: the mockup shows no reputation bar under the action bars.
		game = { xp = 16000, xpMax = 50000, rested = 6000, level = 38, faction = false },
		setup = function(env)
			shared(env, opts)
			Common.ForceScreen(env)
			if opts.menus ~= false then
				D.Menus(env, {
					bags = BAG_ICONS, backpack = BACKPACK, keyring = KEYRING,
					portrait = function(texture)
						local name = "portrait-player.png"
						if Common.StandIn("portrait-player-" .. class:lower() .. ".png") then
							name = "portrait-player-" .. class:lower() .. ".png"
						end
						portraitNote = standIn(texture, name, 0.33, 0.28, 0.22, "the character button's portrait")
					end,
				})
			end
		end,
	})
	env.RunTimers()
	D.W.Settle(env)
	local scene = build(env, opts)
	if portraitNote then
		scene.log[#scene.log + 1] = portraitNote
	end
	return finish(env, K, scene, "databars"), ns
end

-- Auras: the player's buffs beside the minimap, five with their time left ----------------------------------

-- The engine binds each button's icon and timer itself; the stub does not, so the scene fills the buff buttons
-- with the class's buff row (_classes.lua), then more of its spells when opts.buffs asks for a longer row, and
-- lays them out as the container's flow layout would: from the corner the module anchors the container at (the
-- top right, beside the minimap, by default), leftwards, the shortest time left first, wrapping into rows.
-- opts.debuffs fills that many debuff tiles the same way.

local MORE_TIMERS = { "6m", "42s", "1h", "15m", "28s", "2h", "9m", "51s", "3h", "7m", "33s", "4h" }
local DEBUFF_ROW = { { "Rend", 132155, "18s" }, { "Hamstring", 132316, "9s" }, { "Sunder Armor", 132363, "4s" }, { "Demoralizing Shout", 132366, "1m" }, { "Thunder Clap", 136105, "26s" } }

-- BuffRow(spec, count) -> count { "Name", icon, "time" } entries: the class's buff row, then its other spells.
function Hud.BuffRow(spec, count)
	local out = {}
	for i, buff in ipairs(spec.buffRow) do
		if i <= count then
			out[i] = buff
		end
	end
	local pool = {}
	for _, list in ipairs({ spec.bar2, spec.bar1 }) do
		for _, spell in ipairs(list) do
			pool[#pool + 1] = spell
		end
	end
	local n = 0
	while #out < count and n < #pool do
		n = n + 1
		out[#out + 1] = { pool[n][1], pool[n][2], MORE_TIMERS[(n - 1) % #MORE_TIMERS + 1] }
	end
	return out
end

-- fillAuras(env, A, container, key, group, entries) -> the group's first #entries buttons, bound as the engine
-- would bind them; past the engine's first batch of ten it makes more, as the engine does for a later batch.
local function fillAuras(env, A, container, key, group, entries)
	local buttons = {}
	for i, entry in ipairs(entries) do
		local button = group.frames[i]
		if not button then
			button = A.MakeButton(env, container, container._groups[key].initializeFrame)
			group.frames[i] = button
		end
		do
			local aura = button._aura
			if aura.icon then
				aura.icon:SetTexture(env.Secret(entry[2]))
			end
			if aura.timer then
				aura.timer:SetText(entry[3])
			end
			buttons[#buttons + 1] = button
		end
	end
	return buttons
end

function modules.auras(opts)
	local A = dofile("Tools/regression/auras_env.lua")
	local _, spec = Hud.Class(opts)
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
	for _, container in ipairs(env._containers) do
		for _, button in ipairs(A.Buttons(container)) do
			button:Hide()
		end
	end
	local settings = K.Store.Module("Auras")
	local buffRow = Hud.BuffRow(spec, opts.buffs or #spec.buffRow)
	local buffs, group = A.Container(env, "HELPFUL")
	if buffs then
		local columns = ns.Model.Group(settings, "buffs").columns
		Hud.PlaceAuras(buffs, group, fillAuras(env, A, buffs, "buffs", group, buffRow), columns)
	end
	-- The engine sizes an empty container to nothing, and the card's glass follows it, so the debuff
	-- container is laid out even with no debuffs.
	local debuffs, harmful = A.Container(env, "HARMFUL")
	local entries = {}
	for i = 1, opts.debuffs or 0 do
		entries[i] = DEBUFF_ROW[(i - 1) % #DEBUFF_ROW + 1]
	end
	if debuffs then
		Hud.PlaceAuras(debuffs, harmful, fillAuras(env, A, debuffs, "debuffs", harmful, entries), ns.Model.Group(settings, "debuffs").columns)
	end
	-- The card asks the game whether the player has any buff or debuff (C_UnitAuras.GetAuraSlots, readable out
	-- of combat) to drop the debuff band when there are no debuffs; the stub answers from the rows laid out.
	local counts = { HELPFUL = #buffRow, HARMFUL = #entries }
	env.C_UnitAuras = env.C_UnitAuras or {}
	env.C_UnitAuras.GetAuraSlots = function(_, filter, maxSlots)
		local out = {}
		for i = 1, math.min(counts[filter] or 0, maxSlots or math.huge) do
			out[i] = i
		end
		return nil, unpack(out)
	end
	env.FireEvent("UNIT_AURA", "player")
	A.Counters(ns, { #buffRow, 0, #entries })
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
			tracker = Tracker.StandIn(env, S.Blizzard(env), opts.quests or Tracker.QUESTS)
			local a = opts.trackerAnchor
			if a then
				tracker:ClearAllPoints()
				tracker:SetPoint(a.point, env.UIParent, a.relativePoint, a.offsetX, a.offsetY)
			end
		end,
	})
	if not K.Modules.IsRunning("Skins") then
		K.Modules.Enable("Skins")
	end
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	env.RunTimers()
	S.W.Settle(env)
	-- With the RestedXP guide docked over it (the skin's one story card), the tracker's own glass yields to the
	-- guide's, which the restedxp module draws down to the tracker's foot.
	if opts.trackerDocked then
		ns.Tracker.Dock(true)
	end
	-- Blizzard's objective text is yellow for titles and white for lines, under the tracker's fonts.
	local scene = build(env, opts)
	scene.log[#scene.log + 1] = "the quest tracker is a stand-in laid out as Blizzard_ObjectiveTracker does; Edit Mode places the real one" .. (opts.trackerAnchor and ", here at the anchor Layout > Apply wrote into the KstyleUI Edit Mode layout: the story slot" or ", at Forever's preset") .. (opts.trackerDocked and "; its glass is the guide's card, docked" or "")
	return finish(env, K, scene, "tracker"), ns, tracker
end

-- Nameplate: the target's plate over the crocolisk, mid-cast, with the combat numbers -----------------------

-- The plate's base sits where the game puts it over the target: in screen units, 984 across and 396 down.
local PLATE_X, PLATE_Y = 984, 396
-- Blizzard's world numbers (the damage you deal) float above the target in DAMAGE_TEXT_FONT, which
-- KstyleUI_CombatText sets to the kit font; the game sizes them itself. A crit reads larger and gold.
-- A second mob in the pull, casting a spell the player can interrupt right now.
local ADD = {
	x = 700, y = 470,
	unit = { name = "Mirefin Oracle", health = 980, maxHealth = 1210, level = 39, reaction = 2, canAttack = true, powerType = 0, powerMax = 1600 },
	cast = { name = "Mirefin Hex", text = "Mirefin Hex", texture = 136071, notInterruptible = false },
}
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
	local class = Hud.Class(opts)
	Hud.PlateCasts(env, K, ns, class)
	local target = type(opts.target) == "table" and opts.target or TARGET
	local cast = target.cast or { name = "Snap", texture = 132200 }
	local base = N.Add(env, "nameplate1", { name = target.name, health = target.health, maxHealth = target.healthMax, level = target.level, classification = target.classification, reaction = 2, canAttack = true })
	local k = 768 / 1080
	base:ClearAllPoints()
	base:SetPoint("CENTER", env.WorldFrame, "BOTTOMLEFT", PLATE_X * k, (1080 - PLATE_Y) * k)
	local add = N.Add(env, "nameplate2", ADD.unit)
	add:ClearAllPoints()
	add:SetPoint("CENTER", env.WorldFrame, "BOTTOMLEFT", ADD.x * k, (1080 - ADD.y) * k)
	N.Target(env, "nameplate1")
	N.Cast(env, "nameplate1", { name = cast.name, text = cast.name, texture = cast.texture, notInterruptible = false })
	N.Cast(env, "nameplate2", ADD.cast)
	for _ = 1, 20 do
		N.Tick(env, 0.05)
	end
	Hud.FillCast(ns.Plates.Get("nameplate1"), 0.55)
	Hud.FillCast(ns.Plates.Get("nameplate2"), 0.4)
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
	scene.log[#scene.log + 1] = "nameplates: the target's plate stands its cast down while the sigil shows it (cast.hideOnTarget); the " .. ADD.unit.name .. " casts " .. ADD.cast.name .. " with the " .. class:lower() .. "'s interrupt ready, so its bar takes the accent; cast fills stand in for the engine's timer"
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

-- Group frames: the party on the secure party header. opts.party lists the other members (the player comes first,
-- as the module shows it), each { name, class, health %, role }; nothing draws without one.

local CLASS_COLORS = {
	WARRIOR = Common.WARRIOR, MAGE = { 0.25, 0.78, 0.92 }, PRIEST = { 1, 1, 1 }, ROGUE = { 1, 0.96, 0.41 },
	HUNTER = { 0.67, 0.83, 0.45 }, PALADIN = { 0.96, 0.55, 0.73 }, DRUID = { 1, 0.49, 0.04 }, WARLOCK = { 0.53, 0.53, 0.93 },
	SHAMAN = { 0, 0.44, 0.87 },
}

local function classColours(env)
	env.RAID_CLASS_COLORS = env.RAID_CLASS_COLORS or {}
	for class, c in pairs(CLASS_COLORS) do
		env.RAID_CLASS_COLORS[class] = env.RAID_CLASS_COLORS[class] or { r = c[1], g = c[2], b = c[3] }
	end
end

function modules.groupframes(opts)
	local G = dofile("Tools/regression/group_env.lua")
	local class, spec = Hud.Class(opts)
	local env, K, ns = G.New(Common.ScreenOpts({
		saved = saved(opts, "GroupFrames"),
		setup = function(env)
			local unitClass = env.UnitClass
			shared(env, opts)
			classColours(env)
			env.UnitClass = unitClass
		end,
	}))
	local members = {}
	for i, m in ipairs(opts.party or {}) do
		members[i] = { name = m[1], class = m[2], health = m[3], maxHealth = 100, power = 60, maxPower = 100, role = m[4], leader = i == 1 }
	end
	local player = { name = spec.name, class = class, health = 82, maxHealth = 100, power = 45, maxPower = 100, powerType = spec.power.token, role = opts.role or "DAMAGER" }
	G.SetRoster(env, #members > 0 and "party" or nil, members, player)
	if not K.Modules.IsRunning("GroupFrames") then
		K.Modules.Enable("GroupFrames")
	end
	env.RunTimers()
	tick(env, 1)
	local scene = build(env, opts)
	return finish(env, K, scene, "groupframes"), ns
end

-- Meters: the damage meter over the fight in opts.damage ({ name, class, amount }, highest first), and the threat
-- meter when the layout shows it.

function modules.meters(opts)
	local M = dofile("Tools/regression/meters_env.lua")
	local rows = opts.damage or {}
	local env, K, ns = M.New(Common.ScreenOpts({
		saved = saved(opts, "Meters"),
		setup = function(env)
			shared(env, opts)
			classColours(env)
			env.UnitClass = function(unit)
				local u = env._units[unit]
				if u and u.class then
					return u.class, u.class, 1
				end
				return Hud.Class(opts)
			end
			env.AbbreviateNumbers = function(n)
				if type(n) ~= "number" then
					return tostring(n)
				elseif n >= 1e3 then
					return string.format("%.1fK", n / 1e3)
				end
				return tostring(math.floor(n + 0.5))
			end
			local sources, total = {}, 0
			for i, row in ipairs(rows) do
				total = total + row[3]
				sources[i] = {
					name = row[1], classFilename = row[2], totalAmount = row[3], amountPerSecond = row[3] / 60, sourceGUID = "Player-" .. tostring(row[1]),
					sourceDisplayType = 1, isLocalPlayer = i == 1, deathRecapID = 0, deathTimeSeconds = 0,
				}
			end
			env._session = { combatSources = sources, maxAmount = rows[1] and rows[1][3] or 0, totalAmount = total, durationSeconds = 60 }
			env._group = { raid = false, size = #rows }
			env._units.player = { name = rows[1] and rows[1][1] or "Valerin", class = rows[1] and rows[1][2] or "WARRIOR" }
			env._units.target = { name = opts.target and opts.target.name or TARGET.name, hostile = true }
			for i, row in ipairs(rows) do
				local unit = i == 1 and "player" or ("party" .. (i - 1))
				env._units[unit] = { name = row[1], class = row[2] }
				env._threat[unit] = { i == 2, i == 2 and 3 or 0, 100 - i * 14, 100 - i * 16, (#rows - i + 1) * 100000 }
			end
		end,
	}))
	if not K.Modules.IsRunning("Meters") then
		K.Modules.Enable("Meters")
	end
	env.RunTimers()
	env.FireEvent("GROUP_ROSTER_UPDATE")
	env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
	env.FireEvent("PLAYER_TARGET_CHANGED")
	env.RunTimers()
	-- In combat the player is swinging: the main hand 1.1 s into a 2.6 s swing, so the swing timer reads
	-- mid-swing. Out of combat, or between swings, the timer hides.
	if opts.combat then
		local now = env.GetTime()
		env.FireEvent("PLAYER_SWING", 2.6, M.SWING.MainHand)
		env.SetTime(now + 1.1)
	end
	M.Tick(env)
	-- opts.meterHover ({ spellID, name, icon, amount }, highest first): the pointer rests on the player's row, so its
	-- tooltip lists the player's top three spells of the fight, as the game reads them out of combat.
	if opts.meterHover and rows[1] then
		local spells, total = {}, 0
		for i, s in ipairs(opts.meterHover) do
			env._spells[s[1]] = { name = s[2], icon = s[3] }
			spells[i] = { spellID = s[1], totalAmount = s[4], amountPerSecond = s[4] / 60, creatureName = "" }
			total = total + s[4]
		end
		env._sources["Player-" .. tostring(rows[1][1])] = { combatSpells = spells, maxAmount = spells[1].totalAmount, totalAmount = total }
		local row = ns.Damage.list.rows[1].frame
		row._scripts.OnEnter(row)
		env.RunTimers()
		tick(env, 0.3)
	end
	local scene = build(env, opts)
	if opts.meterHover then
		scene.log[#scene.log + 1] = "the pointer rests on the player's row of the damage meter: its tooltip lists the top three spells"
	end
	return finish(env, K, scene, "meters"), ns
end

-- RestedXP: the guide window and its active step, skinned, where the skin's story rail puts it for opts.layout.
-- RestedXP's other windows stay closed.

function modules.restedxp(opts)
	local RestedXP = dofile("Tools/render/scenes/_restedxp.lua")
	RestedXP.PRESET = opts.layout
	local first = RestedXP.STEPS[1]
	RestedXP.STEPS = { { title = first.title, elements = { first.elements[1], first.elements[2] } } }
	local R = RestedXP.Build()
	for _, name in ipairs({ "items", "v2", "configurator" }) do
		for _, frame in ipairs(R.windows[name]) do
			frame:Hide()
		end
	end
	if opts.dockBottom then
		-- A stand-in for the tracker skin's fit frame: its foot the fit's foot (screen units up from the bottom),
		-- its top the quests' cap. The rail docks the guide's card to it as it docks to the real fit in
		-- the game: the glass runs to the quests' foot and the guide's footer hugs the quests' cap.
		local env, K = R.env, R.K
		local fit = env.CreateFrame("Frame", nil, env.UIParent)
		local scale = K.Widgets.ScaleFactor(fit)
		fit:SetSize(1, math.max(1, (opts.dockTop or opts.dockBottom + 1) - opts.dockBottom) / scale)
		fit:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 0, opts.dockBottom / scale)
		R.ns.RestedXP.Rail.DockTo(fit)
		R.env.RunTimers()
		R.log[#R.log + 1] = "restedxp: the quests dock into the guide's card; its glass runs to the tracker glass's foot and its footer hugs the quests' cap"
	end
	local scene = build(R.env, opts)
	for _, line in ipairs(R.log) do
		scene.log[#scene.log + 1] = line
	end
	scene.log[#scene.log + 1] = "restedxp: the guide is where the skin's story rail puts it for the " .. tostring(opts.layout) .. " layout, its step list folded by RestedXP's own rule"
	return finish(R.env, R.K, scene, "restedxp"), R
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

-- EditModeLayout(layout, guide, counts) -> the "KstyleUI <layout>" Edit Mode layout Layout > Apply writes: the
-- addon's own Setup.Apply runs against Forever's Edit Mode API (Tools/regression/editmode_fake.lua) on the owner's
-- screen, where a UIParent unit is a root unit. guide says RestedXP is loaded, so the tracker takes the slot's lower
-- half; counts ({ buffs, bars }) are the tracked cooldowns the Cooldowns module would report, which size Blizzard's
-- tracked buff viewers.
function Hud.EditModeLayout(layout, guide, counts)
	local CoreEnv = dofile("Tools/regression/core_env.lua")
	local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
	local state = { saved = {}, active = 1 }
	local env, K = CoreEnv.New(Common.ScreenOpts({
		setup = function(env)
			Common.ForceScreen(env)
			EditModeFake.Install(env, state)
			env.C_AddOns = env.C_AddOns or {}
			env.C_AddOns.IsAddOnLoaded = function(name)
				return guide == true and name == "RXPGuides"
			end
		end,
	}))
	CoreEnv.Boot(env)
	-- RaidWarningFrame as the encounter warnings skin leaves it at login, narrowed to the lane, so Apply reserves that width.
	local warnings = env.CreateFrame("Frame", "RaidWarningFrame", env.UIParent)
	env.RaidWarningFrame = warnings
	warnings:SetSize(K.Setup.EditMode.WARNING_LANE * K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale(), 100)
	if counts then
		-- The Cooldowns module restyles Blizzard's buff row on Forever's automatic path and stops it at its six-socket
		-- grid with a "+N" chip in the seventh slot (KstyleUI_Cooldowns/Cap.lua), so it reports seven slots past six.
		K.Setup.EditMode.CountTracked(function(group)
			local n = counts[group]
			if group == "buffs" and n and n > 6 then
				return 7
			end
			return n
		end)
	end
	if not K.Setup.Apply({ layout = layout, modules = {} }) then
		return nil
	end
	return EditModeFake.Named(state, "KstyleUI " .. layout), env._printed
end

-- StoryTracker(layout, guide) -> the objective tracker's Edit Mode anchor after Layout > Apply, which Edit Mode hands
-- to the tracker's SetPoint.
function Hud.StoryTracker(layout, guide)
	local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
	local written = Hud.EditModeLayout(layout, guide)
	local entry = written and EditModeFake.Find(written, EditModeFake.TRACKER)
	return entry and entry.anchorInfo
end

-- NativeViewers(env, C, layout, items, shift) lays Blizzard's tracked buff icon and bar viewers out where Apply's
-- Edit Mode write puts them for this many tracked buffs and bars (C.Native); shift(entry, group, placed) -> dx, dy
-- moves each viewer for a gallery column, the icons first, placed holding the entries already moved. Returns the two Edit Mode entries and what Apply told the player.
function Hud.NativeViewers(env, C, layout, items, shift)
	local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
	local written, printed = Hud.EditModeLayout(layout, false, { buffs = #items.buffs, bars = #items.bars })
	assert(written, "Apply wrote no Edit Mode layout")
	local formatter = env.C_StringUtil.CreateSecondsFormatter()
	local function format(seconds)
		return formatter:Format(seconds)
	end
	local out = {}
	for _, view in ipairs({ { "buffs", EditModeFake.BUFF_ICON, "BuffIconCooldownViewer" }, { "bars", EditModeFake.BUFF_BAR, "BuffBarCooldownViewer" } }) do
		local entry = EditModeFake.Copy(EditModeFake.Find(written, EditModeFake.VIEWER, view[2]))
		local dx, dy = 0, 0
		if shift then
			dx, dy = shift(entry, view[1], out)
		end
		entry.anchorInfo.offsetX = entry.anchorInfo.offsetX + dx
		entry.anchorInfo.offsetY = entry.anchorInfo.offsetY + dy
		C.Native(env, view[3], entry, items[view[1]], format)
		out[view[1]] = entry
	end
	return out, printed or {}
end

-- PresetSettings(layout) -> the module settings Layout > Apply writes for the layout (Setup.Layouts.Settings), as
-- saved sections ({ [module] = { nested } }).
function Hud.PresetSettings(layout)
	local CoreEnv = dofile("Tools/regression/core_env.lua")
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	local settings = {}
	for _, entry in ipairs(K.Setup.Layouts.Settings(layout)) do
		local node = settings[entry.module] or {}
		settings[entry.module] = node
		local parts = {}
		for part in entry.key:gmatch("[^%.]+") do
			parts[#parts + 1] = part
		end
		for i = 1, #parts - 1 do
			node[parts[i]] = node[parts[i]] or {}
			node = node[parts[i]]
		end
		node[parts[#parts]] = entry.value
	end
	return settings
end

-- Options(opts) -> opts for a whole-HUD scene: one that names a layout and no settings takes the layout's preset,
-- so a class page shows what Apply leaves on (round 6, Fable: bar 2 drew on while every preset turns it off).
function Hud.Options(opts)
	opts = opts or {}
	if opts.layout and opts.settings == nil and opts.modules == nil then
		opts.settings = Hud.PresetSettings(opts.layout)
	end
	return opts
end

function Hud.Build(opts)
	opts = Hud.Options(opts)
	if opts.layout and opts.trackerAnchor == nil then
		opts.trackerAnchor = Hud.StoryTracker(opts.layout, false)
	end
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
