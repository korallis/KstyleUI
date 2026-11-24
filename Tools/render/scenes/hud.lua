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
local Fx = dofile("Tools/render/scenes/_effects.lua")
local RestScene = dofile("Tools/render/scenes/_rest.lua")
local TotemScene = dofile("Tools/render/scenes/_totems.lua")
local TrackerScene = dofile("Tools/render/scenes/_trackers.lua")

-- The module scenes' draw order lives in this copy of scene.lua, so merges across modules sort with it.
local Hud = { Merge = Scene.Merge }
Hud.Classes = Classes
-- Hud.envs[scene] -> the environment a module scene was built in, for scenes that measure frames after the build.
Hud.envs = setmetatable({}, { __mode = "k" })
-- Hud.layoutElements, while a HUD composes, holds every module's Layout elements ({ [key] = { el, live } }). The game
-- keeps one Layout registry, where the minimap's corners find the elements beside it (KstyleUI_Minimap/Map.lua);
-- build() lets each environment's Layout.Element and Layout.Live fall back to them. Nothing else crosses environments.
Hud.layoutElements = nil

function Hud.ShareLayout(env)
	local Layout = env.KstyleUI and env.KstyleUI.Layout
	if not (Hud.layoutElements and Layout) or Layout._shared then
		return
	end
	local element, live = Layout.Element, Layout.Live
	Layout._shared = true
	Layout.Element = function(key)
		local shared = Hud.layoutElements and Hud.layoutElements[key]
		return element(key) or shared and shared.el
	end
	Layout.Live = function(key)
		if element(key) then
			return live(key)
		end
		local shared = Hud.layoutElements and Hud.layoutElements[key]
		return shared ~= nil and shared.live
	end
end

-- Class(opts) -> the scene's class token and its _classes.lua entry.
-- opts.spec overlays the class's entry field by field (a fixture's own name, bars and buffs).
function Hud.Class(opts)
	local class, spec = Classes.Get(opts and opts.class)
	if not (opts and type(opts.spec) == "table") then
		return class, spec
	end
	local out = {}
	for k, v in pairs(spec) do
		out[k] = v
	end
	for k, v in pairs(opts.spec) do
		out[k] = v
	end
	return class, out
end

local TARGET = { name = "Riverglade Crocolisk", level = 38, health = 864, healthMax = 1540, power = 0, powerMax = 0, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true, classification = "normal", creature = "Beast" }

-- The race each class's player is drawn as, so the Medallions portrait resolver finds painted art; Frames never reads it.
Hud.RACES = { WARRIOR = "Human", PALADIN = "Dwarf", HUNTER = "NightElf", ROGUE = "Human", PRIEST = "Dwarf", SHAMAN = "Dwarf", MAGE = "Gnome", WARLOCK = "Scourge", DRUID = "NightElf" }

-- Pips() -> from, to, off: RENDER_PIPS=from,to, the combo points' change the unit frames' pips play; the crest jewels
-- show the second count and a druid is in cat form. RENDER_PIPS=off turns the class-themed pips off.
function Hud.Pips()
	local value = rawget(_G, "RENDER_PIPS") or os.getenv("RENDER_PIPS") or ""
	local from, to = value:match("^(%d+),(%d+)$")
	assert(value == "" or value == "off" or from, "RENDER_PIPS must be from,to, such as 4,5, or off")
	return tonumber(from), tonumber(to), value == "off"
end

-- Crown(opts) -> under RENDER_PIPS (off too, so the setting is the only change), the crown the game feeds for the
-- scene's class (a druid's in bear form with RENDER_FORM=bear), whose spell the player then knows; nil for the combo
-- point classes and the rest.
local CROWN_AURAS = { WARRIOR = 7386, PRIEST = 15258, MAGE = 400573, HUNTER = 1310687, BEAR = 1328617, SHAMAN = 10432 }
local CROWN_KNOWN = { WARRIOR = 7386, PRIEST = 15257, MAGE = 400574, HUNTER = 1310687, BEAR = 1328617, SHAMAN = 10432 }
function Hud.Crown(opts)
	local class = Hud.Class(opts)
	local kind = class == "DRUID" and os.getenv("RENDER_FORM") == "bear" and "BEAR" or class
	local from, _, off = Hud.Pips()
	return (from or off) and CROWN_KNOWN[kind] and kind or nil
end

-- SetCrown(env, kind, n) gives the crown's aura n stacks through the game's own feed (the same aura while it stays,
-- so the slots ease; a new one is assigned at once).
local function SetCrown(env, kind, n)
	local unit = (kind == "MAGE" or kind == "HUNTER" or kind == "SHAMAN") and "player" or "target"
	local aura = n > 0 and (env._crownAura or { id = CROWN_AURAS[kind], harmful = unit == "target", mine = true }) or nil
	if aura then
		aura.count = n
	end
	env._crownAura = aura
	dofile("Tools/regression/aura_slots.lua").Set(env, unit, aura and { aura } or nil)
end

