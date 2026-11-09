-- Bars.lua: the experience, reputation and honour bars: a track that shows rested experience, the fill, segment ticks, a label in a glass plate on the line, and a tooltip.
local _, ns = ...

local K, L = ns.K, ns.L
local Widgets, Tokens, Motion, Theme = K.Widgets, K.Tokens, K.Motion, K.Theme
local Format, Sources, Font = ns.Format, ns.Sources, ns.Font
local floor, min, max = math.floor, math.min, math.max

local Bars = {}
ns.Bars = Bars

Bars.TOKENS = { gilt = "neutral", muted = "text", cool = "rare" }
local GILT_DIM, GILT_LIT = 0.4, 0.45

local MAX_SEGMENTS = 20
local HIT_PAD = 4
local TEXT_GAP = 2
local CHAR_WIDTH_SHARE = 0.5
local MIN_SIZE = 2
local MAX_WIDTH, MAX_HEIGHT = 1920, 1080
local FALLBACK_WIDTH, FALLBACK_HEIGHT = 441, 5
local FALLBACK_POSITION = { anchor = "BOTTOM", x = 0, y = 0 }

local TEXT_POINTS = {
	CENTER = { "CENTER", "CENTER", 0, 0 },
	TOP = { "BOTTOM", "TOP", 0, 1 },
	BOTTOM = { "TOP", "BOTTOM", 0, -1 },
	LEFT = { "RIGHT", "LEFT", -1, 0 },
	RIGHT = { "LEFT", "RIGHT", 1, 0 },
}

local DEFS = {
	{
		id = "xp", key = "databars.xp", title = L["Experience"], read = Sources.XP,
		events = { "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "PLAYER_LEVEL_CHANGED", "PLAYER_UPDATE_RESTING", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN" },
	},
	{
		id = "rep", key = "databars.rep", title = L["Reputation"], read = Sources.Reputation,
		events = { "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" },
	},
	{
		id = "honor", key = "databars.honor", title = L["Honour"], read = Sources.Honor,
		events = { "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "HONOR_XP_UPDATE", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA" },
	},
}
Bars.DEFS = DEFS
Bars.views = {}

local byId, byKey = {}, {}
for _, def in ipairs(DEFS) do
	byId[def.id], byKey[def.key] = def, def
end

local running = false

local function Size(frame)
	local w, h = frame:GetWidth(), frame:GetHeight()
	return ns.IsNumber(w) and w or 0, ns.IsNumber(h) and h or 0
end

local function SetFill(bar, value)
	bar.kValue = value
	bar:SetValue(value)
end

function Bars.GiltStops()
	local r, g, b = Tokens.Color(Bars.TOKENS.gilt)
	local kr, kg, kb, ka = Tokens.Color("black")
	local wr, wg, wb, wa = Tokens.Color("white")
	local dr, dg, db = Widgets.Mix(r, g, b, 1, kr, kg, kb, ka, GILT_DIM)
	local lr, lg, lb = Widgets.Mix(r, g, b, 1, wr, wg, wb, wa, GILT_LIT)
	return dr, dg, db, lr, lg, lb
end

local function Gradient(fill, gilt)
	local texture = fill:GetStatusBarTexture()
	if not (texture and type(texture.SetGradient) == "function" and type(CreateColor) == "function") then
		return
	end
	if gilt then
		local dr, dg, db, lr, lg, lb = Bars.GiltStops()
		texture:SetGradient("HORIZONTAL", CreateColor(dr, dg, db, 1), CreateColor(lr, lg, lb, 1))
	elseif fill.kGilt then
		local wr, wg, wb, wa = Tokens.Color("white")
		texture:SetGradient("HORIZONTAL", CreateColor(wr, wg, wb, wa), CreateColor(wr, wg, wb, wa))
	end
	fill.kGilt = gilt
end

local function Color(view, s, info)
	local fill = view.fill
	local source = s.colorSource
	local gilt = source == "gilt"
	if not gilt then
		Gradient(fill, false)
	end
	if gilt then
		fill:SetBarColor(Tokens.Color("white"))
		Gradient(fill, true)
	elseif source == "class" then
		fill:SetColorToken("accent")
	elseif source == "reaction" then
		local kind = info and info.kind
		if kind == "major" or kind == "paragon" then
			fill:SetColorToken("rare")
		elseif info and info.reaction then
			fill:SetBarColor(Theme.ReactionColor(info.reaction))
		else
			fill:SetColorToken("neutral")
		end
	else
		local c = s.color
		fill:SetBarColor(c.r, c.g, c.b, c.a or 1)
	end
	local rested = s.restedColor
	if type(rested) == "table" then
		view.track:SetBarColor(rested.r, rested.g, rested.b, rested.a or 1)
	end
