-- gallery_auracounts.lua: the aura rows at three loads, side by side, each cropped as one frame of the gallery:
-- low (3), medium (10) and high (24 on the sigil, 16 on the focus and boss cards, 16 tracked buffs, 6 tracked bars).
-- The sigil's debuffs wrap to a second row of ten, then the last socket reads "+N"; the focus card's single row and the
-- boss card's two rows of three do the same; the tracked buff icons cap at six and the bars at two, the last of each
-- reading the rest. The fake engine lays out nothing, so this scene places the engine's buttons as its flow layout
-- would (sorted, wrapped at the columns, from the container's corner) and sizes the hidden counting container the way
-- its one-element-per-line layout does; the chip shows and reads by anchors alone, as in the game.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = Common.Scene

local NOW = 10
local SCREEN_H = 1080
local COLUMN, LEFT = 548, 20
local LOADS = {
	{ key = "low", label = "3", target = 3, focus = 3, boss = 3, buffs = 3, bars = 1 },
	{ key = "medium", label = "10", target = 10, focus = 10, boss = 8, buffs = 10, bars = 3 },
	{ key = "high", label = "24", target = 24, focus = 16, boss = 16, buffs = 16, bars = 6 },
}

local ICONS = {}
do
	local names = {}
	for name in pairs(Hud.ICONS) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		ICONS[#ICONS + 1] = Hud.ICONS[name]
	end
end

local function icon(i)
	return ICONS[(i * 7) % #ICONS + 1]
end

local UNITS = {
	target = { name = "Bloodtalon Matriarch", level = 38, classification = "elite", creature = "Beast", health = 864, healthMax = 1540, power = 0, powerMax = 0, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true },
	focus = { name = "Elunara Frostweaver", level = 39, health = 2530, healthMax = 4010, power = 2900, powerMax = 4400, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true },
	boss1 = { name = "Magmatus", level = 40, classification = "elite", health = 72000, healthMax = 100000, power = 40, powerMax = 100, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true },
}

local function move(K, key, x, y)
	assert(K.Layout.Set(key, "anchor", "TOPLEFT"))
	assert(K.Layout.Set(key, "x", x))
	assert(K.Layout.Set(key, "y", -y))
end

local function hide(K, keys)
	for _, key in ipairs(keys) do
		assert(K.Layout.Set(key, "shown", "never"))
	end
end

-- Lay(env, K, ns, view, n) places min(n, cap) of the engine's debuff buttons as the flow layout would, soonest-expiring
-- first, and sizes the counting container for n; returns the timers it wrote, for the log.
local function Lay(env, K, ns, view, n)
	local Widgets, Settings = K.Widgets, ns.Settings
	local a = view.auras
	local c = a.container
	local group = c._groups.debuffs
	local cap = group.max
	local shown = math.min(n, cap)
	local buttons = c:_Acquire("debuffs", shown)
	local size = Widgets.Snap(a.host, Settings.Value(view.kind, "auraSize"))
	local spacing = group.layout.elementSpacing
	local lineGap = group.layout.lineSpacing
	local columns = Settings.Value(view.kind, "auraColumns")
	local corner = c._anchor or "TOPLEFT"
	local dx = (c._growth and c._growth[1] or 1) < 0 and -1 or 1
	local dy = (c._growth and c._growth[2] or -1) < 0 and -1 or 1
	local rows = math.ceil(shown / columns)
	local across = math.min(shown, columns)
	c:SetSize(math.max(1, across * size + (across - 1) * spacing), math.max(1, rows * size + (rows - 1) * lineGap))
	local byButton = {}
	for _, entry in ipairs(a.buttons) do
		byButton[entry.button] = entry
	end
	for i, button in ipairs(buttons) do
		local entry = byButton[button]
		if i <= shown and entry then
			local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
			button:ClearAllPoints()
			button:SetSize(size, size)
			button:SetPoint(corner, c, corner, dx * col * (size + spacing), dy * row * (size + lineGap))
			button:Show()
			entry.icon:SetTexture(env.Secret(icon(i + n)))
			Widgets.SetText(entry.timer, (2 + i * 3) .. "s")
			Widgets.SetText(entry.count, i % 5 == 2 and "3" or "")
		else
			button:Hide()
		end
	end
	local chip = a.overflow and a.overflow.debuffs
	if chip then
		chip.ghost:SetSize(1, math.max(1, n * chip.window:GetWidth() * ns.Overflow.PITCH))
	end
	return shown, cap
end

-- Frames(load, k, frames) -> scene: the sigil, the focus card and the first boss card at one load.
local function Frames(load, k, frames)
	local U = dofile("Tools/regression/unitframes_env.lua")
	local env, K, ns = U.New(Common.ScreenOpts({
		saved = Gallery.Saved({ "UnitFrames" }),
		setup = function(env)
			Gallery.Setup(env)
			for token, unit in pairs(UNITS) do
				env._units[token] = unit
			end
		end,
	}))
	env._time = NOW
	local x = LEFT + (k - 1) * COLUMN
	move(K, "unitframes.target", x, 30)
	move(K, "unitframes.focus", x, 262)
	move(K, "unitframes.boss", x + 280, 240)
	hide(K, { "unitframes.player", "unitframes.castbar.player", "unitframes.castbar.target", "unitframes.resource", "unitframes.targettarget", "unitframes.pet", "unitframes.focustarget" })
	env.SetTarget(true)
	env.FireEvent("PLAYER_FOCUS_CHANGED")
	env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	env.RunTimers()
	local Ui = ns.Frames
	local target, focus, boss = Ui.Get("target").views[1], Ui.Get("focus").views[1], Ui.Get("boss").views[1]
	local log = {}
	for _, item in ipairs({ { target, load.target, "sigil" }, { focus, load.focus, "focus" }, { boss, load.boss, "boss" } }) do
		local view, n, name = item[1], item[2], item[3]
		local shown, cap = Lay(env, K, ns, view, n)
		log[#log + 1] = string.format("%s: %d debuffs, %d sockets of %d%s", name, n, shown, cap, n > cap and (", +" .. (n - cap + 1) .. " on the last") or "")
	end
	Gallery.Ticks(U.W, env, 20)
	env.RunTimers()
	frames:Add(env, target.button, {
		name = "auracounts_sigil_" .. load.key, title = "Sigil debuffs, " .. load.label, grade = "bar", reference = "target",
		caption = string.format("The target's sigil with %d of your debuffs: two rows of ten 24-unit sockets centred under it, sorted by the engine (yours, then priority, then time left), each timer on its socket's foot; past twenty the last socket reads +N.", load.target),
		match = "The mockup's sigil sockets, now in two rows inside the 136 units the layouts keep for the sigil, clear of the cooldown cluster under it.",
		rect = Gallery.Union(env, { target.button, target.auras.host }),
		pad = 10,
	})
	frames:Add(env, focus.button, {
		name = "auracounts_focus_" .. load.key, title = "Focus debuffs, " .. load.label, grade = "panel", reference = "player",
		caption = string.format("The focus card with %d of your debuffs over it: one row of eight 20-unit sockets, the last reading +N past eight.", load.focus),
		match = "The focus card's row stays in the 22 units the layouts keep over the card.",
		rect = Gallery.Union(env, { focus.button, focus.auras.host }),
		pad = 10,
	})
	frames:Add(env, boss.button, {
		name = "auracounts_boss_" .. load.key, title = "Boss debuffs, " .. load.label, grade = "panel", reference = "target",
		caption = string.format("A boss card with %d of your debuffs beside it: two rows of three 18-unit sockets growing left, the last reading +N past six.", load.boss),
		match = "The boss column's 60 units of aura room, two rows inside one 62-unit card.",
		rect = Gallery.Union(env, { boss.button, boss.auras.host }),
		pad = 10,
	})
	local scene = Gallery.Build(env, { time = NOW })
	for _, line in ipairs(log) do
		scene.log[#scene.log + 1] = line
	end
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "error: " .. err
	end
	return scene
end

local function layout(K, key, x, top, height)
	assert(K.Layout.Update(key, { anchor = "BOTTOMLEFT", x = x, y = SCREEN_H - top - height }))
end

-- Cooldowns(load, k, frames) -> scene: the mirror's tracked buff icons and bars at one load.
local function Cooldowns(load, k, frames)
	local C = dofile("Tools/regression/cooldowns_env.lua")
	local cooldowns, textures = {}, {}
	for i = 1, load.buffs do
		cooldowns[500 + i] = { spellID = 5000 + i, category = C.CATEGORY.TrackedBuff, selfAura = true, hasAura = true }
		textures[5000 + i] = icon(i)
	end
	for i = 1, load.bars do
		cooldowns[600 + i] = { spellID = 6000 + i, category = C.CATEGORY.TrackedBar, selfAura = true, hasAura = true }
		textures[6000 + i] = icon(i + 40)
	end
	local env, K, ns = C.New({
		saved = Gallery.Saved({ Cooldowns = { path = "mirror" } }),
		cooldowns = cooldowns,
		setup = function(env)
			Gallery.Setup(env)
			C.Game(env)
			env.C_Spell.GetSpellName = function(spell)
				return spell > 6000 and ({ "Battle Shout", "Enrage", "Blood Fury", "Shield Block", "Bloodrage", "Recklessness" })[spell - 6000] or ("Spell " .. spell)
			end
			for spell, texture in pairs(textures) do
				env._cdm.textures[spell] = texture
			end
		end,
	})
	local cdm = env._cdm
	env._time = NOW
	local instance = 900
	for spell in pairs(textures) do
		instance = instance + 1
		local total, left = 30, 3 + (spell % 17)
		cdm.auras[spell] = { auraInstanceID = instance }
		cdm.auraDurations[instance] = { kind = "aura", start = NOW - (total - left), finish = NOW + left, remaining = left, total = total }
	end
	C.Enable(env, K)
	env.FireEvent("PLAYER_ENTERING_WORLD", true, false)
	env.FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
	env.RunTimers()
	local buffs, bars = ns.Mirror.Row("buffs"), ns.Mirror.Row("bars")
	local x = LEFT + (k - 1) * COLUMN
	local _, barsH = bars.holder:GetSize()
	local _, buffsH = buffs.holder:GetSize()
	layout(K, "cooldowns.bars", x, 640, barsH)
	layout(K, "cooldowns.buffs", x, 640 + barsH + 8, buffsH)
	for _, key in ipairs({ "cooldowns.essential", "cooldowns.utility" }) do
		layout(K, key, x + 230, 640, 44)
	end
	hide(K, { "cooldowns.essential", "cooldowns.utility" })
	frames:Add(env, buffs.holder, {
		name = "auracounts_buffs_" .. load.key, title = "Tracked buffs, " .. load.label, grade = "button", reference = "bufficons",
		caption = string.format("%d tracked buffs active, %d tracked bars: the icon row keeps its six sockets in its 195 by 30 footprint and the last reads +N; the bars keep two and the second reads +N more.", load.buffs, load.bars),
		match = "The tracked buff row and bars never grow toward the essential cooldowns beside them.",
		rect = Gallery.Union(env, { buffs.holder, bars.holder }),
		pad = 10,
	})
	local scene = Gallery.Build(env, { time = NOW })
	scene.log[#scene.log + 1] = string.format("tracked buffs: %d active, %d shown%s; bars: %d active, %d shown", load.buffs, buffs.count,
		buffs.chip and buffs.chip:IsShown() and (", " .. buffs.chip.text:GetText() .. " on the last") or "", load.bars, bars.count)
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "error: " .. err
	end
	return scene
end

return Common.Run(function()
	local frames = Gallery.Frames()
	local scenes = {}
	for k, load in ipairs(LOADS) do
		scenes[#scenes + 1] = Frames(load, k, frames)
		scenes[#scenes + 1] = Cooldowns(load, k, frames)
	end
	local scene = Scene.Merge(scenes)
	scene.frames = {}
	for _, entry in ipairs(frames.pending) do
		local rect = entry.spec.rect
		scene.frames[#scene.frames + 1] = {
			name = entry.spec.name, title = entry.spec.title, caption = entry.spec.caption, grade = entry.spec.grade,
			reference = entry.spec.reference, match = entry.spec.match, pad = entry.spec.pad or 14,
			rect = { rect.x, rect.y, rect.w, rect.h },
		}
	end
	frames.pending = {}
	for i, line in ipairs(scene.log) do
		scene.log[i] = "gallery auracounts: " .. line
	end
	return scene
end)
