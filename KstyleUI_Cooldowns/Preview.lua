-- Preview.lua: the settings window's live preview: sample essential and utility rows drawn with the current settings.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Settings, Row, Style = ns.Settings, ns.Row, ns.Style

local Preview = {}
ns.Preview = Preview

local SAMPLE_ICONS = {
	essential = { 132176, 132153, 132111, 132157, 132169, 132172 },
	utility = { 132164, 132179, 132188, 132159 },
}
local SAMPLE_COOLDOWNS = {
	essential = { { 12, 6 }, false, { 30, 26 }, false, { 20, 18 }, { 8, 6 } },
	utility = { false, { 60, 48 }, false, false },
}
local SAMPLE_CHARGES = { essential = { [2] = 2 } }
local SAMPLE_PROC = { essential = { [4] = true } }

local function Fill(row, group)
	local cfg = row.cfg
	local count = row:SetCount(#SAMPLE_ICONS[group])
	local now = GetTime and GetTime() or 0
	for i = 1, count do
		local icon = row.icons[i]
		K.Icons.Apply(icon.icon, SAMPLE_ICONS[group][i])
		local sample = SAMPLE_COOLDOWNS[group][i]
		if sample then
			icon:SetCooldown(now - (sample[1] - sample[2]), sample[1])
		else
			icon:ClearCooldown()
		end
		icon.onCooldown = sample and true or false
		local charges = SAMPLE_CHARGES[group] and SAMPLE_CHARGES[group][i]
		icon:SetCount(charges)
		Style.SetProc(icon, cfg.procGlow and SAMPLE_PROC[group] and SAMPLE_PROC[group][i])
		Style.SetReady(icon, cfg.readyGlow and not sample)
		icon:Paint()
	end
end

local function Refresh(frame)
	Settings.Read()
	local gap = Tokens.Size("gapMedium")
	local previous
	for _, group in ipairs(Settings.ICON_GROUPS) do
		local row = frame.rows[group]
		row:Apply(Settings.current[group])
		row.holder:ClearAllPoints()
		if previous then
			row.holder:SetPoint("TOP", previous.holder, "BOTTOM", 0, -Widgets.Snap(row.holder, gap))
		else
			row.holder:SetPoint("TOP", frame, "TOP", 0, -Widgets.Snap(row.holder, Tokens.Size("gapHuge")))
		end
		Fill(row, group)
		previous = row
	end
end

function Preview.Build(parent)
	Settings.Read()
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	frame.rows = {}
	for _, group in ipairs(Settings.ICON_GROUPS) do
		frame.rows[group] = Row.New(frame, group, Settings.current[group])
	end
	frame.Refresh = Refresh
	Refresh(frame)
	return frame
end
