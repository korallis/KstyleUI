-- GameMenu.lua: the game menu skin: GameMenuFrame's glass panel, its title and the buttons Blizzard draws from a pool.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Kit = ns.PartBKit

local function Hover(button, on)
	local parts = K.Skin.Parts(button)
	if parts and parts.Paint then
		K.Widgets.Hover(parts, on)
	end
end

local function HoverOn(button)
	Hover(button, true)
end

local function HoverOff(button)
	Hover(button, false)
end

local function MenuButton(button)
	if not K.Skin.IsSkinned(button, "Button") then
		Kit.Button(button)
		return
	end
	button:HookScript("OnEnter", HoverOn)
	button:HookScript("OnLeave", HoverOff)
	local parts = K.Skin.Parts(button)
	if parts and parts.Paint then
		parts.hoverT = 0
		parts:Paint()
	end
end

local function SkinButtons(menu)
	local pool = menu.buttonPool
	if type(pool) ~= "table" or type(pool.EnumerateActive) ~= "function" then
		Kit.LogOnce("gameMenu.pool", "GameMenuFrame has no button pool; its buttons keep Blizzard's art")
		return
	end
	for button in pool:EnumerateActive() do
		MenuButton(button)
	end
end

local function Apply()
	local menu = GameMenuFrame
	if not Kit.Have(menu, "GameMenuFrame") then
		return false
	end
	K.Skin.Strip(menu, { children = { "Border", "Header" } })
	K.Skin.Backdrop(menu, { shape = "window", fill = "surface", shadow = true })
	local header = menu.Header
	if type(header) == "table" and type(header.Text) == "table" then
		Kit.Text(header.Text, "heading", "textEmphasis")
	end
	if type(menu.InitButtons) == "function" then
		hooksecurefunc(menu, "InitButtons", SkinButtons)
	else
		Kit.LogOnce("gameMenu.init", "GameMenuFrame:InitButtons is missing; only the buttons shown now are skinned")
	end
	SkinButtons(menu)
	return true
end

ns.Skins.Add({
	key = "gameMenu",
	label = L["Game menu"],
	help = L["Restyles the game menu that Escape opens."],
	addon = "Blizzard_GameMenu",
	frame = "GameMenuFrame",
	Apply = Apply,
})
