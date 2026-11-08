-- components.lua: the component sheet, laid out like the design file's sections, from the real widgets.
--
-- Rendered at 2 px per unit the sections land where the design file (2576 by 1457 px) draws them, so a
-- crop at the same pixel box compares one to one. The kit widgets come from a widget environment; the
-- minimap and the unit frames come from their module environments, moved with Layout.Set.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = Common.Scene

local Components = {}

-- Section origins in screen units, read off the design file at 2 px per unit.
Components.SECTIONS = {
	minimap = { x = 32, y = 120 },
	player = { x = 288, y = 132 },
	-- The design draws the frames 234 units wide; the addon's are 296, so the target sits further right.
	target = { x = 624, y = 132 },
	targetCast = { x = 660, y = 232 },
	buttons = { x = 800, y = 150, step = 80, size = 62 },
	panel = { x = 32, y = 350, w = 220, h = 135 },
	tabs = { x = 427, y = 342, w = 326, h = 31 },
	toggleOn = { x = 431, y = 438 },
	toggleOff = { x = 520, y = 438 },
	slider = { x = 637, y = 442, w = 163 },
	dropdown = { x = 837, y = 424, w = 131 },
	tooltip = { x = 1011, y = 340 },
}
local S = Components.SECTIONS

local function saved(module)
	return {
		version = 2,
		profiles = { Default = module and { [module] = { enabled = true } } or {} },
		characters = {},
		layouts = {},
		account = { setupSeen = true },
		devlog = {},
	}
end

local function shared(env)
	Common.ForceScreen(env)
	env.RAID_CLASS_COLORS = env.RAID_CLASS_COLORS or {}
	env.RAID_CLASS_COLORS.WARRIOR = { r = Common.WARRIOR[1], g = Common.WARRIOR[2], b = Common.WARRIOR[3] }
	env.UnitClass = function()
		return "Warrior", "WARRIOR", 1
	end
end

local function place(frame, section, width, height)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", section.x, -section.y)
	if width then
		frame:SetSize(width, height)
	end
end

local function caption(K, root, text, x, y)
	local label = K.Widgets.Text(root, "caption", "text")
	label:SetPoint("TOPLEFT", root, "TOPLEFT", x, -y)
	K.Widgets.SetText(label, text)
	return label
end

local function ticks(W, env, n)
	for _ = 1, n or 30 do
		W.Tick(env, 0.05)
	end
end

-- Move a Layout element to a top-left origin, in screen units from the top left.
local function move(K, key, x, y, shown)
	assert(K.Layout.Set(key, "anchor", "TOPLEFT"))
	assert(K.Layout.Set(key, "x", x))
	assert(K.Layout.Set(key, "y", -y))
	if shown then
		assert(K.Layout.Set(key, "shown", shown))
	end
end

local function finish(env, K, scene, what)
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "error: " .. err
	end
	for i, line in ipairs(scene.log) do
		scene.log[i] = what .. ": " .. line
	end
	return scene
end

