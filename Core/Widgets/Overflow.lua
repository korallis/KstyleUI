-- Overflow.lua: the "+N" count for a capped aura row, shown and counted by hidden AuraContainers' own flow layout through anchors alone (a row of several aura groups is counted by one container holding the same groups), so no aura count is ever read, compared or summed, and the count stays true while aura data is secret; a row whose timers sit under the tiles gives the chip that lane too (foot), so the covered aura's timer never reads as the count's.
local _, ns = ...

local Widgets, Tokens = ns.Widgets, ns.Tokens

local Overflow = {}
Widgets.Overflow = Overflow

Overflow.LABELS = 24
Overflow.PITCH = 2
local TEMPLATE = "CustomAuraContainerTemplate"
local LAYOUT_TEMPLATE = "DisableUntrustedLayoutScriptsTemplate"
local GROUP = "count"
local TEXT_SHARE = 0.42
local TEXT_MIN = 8
local OPEN = 100000

local function Mute(button)
	if type(button.EnableMouse) == "function" then
		pcall(button.EnableMouse, button, false)
	end
end

local function LayoutFrame(parent)
	local ok, frame = pcall(CreateFrame, "Frame", nil, parent, LAYOUT_TEMPLATE)
	if ok and type(frame) == "table" then
		return frame
	end
	return nil
end

local function Layout(cell)
	return { elementWidth = 1, elementHeight = cell * Overflow.PITCH, elementSpacing = 0, lineSpacing = 0 }
end

local function Specs(groups)
	if type(groups) ~= "table" then
		return { { filter = groups } }
	end
	return groups
end

local function Ghost(parent, unit, spec, max, up)
	local ok, ghost = pcall(CreateFrame, "AuraContainer", nil, parent, TEMPLATE)
	if not ok or type(ghost) ~= "table" or type(ghost.AddAuraGroup) ~= "function" then
		return nil, tostring(ok and "no " .. TEMPLATE or ghost)
	end
	ghost:SetUnit(unit)
	local added, err = pcall(function()
		if spec.policy then
			ghost:SetAuraProcessingPolicy(spec.policy, spec.policyOptions)
		end
		for _, sub in ipairs(spec.groups or { { key = GROUP, filter = spec.filter, candidates = spec.candidates, cap = max } }) do
			ghost:AddAuraGroup(sub.key, sub.filter, { maxFrameCount = sub.cap, layout = Layout(1), initializeFrame = Mute, candidateFilters = sub.candidates })
		end
	end)
	if not added then
		return nil, tostring(err)
	end
	ghost:SetFlowLayoutAnchorPoint(up and "BOTTOMLEFT" or "TOPLEFT")
	local directions = AnchorUtil and AnchorUtil.FlowDirection
	if directions then
		ghost:SetFlowLayoutGrowthDirection(directions.Right, up and directions.Up or directions.Down)
	end
	ghost:SetFlowLayoutMaximumLineSize(1)
	return ghost
end