end

local function LayoutTicks(view, s)
	local count = ns.IsNumber(s.segments) and floor(s.segments) or 0
	count = max(0, min(MAX_SEGMENTS, count))
	local holder, overlay = view.holder, view.overlay
	local w, h = Size(holder)
	local vertical = s.orientation == "VERTICAL"
	local border = Widgets.Border(holder)
	for i, tick in ipairs(view.ticks) do
		if count > 1 and i < count then
			tick:ClearAllPoints()
			if vertical then
				local y = Widgets.Snap(holder, h * i / count)
				tick:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, y)
				tick:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, y)
				tick:SetHeight(border)
			else
				local x = Widgets.Snap(holder, w * i / count)
				tick:SetPoint("TOPLEFT", overlay, "TOPLEFT", x, 0)
				tick:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", x, 0)
				tick:SetWidth(border)
			end
			Widgets.Tint(tick, "edgeOuter")
			tick:Show()
		else
			tick:Hide()
		end
	end
end

local function PlaceText(view, position)
	local p = TEXT_POINTS[position] or TEXT_POINTS.CENTER
	local gap = Widgets.Snap(view.holder, TEXT_GAP)
	view.text:ClearAllPoints()
	view.text:SetPoint(p[1], view.holder, p[2], p[3] * gap, p[4] * gap)
end

local function PlacePlate(view, s)
	local plate, text = view.plate, view.text
	local onLine = (TEXT_POINTS[s.textPosition] or TEXT_POINTS.CENTER) == TEXT_POINTS.CENTER and s.orientation ~= "VERTICAL"
	Widgets.TextColor(text, onLine and "textEmphasis" or Bars.TOKENS.muted)
	onLine = onLine and text:IsShown()
	plate:SetShown(onLine)
	if not onLine then
		return
	end
	local _, size = text:GetFont()
	size = ns.IsNumber(size) and size or s.fontSize
	local holder = view.holder
	local label = text:GetText()
	local guess = type(label) == "string" and not ns.IsSecret(label) and #label * size * CHAR_WIDTH_SHARE or 0
	local width = Widgets.TextWidth(text, guess) + 2 * Widgets.Snap(holder, Tokens.Size("gapMedium"))
	local height = size + 2 * Widgets.Snap(holder, Tokens.Size("gapTiny"))
	plate:ClearAllPoints()
	plate:SetPoint("CENTER", text, "CENTER")
	plate:SetSize(Widgets.Snap(holder, width), Widgets.Snap(holder, height))
end

local function TextFor(s, info)
	if not info or s.text == "none" then
		return nil
	end
	if info.capped then
		return info.label
	end
	return Format.BarText(s.text, info.current, info.max, info.label, info.short, info.rested)
end

local function UpdateText(view, s, info)
	local value = TextFor(s, info)
	if value then
		view.text:SetText(value)
	end
	view.text:SetShown(value ~= nil and (not s.textHover or view.hovered == true))
	PlacePlate(view, s)
end

local function Values(view, s, info, instant)
	local fill, track = view.fill, view.track
	local rangeChanged = view.max ~= info.max or view.level ~= info.level or view.kind ~= info.kind
	view.max, view.level, view.kind = info.max, info.level, info.kind
	fill:SetMinMaxValues(0, info.max)
	track:SetMinMaxValues(0, info.max)
	local from = fill.kValue
	if instant or rangeChanged or from == nil then
		if view.tween then
			Motion.Stop(view.tween)
			view.tween = nil
		end
		SetFill(fill, info.current)
	else
		view.tween = Motion.Tween(fill, SetFill, from, info.current, Tokens.Duration("fade"), Tokens.Easing("fade"))
	end
	local rested = 0
	if s.rested and ns.IsNumber(info.rested) and info.rested > 0 then
		rested = min(info.current + info.rested, info.max)
	end
	track:SetValue(rested)
end

