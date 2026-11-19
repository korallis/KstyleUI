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

local function LineHeight(text)
	return K.Widgets.LineHeight(text) + (text:GetSpacing() or 0)
end

local function SkillRow(row)
	Kit.Hush(row, Texture(row, "GetNormalTexture"), Texture(row, "GetHighlightTexture"), row.selectedTex)
	Kit.CropIcon(row.icon)
	Kit.Select(row, row.selectedTex)
	if ns.Style.MetricsEnabled() and row.name and row.subText and K.Widgets.MayMove(row) then
		local width = row:GetWidth()
		if IsSecret(width) or type(width) ~= "number" then return end
		ns.Style.Sweep(row)
		ns.Style.MetricText(row.name)
		ns.Style.MetricText(row.subText)
		local line, pad = LineHeight(row.subText), K.Widgets.Snap(row, 6)
		row:SetHeight(K.Widgets.Snap(row, 3 * line + 12))
		row.name:ClearAllPoints()
		row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 48, -pad)
		row.name:SetHeight(line)
		row.name:SetWordWrap(false)
		row.subText:ClearAllPoints()
		row.subText:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, 0)
		row.subText:SetWidth(math.max(1, width - 48 - pad))
		row.subText:SetHeight(2 * line)
		row.subText:SetJustifyV("TOP")
		row.subText:SetWordWrap(true)
		row.subText:SetMaxLines(2)
		if row.money then
			row.money:ClearAllPoints()
			row.money:SetPoint("TOPRIGHT", row, "TOPRIGHT", -pad, -pad)
		end
	end
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

local function MetricBar(bar)
	local restyle = bar.Restyle
	bar.Restyle = function(self)
		restyle(self)
		if ns.Style.MetricsEnabled() and K.Widgets.MayMove(self.frame) then
			self.frame:ClearAllPoints()
			K.Widgets.Point(self.frame, "TOPLEFT", ClassTrainerFrame, "TOPLEFT", 64, K.Widgets.Readability("readableBars") and -48 or -35)
		end
	end
	bar:Restyle()
end

local function Layout()
	if not ns.Style.MetricsEnabled() then return end
	K.Combat.Queue(function()
		local frame = ClassTrainerFrame
		local box = frame.ScrollBox
		if not box or not K.Widgets.MayMove(frame) then return end
		local width, height = frame:GetSize()
		if IsSecret(width) or IsSecret(height) or type(width) ~= "number" or type(height) ~= "number" then return end
		local measure = K.Safe.Side(frame).trainerLayout.measure
		ns.Style.MetricText(measure)
		if frame.TrainButton then
			frame.TrainButton:ClearAllPoints()
			frame.TrainButton:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", K.Widgets.Snap(frame.TrainButton, width - 12), -K.Widgets.Snap(frame.TrainButton, height - 12))
		end
		if frame.money then
			frame.money:ClearAllPoints()
			frame.money:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", K.Widgets.Snap(frame.money, 12), -K.Widgets.Snap(frame.money, height - 18))
		end
		if frame.skillStepButton and frame.skillStepButton:IsShown() then
			SkillRow(frame.skillStepButton)
			K.Widgets.Point(box, "TOPLEFT", frame.skillStepButton, "BOTTOMLEFT", 0, -6)
		else
			local point, relative, on, x, y = box:GetPoint(1)
			if point == "TOPLEFT" then K.Widgets.Point(box, point, relative, on, x, y) end
		end
		box:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", K.Widgets.Snap(box, width - 24), -K.Widgets.Snap(box, height - 52))
		local view = type(box.GetView) == "function" and box:GetView()
		if view and type(view.SetElementExtentCalculator) == "function" then
			view:SetElementExtentCalculator(function(_, node)
				return node:GetData().categoryInfo and 25 or K.Widgets.Snap(box, 3 * LineHeight(measure) + 12)
			end)
			if type(box.FullUpdate) == "function" then box:FullUpdate() end
		end
		if type(box.ForEachFrame) == "function" then box:ForEachFrame(Row) end
	end)
end

local function Apply()
	local frame = ClassTrainerFrame
	if not Kit.Have(frame, "ClassTrainerFrame") then
		return false
	end
	Kit.Window(frame, { titleRole = "names" })
	local bar = Kit.Bar(ClassTrainerStatusBar, { accent = true, label = SkillLine(), rankOutside = true })
	if bar then MetricBar(bar) end
	if type(ClassTrainerFrame_Update) == "function" then
		hooksecurefunc("ClassTrainerFrame_Update", function()
			if bar then bar:SetLabel(SkillLine()) end
			Layout()
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
	local layout = { Restyle = Layout }
	if ns.Style.MetricsEnabled() then
		layout.measure = K.Widgets.FontString(frame, "OVERLAY")
		layout.measure:Hide()
	end
	K.Safe.Side(frame).trainerLayout = ns.Style.Track(layout)
	Layout()
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
	metrics = true,
	Apply = Apply,
})
