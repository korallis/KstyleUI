-- Trainer.lua: the trainer skin: ClassTrainerFrame, its skill bar, filter, train button and the category and skill rows of its list.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Kit = ns.PartBKit

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Texture(button, getter)
	if type(button[getter]) == "function" then
		return button[getter](button)
	end
end

local function SkillRow(row)
	Kit.Hush(row, Texture(row, "GetNormalTexture"), Texture(row, "GetHighlightTexture"), row.selectedTex)
	Kit.CropIcon(row.icon)
	Kit.Select(row, row.selectedTex)
end

local function Label(row)
	if type(row.Label) == "table" then
		Kit.Text(row.Label, "body", "textEmphasis")
	end
end

local function CategoryHover(row, tile)
	Kit.Rehover(row, tile)
	row:HookScript("OnEnter", Label)
	row:HookScript("OnLeave", Label)
end

local function CategoryRow(row)
	if K.Safe.Side(row).partBSelect then
		return
	end
	Kit.Hush(row, row.LeftPiece, row.RightPiece, row.CenterPiece)
	local tile = Kit.Select(row, nil, { hover = false })
	Label(row)
	CategoryHover(row, tile)
end

local function CategoryInit(row)
	if type(row) ~= "table" then
		return
	end
	local tile = K.Safe.Side(row).partBSelect
	if not tile then
		CategoryRow(row)
		return
	end
	Label(row)
	CategoryHover(row, tile)
end

local function TrainButtonHover()
	local button = ClassTrainerTrainButton
	local parts = button and K.Skin.Parts(button)
	if parts and parts.kinds.Button then
		Kit.Rehover(button, parts)
	end
end

local function SkillLine()
	if type(GetTrainerServiceSkillLine) ~= "function" or type(GetNumTrainerServices) ~= "function" then
		return L["Skill"]
	end
	local count = GetNumTrainerServices()
	if IsSecret(count) or type(count) ~= "number" then
		return L["Skill"]
	end
	for index = 1, count do
		local line = GetTrainerServiceSkillLine(index)
		if not IsSecret(line) and type(line) == "string" and line ~= "" then
			return line
		end
	end
	return L["Skill"]
end

local function Row(row)
	if row.icon ~= nil then
		SkillRow(row)
	elseif row.LeftPiece ~= nil then
		CategoryRow(row)
	end
end

local function Apply()
	local frame = ClassTrainerFrame
	if not Kit.Have(frame, "ClassTrainerFrame") then
		return false
	end
	Kit.Window(frame)
	local bar = Kit.Bar(ClassTrainerStatusBar, { accent = true, label = SkillLine() })
	if bar and type(ClassTrainerFrame_Update) == "function" then
		hooksecurefunc("ClassTrainerFrame_Update", function()
			bar:SetLabel(SkillLine())
		end)
	elseif bar then
		Kit.LogOnce("trainer.update", "ClassTrainerFrame_Update is missing; the skill bar's label is set at skin time only")
	end
	Kit.Dropdown(frame.FilterDropdown)
	Kit.Button(frame.TrainButton)
	Kit.ScrollBar(frame.ScrollBar)
	if frame.bottomInset then
		Kit.Inset(frame.bottomInset)
	end
	if frame.skillStepButton then
		SkillRow(frame.skillStepButton)
	end
	if frame.ScrollBox then
		Kit.Rows(frame.ScrollBox, Row)
	end
	if type(ClassTrainerFrame_InitCategoryButton) == "function" then
		hooksecurefunc("ClassTrainerFrame_InitCategoryButton", CategoryInit)
	else
		Kit.LogOnce("trainer.categories", "ClassTrainerFrame_InitCategoryButton is missing; category rows lose their hover after a refresh")
	end
	if type(ClassTrainerFrame_SetTrainButtonEnabled) == "function" then
		hooksecurefunc("ClassTrainerFrame_SetTrainButtonEnabled", TrainButtonHover)
	end
	return true
end

ns.Skins.Add({
	key = "trainer",
	label = L["Trainer"],
	help = L["Restyles the class and profession trainer window."],
	addon = "Blizzard_TrainerUI",
	frame = "ClassTrainerFrame",
	Apply = Apply,
})