function Overflow.New(host, unit, groups, cap, opts)
	opts = opts or {}
	local labels = opts.labels or Overflow.LABELS
	local specs = Specs(groups)
	local ghostHost = CreateFrame("Frame", nil, host)
	ghostHost:SetAlpha(0)
	local chain, total = {}, 0
	for _, spec in ipairs(specs) do
		local own, reach = spec.cap or cap, spec.labels or labels
		total = total + reach
		local a, why = Ghost(ghostHost, unit, spec, own + reach)
		local b
		if a and #specs > 1 then
			b, why = Ghost(ghostHost, unit, spec, own, true)
		end
		if not a or (#specs > 1 and not b) then
			ghostHost:Hide()
			return nil, why
		end
		chain[#chain + 1] = { a = a, b = b, labels = reach }
	end
	local window = LayoutFrame(host)
	if not window then
		ghostHost:Hide()
		return nil, LAYOUT_TEMPLATE .. " is missing, and only a frame with it may anchor to the engine's containers"
	end
	window:SetClipsChildren(true)
	local strip = LayoutFrame(window)
	strip:SetClipsChildren(true)
	local chip = {
		ghostHost = ghostHost, ghost = chain[1].a, pairs = chain, window = window, strip = strip,
		labels = {}, texts = {}, count = total, pitch = 0,
	}
	if opts.face ~= false then
		chip.face = LayoutFrame(strip)
		chip.chrome = Widgets.IconChrome(chip.face)
	end
	for i = 1, total do
		local frame = LayoutFrame(strip)
		local text = Widgets.FontString(frame, "OVERLAY")
		text:SetAllPoints(frame)
		chip.labels[i], chip.texts[i] = frame, text
	end
	if opts.saturate then
		chip.sat = LayoutFrame(window)
		chip.sat:SetClipsChildren(true)
		chip.satLabel = LayoutFrame(chip.sat)
		chip.satText = Widgets.FontString(chip.satLabel, "OVERLAY")
		chip.satText:SetAllPoints(chip.satLabel)
	end
	return chip
end

local function StyleLabel(label, size)
	label:SetFont(Tokens.Font("number"), size, "")
	label:SetShadowColor(Tokens.Color("textShadow"))
	local offset = Tokens.Size("textShadowOffset")
	label:SetShadowOffset(offset, -offset)
	pcall(label.SetTextColor, label, Tokens.Color("textEmphasis"))
	label:SetJustifyH("CENTER")
	label:SetJustifyV("MIDDLE")
end

local function Tall(o)
	return o.cell + (o.foot or 0)
end

local function ApplyGroups(chip, o)
	local on = o.enabled == true
	local specs = o.groups or Specs(o.filter)
	for g, pair in ipairs(chip.pairs) do
		local spec = specs[g] or {}
		local cap = spec.cap or o.cap
		local wanted = on and (spec.filter ~= nil or spec.groups ~= nil) and spec.off ~= true
		for _, ghost in ipairs({ pair.a, pair.b }) do
			if spec.policy then
				ghost:SetAuraProcessingPolicy(spec.policy, spec.policyOptions)
			end
			for _, sub in ipairs(spec.groups or { { key = GROUP, filter = spec.filter, candidates = spec.candidates } }) do
				local key, live = sub.key, wanted and sub.off ~= true
				ghost:SetAuraGroupEnabled(key, live)
				if live then
					ghost:SetAuraGroupFilterString(key, sub.filter)
					if type(ghost.SetAuraGroupCandidateFilters) == "function" then
						ghost:SetAuraGroupCandidateFilters(key, sub.candidates)
					end
				end
				ghost:SetAuraGroupMaxFrameCount(key, sub.cap or (ghost == pair.b and cap or cap + pair.labels))
				ghost:SetAuraGroupLayout(key, Layout(Tall(o)))
			end
			ghost:SetEnabled(on)
		end
	end
end

local function Chain(chip, window)
	local frame, point = window, "TOPLEFT"
	for _, pair in ipairs(chip.pairs) do
		pair.a:ClearAllPoints()
		pair.a:SetPoint("TOPLEFT", frame, point, 0, 0)
		if pair.b then
			pair.b:ClearAllPoints()
			pair.b:SetPoint("BOTTOMLEFT", pair.a, "BOTTOMLEFT", 0, 0)
			frame, point = pair.b, "TOPLEFT"
		else
			frame, point = pair.a, "BOTTOMLEFT"
		end
	end
	return frame, point
end

function Overflow.Apply(chip, o)
	local window, strip = chip.window, chip.strip
	ApplyGroups(chip, o)
	window:SetShown(o.enabled == true)
	if o.enabled ~= true then
		return
	end
	local cell, tall = o.cell, Tall(o)
	local width = o.width or cell
	local pitch = tall * Overflow.PITCH
	chip.pitch, chip.cap = pitch, o.cap
	window:ClearAllPoints()
	window:SetPoint(o.point or "TOPLEFT", o.rel, o.relPoint, o.x, o.y)
	window:SetSize(width, tall)
	window:SetFrameLevel(o.level)
	local base, at = Chain(chip, window)
	local lift = #chip.pairs == 1 and (o.groups and o.groups[1].cap or o.cap) * pitch or 0
	strip:ClearAllPoints()
	strip:SetPoint("BOTTOMLEFT", base, at, 0, lift + tall / 2)
	strip:SetPoint("TOPRIGHT", base, at, width, chip.sat and OPEN or lift + chip.count * pitch + tall)
	local face = chip.face
	if face then
		face:ClearAllPoints()
		face:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
		face:SetSize(width, tall)
		chip.chrome:Restyle()
		local r, g, b = Tokens.Color("buttonFill")
		chip.chrome:SetFillRGBA(r, g, b, 1)
		chip.chrome:SetRimAccent(o.accent and o.accent())
	end
	local size = o.textSize or math.max(TEXT_MIN, math.floor(cell * TEXT_SHARE + 0.5))
	local level = (face or strip):GetFrameLevel() + 2
	local shift = o.after and 0 or 1
	local sat = chip.sat
	if sat then
		sat:ClearAllPoints()
		sat:SetPoint("BOTTOMLEFT", base, at, 0, lift + (chip.count + 1) * pitch - tall)
		sat:SetPoint("TOPRIGHT", base, at, width, OPEN)
		local label = chip.satLabel
		label:ClearAllPoints()
		label:SetAllPoints(window)
		label:SetFrameLevel(level)
		if o.style then
			o.style(chip.satText)
		else
			StyleLabel(chip.satText, size)
		end
		Widgets.SetText(chip.satText, (chip.count + shift + 1) .. "+")
	end
	for i, label in ipairs(chip.labels) do
		local top = lift + i * pitch
		label:ClearAllPoints()
		label:SetPoint("TOPLEFT", base, at, 0, top)
		label:SetPoint("BOTTOMRIGHT", base, at, width, top - cell)
		label:SetFrameLevel(level)
		local text = chip.texts[i]
		if o.style then
			o.style(text)
		else
			StyleLabel(text, size)
		end
		Widgets.SetText(text, "+" .. (i + shift))
	end
end

function Overflow.Enable(chip, on)
	for _, pair in ipairs(chip.pairs) do
		pair.a:SetEnabled(on and true or false)
		if pair.b then
			pair.b:SetEnabled(on and true or false)
		end
	end
end

function Overflow.SetUnit(chip, unit)
	for _, pair in ipairs(chip.pairs) do
		pair.a:SetUnit(unit)
		if pair.b then
			pair.b:SetUnit(unit)
		end
	end
end