-- PlayPips(env, K, set) -> note: RENDER_PIPS=from,to moves the combo points from one count to the other RENDER_PIPS_T
-- seconds before the scene's clock through the addon's own power event (set(n) gives the stubs the count); equal
-- counts settle there with no change. RENDER_PIPS_MOTION sets Medallions motion (off shows the end states).
local function PlayPips(env, K, set)
	local from, to = Hud.Pips()
	if not from then
		return nil
	end
	local motion, clock = os.getenv("RENDER_PIPS_MOTION"), env._now
	if motion and motion ~= "" then
		K.Options.Write("Medallions", "motion", motion)
	end
	set(from)
	env.FireEvent("PLAYER_TARGET_CHANGED")
	env._now = env._time - (tonumber(os.getenv("RENDER_PIPS_T") or "") or 0)
	set(to)
	env.FireEvent(from == to and "PLAYER_TARGET_CHANGED" or "UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
	env._now = clock
	return "pips: " .. from .. " to " .. to .. ", " .. (os.getenv("RENDER_PIPS_T") or "0") .. " s in"
end

-- Form(class) -> a druid's form: RENDER_FORM, else cat form under RENDER_PIPS; nil in caster form and for the rest.
local function Form(class)
	return class == "DRUID" and (os.getenv("RENDER_FORM") or Hud.Pips() and "cat") or nil
end

-- Player(opts) -> the player unit for the scene's class, as unitframes_env takes it: a bear on rage, a cat on energy.
function Hud.Player(opts)
	local class, spec = Hud.Class(opts)
	local form = Form(class)
	local power = form == "bear" and { type = 1, token = "RAGE", value = 40, max = 100 } or form == "cat" and { type = 3, token = "ENERGY", value = 80, max = 100 } or spec.power
	local player = {
		name = spec.name, class = class, level = 38, health = 2750, healthMax = 3350,
		power = power.value, powerMax = power.max, powerType = power.type, powerToken = power.token,
		isPlayer = true, reaction = 5, race = Hud.RACES[class], sex = 2,
	}
	for k, v in pairs(type(opts) == "table" and type(opts.player) == "table" and opts.player or {}) do
		player[k] = v
	end
	return player
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

-- Style() -> the HUD style a scene renders: RENDER_HUD_STYLE, set as a global by a test or in the environment.
function Hud.Style()
	local style = rawget(_G, "RENDER_HUD_STYLE") or os.getenv("RENDER_HUD_STYLE")
	if style and style ~= "" then
		return style
	end
end

local function saved(opts, module, settings, more)
	local section = { enabled = true }
	merge(section, opts.settings and opts.settings[module])
	merge(section, settings)
	local profile = { [module] = section }
	if opts.dataBar then
		profile.DataBars = merge(merge({}, opts.dataBar), opts.settings and opts.settings.DataBars)
		if module == "DataBars" then merge(profile.DataBars, section) end
	end
	local style = Hud.Style()
	if style then
		assert(style == "Frames" or style == "Medallions", "RENDER_HUD_STYLE must be Frames or Medallions")
		profile.HudStyle = { style = style:lower() }
	end
	for _, name in ipairs(more or {}) do
		profile[name] = { enabled = true }
		merge(profile[name], opts.settings and opts.settings[name])
	end
	Common.FinishSettings(profile)
	profile.Minimap = profile.Minimap or { enabled = true }
	profile.Minimap.frame = os.getenv("RENDER_MINIMAP_FRAME")
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
	Common.ForceScreen(env, true)
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

local function applyPreset(env, opts)
	if not opts.applyPreset or env._renderPreset then
		return
	end
	local K, enabled = env.KstyleUI, {}
	for _, name in ipairs(K.Modules.List()) do
		enabled[name] = K.Modules.IsEnabled(name)
	end
	assert(K.Setup.Apply({ layout = opts.layout, modules = enabled }), "the scene could not Apply " .. tostring(opts.layout))
	local extra = os.getenv("RENDER_EXTRA_BARS")
	if extra and extra ~= "off" then
		local cfg, layouts = K.Store.Module("ActionBars"), K.Setup.Layouts
		local preset = assert(layouts.ExtraBarsPreset(extra, K.Scale.Aspect()), "RENDER_EXTRA_BARS must be off, rows or beside")
		if K.Modules.IsEnabled("ActionBars") then
			K.Options.Write("ActionBars", "extraBarsLayout", extra)
		else
			cfg.extraBarsApplied = extra
			cfg.bar4, cfg.bar5 = preset, preset
			K.Callbacks.Fire("SettingChanged", "ActionBars", "extraBarsApplied", extra)
		end
	end
	-- RENDER_CONTROLS (Keyboard or Gamepad) applies that bar set after the preset, as setup's Controls choice does.
	if os.getenv("RENDER_CONTROLS") and K.Modules.IsEnabled("ActionBars") then
		assert(K.Setup.Looks.ApplyControls(os.getenv("RENDER_CONTROLS")), "RENDER_CONTROLS must be Keyboard or Gamepad")
	end
	local bar2Buttons = tonumber(os.getenv("RENDER_BAR2_BUTTONS") or "")
	if bar2Buttons and K.Modules.IsEnabled("ActionBars") then K.Options.Write("ActionBars", "bar2.buttons", bar2Buttons) end
	if (rawget(_G, "RENDER_BAR3") or os.getenv("RENDER_BAR3")) == "1" and K.Modules.IsEnabled("ActionBars") then
		K.Options.Write("ActionBars", "bar3.enabled", true)
		local buttons = tonumber(os.getenv("RENDER_BAR3_BUTTONS") or "")
		if buttons then K.Options.Write("ActionBars", "bar3.buttons", buttons) end
		local defaults = K.Store.Defaults("ActionBars")
		for _, bar in ipairs({ "bar3", "pet", "stance" }) do
			if type(defaults[bar]) == "table" and defaults[bar].showEmpty ~= nil then
				K.Options.Write("ActionBars", bar .. ".showEmpty", true)
			end
		end
	end
	env._renderPreset = opts.layout
	env.RunTimers()
end

-- build(env, opts, extra) -> the scene, with icon IDs resolved as the installed pack shows them. opts.sizes
-- ({ [key] = { w, h } }) resizes a free-sized element as Layout > Apply does for the layout (the Tank meters).
-- With opts.combat the environment enters combat first and runs half a second, so the combat calm has faded the
-- slow cards.
local function build(env, opts, extra, beforeDraw)
	local K = env.KstyleUI
	applyPreset(env, opts)
	dofile("Tools/render/scenes/_audit.lua").Apply(K)
	local artwork = os.getenv("RENDER_DATABAR_ARTWORK")
	if artwork and K.Options.Row("DataBars", "strip.artwork") then K.Options.Write("DataBars", "strip.artwork", artwork) end
	local placement = os.getenv("RENDER_DATABAR_PLACEMENT")
	if placement and K.Options.Row("DataBars", "strip.placement") then K.Options.Write("DataBars", "strip.placement", placement) end
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
	Hud.ShareLayout(env)
	if beforeDraw then
		beforeDraw()
	end
	local rested = RestScene.Apply(env, tick)
	local scene = Scene.Build(env, sceneOpts)
	scene.log[#scene.log + 1] = rested
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
	container:SetSize(math.max(0, across * width + (across - 1) * spacing), rows * height + math.max(0, rows - 1) * (layout.lineSpacing or 0))
	for i, button in ipairs(buttons) do
		local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
		button:ClearAllPoints()
		button:SetSize(width, height)
		button:SetPoint(corner, container, corner, dx * col * (width + spacing), dy * row * (height + (layout.lineSpacing or 0)))
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

-- CastCues(env, class, plates) -> RENDER_CAST_CUES: the target's cast (and on the plates the oracle's, as your focus) in one
-- state of Cast targets and interrupts: aimed (at Valerin, a mage), you, locked (uninterruptible), wait (cast while your
-- interrupt recharges, back about three quarters of the way through) or interrupted (by Valerin); off switches them off.
-- RENDER_CAST_CUES_T moves the casts that many seconds on, so frames at 0, 0.2, 0.4 and 0.6 show wait's fill reach the
-- ready mark and the interrupt come back at 0.4.
local CUES = { aimed = true, you = true, locked = true, wait = true, interrupted = true, off = true }
Hud.CUES_T = tonumber(os.getenv("RENDER_CAST_CUES_T") or "") or 0
function Hud.CastCues(env, class, plates)
	local cue = os.getenv("RENDER_CAST_CUES")
	if not cue or cue == "off" then
		return cue
	end
	assert(CUES[cue], "RENDER_CAST_CUES must be aimed, you, locked, wait, interrupted or off")
	local me = cue == "you"
	env.UnitShouldDisplaySpellTargetName = function() return true end
	env.UnitSpellTargetName = function() return env.Secret(me and "Kstyle" or "Valerin") end
	env.UnitSpellTargetClass = function() return env.Secret(me and class or "MAGE") end
	env.PlayerIsSpellTarget = function() return env.Secret(me) end
	env.UnitGUID = function(token) return token == "player" and "Player-1" or nil end
	env.UnitNameFromGUID = function() return "Valerin" end
	env.UnitClassFromGUID = function() return "Mage", "MAGE", 8 end
	local function interrupt(id)
		for _, each in ipairs(env.KstyleUI.Interrupt.INTERRUPTS[class] or {}) do
			if each == id then return true end
		end
		return false
	end
	if plates then
		-- The plates' casts run from 1 s to 3 s; the interrupt is back at 2.6 s.
		for _, id in ipairs(cue == "wait" and Hud.CUES_T < 0.4 and env.KstyleUI.Interrupt.INTERRUPTS[class] or {}) do
			env._cooldowns[id] = { startTime = 0.6, duration = 2, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }
		end
		return cue
	end
	env.C_ClassColor = env.C_ClassColor or { GetClassColor = function(file)
		local c = env.RAID_CLASS_COLORS[env.issecretvalue(file) and env.Reveal(file) or file]
		return c and { r = c.r, g = c.g, b = c.b, GetRGB = function() return c.r, c.g, c.b end } or nil
	end }
	env.C_SpellBook = env.C_SpellBook or {}
	local known, cooldown = env.C_SpellBook.IsSpellKnown, env.C_Spell.GetSpellCooldown
	env.C_SpellBook.IsSpellKnown = function(id, bank) return interrupt(id) or known ~= nil and known(id, bank) end
	-- The target's cast runs from 8.8 s or 9 s to 10.8 s or 11.5 s; the interrupt is back at 10.4 s.
	env.C_Spell.GetSpellCooldown = function(id)
		if cue == "wait" and Hud.CUES_T < 0.4 and interrupt(id) then
			return { startTime = 0.4 - Hud.CUES_T, duration = 10, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }
		end
		return cooldown and cooldown(id) or { startTime = 0, duration = 0, isEnabled = true, isActive = false, isOnGCD = false, modRate = 1 }
	end
	return cue
end

local modules = {}

-- Unit frames: player, target, both cast bars, the target of target, the pet and the class resource ----------

-- The player's cast ends 0.8 s from the scene's clock (10 s), as the mockup's Slam does; each class's cast
-- started its own cast time earlier.
local CAST_END = 10800

-- The boss's debuffs as sockets under the sigil, as the mockup's combat board draws them: the fake engine's buttons
-- placed where the AuraContainer would, centred, with their timers.
local SIGIL_DEBUFFS = { { 132155, "18s" }, { 132363, "9s", "3" }, { 132316, "4s" } }

local function sigilSockets(env, K, ns, view, list)
	list = list or SIGIL_DEBUFFS
	local a = view.auras
	if a and K.HudStyle.Current() == "medallions" then
		if ns.Fan.Wanted(view) then K.Options.Write("UnitFrames", "target.auraFilter", "debuffs") end
		local Engine = dofile("Tools/regression/aura_fixture_engine.lua")
		local count = tonumber(os.getenv("RENDER_CREST_DEBUFFS")) or #list
		local icons = { 135813, 136026, 136207, 136197, 136118, 136016, 136048 }
		local fixtures = {}
		for i = 1, count do
			fixtures[i] = { id = i, icon = icons[(i - 1) % #icons + 1], left = i * 3, harmful = true, mine = true }
		end
		fixtures[#fixtures + 1] = { id = 100, icon = 132155, left = 19, harmful = true, mine = false }
		env._units.target.auras = fixtures
		Engine.Install(env)
		if os.getenv("RENDER_MEDALLIONS_STATE") == "combat" then env.SetCombat(true) end
		return "crest debuffs: " .. count .. " of yours, soonest expiry at the apex, then alternating left and right; another player's debuff stays on the target"
	end
	local group = a and a.container and a.container._groups and a.container._groups.debuffs
	if not (group and group.buttons) then
		return "the sigil's debuff sockets: no aura engine stand-in"
	end
	local Widgets = K.Widgets
	local size, spacing = Widgets.Snap(a.host, ns.Settings.Value("target", "auraSize")), Widgets.Snap(a.host, ns.Settings.Value("target", "auraSpacing"))
	local count = math.min(#group.buttons, #list)
	a.container:SetSize(count * size + (count - 1) * spacing, size)
	for i = 1, count do
		local button = group.buttons[i]
		for _, entry in ipairs(a.buttons) do
			if entry.button == button then
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", a.container, "TOPLEFT", (i - 1) * (size + spacing), 0)
				button:SetSize(size, size)
				entry.icon:SetTexture(env.Secret(list[i][1]))
				Widgets.SetText(entry.timer, list[i][2])
				Widgets.SetText(entry.count, list[i][3] or "")
			end
		end
	end
	return "the sigil's debuff sockets: " .. count .. " of yours on the " .. (list == SIGIL_DEBUFFS and "boss" or "target")
end

local LOSS_AGO, LOSS_SHARE = 0.12, { player = 0.14, target = 0.08 }
-- The target's health share at a tracker story's start and end, and the story's length in seconds: the warrior's
-- target is under 20% when Execute lights at 9 s.
local STORY_HEALTH = { WARRIOR = { 0.62, 0.15, 9 }, DRUID = { 0.97, 0.82, 3 }, PRIEST = { 0.92, 0.6, 6 }, WARLOCK = { 1, 0.55, 6 } }
-- A humanoid target's portrait stand-in: KstyleUI's painted bust of a human caster.
local HUMANOID_BUST = "Interface\\AddOns\\KstyleUI\\Media\\Textures\\Medallions\\Busts\\human_warlock_male.png"

function modules.unitframes(opts)
	local U = dofile("Tools/regression/unitframes_env.lua")
	local class, spec = Hud.Class(opts)
	local player, target = Hud.Player(opts), {}
	for k, v in pairs(TARGET) do
		target[k] = v
	end
	-- opts.playerCast == false or RENDER_PLAYER_CAST=off: the player casts nothing (the questing HUD is out of combat; round 6, Opus).
	-- opts.castLeft: the seconds the player's cast has left at the scene's clock (0.8 when absent).
	local castEnd = opts.castLeft and (10000 + opts.castLeft * 1000) or CAST_END
	local form = Form(class)
	if spec.cast and opts.playerCast ~= false and os.getenv("RENDER_PLAYER_CAST") ~= "off" and form ~= "cat" and form ~= "bear" then
		player.cast = { name = spec.cast[1], texture = spec.cast[2], start = castEnd - spec.cast[4] * 1000, finish = castEnd, spellID = spec.cast[3] }
	end
	for k, v in pairs(type(opts.target) == "table" and opts.target or {}) do
		target[k] = v
	end
	target.cast = target.cast or { name = "Snap", texture = 132200, start = 9000, finish = 11500, spellID = 999 }
	-- RENDER_TARGET_CAST=off: the target casts nothing.
	if os.getenv("RENDER_TARGET_CAST") == "off" then
		target.cast = nil
	end
	-- RENDER_TRACKERS=moment: the target loses health as the class's story runs.
	if os.getenv("RENDER_TRACKERS") == "moment" then
		local from, to, over = unpack(STORY_HEALTH[class] or { 0.8, 0.5, 6 })
		local share = math.min(1, (tonumber(os.getenv("RENDER_TRACKERS_T") or "") or over) / over)
		target.health = math.floor(target.healthMax * (from + (to - from) * share))
	end
	if opts.target == false then
		target = nil
	end
	local pet
	if spec.pet then
		pet = { name = spec.pet.name, level = spec.pet.level, health = spec.pet.health, healthMax = spec.pet.healthMax, power = spec.pet.power, powerMax = spec.pet.powerMax, powerType = spec.pet.powerType, powerToken = spec.pet.powerToken, reaction = 5 }
	end
	-- Under Frames the player frame's own row shows the crown the game feeds, as the action bars' crest does under Medallions.
	local crown = Hud.Style() == "Frames" and Hud.Crown(opts)
	local cue
	-- Round portraits: the owner chose the mockup's round shape as the default on 2026-11-08.
	local env, K, ns = U.New(Common.ScreenOpts({
		saved = saved(opts, "UnitFrames", {
			dangerEdge = os.getenv("RENDER_DANGER") ~= "previous", cleanLowRing = os.getenv("RENDER_DANGER") ~= "previous",
			player = { portraitShape = "round" }, target = { portraitShape = "round", style = os.getenv("RENDER_TARGET_STYLE") },
		}, { "ActionBars" }),
		setup = function(env)
			shared(env, opts)
			env._units.player = player
			env._units.target = target
			env._units.pet = pet
			-- The boss you target is one unit under both tokens, as in the game, so the boss card marks it. In a fight
			-- the boss targets you, so the target of target shows beside the sigil.
			env._units.boss1 = opts.boss and opts.target == opts.boss and target or opts.boss
			env._units.targettarget = opts.boss and target and player or nil
			env._comboPoints = opts.combo or spec.combo or 0
			env._resting = os.getenv("RENDER_RESTING") == "1"
			if os.getenv("RENDER_UNIT_STATUS") == "1" then
				player.combat, player.leader, player.role = true, true, "DAMAGER"
				if target then target.combat, target.marker = true, 8 end
			end
			if crown then
				dofile("Tools/regression/aura_slots.lua").Install(env)
				env.C_SpellBook = env.C_SpellBook or {}
				env.C_SpellBook.IsSpellKnown = function(id) return id == CROWN_KNOWN[crown] end
			end
			env.UnitClass = function(token)
				local u = env._units[token]
				if u and u.class then
					return u.class:sub(1, 1) .. u.class:sub(2):lower(), u.class, 1
				end
			end
			cue = Hud.CastCues(env, class)
			if target and cue == "locked" then target.cast.notInterruptible = true end
			if target and cue then
				target.cast.start, target.cast.finish = target.cast.start - Hud.CUES_T * 1000, target.cast.finish - Hud.CUES_T * 1000
			end
		end,
	}))
	if cue == "off" then K.Options.Write("UnitFrames", "castCaster", false) end
	if os.getenv("RENDER_PLAYER_AURAS") == "on" then K.Options.Write("UnitFrames", "player.medallionsAuras", true) end
	env._time = 10
	env.SetTarget(target ~= nil)
	if player.cast then
		env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", player.cast.spellID)
	end
	if target then
		if target.cast then
			env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", target.cast.spellID)
		end
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
		-- The player's model stands in as KstyleUI's painted bust of its race and class, a humanoid target's as a human's.
		local bust = token == "player" and K.Medallions.PortraitPath("player", "bust") or token == "target" and target and target.creature == "Humanoid" and HUMANOID_BUST
		if token == "pet" and spec.pet and spec.pet.portrait then
			texture:SetTexture(spec.pet.portrait)
			notes[#notes + 1] = "the pet portrait is its summoning spell's icon; the game draws the pet's model"
		elseif bust then
			texture:SetTexture(bust)
			notes[#notes + 1] = "the " .. token .. " portrait is KstyleUI's painted bust (" .. bust .. "); the game draws the unit's model"
		else
			notes[#notes + 1] = standIn(texture, name, 0.33, 0.28, 0.22, "the " .. tostring(token) .. " portrait")
		end
	end
	table.sort(notes)
	-- opts.targetAuras ({ icon, "time", "count" } each): your debuffs on a target that is no boss, in the same sockets.
	if (opts.boss or opts.targetAuras) and target then
		notes[#notes + 1] = sigilSockets(env, K, ns, ns.Frames.Get("target").views[1], opts.targetAuras)
	end
	-- RENDER_LOSS=1 (or opts.loss): the player and the target were hit 0.12 s before the scene's clock, so their health
	-- bars show the pale band of health just lost, the fading hit flash and the spark, as in a fight.
	if opts.loss or os.getenv("RENDER_LOSS") == "1" then
		local clock = env._now
		env._now = env._time - LOSS_AGO
		for _, token in ipairs({ "player", "target" }) do
			local u = env._units[token]
			if u and u.health and u.healthMax then
				local now = u.health
				u.health = math.min(u.healthMax, now + math.floor(u.healthMax * LOSS_SHARE[token]))
				env.FireEvent("UNIT_HEALTH", token)
				u.health = now
				env.FireEvent("UNIT_HEALTH", token)
			end
		end
		env._now = clock
		local who = "the player lost " .. LOSS_SHARE.player * 100 .. "% and the target "
		notes[#notes + 1] = who .. LOSS_SHARE.target * 100 .. "% of their health " .. LOSS_AGO .. " s ago (RENDER_LOSS)"
	end
	if select(3, Hud.Pips()) then
		K.Options.Write("UnitFrames", "resource.classPips", false)
	end
	-- The action bars' scene is its own client: under Medallions its crest's crown shows the points, as in the game,
	-- and a cat-form druid's bar sits on a stand-in of the crown's seat, placed where that scene puts it.
	if K.HudStyle.Current() == "medallions" then
		local seat = env.CreateFrame("Frame", nil, env.UIParent)
		seat:SetSize(1, 1)
		seat:SetPoint("CENTER")
		if class == "DRUID" and Hud.Pips() and ns.Resource.state.showMana then
			local line = select(2, modules.actionbars(opts)).SlabCrown.state.line
			local r, scale = Scene.RectSolver(line._env):rect(line), env.UIParent:GetScale()
			seat:SetPoint("CENTER", env.UIParent, "BOTTOMLEFT", (r[1] + r[3]) / 2 / scale, (r[2] + r[4]) / 2 / scale)
		end
		K.Widgets.SetClassCrown(seat)
	end
	notes[#notes + 1] = PlayPips(env, K, function(n)
		env._comboPoints = n
		if crown then SetCrown(env, crown, n) end
	end)
	local scene = build(env, opts, { time = env._time }, function()
		Fx.Apply(env, "unitframes", ns, notes)
		if cue == "interrupted" and target then
			local id = target.cast.spellID
			target.cast = nil
			env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "target", "Cast-1", id, "Player-2", 1)
		end
	end)
	for _, note in ipairs(notes) do
		scene.log[#scene.log + 1] = note
	end
	return finish(env, K, scene, "unitframes"), ns
end

-- Action bars: bar 1 and bar 2 filled with the class's icons, one on cooldown, one proc, one pressed, one
-- disabled; the stance bar when the class has forms; the pet bar when it has a pet.

function modules.actionbars(opts)
	local AB = dofile("Tools/regression/actionbars_env.lua")
	local travel = rawget(_G, "RENDER_TRAVEL") or os.getenv("RENDER_TRAVEL")
	local class, spec = Hud.Class(opts)
	local bar1, bar2 = slots(spec.bar1), slots(spec.bar2)
	local env, K, ns = AB.New({
		class = class,
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		saved = saved(opts, "ActionBars"),
		setup = function(env)
			shared(env, opts)
			local kind = Hud.Crown(opts)
			if kind then
				dofile("Tools/regression/aura_slots.lua").Install(env)
				-- A hunter's crown is drawn with its Summon Hawk perches (1293241), which share the crest, on or off.
				env.C_SpellBook = env.C_SpellBook or {}
				env.C_SpellBook.IsSpellKnown = function(id) return id == CROWN_KNOWN[kind] or kind == "HUNTER" and id == 1293241 end
				env.GetTotemInfo = function() return false, "", 0, 0, 0, 1, 0 end
				env.GetTotemDuration = function() return { start = 0, finish = 0 } end
			end
			if opts.vehicle then
				env.UnitHasVehicleUI = function() return true end
				env.CanExitVehicle = function() return true end
			end
			local keys = opts.keys or { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }
			local keys2 = opts.keys2 or { "Q", "W", "E", "R", "T", "Y", "V", "I", "O", "P", "L", "1" }
			for i = 1, 12 do
				env._game.bindings["ACTIONBUTTON" .. i] = { keys[i] }
				env._game.bindings["MULTIACTIONBAR1BUTTON" .. i] = { keys2[i] }
			end
			if os.getenv("RENDER_BOUND_ACTIONS") == "1" then
				local commands = { [3] = "MULTIACTIONBAR3BUTTON", [4] = "MULTIACTIONBAR4BUTTON", [5] = "MULTIACTIONBAR2BUTTON" }
				for slot in pairs(opts.slots or {}) do
					local page, index = math.floor((slot - 1) / 12) + 1, (slot - 1) % 12 + 1
					if commands[page] then env._game.bindings[commands[page] .. index] = { "SHIFT-" .. index } end
				end
			end
			env.GetBindingText = function(key)
				return key
			end
			-- RENDER_GAMEPAD (Letters, Shapes or Reverse, the pad's labelStyle) binds bars 1 and 2 to pad keys and makes the pad active.
			local pad = os.getenv("RENDER_GAMEPAD")
			if pad then
				for i, key in ipairs({ "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT", "PAD4", "PAD2", "PAD1", "PAD3" }) do
					env._game.bindings["ACTIONBUTTON" .. i] = { key }
					env._game.bindings["MULTIACTIONBAR1BUTTON" .. i] = { "SHIFT-" .. key }
				end
				env.IsBindingForGamePad = function(key) return key:find("PAD", 1, true) ~= nil end
				env.IsUsingGamepad = function() return true end
				env.C_GamePad = { IsEnabled = function() return true end, GetActiveDeviceID = function() return 1 end, GetDeviceMappedState = function() return { labelStyle = pad } end }
				env.C_Texture = env.C_Texture or {}
				env.C_Texture.GetAtlasInfo = Scene.AtlasInfo
			end
			-- The game lists the class's forms (GetNumShapeshiftForms); the bar shows one button per form.
			for i, form in ipairs(spec.forms or {}) do
				env._game.forms[i] = { texture = form[2], isActive = form[3] == true, spellID = 7000 + i }
			end
			if class == "SHAMAN" and TotemScene.Story() then TotemScene.Install(env) end
			if TrackerScene.Story(class) then TrackerScene.Install(env, class) end
			-- The player's race, which picks the Medallions crest with the class, as the unit frames draw it (Hud.RACES).
			env.UnitRace = env.UnitRace or function()
				local race = Hud.RACES[(Hud.Class(opts))] or "Human"
				return race, race, 1
			end
			env.UnitSex = env.UnitSex or function()
				return 2
			end
			-- The player's level, which the Medallions hub's plaque shows, as the unit frames draw it (Hud.Player).
			env.UnitLevel = env.UnitLevel or function()
				return Hud.Player(opts).level
			end
			-- The player's combo points, holy power or soul shards, which the Medallions hub's jewels light (spec.combo, else 3 of 5).
			env.GetComboPoints = env.GetComboPoints or function()
				return env._pips or spec.combo or 0
			end
			if Hud.Pips() or Hud.Crown(opts) then
				env.UnitPowerType = function()
					return Hud.Player(opts).powerType
				end
			end
			env.UnitPower = env.UnitPower or function()
				return spec.combo or 3
			end
			-- RENDER_FOREVER_POWERS=1 gives soul shards (7) and holy power (9) no maximum, as Forever does, so no jewels show.
			env.UnitPowerMax = env.UnitPowerMax or function(_, power)
				return os.getenv("RENDER_FOREVER_POWERS") == "1" and (power == 7 or power == 9) and 0 or 5
			end
			-- The client's seconds formatter, which the sockets put on their cooldown numbers ("4s").
			if travel then
				env._resolveRects = true
				dofile("Tools/regression/travel_fixture.lua").Install(env, travel:find("mage", 1, true) ~= nil)
			end
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
	if select(3, Hud.Pips()) then
		K.Store.Profile().UnitFrames = { resource = { classPips = false } }
	end
	AB.Enable(env, K)
	local consumables = tonumber(rawget(_G, "RENDER_CONSUMABLES") or os.getenv("RENDER_CONSUMABLES") or "")
	if consumables and ns.Consumables then
		local items = { { 13446, 134834 }, { 13444, 134856 }, { 5510, 135230 }, { 14530, 133682 }, { 22895, 134029 }, { 8079, 132805 }, { 18253, 134828 }, { 20452, 133971 }, { 13510, 134842 }, { 13452, 134812 }, { 20007, 134825 }, { 954, 134938 } }
		env.C_Container = {
			GetContainerNumSlots = function(bag) return bag == 0 and math.min(12, consumables) or 0 end,
			GetContainerItemInfo = function(_, slot) return { itemID = items[slot][1], iconFileID = items[slot][2], stackCount = slot + 2 } end,
		}
		local rows = tonumber(os.getenv("RENDER_CONSUMABLE_ROWS") or "2")
		for i = 1, 12 do env._game.bindings["CLICK KstyleUI_Consumable" .. i .. ":LeftButton"] = { "SHIFT-" .. ((i - 1) % 9 + 1) } end
		env.C_Item = { GetItemCooldown = function(id) return id == 13446 and 5 or 0, id == 13446 and 120 or 0, 1 end }
		K.Options.Write("ActionBars", "consumables.rows", rows)
		K.Options.Write("ActionBars", "consumables.hotkey", os.getenv("RENDER_CONSUMABLE_KEYS") == "1")
		K.Options.Write("ActionBars", "consumables.count", os.getenv("RENDER_CONSUMABLE_COUNTS") ~= "0")
		ns.Consumables.Refresh()
		for i, b in ipairs(ns.Consumables.buttons) do b.cooldown:GetScript(i == 1 and "OnShow" or "OnHide")(b.cooldown) end
	end
	-- Each bar's shape as Layout > Apply writes it for the layout (rows and growth), so the pet and stance bars draw
	-- the footprint the layout reserves for them.
	for _, entry in ipairs(K.Setup.Layouts.Settings(opts.layout or "DPS")) do
		if entry.module == "ActionBars" and (entry.key:find("%.rows$") or entry.key:find("%.growth$")) then
			K.Options.Write("ActionBars", entry.key, entry.value)
		end
	end
	if os.getenv("RENDER_STANCE_BACKING") == "1" then K.Options.Write("ActionBars", "stance.backing", true) end
	env.RunTimers()
	for i = 1, 12 do
		if bar1[i] then
			env._game.slots[i] = { texture = bar1[i], type = "spell", id = 1000 + i }
		end
		if bar2[i] then
			env._game.slots[60 + i] = { texture = bar2[i], type = "spell", id = 2000 + i }
		end
	end
	-- opts.slots ({ [action slot] = icon }) fills further slots: the right-hand columns are bars 4 and 5, slots 25 to 48.
	for slot, icon in pairs(opts.slots or {}) do
		env._game.slots[slot] = { texture = icon, type = "spell", id = 3000 + slot }
	end
	if opts.vehicle then
		env._game.vehicle = 12
		for i = 1, 12 do
			env._game.slots[132 + i] = env._game.slots[i]
		end
		env.RunStateDrivers()
		env.FireEvent("UNIT_ENTERED_VEHICLE", "player")
	end
	-- States: slot 3 on an 8 s cooldown with 4 s left, slot 7 procs, slot 6 disabled, slot 2 pressed (for the
	-- warrior: Charge, Overpower, Execute and Slam). opts.barStates == false leaves every button at rest.
	local states = opts.barStates ~= false
	if states then
		env._game.slots[3].cooldown = { start = 6, finish = 14, remaining = 4, total = 8 }
		env._game.procs[1007] = true
		env._game.slots[6].usable = false
		env._game.slots[12] = nil
	end
	for i = 1, 12 do
		env.FireEvent("ACTIONBAR_SLOT_CHANGED", i)
		env.FireEvent("ACTIONBAR_SLOT_CHANGED", 60 + i)
	end
	for slot in pairs(opts.slots or {}) do
		env.FireEvent("ACTIONBAR_SLOT_CHANGED", slot)
	end
	env.FireEvent("ACTIONBAR_UPDATE_COOLDOWN")
	if states then
		env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 1007)
		env.FireEvent("ACTION_USABLE_CHANGED", { { slot = 6, usable = false, noMana = false } })
		local pressed = AB.Button(ns, "bar1", 2)
		AB.W.Down(pressed)
		-- The game runs a cooldown frame's OnShow when its swipe starts; the stub leaves that to the scene.
		local charging = AB.Button(ns, "bar1", 3)
		charging.cooldown:Show()
		charging.cooldown:GetScript("OnShow")(charging.cooldown)
	end
	env.RunTimers()
	AB.W.Settle(env)
	-- RENDER_MEDALLIONS_STATE (under Medallions) puts the slots beside the hub to work, so a crop shows
	-- them over every hub layer: bar 2's first slot on an 8 s cooldown with 4 s left, then calm (nothing more), combat
	-- (entering combat 0.3 s ago: the shockwave and the sweep halfway), proc (a fresh proc on bar 1's slot 12, beside the hub,
	-- or the nearest filled slot before it, 0.3 s in) or levelup (level 12, 0.4 s into the burst, which spreads under the slots either side).
	local slabState = os.getenv("RENDER_MEDALLIONS_STATE")
	if slabState and slabState ~= "" then
		local ago = ({ calm = 0, combat = 0.3, proc = 0.3, levelup = 0.4 })[slabState]
		assert(ago, "RENDER_MEDALLIONS_STATE must be calm, combat, proc or levelup")
		assert(ns.Slab and ns.Slab.Active(), "RENDER_MEDALLIONS_STATE needs the Medallions HUD style")
		env._game.slots[61].cooldown = { start = 6, finish = 14, remaining = 4, total = 8 }
		env.FireEvent("ACTIONBAR_UPDATE_COOLDOWN")
		local charging = AB.Button(ns, "bar2", 1)
		charging.cooldown:Show()
		charging.cooldown:GetScript("OnShow")(charging.cooldown)
		local clock = env._now
		env._now = env._time - ago
		if slabState == "combat" then
			env.SetCombat(true)
		elseif slabState == "proc" then
			local beside
			for i = 12, 1, -1 do
				beside = beside or AB.Button(ns, "bar1", i).spellID
			end
			env._game.procs[beside] = true
			env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", beside)
		elseif slabState == "levelup" then
			env.FireEvent("PLAYER_LEVEL_UP", 12)
		end
		env._now = clock
	end
	local crown = Hud.Crown(opts)
	local notes = { PlayPips(env, K, function(n)
		env._pips = n
		if crown then SetCrown(env, crown, n) end
	end) }
	local scene = build(env, opts, { time = env._time }, function()
		Fx.Apply(env, "actionbars", ns, notes)
		if class == "SHAMAN" and TotemScene.Story() then TotemScene.Play(env, K, ns, AB, notes) end
		if TrackerScene.Story(class) then TrackerScene.Play(env, K, ns, notes) end
		if travel then
			K.Options.Write("ActionBars", "crestTravel", not travel:find("before", 1, true))
			if ns.Travel.crest and ns.Travel.crest:IsShown() then ns.Travel.Prepare(); AB.Click(env, ns.Travel.crest, "RightButton", false) end
		end
		if consumables and ns.Consumables and os.getenv("RENDER_CONSUMABLE_FREE") == "1" then
			K.Options.Write("ActionBars", "consumables.attached", false)
			K.Layout.Set("consumables.bar", "x", -600)
			K.Layout.Set("consumables.bar", "y", 400)
		end
	end)
	for _, note in ipairs(notes) do
		scene.log[#scene.log + 1] = note
	end
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

-- The utility cooldowns a fallback scene shows when the class tracks none, so Blizzard's utility row has items.
local FALLBACK_UTILITY = {
	{ "Purge", 136075, { 8, 3 } }, { "Ghost Wolf", 136095 }, { "Earthbind Totem", 136102, { 15, 9 } }, { "Healing Stream Totem", 135127 },
}

-- opts.cooldownFallback (or RENDER_COOLDOWN_FALLBACK=1) draws the fallback: every group restyles Blizzard's own viewer,
-- as when the mirror cannot run, and the essential and utility viewers stand where Edit Mode puts them, Apply's
-- anchors when Apply placed them, else the managed bottom stack (NativeViewers).
function modules.cooldowns(opts)
	local C = dofile("Tools/regression/cooldowns_env.lua")
	local _, spec = Hud.Class(opts)
	spec = Tracked(spec, opts.tracked)
	local fallback = opts.cooldownFallback == true or os.getenv("RENDER_COOLDOWN_FALLBACK") == "1"
	if fallback and #spec.utility == 0 then
		local copy = {}
		for key, value in pairs(spec) do
			copy[key] = value
		end
		copy.utility = FALLBACK_UTILITY
		spec = copy
	end
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
			-- RENDER_COOLDOWN_VIEWER=off: Blizzard's Cooldown Manager switched off, its viewers hidden as UpdateShownState hides them.
			if os.getenv("RENDER_COOLDOWN_VIEWER") == "off" then
				env.C_CVar = { GetCVarBool = function(name) if name == "cooldownViewerEnabled" then return false end end }
				for _, viewer in pairs(env._viewers) do viewer:Hide() end
			end
			Common.ForceScreen(env, true)
			env.C_Spell.GetSpellName = function(spell)
				return names[spell] or ("Spell " .. spell)
			end
			for spell, texture in pairs(textures) do
				env._cdm.textures[spell] = texture
			end
		end,
	})
	-- RENDER_COOLDOWN_PARITY=1: EllesmereUI parity round 1 switched on, spell rules named as the reference shaman's spells.
	if os.getenv("RENDER_COOLDOWN_PARITY") == "1" then
		for key, value in pairs({ ["rules.fade"] = "Stoneclaw Totem", ["rules.tint"] = "Earth Shock", ["rules.hideReady"] = "Searing Totem", closeGaps = true,
			glowsInCombat = true, ["essential.timerPosition"] = "TOP", ["buffs.inactiveShade"] = "colour", ["essential.hideZero"] = true, ["essential.vertical"] = true }) do
			K.Options.Write("Cooldowns", key, value)
		end
	end
	-- RENDER_COOLDOWN_PARITY=2: round 2 switched on over KstyleUI rows: tenths below its own 30 seconds and an own countdown
	-- colour on the first cooling essential spell, an own swipe colour on the second, the last hidden with its gap closed,
	-- utility numbers only, the first tracked buff glowing, and the bars renamed, filling up with a spark.
	if os.getenv("RENDER_COOLDOWN_PARITY") == "2" then
		local cooling, last, buff, bar = {}, nil, nil, nil
		for _, entry in ipairs(entries) do
			if entry.group == "essential" then
				last = entry.name
				if type(entry.state) == "table" then cooling[#cooling + 1] = entry.name end
			end
			buff = buff or entry.group == "buffs" and entry.name or nil
			bar = bar or entry.group == "bars" and entry.name or nil
		end
		for key, value in pairs({ path = "mirror", ["rules.decimals"] = cooling[1] and cooling[1] .. "=30" or "",
			["rules.timerColour"] = (cooling[1] or "") .. " #FFB000", ["rules.tint"] = (cooling[2] or "") .. " #3070FF", ["rules.hide"] = last or "", ["rules.shift"] = last or "",
			["utility.numbersOnly"] = true, ["rules.activeGlow"] = buff or "", ["rules.names"] = bar and bar .. "=Shield" or "",
			["bars.fillUp"] = true, ["bars.spark"] = true, ["bars.smooth"] = true }) do
			K.Options.Write("Cooldowns", key, value)
		end
	end
	-- RENDER_COOLDOWN_PARITY=3: round 3 switched on over KstyleUI rows: the first cooling essential countdown red below
	-- 30 seconds, the last essential spell swept by a main hand swing and glowing late in it, numbers over the proc
	-- glow, a two-row essential grid with a smaller second row, and an equipped trinket with no use effect.
	local swing
	if os.getenv("RENDER_COOLDOWN_PARITY") == "3" then
		local cooling, last = nil, nil
		for _, entry in ipairs(entries) do
			if entry.group == "essential" then
				last = entry.name
				if type(entry.state) == "table" then cooling = cooling or entry.name end
			end
		end
		swing = last
		env.GetInventoryItemID = function(_, slot) return slot == 13 and 1 or nil end
		env.GetInventoryItemTexture = function() return 133283 end
		env.GetInventoryItemCooldown = function() return 0, 0, 1, false end
		for key, value in pairs({ path = "mirror", ["rules.threshold"] = cooling or "", thresholdBelow = 30, ["rules.swing"] = last or "",
			["rules.swingGlow"] = last or "", textAboveGlow = true, ["essential.rows"] = 2, ["essential.baseCount"] = 4,
			["essential.secondSize"] = -6, ["utility.trinkets"] = true }) do
			K.Options.Write("Cooldowns", key, value)
		end
	end
	-- RENDER_COOLDOWN_PARITY=4: round 4 switched on over KstyleUI rows: each essential spell on its own main bar slot
	-- with keys 1 to 5 and Shift-1, an equipped trinket with a rank-3 crafted quality, and the first two cooling
	-- essential spells as cooldown bars beside the tracked buff bars, the second with two charges split by a line
	-- and its recharging section shaded.
	local charged
	if os.getenv("RENDER_COOLDOWN_PARITY") == "4" then
		local held, keys, cooling, n = {}, {}, {}, 0
		for _, entry in ipairs(entries) do
			if entry.group == "essential" then
				n = n + 1
				held[entry.spell], keys["ACTIONBUTTON" .. n] = { n }, n == 6 and "SHIFT-1" or tostring(n)
				if type(entry.state) == "table" then cooling[#cooling + 1] = entry end
			end
		end
		local no = function() return false end
		env.C_ActionBar = { FindSpellActionButtons = function(spell) return held[spell] or {} end, GetActionBarPage = function() return 1 end,
			HasVehicleActionBar = no, HasOverrideActionBar = no, HasTempShapeshiftActionBar = no, HasBonusActionBar = no }
		env.GetBindingKey = function(command) return keys[command] end
		env.GetInventoryItemID = function(_, slot) return slot == 13 and 1 or nil end
		env.GetInventoryItemTexture = function() return 133283 end
		env.GetInventoryItemCooldown = function() return 0, 0, 1, false end
		env.C_TradeSkillUI = { GetItemCraftedQualityByItemInfo = function() return 3 end }
		charged = cooling[2]
		if charged then
			cooldowns[charged.id].charges = true
			env.C_Spell.GetSpellCharges = function(spell) if spell == charged.spell then return { currentCharges = 1, maxCharges = 2, isActive = true } end end
		end
		for key, value in pairs({ path = "mirror", ["essential.keybind"] = true, ["utility.trinkets"] = true, ["utility.itemQuality"] = true,
			["rules.cdBars"] = (cooling[1] and cooling[1].name or "") .. (charged and ", " .. charged.name or ""), ["bars.count"] = 4,
			["bars.hashLines"] = true, ["bars.chargeShade"] = true }) do
			K.Options.Write("Cooldowns", key, value)
		end
	end
	-- RENDER_COOLDOWN_PARITY=5: round 5 switched on over KstyleUI rows: a custom bar group named Burst with the first
	-- cooling essential spell, above the tracked bars, which keep the second as a cooldown bar.
	if os.getenv("RENDER_COOLDOWN_PARITY") == "5" then
		local cooling = {}
		for _, entry in ipairs(entries) do
			if entry.group == "essential" and type(entry.state) == "table" then cooling[#cooling + 1] = entry.name end
		end
		for key, value in pairs({ path = "mirror", ["rules.group"] = cooling[1] or "", ["rules.cdBars"] = cooling[2] or "", ["custom.name"] = "Burst" }) do
			K.Options.Write("Cooldowns", key, value)
		end
	end
	local cdm = env._cdm
	local now = 10
	env._time = now
	if charged then
		local state = charged.state
		cdm.chargeDurations[charged.spell] = { kind = "charge", start = now - (state[1] - state[2]), finish = now + state[2] }
	end
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
	if fallback then
		items.essential, items.utility = {}, {}
		K.Options.Write("Cooldowns", "path", "reskin")
	end
	for _, entry in ipairs(entries) do
		local list = items[entry.group]
		local state = type(entry.state) == "table" and entry.state or {}
		if list then
			list[#list + 1] = { id = entry.id, icon = entry.icon, name = entry.name, left = state[2], total = state[1] }
		end
	end
	local _, told, rows = Hud.NativeViewers(env, C, opts.layout or "DPS", items, nil, fallback)
	C.Enable(env, K)
	env.FireEvent("PLAYER_ENTERING_WORLD", true, false)
	for _, spell in ipairs(procs) do
		env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", spell)
	end
	env.RunTimers()
	if swing then
		local after, late = env.C_Timer.After, nil
		env.C_Timer.After = function(delay, fn) if delay > 0 then late = late or fn else after(delay, fn) end end
		env._time = now - 2
		env.FireEvent("PLAYER_SWING", 2.6, 0)
		env._time = now
		env.C_Timer.After = after
		late()
		env.RunTimers()
	end
	C.W.Settle(env)
	local scene = build(env, opts, { time = env._time })
	scene.log[#scene.log + 1] = "cooldowns: " .. ns.Mirror.Report() .. "; Blizzard's tracked buff viewers at Apply's Edit Mode anchors" .. (#told > 0 and (", and Apply said: " .. table.concat(told, " ")) or "")
	if fallback then
		scene.log[#scene.log + 1] = "cooldowns: the fallback; Blizzard's essential and utility viewers " .. rows
	end
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

-- opts.chatLines and opts.chatTabs replace the session's lines and the docked windows' names; opts.chatClock
-- ({ year, month, day, hour, min }) is the time the first line is stamped with.
function modules.chat(opts)
	local C = dofile("Tools/regression/chat_env.lua")
	local lines, tabs = opts.chatLines or CHAT_LINES, opts.chatTabs or CHAT_TABS
	local env, K, ns = C.New({
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		saved = saved(opts, "Chat"),
		install = { frames = #tabs },
		setup = function(env)
			shared(env, opts)
			env._now = os.time(opts.chatClock or { year = 2026, month = 11, day = 7, hour = 14, min = 31, sec = 0 })
			local dock = env.GENERAL_CHAT_DOCK
			for i, name in ipairs(tabs) do
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
	applyPreset(env, opts)
	Common.ChatSettings(env, K)
	local chat = env.ChatFrame1
	local stamp = env._cvars.showTimestamps
	local function stamped(text)
		if type(stamp) == "string" and stamp ~= "none" then
			return os.date(stamp, env.time()) .. text
		end
		return text
	end
	for _, line in ipairs(lines) do
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
	-- RENDER_CHAT_TYPING="text" types into the general window's edit box, so its font shows. The stub's SetFocus does
	-- not make HasFocus answer, and the module hides an unfocused box, so the scene answers for the game.
	local typing = os.getenv("RENDER_CHAT_TYPING")
	if typing then
		local box = chat.editBox
		box:SetText(typing)
		box.HasFocus = function() return true end
		box:SetFocus()
		local gained = box:GetScript("OnEditFocusGained")
		if gained then gained(box) end
	end
	C.Dock(env, Scene.TextWidth)
	env.RunTimers()
	C.W.Settle(env)
	-- ScrollingMessageFrame.lua: RefreshLayout anchors width-constrained messages bottom-to-top with font spacing;
	-- InitializeFontString keeps wrapping enabled, and FontStringContainer clips scrolling content (70862).
	local path, size, flags = chat:GetFont()
	path, size, flags = path or "Fonts\\ARIALN.TTF", size or 14, flags or ""
	-- The window's width comes from its anchors in the panel, in its own units.
	local _, _, screenWidth = Scene.Rect(env, chat)
	local toOwn = 768 / 1080 / chat:GetEffectiveScale()
	local width = (screenWidth or 300 * 1080 / 768) * toOwn
	local entries = C.Entries(chat)
	local spacing = chat:GetSpacing()
	spacing = type(spacing) == "number" and spacing or 0
	local container = env.CreateFrame("Frame", nil, chat)
	chat.FontStringContainer = container
	container:SetAllPoints(chat)
	container:SetClipsChildren(true)
	local content = env.CreateFrame("Frame", nil, container)
	content:SetAllPoints(container)
	local previous
	for i = #entries, 1, -1 do
		local entry = entries[i]
		local text = content:CreateFontString(nil, "ARTWORK")
		text:SetFont(path, size, flags)
		text:SetJustifyH("LEFT")
		text:SetJustifyV("BOTTOM")
		text:SetWordWrap(true)
		text:SetNonSpaceWrap(true)
		text:SetWidth(width)
		-- A line of the game's ScrollingMessageFrame is as tall as its font, not 1.2 em: CalculateLineSpacing reads the font string's
		-- GetLineHeight (ScrollingMessageFrame.lua 730-735) and each line stands on the one before it plus GetSpacing (lines 595-602).
		text._lineEm = 1
		text:SetSpacing(spacing)
		if previous then
			text:SetPoint("BOTTOMLEFT", previous, "TOPLEFT", 0, spacing)
		else
			text:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT")
		end
		text:SetTextColor(entry[2] or 1, entry[3] or 1, entry[4] or 1)
		text:SetText(tostring(entry[1]))
		previous = text
	end
	local scene = build(env, opts, nil, function()
		-- Settle the stub's pending size callbacks before the native tab update.
		Scene.Build(env)
		local dock = env.GENERAL_CHAT_DOCK
		for _, frame in ipairs(dock.DOCKED_CHAT_FRAMES) do
			env.FCFTab_UpdateColors(env[frame:GetName() .. "Tab"], frame == dock.selected)
		end
	end)
	scene.log[#scene.log + 1] = "chat lines are laid out by the scene; the game's ScrollingMessageFrame wraps and spaces them itself"
	scene.log[#scene.log + 1] = "chat tabs are laid out by the scene as Blizzard's dock lays them; the game fades them when the pointer is away"
	return finish(env, K, scene, "chat"), ns
end

-- Loot feed: the lines QoL draws over the chat card for the loot of the mockup's session: a Bug Eye and a Worn Leather
-- Vest (their links say IQ0 in the game; the item API gives poor and common) and 14 copper -------------------------

local FEED_ITEMS = {
	{ 7101, "Bug Eye", 133884, 0 },
	{ 1425, "Worn Leather Vest", 135009, 1 },
}

function modules.lootfeed(opts)
	local Q = dofile("Tools/regression/qol_env.lua")
	local env, K, ns = Q.New({
		saved = saved(opts, "QoL"),
		setup = function(env)
			shared(env, opts)
		end,
	})
	assert(K.Modules.IsRunning("QoL"), "QoL runs from the saved switch")
	local function say(event, text)
		env.FireEvent(event, text, "Korallis", "", "", "Korallis", "", 0, 0, "", 0, 1, "Player-1-1", 0)
		env.RunTimers()
		Q.W.Settle(env)
	end
	for _, item in ipairs(opts.feed or FEED_ITEMS) do
		env._items[item[1]] = { icon = item[3], quality = item[4] }
		local link = "|cnIQ0:|Hitem:" .. item[1] .. "::::::::11:1489:::::::::|h[" .. item[2] .. "]|h|r"
		say("CHAT_MSG_LOOT", "You receive loot: " .. link .. (item[5] and ("x" .. item[5]) or ""))
	end
	say("CHAT_MSG_MONEY", "You loot 14 Copper")
	local scene = build(env, opts)
	scene.log[#scene.log + 1] = "the feed's lines are the player's own loot, as CHAT_MSG_LOOT and CHAT_MSG_MONEY give it; the game fades each one after its hold"
	return finish(env, K, scene, "lootfeed"), ns
end

-- Minimap: the square map with the zone and clock bands; the hover-only controls stay hidden, as at rest ------

function modules.minimap(opts)
	local M = dofile("Tools/regression/minimap_env.lua")
	-- opts.zone, opts.clock ({ hour, minute, realmHour, realmMinute }) and opts.position ({ x, y }, 0 to 1) are the
	-- zone, the clock and the player's map position the module reads.
	local env, K, ns = M.New({
		enabled = true,
		boot = not opts.dataBar,
		saved = opts.dataBar and saved(opts, "Minimap", Common.PreviousFinish() and { clearPlaques = false } or nil) or nil,
		settings = { frame = os.getenv("RENDER_MINIMAP_FRAME"), clearPlaques = not Common.PreviousFinish() },
		zone = opts.zone or "Riverglades",
		position = opts.position,
		setup = function(env)
			shared(env, opts)
			Common.ForceScreen(env, true)
			env._clock = opts.clock or { hour = 14, minute = 32, realmHour = 9, realmMinute = 5 }
			for name, value in pairs(opts.cvars or {}) do
				env._cvars[name] = value
			end
		end,
	})
	if opts.dataBar then
		local D = dofile("Tools/regression/databars_env.lua")
		dofile("Tools/regression/load_files.lua")(D.Files(), env)
		M.CoreEnv.Boot(env)
	end
	M.Settle(env)
	-- The Minimap frame draws the world in the game; the mockup's map, or a flat tone, stands in, clipped as the
	-- game clips the frame.
	local _, note = Hud.Terrain(env)
	local scene = build(env, opts, { roots = { ns.Map.holder } })
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
	local Readouts = dofile("Tools/regression/databars_readouts_fixture.lua")
	local portraitNote
	local class = Hud.Class(opts)
	local env, K, ns = D.New({
		saved = saved(opts, "DataBars"),
		-- No watched faction: the mockup shows no reputation bar under the action bars.
		-- opts.game overlays the experience, level, frame rate, latency and money the module reads.
		game = merge({ xp = 16000, xpMax = 50000, rested = 6000, level = 38, faction = false }, opts.game),
		setup = function(env)
			shared(env, opts)
			Common.ForceScreen(env, true)
			Readouts(env)
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
	dofile("Tools/regression/load_files.lua")({ "KstyleUI_ActionBars/TravelData.lua" }, env)
	ns.Strip.Refresh()
	local scene = build(env, opts)
	if portraitNote then
		scene.log[#scene.log + 1] = portraitNote
	end
	return finish(env, K, scene, "databars"), ns
end

-- Auras: the player's buff and debuff rows under the minimap, five buffs with their time left -----------------

-- The engine binds each button's icon and timer itself; the stub does not, so the scene fills the buff buttons
-- with the class's buff row (_classes.lua), then more of its spells when opts.buffs asks for a longer row, and
-- lays them out as the container's flow layout would: from the corner the module anchors the container at (the
-- element's top right, under the minimap, by default), leftwards, the shortest time left first, wrapping into rows.
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

-- RENDER_AURAS_REMINDER=1 switches on the missing buff reminder (parity round 3): the class knows its reminder buff
-- and lacks it, so the buff is left off the buff row and the card names it. Its other spells get stand-in names, as the reminder reads every one.
local REMINDER = { MAGE = { 1459, "Arcane Intellect", 135932 }, PRIEST = { 1243, "Power Word: Fortitude", 135987 }, DRUID = { 1126, "Mark of the Wild", 136078 },
	WARLOCK = { 687, "Demon Skin", 136185 }, SHAMAN = { 324, "Lightning Shield", 136048 }, PALADIN = { 465, "Devotion Aura", 135893 }, HUNTER = { 13165, "Aspect of the Hawk", 136076 } }

function modules.auras(opts)
	local A = dofile("Tools/regression/auras_env.lua")
	local class, spec = Hud.Class(opts)
	local mode = os.getenv("RENDER_AURAS_REMINDER")
	local reminder = mode == "1" and REMINDER[class]
	local setting = reminder and "reminder.enabled" or ({ flask = "reminder.flasks", mana = "reminder.mana" })[mode or ""]
	local env, K, ns = A.New(Common.ScreenOpts({
		saved = saved(opts, "Auras"),
		setup = function(env)
			shared(env, opts)
			if not setting then return end
			env.C_Secrets.ShouldSpellAuraBeSecret = function() return false end
			env.C_UnitAuras = env.C_UnitAuras or {}
			env.UnitIsDeadOrGhost = function() return false end
			if reminder then
				env.C_SpellBook = { IsSpellKnown = function(id) return id == reminder[1] end }
				env.C_Spell = env.C_Spell or {}
				env.C_Spell.GetSpellName = function(id) return id == reminder[1] and reminder[2] or "Spell " .. id end
				env.C_Spell.GetSpellTexture = function(id) return id == reminder[1] and reminder[3] or nil end
				env.C_UnitAuras.GetAuraDataBySpellName = function() return nil end
			else
				-- RENDER_AURAS_REMINDER=flask: in a raid with three Flasks of the Titans and none on; =mana: a ready check at 25 percent mana.
				env.C_UnitAuras.GetPlayerAuraBySpellID = function() return nil end
				env.C_Item = { GetItemCount = function(id) return id == 13510 and 3 or 0 end, GetItemNameByID = function() return "Flask of the Titans" end, GetItemIconByID = function() return 134842 end }
				env.IsInInstance = function() return true, "raid" end
				env.Enum.PowerType = { Mana = 0 }
				env.UnitPowerMax = function() return 4000 end
				env.UnitPower = function() return 1000 end
			end
		end,
	}))
	if setting then
		K.Options.Write("Auras", setting, true)
	end
	if not K.Modules.IsRunning("Auras") then
		K.Modules.Enable("Auras")
	end
	env.RunTimers()
	if mode == "mana" then
		env.FireEvent("READY_CHECK", "Leader", 35)
		env.RunTimers()
	end
	-- RENDER_AURAS_EXTRA=1 switches on the extra buff and debuff rows (parity round 2) at their default places, the
	-- debuff one glowing, with two important buffs and one crowd control debuff.
	local extra = os.getenv("RENDER_AURAS_EXTRA") == "1"
	if extra then
		for key, value in pairs({ ["extraBuffs.enabled"] = true, ["extraDebuffs.enabled"] = true, ["extraDebuffs.glow"] = true }) do
			K.Options.Write("Auras", key, value)
		end
		env.RunTimers()
	end
	for _, container in ipairs(env._containers) do
		for _, button in ipairs(A.Buttons(container)) do
			button:Hide()
		end
	end
	local settings = K.Store.Module("Auras")
	-- opts.buffRow and opts.debuffRow ({ "Name", icon, "time" } each) replace the class's row and the warrior's debuffs.
	local buffRow = opts.buffRow or Hud.BuffRow(spec, opts.buffs or #spec.buffRow)
	if reminder then
		local kept = {}
		for _, buff in ipairs(buffRow) do
			if buff[1] ~= reminder[2] then kept[#kept + 1] = buff end
		end
		buffRow = kept
	end
	local buffs, group = A.Container(env, "HELPFUL")
	if buffs then
		local columns = ns.Model.Group(settings, "buffs").columns
		Hud.PlaceAuras(buffs, group, fillAuras(env, A, buffs, "buffs", group, buffRow), columns)
	end
	-- The engine sizes an empty container to nothing, so the debuff container is laid out even with no debuffs.
	local debuffs, harmful = A.Container(env, "HARMFUL")
	local entries = {}
	for i = 1, opts.debuffs or 0 do
		entries[i] = DEBUFF_ROW[(i - 1) % #DEBUFF_ROW + 1]
	end
	if opts.debuffRow then
		entries = opts.debuffRow
	end
	if debuffs then
		Hud.PlaceAuras(debuffs, harmful, fillAuras(env, A, debuffs, "debuffs", harmful, entries), ns.Model.Group(settings, "debuffs").columns)
	end
	for _, row in ipairs(extra and { { "HELPFUL|IMPORTANT", "extraBuffs", { buffRow[1], buffRow[2] } }, { "HARMFUL|CROWD_CONTROL", "extraDebuffs", { DEBUFF_ROW[2] } } } or {}) do
		local container, extraGroup = A.Container(env, row[1])
		Hud.PlaceAuras(container, extraGroup, fillAuras(env, A, container, row[2], extraGroup, row[3]), ns.Model.Group(settings, row[2]).columns)
	end
	-- The rows' "+N" cells are counted by the engine's layout; the stub plays that pass for the counts laid out.
	A.Counters(ns, { #buffRow, 0, #entries })
	A.W.Settle(env)
	local scene = build(env, opts)
	scene.log[#scene.log + 1] = "the buffs are laid out by the scene as the AuraContainer engine would; the game binds each icon (as a secret, so the tiles show Blizzard's art) and timer itself"
	return finish(env, K, scene, "auras"), ns
end

-- Quest card: the tracked quests on the Skins quest card, which stands in for Blizzard's objective tracker -------

local Tracker = dofile("Tools/render/scenes/_tracker.lua")
local QuestLog = dofile("Tools/regression/quests_fake.lua")

-- CardQuests(list) -> the scene's quests as the quest log fake holds them, and the super-tracked quest's id.
local function CardQuests(list)
	local out, super = {}, 0
	for i, quest in ipairs(list) do
		local objectives = {}
		for k, text in ipairs(quest.objectives) do
			objectives[k] = { text = text, finished = false }
		end
		out[i] = { id = quest.questID, title = quest.title, level = quest.level or 0, objectives = objectives, complete = quest.complete, item = quest.item }
		if quest.superTracked then
			super = quest.questID
		end
	end
	return out, super
end

function modules.tracker(opts)
	local S = dofile("Tools/regression/skins_env.lua")
	local tracker
	local env, K, ns = S.New({
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		saved = saved(opts, "Skins"),
		loaded = opts.withGuide and { RXPGuides = true } or nil,
		setup = function(env)
			shared(env, opts)
			local quests, super = CardQuests(opts.quests or Tracker.QUESTS)
			QuestLog.Install(env, quests).super = super
		end,
		before = function(env)
			tracker = QuestLog.Tracker(env, S.Blizzard(env))
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
	-- The guide renders in its own environment, so here the rail stands in for it being on screen (opts.withGuide):
	-- the quest card then holds the story slot and the guide the column.
	local rail = opts.withGuide and ns.RestedXP and ns.RestedXP.Rail
	if rail then
		function rail.Shown()
			return K.Setup.Story(K.Layout.Setting("preset") or "DPS", true) ~= nil and ns.Quests.Active()
		end
		ns.Quests.Replace()
		S.W.Settle(env)
	end
	-- The quest card stands in for Blizzard's tracker, four quests at a time, in its own Layout element: the story slot.
	local card = ns.Quests.Active()
	local scene = build(env, opts)
	local place = opts.withGuide and "in the column beside the story slot, the shown RestedXP guide's card in the top left corner" or "in the column beside the layout's story slot"
	if card then
		scene.log[#scene.log + 1] = "the quest card shows " .. #(opts.quests or Tracker.QUESTS) .. " tracked quests from a stand-in quest log, four at a time, " .. place .. "; Blizzard's tracker is hidden while it holds only quests"
	else
		scene.log[#scene.log + 1] = "the quest tracker is a stand-in laid out as Blizzard_ObjectiveTracker does; Edit Mode places the real one" .. (opts.trackerAnchor and ", here at the anchor Layout > Apply wrote into the KstyleUI Edit Mode layout, " .. place or ", at Forever's preset")
	end
	return finish(env, K, scene, "tracker"), ns, card and ns.Quests.Card() or tracker
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
			env.BreakUpLargeNumbers = tostring
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
	local cue = Hud.CastCues(env, class, true)
	if cue == "off" then K.Options.Write("Nameplates", "cast.caster", false) end
	Hud.PlateCasts(env, K, ns, class)
	local k = 768 / 1080
	local combatText = K.Modules.IsRunning("CombatText")
	-- opts.plates ({ unit = { name, level, health, maxHealth, ... }, x, y, target, cast = { name, texture, share } },
	-- in screen units) replaces the crocolisk, the oracle and the combat numbers with the plates a fixture lists.
	local plates = opts.plates
	if not plates then
		local target = type(opts.target) == "table" and opts.target or TARGET
		local cast = target.cast or { name = "Snap", texture = 132200 }
		plates = {
			{ unit = { name = target.name, health = target.health, maxHealth = target.healthMax, level = target.level, classification = target.classification, reaction = 2, canAttack = true }, x = target.plateX or PLATE_X, y = PLATE_Y, target = true, cast = { name = cast.name, text = cast.name, texture = cast.texture, notInterruptible = false, share = 0.55 } },
			{ unit = ADD.unit, x = ADD.x, y = ADD.y, cast = { name = ADD.cast.name, text = ADD.cast.text, texture = ADD.cast.texture, notInterruptible = ADD.cast.notInterruptible, share = 0.4 } },
		}
		if cue and cue ~= "off" then N.Focus(env, "nameplate2") end
	end
	for _, plate in ipairs(cue == "locked" and plates or {}) do
		if plate.cast then plate.cast.notInterruptible = true end
	end
	for i, plate in ipairs(plates) do
		local base = N.Add(env, "nameplate" .. i, plate.unit)
		base:ClearAllPoints()
		base:SetPoint("CENTER", env.WorldFrame, "BOTTOMLEFT", plate.x * k, (1080 - plate.y) * k)
		if plate.target then
			N.Target(env, "nameplate" .. i)
		end
		if plate.cast then
			N.Cast(env, "nameplate" .. i, { name = plate.cast.name, text = plate.cast.text or plate.cast.name, texture = plate.cast.texture, notInterruptible = plate.cast.notInterruptible == true })
		end
	end
	for _ = 1, 20 do
		N.Tick(env, 0.05)
	end
	for i, plate in ipairs(plates) do
		if plate.cast then
			Hud.FillCast(ns.Plates.Get("nameplate" .. i), (plate.cast.share or 0.5) + (cue and Hud.CUES_T / 2 or 0))
		end
	end
	local base = env._bases.nameplate1
	-- The heal on the player shows in KstyleUI's own field above the character; the numbers sit at
	-- the start of their travel, since the stub runs no animations.
	if combatText and not opts.plates then
		CT.Hit(env, "player", "HEAL", "", 168, 2)
	end
	local font = env.DAMAGE_TEXT_FONT
	local worldShown = env._cvars[CT.TARGETS[1]] ~= "0"
	for _, number in ipairs((opts.plates or not worldShown) and {} or WORLD_NUMBERS) do
		local text = env.WorldFrame:CreateFontString(nil, "OVERLAY")
		if type(font) == "string" then
			text:SetFont(font, number[2], "OUTLINE")
		end
		text:SetTextColor(number[3][1], number[3][2], number[3][3])
		text:SetPoint("CENTER", base, "CENTER", number[4] * k, number[5] * k)
		text:SetText(number[1])
	end
	local scene = build(env, opts, { time = env._time }, cue == "interrupted" and function()
		for i, plate in ipairs(plates) do
			if plate.cast then
				env._units["nameplate" .. i].cast = nil
				env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "nameplate" .. i, "cast-guid", 133, "Player-2")
			end
		end
	end or nil)
	if opts.plates then
		scene.log[#scene.log + 1] = "nameplates: " .. #opts.plates .. " plates where the scene puts them; the target's plate stands its cast down while the sigil shows it (cast.hideOnTarget); cast fills stand in for the engine's timer"
	else
		scene.log[#scene.log + 1] = worldShown and "the world numbers over the target are stand-ins in DAMAGE_TEXT_FONT; the game draws and sizes them itself" or "Blizzard world numbers are hidden by CombatText's damage CVar"
		scene.log[#scene.log + 1] = "nameplates: the target's plate stands its cast down while the sigil shows it (cast.hideOnTarget); the " .. ADD.unit.name .. " casts " .. ADD.cast.name .. " with the " .. class:lower() .. "'s interrupt ready, so its bar takes the accent; cast fills stand in for the engine's timer"
	end
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
		saved = saved(opts, "Tooltips", { anchor = "fixed" }),
		setup = function(env)
			shared(env, opts)
		end,
	})
	if not K.Modules.IsRunning("Tooltips") then
		K.Modules.Enable("Tooltips")
	end
	env.RunTimers()
	local threat = opts.settings and opts.settings.Meters and opts.settings.Meters.threat
	local liftNote
	if threat and threat.shown then
		local Layouts, key = K.Setup.Layouts, "meters.threat"
		local element = Layouts.Element(key)
		local card = env.CreateFrame("Frame", nil, K.Scale.Root())
		K.Widgets.Place(card, key, Layouts.Default(key), { label = element.label, module = "Meters" })
		K.Widgets.Size(card, element.width, element.height)
		liftNote = "the threat card's place stands in for the Meters module in the tooltip's environment, so the tooltip lifts over it as in the game"
	end
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
	if liftNote then
		scene.log[#scene.log + 1] = liftNote
	end
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
		members[i] = { name = m[1], class = m[2], health = m[3], maxHealth = m[5] or 100, power = 60, maxPower = 100, role = m[4], leader = i == 1 }
	end
	local player = { name = spec.name, class = class, health = 82, maxHealth = 100, power = 45, maxPower = 100, powerType = spec.power.token, role = opts.role or "DAMAGER" }
	G.SetRoster(env, opts.raid and "raid" or #members > 0 and "party" or nil, members, player)
	if not K.Modules.IsRunning("GroupFrames") then
		K.Modules.Enable("GroupFrames")
	end
	env.RunTimers()
	tick(env, 1)
	local scene = build(env, opts)
	return finish(env, K, scene, "groupframes"), ns
end

-- Meters: the damage meter over the fight in opts.damage ({ name, class, amount }, highest first), and the threat
-- meter when the layout shows it. The client has secret restrictions, as Forever does, so auto picks KstyleUI's own
-- card. With opts.meterSecret the player is in combat and the game hands every amount over as a secret.

function modules.meters(opts)
	local M = dofile("Tools/regression/meters_env.lua")
	local rows = opts.damage or {}
	local hide
	local env, K, ns = M.New(Common.ScreenOpts({
		followRole = opts.followRole,
		restricted = true,
		saved = saved(opts, "Meters"),
		setup = function(env)
			shared(env, opts)
			env.UnitGroupRolesAssigned = function() return opts.role or "DAMAGER" end
			classColours(env)
			env.UnitClass = function(unit)
				local u = env._units[unit]
				if u and u.class then
					return u.class, u.class, 1
				end
				return Hud.Class(opts)
			end
			hide = function(value)
				return opts.meterSecret and env.Secret(value) or value
			end
			-- The client's class icons (Blizzard_DamageMeter's GetClassAtlas) from the atlas cache.
			env.GetClassAtlas = function(class)
				return ("classicon-%s"):format(class)
			end
			env.C_Texture = env.C_Texture or {}
			env.C_Texture.GetAtlasInfo = Scene.AtlasInfo
			local me = opts.meterMe or 1
			local sources, total = {}, 0
			for i, row in ipairs(rows) do
				total = total + row[3]
				sources[i] = {
					name = row[1], classFilename = row[2], totalAmount = hide(row[3]), amountPerSecond = hide(row[3] / 60), sourceGUID = hide("Player-" .. tostring(row[1])),
					sourceDisplayType = 1, isLocalPlayer = i == me, deathRecapID = 0, deathTimeSeconds = 0,
				}
			end
			env._session = { combatSources = sources, maxAmount = hide(rows[1] and rows[1][3] or 0), totalAmount = hide(total), durationSeconds = 60 }
			env._group = { raid = #rows > 5, size = opts.meterSolo and 0 or #rows }
			env._units.player = { name = rows[me] and rows[me][1] or "Valerin", class = rows[me] and rows[me][2] or "WARRIOR", guid = rows[me] and ("Player-" .. tostring(rows[me][1])) or nil }
			env._units.target = { name = opts.target and opts.target.name or TARGET.name, hostile = true }
			for i, row in ipairs(rows) do
				local unit = i == 1 and "player" or ("party" .. (i - 1))
				if i == 1 and me ~= 1 then
					unit = "party" .. me
				end
				env._units[unit] = env._units[unit] or { name = row[1], class = row[2], guid = "Player-" .. tostring(row[1]) }
				env._threat[unit] = { i == 2, i == 2 and 3 or 0, 100 - i * 14, 100 - i * 16, (#rows - i + 1) * 100000 }
			end
		end,
	}))
	if opts.followRole then K.Options.Write("Meters", "followRole", true) end
	if not K.Modules.IsRunning("Meters") then
		K.Modules.Enable("Meters")
	end
	env.RunTimers()
	applyPreset(env, opts)
	if opts.meterSecret then
		env.SetCombat(true)
		env.FireEvent("PLAYER_REGEN_DISABLED")
	end
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
	-- opts.meterCasts ({ spellID, name, icon }, newest last): the player cast these 84.3 seconds into a fight, for the
	-- combat timer and spell history.
	if opts.meterCasts then
		local now = env.GetTime()
		env.SetCombat(true)
		for _, s in ipairs(opts.meterCasts) do
			env._spells[s[1]] = { name = s[2], icon = s[3] }
			env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. s[1], s[1])
		end
		env.SetTime(now + 84.3)
		env.RunTickers()
	end
	-- opts.meterHover ({ spellID, name, icon, amount }, highest first): the pointer rests on the player's row, so its
	-- split opens under the row, inside the card, with the player's top three spells of the fight, as the game reads them out of combat.
	if opts.meterHover and rows[1] then
		local spells, total = {}, 0
		for i, s in ipairs(opts.meterHover) do
			env._spells[s[1]] = { name = s[2], icon = s[3] }
			spells[i] = { spellID = s[1], totalAmount = hide(s[4]), amountPerSecond = hide(s[4] / 60), creatureName = "" }
			total = total + s[4]
		end
		env._sources["Player-" .. tostring(rows[1][1])] = { combatSpells = spells, maxAmount = spells[1].totalAmount, totalAmount = hide(total) }
		local row = ns.Damage.list.rows[1].frame
		row._scripts.OnEnter(row)
		env.RunTimers()
		tick(env, 0.3)
	end
	-- opts.meterSpells (the same shape): the player clicked their own row, so the card lists every spell of theirs.
	-- With opts.meterSolo the player is alone: the card rests on their own spells with no click.
	if opts.meterSpells and rows[1] then
		local spells, total = {}, 0
		for i, s in ipairs(opts.meterSpells) do
			env._spells[s[1]] = { name = s[2], icon = s[3] }
			spells[i] = { spellID = s[1], totalAmount = hide(s[4]), amountPerSecond = hide(s[4] / 60), creatureName = "" }
			total = total + s[4]
		end
		env._sources["Player-" .. tostring(rows[1][1])] = { combatSpells = spells, maxAmount = spells[1].totalAmount, totalAmount = hide(total) }
		if opts.meterSolo then
			env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
		else
			local row = ns.Damage.list.rows[1].frame
			local click = row:GetScript("OnClick") or row:GetScript("OnMouseUp")
			if click then
				click(row, "LeftButton")
			end
		end
		env.RunTimers()
		tick(env, 0.3)
	end
	local scene = build(env, opts)
	if opts.meterHover then
		scene.log[#scene.log + 1] = "the pointer rests on the player's row of the damage meter: its split lists the top three spells under the row"
	end
	if opts.meterSpells and not opts.meterSolo then
		scene.log[#scene.log + 1] = "the player clicked their own row of the damage meter: the card lists their spells"
	end
	return finish(env, K, scene, "meters"), ns
end

-- RestedXP: the guide window and its active step, skinned, where the skin's guide card puts it for opts.layout.
-- RestedXP's other windows stay closed.

function modules.restedxp(opts)
	local RestedXP = dofile("Tools/render/scenes/_restedxp.lua")
	RestedXP.PRESET = opts.layout
	local first = RestedXP.STEPS[1]
	RestedXP.STEPS = { { title = first.title, elements = { first.elements[1], first.elements[2] } } }
	-- opts.guide ({ title, steps, rows }) replaces the guide's name, its active steps and its step list.
	if type(opts.guide) == "table" then
		RestedXP.TITLE = opts.guide.title or RestedXP.TITLE
		RestedXP.STEPS = opts.guide.steps or RestedXP.STEPS
		RestedXP.ROWS = opts.guide.rows or RestedXP.ROWS
	end
	local R = RestedXP.Build()
	applyPreset(R.env, opts)
	-- The quest card renders in its own environment; a clear stand-in of its rect lets a stacked rail hang the guide
	-- under it, as the game does with both cards in one.
	local card = opts.questCard
	-- The quest card renders in the tracker's environment; while it is up there, the rail here sees it up.
	if card and R.ns.Quests then
		R.ns.Quests.Active = function()
			return true
		end
	end
	if card and R.ns.QuestCard then
		local root = R.K.Scale.Root()
		local standin = R.env.CreateFrame("Frame", nil, root)
		standin:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", card[1], card[2])
		standin:SetSize(card[3], card[4])
		standin:SetAlpha(0)
		R.ns.QuestCard = setmetatable({ Frame = function() return standin end }, { __index = R.ns.QuestCard })
		R.ns.RestedXP.Rail.Place()
	end
	for _, name in ipairs({ "items", "v2", "configurator" }) do
		for _, frame in ipairs(R.windows[name]) do
			frame:Hide()
		end
	end
	R.ns.RestedXP.Rail.Place()
	-- RENDER_RXP_ANCHOR=bottom anchors RestedXP's active steps under its window, as its "bottom" orientation does and as
	-- RestedXP does itself when the steps' top would pass the screen's top (GuideWindow.lua 353-391), then lays the
	-- steps out again, as its update loop does.
	if (rawget(_G, "RENDER_RXP_ANCHOR") or os.getenv("RENDER_RXP_ANCHOR")) == "bottom" then
		R.rxp.settings.profile.anchorOrientation = "bottom"
		R.rxp.RXPFrame.SetStepFrameAnchor()
		R.rxp.RXPFrame.CurrentStepFrame.UpdateText()
		R.env.RunTimers()
		R.ns.RestedXP.Rail.Place()
	end
	-- RENDER_RXP_BOXES=1 shows both boxes with one icon; =click also changes RestedXP's target scale and clicks its
	-- locked title without moving it, reproducing a false drag that used to release both boxes (#484).
	local boxes = rawget(_G, "RENDER_RXP_BOXES") or os.getenv("RENDER_RXP_BOXES")
	if boxes == "1" or boxes == "click" then
		local rxp, UIParent = R.rxp, R.env.UIParent
		local items, itemParts = R.Fake.Box(rxp, "items")
		local targets, targetParts = R.Fake.Box(rxp, "targets")
		items:ClearAllPoints()
		items:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -47.7, 242.5)
		targets:ClearAllPoints()
		targets:SetPoint("RIGHT", UIParent, "RIGHT", -191.5, -276.6)
		rxp.targeting:UpdateTargetFrame(1, 0)
		rxp.UpdateItemFrame(nil, 1)
		itemParts.buttonList[1].icon:SetTexture(135230)
		targetParts.enemyTargetButtons[1].icon:SetTexture(132333)
		for _, frame in ipairs({ items, itemParts.title, R.K.Skin.Parts(items).backdrop }) do
			frame:Show()
		end
		R.env.RunTimers()
		R.ns.RestedXP.Rail.Place()
		R.S.W.Settle(R.env)
		if boxes == "click" then
			rxp.settings.profile.activeTargetScale = 1.25
			-- 4.11.39's scale setting calls SetScale (SettingsPanel.lua 1859); 4.11.35's redraw applied it.
			if rxp.targeting.SetScale then rxp.targeting:SetScale(1.25) else R.Fake.Redraw(targetParts) end
			rxp.settings.profile.lockFrames = true
			targetParts.title:GetScript("OnMouseDown")(targetParts.title, "LeftButton")
			targetParts.title:GetScript("OnMouseUp")(targetParts.title, "LeftButton")
			rxp.SetStep()
			R.env.RunTimers()
			R.S.W.Settle(R.env)
		end
	end
	local scene = build(R.env, opts)
	for _, line in ipairs(R.log) do
		scene.log[#scene.log + 1] = line
	end
	scene.log[#scene.log + 1] = "restedxp: the guide is in its own card in the top left corner for the " .. tostring(opts.layout) .. " layout, its step list folded by RestedXP's own rule" .. (R.ns.RestedXP.Rail.Hidden() > 0 and ("; " .. R.ns.RestedXP.Rail.Hidden() .. " steps rest under its more line") or "")
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
function Hud.EditModeLayout(layout, guide, counts, natives)
	local CoreEnv = dofile("Tools/regression/core_env.lua")
	local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
	local state = { saved = {}, active = 1 }
	local env, K = CoreEnv.New(Common.ScreenOpts({
		saved = os.getenv("RENDER_NEEDS_OFF") == "1" and { version = 2, profiles = { Default = Common.FinishSettings({}) }, account = { setupSeen = true } } or nil,
		setup = function(env)
			Common.ForceScreen(env, true)
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
	warnings:SetSize(K.Setup.EditMode.WarningLane() * K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale(), 100)
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
	if natives and K.Setup.EditMode.NativeRows then
		K.Setup.EditMode.NativeRows(function(group)
			return group == "essential" or group == "utility"
		end)
	end
	K.Store.Module("Minimap").enabled = true
	K.Store.Module("Minimap").frame = os.getenv("RENDER_MINIMAP_FRAME")
	local style = Hud.Style()
	if style then
		K.Options.Write("HudStyle", "style", style:lower())
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

-- The managed bottom stack Blizzard's essential and utility viewers stand in while Edit Mode keeps them in their
-- default places (EditModeSystemTemplates.lua:347, ManagedFrameSystem.lua:47): BottomManagedFrameContainer, a vertical
-- layout of spacing 10, hangs from UIParent's bottom at MAIN_ACTION_BAR_OFFSET_Y (-4 on Camelot,
-- Camelot/EditModePresetLayoutConstants.lua:10) when no Blizzard bottom bar shows (UIParentPanelManager.lua:806), as
-- KstyleUI's action bars and data bars hide them, and centres utility (layoutIndex 14) under essential (13).
local MANAGED_BOTTOM, MANAGED_SPACING = -4, 10
local ROW_VIEWS = { essential = 50, utility = 30 }

local function RowHeight(EditModeFake, entry, count, size)
	local scale = (EditModeFake.Setting(entry, EditModeFake.ICON_SIZE) * 10 + 50) / 100
	local pad = EditModeFake.Setting(entry, EditModeFake.ICON_PADDING) - 4
	local lines = math.ceil(math.max(2, count) / EditModeFake.Setting(entry, EditModeFake.ICON_LIMIT))
	return lines * size * scale + (lines - 1) * pad
end

-- NativeViewers(env, C, layout, items, shift, natives) lays Blizzard's tracked buff icon and bar viewers out where Apply's
-- Edit Mode write puts them for this many tracked buffs and bars (C.Native); shift(entry, group, placed) -> dx, dy
-- moves each viewer for a gallery column, the icons first, placed holding the entries already moved. natives adds the
-- essential and utility viewers (items.essential, items.utility) of the fallback: at Apply's anchors when it placed
-- them, else in the managed bottom stack. Returns the Edit Mode entries, what Apply told the player and where the
-- rows stand.
function Hud.NativeViewers(env, C, layout, items, shift, natives)
	local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
	local counts = { buffs = #items.buffs, bars = #items.bars }
	if natives then
		counts.essential, counts.utility = #items.essential, #items.utility
	end
	local written, printed = Hud.EditModeLayout(layout, false, counts, natives)
	assert(written, "Apply wrote no Edit Mode layout")
	local formatter = env.C_StringUtil.CreateSecondsFormatter()
	local function format(seconds)
		return formatter:Format(seconds)
	end
	local out = {}
	local views = { { "buffs", EditModeFake.BUFF_ICON, "BuffIconCooldownViewer" }, { "bars", EditModeFake.BUFF_BAR, "BuffBarCooldownViewer" } }
	if natives then
		views[#views + 1] = { "utility", EditModeFake.UTILITY, "UtilityCooldownViewer" }
		views[#views + 1] = { "essential", EditModeFake.ESSENTIAL, "EssentialCooldownViewer" }
	end
	local stack, managed = MANAGED_BOTTOM, {}
	for _, view in ipairs(views) do
		local entry = EditModeFake.Copy(EditModeFake.Find(written, EditModeFake.VIEWER, view[2]))
		local dx, dy = 0, 0
		if shift then
			dx, dy = shift(entry, view[1], out)
		end
		if ROW_VIEWS[view[1]] and entry.isInDefaultPosition then
			entry.anchorInfo = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 0, offsetY = stack }
			stack = stack + RowHeight(EditModeFake, entry, #items[view[1]], ROW_VIEWS[view[1]]) + MANAGED_SPACING
			managed[#managed + 1] = view[1]
		end
		if ROW_VIEWS[view[1]] then
			env._viewers[view[3]]._hideWhenInactive = false
		end
		entry.anchorInfo.offsetX = entry.anchorInfo.offsetX + dx
		entry.anchorInfo.offsetY = entry.anchorInfo.offsetY + dy
		C.Native(env, view[3], entry, items[view[1]], format)
		out[view[1]] = entry
	end
	local rows = #managed > 0 and ("in the managed bottom stack (" .. table.concat(managed, ", ") .. "), as Edit Mode keeps them in their default places") or "at Apply's Edit Mode anchors on KstyleUI's rows"
	return out, printed or {}, rows
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
	local merged = Scene.Merge(scenes, Hud.Style() ~= "Frames")
	local class, spec = Hud.Class(opts)
	-- The class the scene drew, for Tools/render/classes.py's manifest.
	merged.class = { class = class, title = spec.title, name = spec.name, colour = { spec.colour[1], spec.colour[2], spec.colour[3] }, power = spec.power.token, cast = spec.cast and spec.cast[1] or nil }
	merged.log[#merged.log + 1] = "class: " .. class .. " (" .. spec.name .. ", " .. spec.power.token:lower() .. ", " .. (spec.cast and ("casting " .. spec.cast[1]) or "no cast") .. ")"
	merged.log[#merged.log + 1] = "icons: set B's repaint for every file ID the pack has, else Blizzard's icon, as the installed pack shows them"
	return merged
end

return Hud
