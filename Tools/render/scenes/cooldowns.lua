-- cooldowns.lua: the Cooldown Manager on both paths: the HUD's mirror rows and bars, and Blizzard's viewers
-- restyled in place, their items laid out by the scene the way Edit Mode would, in the empty middle of the screen.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = Common.Scene
local I = Hud.ICONS

-- Where the scene puts Blizzard's viewers, in screen units from the top left, and the sizes Edit Mode gives
-- their items: essential icons, tracked buff icons and tracked buff bars.
local ESSENTIAL = { x = 760, y = 380, size = 56, gap = 8, icons = { I.mortalStrike, I.whirlwind }, cooldown = { [1] = { total = 8, left = 4 } } }
local BUFFS = { x = 790, y = 470, size = 30, gap = 3, icons = { I.bloodrage, I.berserkerRage }, cooldown = { [2] = { total = 18, left = 10 } } }
local BARS = { x = 441, y = 540, width = 195, height = 24, gap = 3, icons = { I.battleShout, I.enrage }, names = { "Battle Shout", "Enrage" }, times = { "24s", "12s" }, values = { { 120, 24 }, { 12, 12 } } }
local NAME_INSET, NAME_END, DURATION_INSET, ICON_GAP = 5, -25, -8, 2

local function saved()
	return {
		version = 2,
		profiles = { Default = { Cooldowns = { enabled = true, path = "reskin" } } },
		characters = {},
		layouts = {},
		account = { setupSeen = true },
		devlog = {},
	}
end

local function place(frame, relative, x, y, width, height)
	frame:ClearAllPoints()
	frame:SetSize(width, height)
	frame:SetPoint("TOPLEFT", relative, "TOPLEFT", x, -y)
end

local function iconViewer(env, viewer, spec, now)
	local count = #viewer._items
	place(viewer, env.UIParent, spec.x, spec.y, count * spec.size + (count - 1) * spec.gap, spec.size)
	for i, item in ipairs(viewer._items) do
		place(item, viewer, (i - 1) * (spec.size + spec.gap), 0, spec.size, spec.size)
		item.Icon:SetAllPoints(item)
		item.Icon:SetTexture(spec.icons[i])
		item.Overlay:SetAllPoints(item)
		item.OutOfRange:SetAllPoints(item)
		item.Cooldown:SetAllPoints(item)
		local cooldown = spec.cooldown[i]
		if cooldown then
			item.Cooldown:SetCooldown(now - (cooldown.total - cooldown.left), cooldown.total)
		end
	end
end

local function barViewer(env, viewer, spec)
	local count = #viewer._items
	place(viewer, env.UIParent, spec.x, spec.y, spec.width, count * spec.height + (count - 1) * spec.gap)
	for i, item in ipairs(viewer._items) do
		place(item, viewer, 0, (i - 1) * (spec.height + spec.gap), spec.width, spec.height)
		local icon = item.Icon
		place(icon, item, 0, 0, spec.height, spec.height)
		icon.Icon:SetAllPoints(icon)
		icon.Icon:SetTexture(spec.icons[i])
		icon.Overlay:SetAllPoints(icon)
		local bar = item.Bar
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", icon, "TOPRIGHT", ICON_GAP, 0)
		bar:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)
		bar.BarBG:SetAllPoints(bar)
		bar.Pip:SetAllPoints(bar)
		bar.Name:ClearAllPoints()
		bar.Name:SetPoint("TOPLEFT", bar, "TOPLEFT", NAME_INSET, 0)
		bar.Name:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", NAME_END, 0)
		bar.Name:SetJustifyH("LEFT")
		bar.Name:SetText(spec.names[i])
		bar.Duration:ClearAllPoints()
		bar.Duration:SetPoint("RIGHT", bar, "RIGHT", DURATION_INSET, 0)
		bar.Duration:SetText(spec.times[i])
		bar:SetMinMaxValues(0, spec.values[i][1])
		bar:SetValue(spec.values[i][2])
	end
end

-- Reskin() -> the scene of Blizzard's viewers restyled in place, in their own environment.
local function Reskin()
	local C = dofile("Tools/regression/cooldowns_env.lua")
	local env, K = C.New({
		saved = saved(),
		setup = function(env)
			Common.ForceScreen(env)
			env.RAID_CLASS_COLORS = env.RAID_CLASS_COLORS or {}
			env.RAID_CLASS_COLORS.WARRIOR = { r = Common.WARRIOR[1], g = Common.WARRIOR[2], b = Common.WARRIOR[3] }
			env.UnitClass = function(unit)
				if unit == "player" or unit == nil then
					return "Warrior", "WARRIOR", 1
				end
			end
			C.Game(env)
		end,
	})
	env._time = 10
	C.Enable(env, K)
	local viewers = env._viewers
	iconViewer(env, viewers.EssentialCooldownViewer, ESSENTIAL, env._time)
	iconViewer(env, viewers.BuffIconCooldownViewer, BUFFS, env._time)
	barViewer(env, viewers.BuffBarCooldownViewer, BARS)
	viewers.UtilityCooldownViewer:Hide()
	C.W.Settle(env)
	local scene = Scene.Build(env, { time = env._time })
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "cooldowns reskin error: " .. err
	end
	for i, line in ipairs(scene.log) do
		scene.log[i] = "cooldowns reskin: " .. line
	end
	return scene
end

return Common.Run(function()
	local mirror = Hud.Module("cooldowns")
	return Scene.Merge({ mirror, Reskin() })
end)