-- The widget kit: panel, tabs, toggles, slider, dropdown, tooltip and the six action button states.
function Components.Widgets()
	local W = dofile("Tools/regression/widget_env.lua")
	local env, K = W.New(Common.ScreenOpts({ saved = saved(nil), setup = shared }))
	local root = K.Scale.Root()
	local Widgets = K.Widgets

	caption(K, root, "Minimap", 30, 87)
	caption(K, root, "Player & target frames", 288, 87)
	caption(K, root, "Action button states", 800, 87)
	caption(K, root, "Glass panel", 30, 312)
	caption(K, root, "Tabs", 427, 312)
	caption(K, root, "Toggle switch", 427, 396)
	caption(K, root, "Slider", 637, 396)
	caption(K, root, "Dropdown", 837, 396)
	caption(K, root, "Item tooltip", 1011, 312)

	-- Action button states, left to right: normal, hover, pressed, cooldown, proc, disabled.
	local states = { "Normal", "Hover", "Pressed", "Cooldown", "Proc", "Disabled" }
	local buttons = {}
	for i, name in ipairs(states) do
		local button = Widgets.IconButton(root, { icon = Hud.ICONS.mortalStrike, size = S.buttons.size })
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", root, "TOPLEFT", S.buttons.x + (i - 1) * S.buttons.step, -S.buttons.y)
		buttons[i] = button
		local label = Widgets.Text(root, "caption", "text")
		label:SetPoint("TOP", button, "BOTTOM", 0, -12)
		Widgets.SetText(label, name)
	end
	W.Enter(buttons[2])
	W.Down(buttons[3])
	buttons[4]:SetCooldownFromDuration({ remaining = 3.2, total = 8 }, false)
	buttons[4].cooldown:Show()
	buttons[4].cooldown:GetScript("OnShow")(buttons[4].cooldown)
	buttons[5]:SetProc(true)
	buttons[6]:SetUsable(false)

	-- Glass panel.
	local panel = Widgets.Panel(root, { width = S.panel.w, height = S.panel.h })
	place(panel, S.panel, S.panel.w, S.panel.h)
	local title = Widgets.Text(panel, "heading", "textEmphasis")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -40)
	Widgets.SetText(title, "Panel Title")
	local body = Widgets.Text(panel, "body", "text")
	body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	body:SetWidth(S.panel.w - 40)
	body:SetJustifyH("LEFT")
	Widgets.SetText(body, "A clean, minimal panel with subtle depth and refined edges.")

	-- Tabs.
	local tabs = Widgets.Tabs(root, {
		width = S.tabs.w, height = S.tabs.h,
		tabs = { { value = "character", label = "Character" }, { value = "skills", label = "Skills" }, { value = "journal", label = "Journal" }, { value = "map", label = "Map" } },
		value = "character",
	})
	place(tabs, S.tabs, S.tabs.w, S.tabs.h)

	-- Toggles.
	local on = Widgets.Toggle(root, { value = true })
	place(on, S.toggleOn)
	local off = Widgets.Toggle(root, { value = false })
	place(off, S.toggleOff)
	local onLabel = Widgets.Text(root, "caption", "text")
	onLabel:SetPoint("TOP", on, "BOTTOM", 0, -16)
	Widgets.SetText(onLabel, "On")
	local offLabel = Widgets.Text(root, "caption", "text")
	offLabel:SetPoint("TOP", off, "BOTTOM", 0, -16)
	Widgets.SetText(offLabel, "Off")

	-- Slider.
	local slider = Widgets.Slider(root, { min = 0, max = 100, step = 1, value = 68, width = S.slider.w })
	place(slider, S.slider)

	-- Dropdown, open.
	local dropdown = Widgets.Dropdown(root, {
		width = S.dropdown.w,
		placeholder = "Select Option",
		options = { { value = 1, label = "Option 1" }, { value = 2, label = "Option 2" }, { value = 3, label = "Option 3" }, { value = 4, label = "Option 4" } },
	})
	place(dropdown, S.dropdown)
	dropdown:Open()

	-- Item tooltip, anchored to the right of an invisible owner so its left edge sits at the section.
	local owner = env.CreateFrame("Frame", nil, root)
	owner:SetSize(1, 1)
	owner:SetPoint("TOPRIGHT", root, "TOPLEFT", S.tooltip.x - 6, -S.tooltip.y)
	local tip = Widgets.Tooltip()
	tip:SetOwner(owner, "RIGHT")
	tip:SetIcon(Hud.ICONS.mortalStrike)
	tip:AddTitle("Ranger's Long Bow", K.Tokens.Color("accent"))
	tip:AddCaption("Uncommon", K.Tokens.Color("accent"))
	tip:AddLine("Level 38")
	tip:AddLine("Two-Handed Bow")
	tip:AddDoubleLine("Physical Damage", "142 - 198")
	tip:AddDoubleLine("Attack Speed", "1.8")
	tip:AddDivider()
	tip:AddLine("+24 Agility", K.Tokens.Color("friendly"))
	tip:AddLine("+18 Critical Strike", K.Tokens.Color("friendly"))
	tip:AddDivider()
	tip:AddLine("Durability 96 / 100")
	tip:AddLine("Requires Level 38")
	tip:Show()
	tip:ClearAllPoints()
	tip:SetPoint("TOPLEFT", root, "TOPLEFT", S.tooltip.x, -S.tooltip.y)

	env.RunTimers()
	ticks(W, env, 40)
	local scene = Scene.Build(env, { hover = { [buttons[2]] = true } })
	return finish(env, K, scene, "widgets")
end

-- The minimap, moved to its section.
function Components.Minimap()
	local M = dofile("Tools/regression/minimap_env.lua")
	local env, K = M.New({ enabled = true, zone = "Valley of Whispers", setup = function(env)
		shared(env)
		env._clock = { hour = 14, minute = 32, realmHour = 9, realmMinute = 5 }
	end })
	M.Settle(env)
	move(K, "minimap.main", S.minimap.x, S.minimap.y)
	M.Settle(env)
	local map = env.Minimap:CreateTexture(nil, "BACKGROUND")
	map:SetAllPoints(env.Minimap)
	map:SetColorTexture(0.22, 0.30, 0.20, 1)
	local scene = Scene.Build(env)
	return finish(env, K, scene, "minimap")
end

-- The player and target frames and the target's cast bar, moved to their sections; the rest hidden.
function Components.UnitFrames()
	local U = dofile("Tools/regression/unitframes_env.lua")
	local player = { name = "Valerin", class = "WARRIOR", level = 42, health = 3120, healthMax = 3980, power = 60, powerMax = 100, powerType = 1, powerToken = "RAGE", isPlayer = true, reaction = 5 }
	local target = { name = "Frost Howler", level = 40, health = 2240, healthMax = 4020, power = 0, powerMax = 0, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true,
		cast = { name = "Frost Bite", texture = 135846, start = 8000, finish = 11000, spellID = 116 } }
	local env, K = U.New(Common.ScreenOpts({
		saved = saved("UnitFrames"),
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
	env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", 116)
	env.RunTimers()
	move(K, "unitframes.player", S.player.x, S.player.y)
	move(K, "unitframes.target", S.target.x, S.target.y)
	move(K, "unitframes.castbar.target", S.targetCast.x, S.targetCast.y)
	for _, key in ipairs({ "unitframes.castbar.player", "unitframes.targettarget", "unitframes.pet", "unitframes.focus", "unitframes.focustarget", "unitframes.boss", "unitframes.resource" }) do
		K.Layout.Set(key, "shown", "never")
	end
	for _ = 1, 40 do
		U.W.Tick(env, 0.05)
	end
	for texture in pairs(env._portraits) do
		texture:SetColorTexture(0.33, 0.28, 0.22, 1)
	end
	local scene = Scene.Build(env, { time = env._time })
	return finish(env, K, scene, "unitframes")
end

function Components.Build()
	return Scene.Merge({ Components.Minimap(), Components.UnitFrames(), Components.Widgets() })
end

return Components