local function Style(view, s)
	local fill, track = view.fill, view.track
	fill:SetBarTexture(s.texture)
	track:SetBarTexture(s.texture)
	local orientation = s.orientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL"
	fill:SetOrientation(orientation)
	track:SetOrientation(orientation)
	fill:SetReverseFill(s.reverse == true)
	track:SetReverseFill(s.reverse == true)
	if track.borderFrame then
		track.borderFrame:SetShown(s.border ~= false)
	end
	if orientation == "VERTICAL" then
		view.holder:SetHitRectInsets(-HIT_PAD, -HIT_PAD, 0, 0)
	else
		view.holder:SetHitRectInsets(0, 0, -HIT_PAD, -HIT_PAD)
	end
	LayoutTicks(view, s)
	Font.Apply(view.text, s.font, s.fontSize, s.outline)
	PlaceText(view, s.textPosition)
end

function Bars.PaintValues(view, s, info, instant)
	Color(view, s, info)
	if info then
		Values(view, s, info, instant)
	end
	UpdateText(view, s, info)
end

function Bars.Paint(view, s, info, instant)
	Style(view, s)
	view.styled = true
	Bars.PaintValues(view, s, info, instant)
end

local function AddTooltip(view, tip)
	local info = view.info
	tip:AddTitle(view.def.title)
	if not info then
		tip:AddLine(L["Nothing to show right now."], "textDisabled")
		return
	end
	local id = view.def.id
	if id == "rep" then
		tip:AddLine(info.name, "textEmphasis")
		tip:AddDoubleLine(L["Standing"], info.standing)
	else
		tip:AddLine(info.label, "textEmphasis")
	end
	if info.capped then
		tip:AddLine(L["Fully earned."], "text")
		return
	end
	tip:AddDivider()
	tip:AddDoubleLine(L["Progress"], Format.BarText("valuePercent", info.current, info.max))
	tip:AddDoubleLine(L["Remaining"], Format.Number(info.max - info.current))
	if id == "xp" and info.rested > 0 then
		tip:AddDoubleLine(info.restName or L["Rested"], Format.Number(info.rested) .. " (" .. Format.Percent(info.rested, info.max) .. "%)")
	elseif id == "rep" and info.rewardPending then
		tip:AddLine(L["A paragon reward is waiting for you."], "friendly")
	elseif id == "honor" and info.kind == "rank" then
		tip:AddLine(L["Rank points earned toward your next PvP rank."], "text")
	end
end

local function OnEnter(holder)
	local view = holder.kView
	view.hovered = true
	if running then
		UpdateText(view, ns.Settings()[view.def.id], view.info)
	end
	local tip = Widgets.Tooltip()
	tip:SetOwner(holder, "ANCHOR_TOP")
	K.Call(AddTooltip, view, tip)
	tip:Show()
end

local function OnLeave(holder)
	local view = holder.kView
	view.hovered = false
	if running then
		UpdateText(view, ns.Settings()[view.def.id], view.info)
	end
	local tip = Widgets.Tooltip()
	if tip:IsOwned(holder) then
		tip:Hide()
	end
end

function Bars.NewView(parent, def)
	local view = { def = def, ticks = {} }
	local holder = CreateFrame("Frame", nil, parent)
	holder.kView = view
	view.holder = holder
	local content = CreateFrame("Frame", nil, holder)
	content:SetAllPoints(holder)
	view.content = content
	local track = Widgets.StatusBar(content, { background = "track", border = true, min = 0, max = 1, value = 0 })
	track:SetAllPoints(content)
	local fill = Widgets.StatusBar(content, { background = false, min = 0, max = 1, value = 0 })
	fill:SetAllPoints(content)
	fill:SetFrameLevel(track:GetFrameLevel() + 1)
	local overlay = CreateFrame("Frame", nil, content)
	overlay:SetAllPoints(content)
	overlay:SetFrameLevel(fill:GetFrameLevel() + 1)
	view.track, view.fill, view.overlay = track, fill, overlay
	for i = 1, MAX_SEGMENTS - 1 do
		local tick = overlay:CreateTexture(nil, "OVERLAY")
		tick:SetColorTexture(Tokens.Color("white"))
		tick:Hide()
		view.ticks[i] = tick
	end
	local plate = CreateFrame("Frame", nil, overlay)
	plate:SetFrameLevel(overlay:GetFrameLevel() + 1)
	plate.chrome = Widgets.Chrome(plate, { shape = "tile", fill = "surface", shadow = false, edge = "edgeBar" })
	plate:Hide()
	view.plate = plate
	local label = CreateFrame("Frame", nil, overlay)
	label:SetAllPoints(overlay)
	label:SetFrameLevel(plate:GetFrameLevel() + 1)
	view.text = Widgets.FontString(label, "OVERLAY")
	Widgets.TextColor(view.text, "textEmphasis")
	view.text:Hide()
	return view
