-- Warnings.lua: the encounter warnings skin: Forever's RaidWarningFrame, where boss emotes, boss whispers and raid warnings show, narrowed to the combat lane, its messages in the Lumen world face over a glass plate that grows with the messages and fades with them, through hooks only.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Tokens, Widgets = K.Tokens, K.Widgets
local Style, Skins = ns.Style, ns.Skins

local KEY = "encounterWarnings"
local FRAME = "RaidWarningFrame"
local TEXT_HEIGHT = 20
local ROLE = "world"
local abs = math.abs
local PAD_X, PAD_Y = "gapLarge", "gapMedium"

local Encounter = {}
ns.Encounter = Encounter

local styled = setmetatable({}, { __mode = "k" })
local frame, plate, lane

local function Lane()
	return K.Setup.EditMode.WARNING_LANE / Widgets.ScaleFactor(frame)
end

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Plain(value)
	if IsSecret(value) or type(value) ~= "number" or value ~= value or value <= 0 then
		return nil
	end
	return value
end

local function Pool()
	local pool = frame and frame.fontStringPool
	if type(pool) == "table" and type(pool.EnumerateActive) == "function" and type(pool.GetNumActive) == "function" then
		return pool
	end
end

local function Face(text)
	Style.ApplyFont(text, ROLE, TEXT_HEIGHT)
end

local function Fill(text)
	local width = Plain(text:GetWidth())
	if width and abs(width - lane) > 0.5 then
		text:SetWidth(lane)
	end
end

local function StyleText(text)
	if styled[text] then
		return
	end
	styled[text] = true
	Face(text)
	Fill(text)
end

local function Fit()
	local pool = Pool()
	if not plate or not pool then
		return
	end
	local count = pool:GetNumActive()
	if not Plain(count) then
		plate:Hide()
		return
	end
	local height = 0
	for text in pool:EnumerateActive() do
		StyleText(text)
		height = height + (Plain(text:GetStringHeight()) or TEXT_HEIGHT)
	end
	local padY = Widgets.Snap(plate, Tokens.Size(PAD_Y))
	plate:SetHeight(Widgets.Snap(plate, height) + 2 * padY)
	plate:Show()
end

local function Fade()
	local pool = Pool()
	if not plate or not pool or not plate:IsShown() then
		return
	end
	local alpha = 0
	for text in pool:EnumerateActive() do
		local a = text:GetAlpha()
		if IsSecret(a) or type(a) ~= "number" then
			alpha = 1
			break
		end
		if a > alpha then
			alpha = a
		end
	end
	plate:SetAlpha(alpha)
end

local function Restyle(self)
	lane = Lane()
	frame:SetWidth(lane)
	local padX, padY = Widgets.Snap(self, Tokens.Size(PAD_X)), Widgets.Snap(self, Tokens.Size(PAD_Y))
	self:ClearAllPoints()
	self:SetPoint("TOP", frame, "TOP", 0, padY)
	self:SetWidth(lane + 2 * padX)
	for text in pairs(styled) do
		Face(text)
		Fill(text)
	end
	Fit()
end

local function Apply()
	frame = _G[FRAME]
	if type(frame) ~= "table" or type(frame.UpdateLayout) ~= "function" or not Pool() then
		frame = nil
		K.DevTest.Log("Skins", KEY .. ": " .. FRAME .. " or its message pool is missing on this client; the warnings keep Blizzard's look")
		return
	end
	plate = CreateFrame("Frame", nil, frame)
	plate:SetFrameStrata("BACKGROUND")
	plate.chrome = Widgets.Chrome(plate, { shape = "panel", fill = "surface" })
	plate.Restyle = Restyle
	plate:Hide()
	Widgets.Track(plate)
	Style.Track(plate)
	hooksecurefunc(frame, "UpdateLayout", Fit)
	frame:HookScript("OnUpdate", Fade)
	Restyle(plate)
end

function Encounter.Plate()
	return plate
end

Skins.Add({
	key = KEY,
	label = L["Encounter warnings"],
	help = L["Puts boss emotes and raid warnings on a glass lane above the target."],
	addon = "Blizzard_RaidWarning",
	Apply = Apply,
})
