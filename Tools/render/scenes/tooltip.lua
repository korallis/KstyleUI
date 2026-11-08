-- tooltip.lua: the design file's item tooltip on Blizzard's GameTooltip, wearing the Tooltips glass, with the
-- stand-in tooltip's lines laid out as the game lays them out.
--
--   local Tooltip = dofile("Tools/render/scenes/tooltip.lua")
--   Tooltip.Layout(env, tip)      -- place a stand-in GameTooltip's lines and size the tooltip as the game would
--   local scene = Tooltip.Build()  -- the design sheet's item tooltip at the sheet's position
--
-- The game's GameTooltip lays its own lines out: a 10-unit margin, each line pitched by its string height plus
-- the custom line spacing (SharedTooltipTemplates.lua, GameTooltip_InsertFrame), and the padding
-- (right, bottom, left, top) pushes the lines inward. The stand-in from tooltips_env.lua does none of that, so
-- a scene calls Layout after the post-call. A title that keeps a blank second line for the rarity caption
-- ("NAME\n ") is two lines tall, as its string height is in the game.
local Common = dofile("Tools/render/scenes/_common.lua")
local Scene = Common.Scene

local Tooltip = {}

local MARGIN = 10
local LINE_EM = 1.2
local DEFAULT_SPACING = 2
local MIN_WIDTH = 180

-- The design file's tooltip section: the panel's top left corner in units at 2 px per unit (x 2014, y 676).
Tooltip.DESIGN = { x = 1007, y = 338 }

-- The design's lines, as Blizzard would add them: the name in the uncommon green, the rest in white.
Tooltip.ITEM = 19019
Tooltip.ICON = 132355
Tooltip.LINES = {
	{ "Ranger's Long Bow", 0.12, 1, 0 },
	{ "Level 38", 1, 1, 1 },
	{ "Two-Handed Bow", 1, 1, 1 },
	{ "Physical Damage   142 - 198", 1, 1, 1 },
	{ "Attack Speed   1.8", 1, 1, 1 },
	{ "+24 Agility", 1, 1, 1 },
	{ "+18 Critical Strike", 1, 1, 1 },
	{ "Durability 96 / 100", 1, 1, 1 },
	{ "Requires Level 38", 1, 1, 1 },
}

local function lineCount(text)
	local _, breaks = text:gsub("\n", "")
	return breaks + 1
end

-- Layout(env, tip) places every line of a stand-in GameTooltip and sizes the tooltip, in the tooltip's units.
function Tooltip.Layout(env, tip)
	local padding = tip._state.Padding or { 0, 0, 0, 0 }
	local padRight, padBottom, padLeft, padTop = padding[1] or 0, padding[2] or 0, padding[3] or 0, padding[4] or 0
	local spacing = tip:GetCustomLineSpacing() or DEFAULT_SPACING
	local y = -MARGIN - padTop
	local width = 0
	for i = 1, tip:NumLines() do
		local left, right = tip:GetLeftLine(i), tip:GetRightLine(i)
		local text = left:GetText() or ""
		local fontPath, size = Scene.Font(env, left)
		local height = size * LINE_EM * lineCount(text)
		left:ClearAllPoints()
		left:SetPoint("TOPLEFT", tip, "TOPLEFT", MARGIN + padLeft, y)
		local chars = Scene.TextWidth(text, size, fontPath)
		if right:IsShown() then
			right:ClearAllPoints()
			right:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -MARGIN - padRight, y)
			chars = chars + Scene.TextWidth(right:GetText() or "", size, fontPath) + 4 * size
		end
		width = math.max(width, chars)
		y = y - height - spacing
	end
	tip:SetSize(math.max(MIN_WIDTH, width + MARGIN * 2 + padLeft + padRight), -y + MARGIN - spacing + padBottom)
end

local function saved()
	return {
		version = 2,
		profiles = { Default = { Tooltips = { enabled = true } } },
		characters = {},
		layouts = {},
		account = { setupSeen = true },
		devlog = {},
	}
end

-- Build(opts) -> the scene: the design's item tooltip at opts.x, opts.y (default the design sheet's corner).
function Tooltip.Build(opts)
	opts = opts or {}
	local T = dofile("Tools/regression/tooltips_env.lua")
	local env, K = T.New({
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
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
		end,
	})
	if not K.Modules.IsRunning("Tooltips") then
		K.Modules.Enable("Tooltips")
	end
	env.RunTimers()
	local tip = env.GameTooltip
	env._items[Tooltip.ITEM] = { quality = 2, icon = Tooltip.ICON }
	tip:SetOwner(env.UIParent, "ANCHOR_NONE")
	tip:ClearAllPoints()
	tip:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", opts.x or Tooltip.DESIGN.x, -(opts.y or Tooltip.DESIGN.y))
	for _, line in ipairs(Tooltip.LINES) do
		tip:AddLine(line[1], line[2], line[3], line[4])
	end
	T.BlizzardShow(tip, true)
	T.PostCall(env, tip, { type = env.Enum.TooltipDataType.Item, id = Tooltip.ITEM })
	Tooltip.Layout(env, tip)
	env.RunTimers()
	T.W.Settle(env)
	local scene = Scene.Build(env)
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "tooltip error: " .. err
	end
	scene.log[#scene.log + 1] = "tooltip: the lines are laid out by the scene; the game's GameTooltip sizes and places its own text"
	return scene
end

return Tooltip
