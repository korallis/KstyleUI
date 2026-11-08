-- Preview.lua: the settings window's live preview: sample essential, utility and buff rows and buff bars drawn with the current settings.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Settings, Row, BarRow, Style = ns.Settings, ns.Row, ns.BarRow, ns.Style

local Preview = {}
ns.Preview = Preview

local SAMPLE_ICONS = {
	essential = { 132176, 132153, 132111, 132157, 132169, 132172 },
	utility = { 132164, 132179, 132188, 132159 },
	buffs = { 132159, 132160, 132188 },
}
local SAMPLE_COOLDOWNS = {
	essential = { { 12, 6 }, false, { 30, 26 }, false, { 20, 18 }, { 8, 6 } },
	utility = { false, { 60, 48 }, false, false },
	buffs = { { 30, 12 }, { 600, 420 }, false },
}
local SAMPLE_CHARGES = { essential = { [2] = 2 }, buffs = { [1] = 3 } }
local SAMPLE_PROC = { essential = { [4] = true } }
local SAMPLE_BARS = {
	{ icon = 132208, name = L["Rapid Fire"], duration = 15, left = 9 },
	{ icon = 136076, name = L["Aspect of the Hawk"], duration = 1800, left = 1260 },
}
local SAMPLE_BAR_FILL = 0.6

local function Fill(row, group)
	local cfg = row.cfg
	local count = row:SetCount(#SAMPLE_ICONS[group])
	local now = GetTime and GetTime() or 0
	for i = 1, count do
		local icon = row.icons[i]
		icon:SetIcon(SAMPLE_ICONS[group][i])
		local sample = SAMPLE_COOLDOWNS[group][i]
		local cooldownGroup = Settings.COOLDOWN_GROUPS[group]
		if sample and cooldownGroup then
			icon:SetCooldown(now - (sample[1] - sample[2]), sample[1])
		elseif sample then
			icon:ClearCooldown()
			icon.cooldown:SetCooldown(now - (sample[1] - sample[2]), sample[1])
		else
			icon:ClearCooldown()
		end
		icon.onCooldown = cooldownGroup and sample and true or false
		icon:SetCount(SAMPLE_CHARGES[group] and SAMPLE_CHARGES[group][i])
		Style.SetProc(icon, cfg.procGlow and SAMPLE_PROC[group] and SAMPLE_PROC[group][i])
		Style.SetReady(icon, cooldownGroup and cfg.readyGlow and not sample)
		if not cooldownGroup then
			icon:SetUsable(sample and true or false)
		end
		icon:Paint()
	end
end

local function FillBars(row)
	local count = row:SetCount(#SAMPLE_BARS)
	local now = GetTime and GetTime() or 0
	for i = 1, count do
		local bar, sample = row.bars[i], SAMPLE_BARS[i]
		bar.icon:SetTexture(sample.icon)
		Widgets.SetText(bar.name, sample.name)
		bar.status:SetMinMaxValues(0, 1)
		bar.status:SetValue(SAMPLE_BAR_FILL)
		bar.timer:SetCooldown(now - (sample.duration - sample.left), sample.duration)
		Widgets.SetText(bar.count, nil)
		bar:SetAlpha(1)
	end
end

local function Fitted(frame, cfg)
	local width = frame.pane:GetWidth()
	if issecretvalue(width) or type(width) ~= "number" or width <= 0 then
		return cfg
	end
	local columns = math.max(1, math.min(cfg.columns, math.floor((width + cfg.spacing) / (cfg.size + cfg.spacing))))
	if columns == cfg.columns then
		return cfg
	end
	local out = {}
	for key, value in pairs(cfg) do
		out[key] = value
	end
	out.columns = columns
	return out
end

local function Refresh(frame)
	Settings.Read()
	local gap = Tokens.Size("gapMedium")
	local previous
	for _, group in ipairs(Settings.GROUPS) do
		local row = frame.rows[group]
		row:Apply(group == "bars" and Settings.current.bars or Fitted(frame, Settings.current[group]))
		row.holder:ClearAllPoints()
		if previous then
			row.holder:SetPoint("TOP", previous.holder, "BOTTOM", 0, -Widgets.Snap(row.holder, gap))
		else
			row.holder:SetPoint("TOP", frame, "TOP", 0, -Widgets.Snap(row.holder, Tokens.Size("gapHuge")))
		end
		if group == "bars" then
			FillBars(row)
		else
			Fill(row, group)
		end
		previous = row
	end
end

function Preview.Build(parent)
	Settings.Read()
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	frame.pane = parent
	frame.rows = {}
	for _, group in ipairs(Settings.GROUPS) do
		if group == "bars" then
			frame.rows[group] = BarRow.New(frame, Settings.current.bars)
		else
			frame.rows[group] = Row.New(frame, group, Settings.current[group])
		end
	end
	frame.Refresh = Refresh
	Refresh(frame)
	return frame
end
