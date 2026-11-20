-- Micro.lua: the list a middle-click on the map opens out of combat: Blizzard's micro menu buttons as kit buttons, each clicked through the secure overlay.
local _, ns = ...

local K = KstyleUI
local L, Tokens, Widgets, Motion = K.L, K.Tokens, K.Widgets, K.Motion
local SecureClick, Plain = ns.SecureClick, ns.Face.Plain

local Micro = {}
ns.Micro = Micro

local WIDTH = 150
local HOVER_GRACE = 0.5
local ENTRIES = {
	{ "CharacterMicroButton", L["Character"] }, { "ProfessionMicroButton", L["Professions"] },
	{ "PlayerSpellsMicroButton", L["Spells and talents"] }, { "SpellbookMicroButton", L["Spellbook"] },
	{ "TalentMicroButton", L["Talents"] }, { "AchievementMicroButton", L["Achievements"] },
	{ "LegacyMicroButton", L["Legacy"] }, { "QuestLogMicroButton", L["Quest log"] },
	{ "HousingMicroButton", L["Housing"] }, { "GuildMicroButton", L["Guild and communities"] },
	{ "LFDMicroButton", L["Group finder"] }, { "CollectionsMicroButton", L["Collections"] },
	{ "EJMicroButton", L["Adventure guide"] }, { "HelpMicroButton", L["Help"] },
	{ "StoreMicroButton", L["Shop"] }, { "MainMenuMicroButton", L["Game menu"] },
}

local panel

local function Target(name)
	local button = _G[name]
	if type(button) == "table" and type(button.IsShown) == "function" and button:IsShown() == true then
		return button
	end
end

local function AfterCombat()
	K.Print((InCombatLockdown() and L["%s opens after combat."] or L["%s is not available on this client."]):format(L["Micro menu"]))
end

function Micro.Close()
	if panel and panel:IsShown() then
		panel:SetScript("OnUpdate", nil)
		Motion.FadeOut(panel, Tokens.Duration("fade"))
	end
end

local function Watch(frame, elapsed)
	if frame:IsMouseOver() or frame.anchor:IsMouseOver() then
		frame.grace = HOVER_GRACE
		return
	end
	frame.grace = frame.grace - elapsed
	if frame.grace <= 0 then
		Micro.Close()
	end
end

local function Build()
	panel = CreateFrame("Frame", nil, K.Scale.Root())
	Micro.panel = panel
	panel:SetFrameStrata("FULLSCREEN_DIALOG")
	panel:SetClampedToScreen(true)
	panel:EnableMouse(true)
	panel:Hide()
	Widgets.Chrome(panel, { shape = "panel", popup = true })
	panel.rows = {}
	for i, entry in ipairs(ENTRIES) do
		local row = Widgets.Button(panel, { text = entry[2], width = WIDTH, onClick = AfterCombat })
		row.afterClick = Micro.Close
		SecureClick.Bind(row, function() return Target(entry[1]) end)
		panel.rows[i] = row
	end
end

function Micro.Toggle(anchor)
	if panel and panel:IsShown() then
		return Micro.Close()
	end
	if InCombatLockdown() then
		return AfterCombat()
	end
	if not panel then
		Build()
	end
	local pad, gap, y = Widgets.Snap(panel, Tokens.Size("gapSmall")), Widgets.Snap(panel, Tokens.Size("gapTiny")), 0
	for i, row in ipairs(panel.rows) do
		row:SetShown(Target(ENTRIES[i][1]) ~= nil)
		if row:IsShown() then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -(pad + y))
			y = y + row:GetHeight() + gap
		end
	end
	if y == 0 then
		return
	end
	Widgets.Size(panel, WIDTH + 2 * pad, y - gap + 2 * pad)
	local x, scale = anchor:GetCenter(), anchor:GetEffectiveScale()
	local right = Plain(x) and Plain(scale) and x * scale > UIParent:GetWidth() * UIParent:GetEffectiveScale() / 2
	panel:ClearAllPoints()
	panel:SetPoint(right and "TOPRIGHT" or "TOPLEFT", anchor, right and "TOPLEFT" or "TOPRIGHT", right and -pad or pad, 0)
	panel.anchor, panel.grace = anchor, HOVER_GRACE
	panel:SetScript("OnUpdate", Watch)
	Motion.FadeIn(panel, Tokens.Duration("fade"))
end