end

local function Footprint(key)
	local layouts = K.Setup and K.Setup.Layouts
	local element = layouts and layouts.Element(key)
	if element then
		return element.width, element.height, element.label, layouts.Default(key)
	end
	ns.LogOnce("footprint:" .. key, key .. " has no footprint in Setup.Layouts; using the fallback size and position")
	return FALLBACK_WIDTH, FALLBACK_HEIGHT, key, { anchor = FALLBACK_POSITION.anchor, x = FALLBACK_POSITION.x, y = FALLBACK_POSITION.y }
end

local function Build(def)
	local view = Bars.NewView(K.Scale.Root(), def)
	local holder = view.holder
	local width, height, label, position = Footprint(def.key)
	holder:SetSize(width, height)
	holder:EnableMouse(true)
	holder:HookScript("OnEnter", OnEnter)
	holder:HookScript("OnLeave", OnLeave)
	K.Layout.Register(holder, def.key, position, {
		label = label, module = ns.MODULE, resizable = true,
		minWidth = MIN_SIZE, minHeight = MIN_SIZE, maxWidth = MAX_WIDTH, maxHeight = MAX_HEIGHT,
	})
	Bars.views[def.id] = view
	return view
end

function Bars.Update(id, instant)
	local view = Bars.views[id]
	if not view or not running then
		return
	end
	local s = ns.Settings()[id]
	local info, why = view.def.read()
	if info and id == "honor" and s.show == "pvp" and not Sources.InPvP() then
		info, why = nil, "not in PvP"
	end
	if not info and view.why ~= why then
		ns.Log(id .. " bar hidden: " .. tostring(why))
	end
	view.info, view.why = info, why
	view.content:SetShown(info ~= nil)
	if instant or not view.styled then
		Bars.Paint(view, s, info, instant)
	else
		Bars.PaintValues(view, s, info, instant)
	end
end

function Bars.UpdateAll(instant)
	for _, def in ipairs(DEFS) do
		Bars.Update(def.id, instant)
	end
end

local function MatchOrientation(def)
	local s = ns.Settings()[def.id]
	local layout = K.Layout.Get(def.key)
	if not layout then
		return
	end
	local w, h = layout.width, layout.height
	local vertical = s.orientation == "VERTICAL"
	if (vertical and w > h) or (not vertical and h > w) then
		local ok, why = K.Layout.Update(def.key, { width = h, height = w })
		if not ok then
			ns.Log("could not turn " .. def.key .. ": " .. tostring(why))
		end
	end
end

local function MatchAll()
	for _, def in ipairs(DEFS) do
		MatchOrientation(def)
	end
end

function Bars.Enable()
	running = true
	for _, def in ipairs(DEFS) do
		local view = Bars.views[def.id] or Build(def)
		view.holder:Show()
	end
	MatchAll()
	Bars.UpdateAll(true)
end

function Bars.Disable()
	running = false
	for _, view in pairs(Bars.views) do
		if view.tween then
			Motion.Stop(view.tween, true)
			view.tween = nil
		end
		view.hovered = false
		view.holder:Hide()
		local tip = Widgets.Tooltip()
		if tip:IsOwned(view.holder) then
			tip:Hide()
		end
	end
end

function Bars.Setting(key)
	local id, field = key:match("^(%a+)%.(.+)$")
	local def = id and byId[id]
	if not def then
		return
	end
	if field == "orientation" then
		MatchOrientation(def)
	end
	Bars.Update(id, true)
end

for _, def in ipairs(DEFS) do
	local id = def.id
	local function update()
		Bars.Update(id)
	end
	for _, event in ipairs(def.events) do
		ns.Listen(event, update)
	end
	ns.Listen("PLAYER_ENTERING_WORLD", update)
end

ns.Subscribe("LayoutChanged", function(key)
	local def = byKey[key]
	if def and running then
		Bars.Update(def.id, true)
	end
end)

ns.AddPart({ Enable = Bars.Enable, Disable = Bars.Disable, Setting = Bars.Setting, Refresh = function()
	MatchAll()
	Bars.UpdateAll(true)
end })
