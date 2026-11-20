-- Preview.lua: the settings window's live preview: sample buffs and debuffs on the module's own plain tiles, laid out as the settings say.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Model, Button = ns.Model, ns.Button
local floor, min, max, ceil = math.floor, math.min, math.max, math.ceil

local Preview = {}
ns.Preview = Preview

local build
function Preview.Build(...)
	if build then return build(...) end
	local BUFFS = {
		{ icon = 135987, seconds = 24, spell = 1243, cancelable = true, dispellable = true },
		{ icon = 136078, seconds = 17, stacks = "3", spell = 1126, cancelable = true, important = true },
		{ icon = 135932, seconds = 12, spell = 1459, cancelable = true, bigDefensive = true },
		{ icon = 135906, seconds = 480, spell = 19740, cancelable = true, important = true },
		{ icon = 132333, seconds = 180, spell = 6673, cancelable = true },
		{ icon = 135953, seconds = 2.4, refresh = true, spell = 139, cancelable = true, dispellable = true },
		{ icon = 135893, spell = 465 },
	}
	local DEBUFFS = {
		{ icon = 136207, seconds = 18, kind = "MAGIC", dispellable = true },
		{ icon = 136118, seconds = 9, kind = "CURSE", stacks = "2", dispellable = true },
		{ icon = 135846, seconds = 4, kind = "NONE", refresh = true, crowdControl = true },
	}
	local TYPE_NAMES = { MAGIC = "Magic", CURSE = "Curse" }

	local function DispelColor(kind)
		local colors = {
			MAGIC = DEBUFF_TYPE_MAGIC_COLOR,
			CURSE = DEBUFF_TYPE_CURSE_COLOR,
			NONE = DEBUFF_TYPE_NONE_COLOR,
		}
		local color = colors[kind]
		if type(color) == "table" and type(color.GetRGB) == "function" then
			local ok, r, g, b = pcall(color.GetRGB, color)
			if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
				return r, g, b
			end
		end
		return Tokens.Color("hostile")
	end

	local function Settings()
		local Store = K.Store
		if Store.IsLoaded and Store.IsLoaded() then
			return Store.Module(Model.MODULE)
		end
		return Model.defaults
	end

	local function Sample(canvas, spec, hasDispel)
		local button = CreateFrame("Frame", nil, canvas)
		local entry = Button.Create(button, hasDispel)
		entry.spec = spec
		entry.icon:SetTexture(spec.icon)
		return entry
	end

	local function Context(canvas, group, timer, count, edge)
		local function snap(units)
			return Widgets.Snap(canvas, units)
		end
		local ctx = { group = group, timer = timer, count = count, icon = snap(group.iconSize), edge = edge, iconZoom = Model.IconZoom(Settings()), rule = ns.Panel.RuleFormatter(timer) }
		ctx.width, ctx.height = Model.ElementSize(group, timer, snap)
		ctx.spacing, ctx.rowSpacing = Model.Gaps(group, timer, snap)
		return ctx
	end

	local function StyleSample(entry, ctx)
		Button.Style(entry, ctx)
		local seconds = entry.spec.seconds
		entry.timer:SetText(ctx.rule and seconds and ctx.rule:FormatNumber(seconds) or Model.FormatTime(seconds, ctx.timer.format))
		entry.timer:SetShown(ctx.timer.format ~= "none")
		if seconds and seconds < ctx.timer.expiring then
			entry.timer:SetTextColor(Tokens.Color("hostile"))
		end
		if seconds and entry.swipe and ctx.group.swipe and type(entry.swipe.SetCooldown) == "function" and type(GetTime) == "function" then
			entry.swipe:SetCooldown(GetTime(), seconds)
		end
		entry.count:SetText(entry.spec.stacks or "")
		entry.badge:SetShown(entry.spec.stacks ~= nil)
		if entry.dispel then
			Widgets.ColorSlice(entry.dispel, DispelColor(entry.spec.kind))
			Widgets.ShowSlice(entry.dispel, ctx.group.dispel == true)
		end
		if entry.typeIcon then
			local util, kind = AuraUtil, TYPE_NAMES[entry.spec.kind]
			local atlas = kind and ctx.group.typeIcon ~= "none" and type(util) == "table" and type(util.GetAuraDispelTypeIcon) == "function" and util.GetAuraDispelTypeIcon(kind)
			if atlas then
				entry.typeIcon:SetAtlas(atlas)
			end
			entry.typeIcon:SetShown(atlas and true or false)
		end
		if entry.cue then
			entry.cue:SetShown(ctx.group.refresh and entry.spec.refresh == true)
		end
	end

	local function Passes(spec, group, lists)
		if (group.show ~= "all" and not spec[group.show]) or (group.timed and not spec.seconds) or (group.dispellable and not spec.dispellable) then
			return false
		end
		local include, exclude = lists and lists.includeSpellIDs, lists and lists.excludeSpellIDs
		return not (include and not include[spec.spell]) and not (exclude and exclude[spec.spell])
	end

	local function PlaceGroup(box, entries, group, ctx, lists)
		local w, h = ctx.width, ctx.height
		local visible = {}
		for i = 1, #entries do
			local entry = entries[group.reverse and #entries + 1 - i or i]
			local pass = #visible < group.rows * group.columns and Passes(entry.spec, group, lists)
			if pass then
				visible[#visible + 1] = entry
			end
			entry.button:SetShown(pass)
		end
		local shown = #visible
		local columns = max(1, min(group.columns, shown))
		local rows = max(1, ceil(shown / group.columns))
		local boxWidth = columns * w + (columns - 1) * ctx.spacing
		local boxHeight = rows * h + (rows - 1) * ctx.rowSpacing
		box:SetSize(max(1, boxWidth), max(1, boxHeight))
		local _, horizontal, vertical = Model.Growth(group.growth)
		for i, entry in ipairs(visible) do
			local button = entry.button
			local col, row = (i - 1) % group.columns, floor((i - 1) / group.columns)
			local x = col * (w + ctx.spacing)
			if horizontal == "Left" then
				x = boxWidth - w - x
			end
			local top = row * (h + ctx.rowSpacing)
			if vertical == "Up" then
				top = boxHeight - h - top
			end
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", box, "TOPLEFT", x, -top)
		end
		return boxWidth, boxHeight
	end

	local function Fit(group, timer, available)
		if not available then
			return group
		end
		local w = Model.ElementSize(group, timer)
		local columns = max(1, floor((available + group.spacing) / (w + group.spacing)))
		if columns >= group.columns then
			return group
		end
		local fitted = {}
		for key, value in pairs(group) do
			fitted[key] = value
		end
		fitted.columns = columns
		return fitted
	end

	local function Refresh(frame)
		local settings = Settings()
		local timer, count = Model.Timer(settings), Model.Count(settings)
		local textScale = Model.TextScale()
		timer.size, count.size = timer.size * textScale, count.size * textScale
		local gap = Tokens.Size("gapLarge")
		local widest = 0
		local boxes = {
			{ frame.buffBox, frame.buffs, "buffs" }, { frame.debuffBox, frame.debuffs, "debuffs" },
			{ frame.extraBuffBox, frame.extraBuffs, "extraBuffs" }, { frame.extraDebuffBox, frame.extraDebuffs, "extraDebuffs" },
		}
		local top = 0
		local available = frame:GetWidth()
		if type(available) ~= "number" or Widgets.IsSecret(available) or available <= 0 then
			available = nil
		end
		for _, item in ipairs(boxes) do
			local box, entries, name = item[1], item[2], item[3]
			local group = Fit(Model.Group(settings, name), timer, available)
			box:SetShown(group.enabled)
			if group.enabled then
				local r, g, b = Tokens.Color("black")
				local ctx = Context(frame.canvas, group, timer, count, { r, g, b, 1 })
				for _, entry in ipairs(entries) do
					StyleSample(entry, ctx)
				end
				local w, h = PlaceGroup(box, entries, group, ctx, Model.KIND[name] == "buffs" and K.Options.AuraCandidates(settings[name] or {}) or nil)
				box:ClearAllPoints()
				Widgets.Point(box, "TOPRIGHT", frame.canvas, "TOPRIGHT", 0, -top)
				top = top + h + gap
				widest = max(widest, w)
			end
		end
		local scale = 1
		if available and widest > available then
			scale = available / widest
		end
		local height = frame:GetHeight()
		if not Widgets.IsSecret(height) and type(height) == "number" and height > 0 then
			scale = min(scale, height / max(1, top - gap))
		end
		frame.canvas:SetScale(scale)
		frame.canvas:SetSize(max(widest, 1), max(top, 1))
		frame.canvas:ClearAllPoints()
		Widgets.Point(frame.canvas, "TOPRIGHT", frame, "TOPRIGHT")
	end

	build = function(parent)
		local frame = CreateFrame("Frame", nil, parent)
		frame:SetAllPoints(parent)
		local canvas = CreateFrame("Frame", nil, frame)
		frame.canvas = canvas
		for _, row in ipairs({ { "buffBox", "buffs", BUFFS }, { "debuffBox", "debuffs", DEBUFFS }, { "extraBuffBox", "extraBuffs", BUFFS }, { "extraDebuffBox", "extraDebuffs", DEBUFFS } }) do
			local box = CreateFrame("Frame", nil, canvas)
			frame[row[1]], frame[row[2]] = box, {}
			for i, spec in ipairs(row[3]) do
				frame[row[2]][i] = Sample(box, spec, row[3] == DEBUFFS)
			end
		end
		frame.Refresh = Refresh
		Refresh(frame)
		return frame
	end
	return build(...)
end
