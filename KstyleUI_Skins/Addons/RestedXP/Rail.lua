-- Rail.lua: puts RestedXP's guide window in a card of its own on the story rail: a Layout element, the RestedXP guide, holds its place (its own mover in Layout Mode, above the quest card's by default; in Orbs under it in one column, hanging a rail gap under the quest card's own foot while both stand at their places) and the guide hangs from the element's top on its left edge and width, the cap, the active steps and the route row stacked down from there with RestedXP's window folded to its floor behind them, its step list folded by RestedXP's own rule and its footer at rest (the footer comes back while a RestedXP timer bar runs); the steps that would run past the element's foot rest unseen behind a muted "N more" line, in combat too, so the guide never draws over the quest card or anything under it; re-placed after each step, on entering the world and after a layout change, out of combat, and kept out of RestedXP's saved settings by RestedXP's own savePosition switch while the rail holds the window.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L

local RestedXP = ns.RestedXP
local LogOnce = RestedXP.LogOnce

local Rail = {}
RestedXP.Rail = Rail

local MODULE = "Skins"
local KEY = "restedXP"
local FIELD = "rail"
local OWNER = "Skins.RestedXP.Rail"
local DEFAULT_PRESET = "DPS"
local SIDE, FOOTER, HEAD_HEIGHT, HEADER_OVERLAP, STEP_GAP = 3, 20, 35, 9, 2
local MIN_HEIGHT, LIST_SHOWN, EMPTY_STEPS = 28, 30, 0.01
local SAVE = "savePosition"
local FOOT_GAP = "gapSmall"
local MOVED = 1
local RXP_STEP_GAP, MORE_ROW, MORE_SCALE, REST_FOOT = 5, 12.5, 0.85, 12

local state = { rxp = nil, placed = nil, original = nil, queued = false, hooked = false, tracked = false, holder = nil, cut = setmetatable({}, { __mode = "k" }), hidden = 0 }

local function Log(message)
	K.DevTest.Log(MODULE, "restedXP rail: " .. message)
end

local function IsTable(value)
	return type(value) == "table"
end

local function Plain(value)
	return type(value) == "number" and not Widgets.IsSecret(value) and value == value
end

local function On()
	return K.Modules.IsRunning(MODULE) and ns.Skins.IsOn(KEY) and ns.Skins.Setting(KEY, FIELD) == true
end

local function Frame()
	local rxp = state.rxp
	local f = IsTable(rxp) and rxp.RXPFrame
	if not IsTable(f) or not IsTable(f.GuideName) or not IsTable(f.CurrentStepFrame) then
		return nil
	end
	if IsTable(rxp.v2) and type(rxp.v2.IsGuideWindowEnabled) == "function" then
		local ok, v2 = pcall(rxp.v2.IsGuideWindowEnabled, rxp.v2)
		if ok and v2 == true then
			LogOnce("rail v2", "RestedXP's v2 guide window is on; the story rail places only the v1 guide window")
			return nil
		end
	end
	return f
end

local function Preset()
	local Layout = K.Layout
	return Layout and type(Layout.Setting) == "function" and Layout.Setting("preset") or DEFAULT_PRESET
end

local function Spec(style)
	local Setup = K.Setup
	local Layouts = Setup and Setup.Layouts
	if not (Layouts and type(Layouts.Story) == "function") then
		return nil
	end
	local _, rh = Setup.RootSize()
	local story = Layouts.Story(Preset(), rh, true, style) or Layouts.Story(DEFAULT_PRESET, rh, true, style)
	return story and story.guide
end

local function Size()
	local holder, spec = state.holder, Spec(K.HudStyle.Current())
	if holder and spec then
		holder:SetSize(spec.width, spec.height)
	end
	return spec
end

local function Holder()
	if state.holder then
		return state.holder
	end
	local spec = Spec()
	if not spec then
		return nil
	end
	local holder = CreateFrame("Frame", "KstyleUI_GuideCard", K.Scale.Root())
	holder:EnableMouse(false)
	state.holder = holder
	Size()
	Widgets.Place(holder, spec.key, { anchor = spec.anchor, x = spec.x, y = spec.y }, { label = L["RestedXP guide"], module = MODULE })
	return holder
end

local function Live()
	local Layout = K.Layout
	local spec = Spec()
	if state.holder and spec and Layout and type(Layout.SetLive) == "function" then
		Layout.SetLive(spec.key, On())
	end
end

function Rail.Story()
	local Setup = K.Setup
	Size()
	return Setup and type(Setup.Story) == "function" and Setup.Story(Preset(), true) or nil
end

local function CardBottom()
	local quests = ns.QuestCard
	local card = quests and quests.Frame()
	if not (card and card:IsShown()) then
		return nil
	end
	local bottom, rb = card:GetBottom(), K.Scale.Root():GetBottom()
	if Plain(bottom) and Plain(rb) then
		return bottom * Widgets.ScaleFactor(card) - rb
	end
end

function Rail.Band()
	local story = Rail.Story()
	local band = story and story.guide
	if not (band and story.stacked) then
		return band
	end
	local gap = K.Setup.Layouts.STORY_GAP
	local bottom = CardBottom()
	if bottom and math.abs(story.tracker.bottom - band.top - gap) < 2 * K.Scale.Pixel(1) and bottom > story.tracker.bottom then
		band.top = math.min(story.tracker.top, bottom) - gap
	end
	return band
end

local function Remember(f)
	if state.original then
		return
	end
	local points = {}
	for i = 1, f:GetNumPoints() do
		points[i] = { f:GetPoint(i) }
	end
	state.original = { points = points, width = f:GetWidth(), height = f:GetHeight() }
end

local function Hold(f, on)
	if on and not state.held then
		state.held = { value = f[SAVE] }
		f[SAVE] = false
	elseif not on and state.held then
		f[SAVE] = state.held.value
		state.held = nil
	end
end

local function Bars(f)
	local bars = IsTable(f.BarContainer) and f.BarContainer.bars
	return IsTable(bars) and next(bars) ~= nil
end

local function IsTip(step)
	return IsTable(step.step) and step.step.tip and true or false
end

local function Alpha(region)
	local alpha = region:GetAlpha()
	return Plain(alpha) and alpha or 1
end

local function Height(region)
	local height = region:GetHeight()
	return Plain(height) and height or 0
end

local function Shape(f, path, steps)
	local head = path and Widgets.Snap(f.GuideName, path.height) or HEAD_HEIGHT
	local below = f.CurrentStepFrame.anchor == "BOTTOM"
	local above = (steps and not below) and steps + STEP_GAP or 0
	local under = below and steps or 0
	local folded = path ~= nil and under == 0 and not Bars(f)
	local height = folded and MIN_HEIGHT or math.max(MIN_HEIGHT, Widgets.Snap(f, HEADER_OVERLAP + SIDE + FOOTER + Tokens.Size(FOOT_GAP)))
	local foot = height + under
	if folded then
		foot = HEADER_OVERLAP + SIDE - (path.metaShown and 0 or head + (above > 0 and STEP_GAP or 0))
	end
	local rest = folded and Widgets.Snap(f, MIN_HEIGHT - REST_FOOT) or foot
	local headTop = head - HEADER_OVERLAP - SIDE
	local cap = path and path.capHeight or 0
	return { headTop = headTop, above = above, foot = foot, height = height, folded = folded, cap = cap, span = headTop + above + cap + math.max(foot, rest) }
end

local function Around(f, path)
	local card, current = path and path.card, f.CurrentStepFrame
	if not card or not current:IsShown() then
		return nil
	end
	local ct, cb, st, sb = card:GetTop(), card:GetBottom(), current:GetTop(), current:GetBottom()
	if not (Plain(ct) and Plain(cb) and Plain(st) and Plain(sb)) or ct <= cb then
		return nil
	end
	return ct - st, sb - cb
end

local function More(path)
	local card = path and path.card
	if not card then
		return nil
	end
	if not state.more or state.more:GetParent() ~= card then
		state.more = Widgets.FontString(card, "OVERLAY")
		state.more:SetJustifyH("CENTER")
	end
	return state.more
end

local function Mute(region)
	if IsTable(region) and type(region.EnableMouse) == "function" and not state.cut[region] then
		state.cut[region] = "mouse"
		region:EnableMouse(false)
	end
end

local function Cut(region)
	Mute(region)
	state.cut[region] = "alpha"
	region:SetAlpha(0)
	for _, line in ipairs(IsTable(region.elements) and region.elements or {}) do
		Mute(line)
		Mute(IsTable(line) and line.button)
	end
end

local function Uncut()
	local any = false
	for region, how in pairs(state.cut) do
		state.cut[region] = nil
		any = true
		if Height(region) > 1 then
			if how == "alpha" then
				region:SetAlpha(1)
			end
			region:EnableMouse(true)
		end
	end
	return any
end

local function Lines(step, room)
	local top = step:GetTop()
	local reach = 0
	for _, line in ipairs(IsTable(step.elements) and step.elements or {}) do
		if IsTable(line) and line:IsShown() and Alpha(line) > 0 then
			local bottom = line:GetBottom()
			local ends = Plain(top) and Plain(bottom) and top - bottom or nil
			if not ends or ends > room then
				Cut(line)
				Mute(line.button)
			else
				reach = math.max(reach, ends)
			end
		end
	end
	return reach
end

local function Fit(f, path, band)
	local current = f.CurrentStepFrame
	local pool = IsTable(current.framePool) and current.framePool or {}
	local more = More(path)
	local restored = Uncut()
	local steps, natural, counted = {}, 0, 0
	for _, step in ipairs(pool) do
		if IsTable(step) and step:IsShown() and not IsTip(step) then
			local h = Height(step)
			natural = natural + h + (counted > 0 and RXP_STEP_GAP or 0)
			counted = counted + 1
			if h > 1 and Alpha(step) > 0 then
				steps[#steps + 1] = { step = step, height = h, top = natural - h }
			end
		end
	end
	if not band or not current:IsShown() then
		if restored then
			current:SetHeight(math.max(EMPTY_STEPS, natural))
		end
		if more then
			more:Hide()
		end
		state.hidden = 0
		return 0
	end
	local scale = Widgets.ScaleFactor(f)
	local room = (band.top - band.bottom) / scale
	local row = Widgets.Snap(f, MORE_ROW / scale)
	local pixel = K.Scale.Pixel(1) / scale
	local over, under = Around(f, path)
	local function Span(reach)
		if over then
			return over + reach + under
		end
		return Shape(f, path, reach).span
	end
	local keep, height = #steps, natural
	while keep > 0 do
		local reach = keep < #steps and steps[keep].top + steps[keep].height + row or natural
		if Span(reach) <= room + pixel then
			height = reach
			break
		end
		keep = keep - 1
	end
	local partial = 0
	if keep == 0 and #steps > 0 then
		local first = steps[1].step
		local fixed = Span(0) + row
		local reach = Lines(first, room + pixel - fixed)
		if reach > 0 then
			keep, partial = 1, 1
		end
		height = reach + row
	end
	for i = keep + 1, #steps do
		Cut(steps[i].step)
	end
	local hidden = #steps - keep + partial
	if hidden > 0 or Plain(current:GetHeight()) and math.abs(current:GetHeight() - height) > 0.01 then
		current:SetHeight(math.max(EMPTY_STEPS, height))
	end
	if more then
		if hidden > 0 then
			ns.Style.ApplyFont(more, "body", ns.Lumen.Size(more, ns.Lumen.TEXT_SIZE) * MORE_SCALE)
			Widgets.TextColor(more, "muted")
			more:SetText(string.format(L["%d more"], hidden))
			more:ClearAllPoints()
			more:SetPoint("CENTER", current, "BOTTOM", 0, row / 2)
			more:Show()
		else
			more:SetText("")
			more:Hide()
		end
	end
	if hidden ~= state.hidden then
		state.hidden = hidden
		Log(hidden > 0 and string.format("%d of the guide's steps rest under a more line, past the foot of its card", hidden) or "every step of the guide fits its card")
	end
	return hidden
end

local function Refresh(f)
	local list = f.BottomFrame
	if IsTable(list) and type(list.UpdateFrame) == "function" then
		RestedXP.Try("BottomFrame.UpdateFrame", list.UpdateFrame)
	end
end

function Rail.Fit()
	local f = Frame()
	if not f or not On() or not state.placed then
		return 0
	end
	return Fit(f, RestedXP.Chrome.Path(f), Rail.Band())
end

function Rail.Hidden()
	return state.hidden
end

function Rail.Place()
	state.queued = false
	if not On() then
		return false
	end
	local f = Frame()
	Holder()
	local band = Rail.Band()
	if not f or not band then
		return false
	end
	local path = RestedXP.Chrome.Path(f)
	local scale = Widgets.ScaleFactor(f)
	local reach = Widgets.Snap(f, RestedXP.Chrome.Reach(f.GuideName))
	local width = (band.right - band.left) / scale + 2 * SIDE - 2 * reach
	local left = band.left / scale - SIDE + reach
	Remember(f)
	Hold(f, true)
	local shape
	for _ = 1, 2 do
		local before = Height(f.CurrentStepFrame)
		Fit(f, path, band)
		if shape and math.abs(Height(f.CurrentStepFrame) - before) < 0.01 then
			break
		end
		local steps = f.CurrentStepFrame:IsShown() and Height(f.CurrentStepFrame) or nil
		shape = Shape(f, path, steps)
		local top = band.top / scale - shape.headTop - shape.above - shape.cap
		f:ClearAllPoints()
		f:SetSize(width, shape.height)
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + K.Scale.Origin() / scale, top)
		state.placed = { left = left, top = top, width = width, height = shape.height }
		RestedXP.Chrome.Rest(f, true, shape.folded)
	end
	Refresh(f)
	if shape.height - SIDE - (FOOTER - 6) >= LIST_SHOWN then
		LogOnce("rail list", "the guide's head is tall enough that RestedXP keeps a sliver of its step list")
	end
	local card, root = path and path.card, K.Scale.Root()
	local bottom, rb = card and card:GetBottom(), root:GetBottom()
	if Plain(bottom) and Plain(rb) then
		local reached = band.bottom - (bottom * scale - rb)
		if reached > 0.5 then
			Log(string.format("the guide's card reaches %.0f units under its element on the story rail", reached))
		end
	end
	Live()
	return true
end

local function Schedule()
	if state.queued or not On() then
		return
	end
	state.queued = true
	C_Timer.After(0, function()
		K.Combat.Queue(Rail.Place)
	end)
end

Rail.Schedule = Schedule

local function Restore()
	local f = Frame()
	local original = state.original
	state.placed = nil
	Live()
	if f then
		Fit(f, nil, nil)
	end
	if not f or not original then
		return
	end
	state.original = nil
	K.Combat.Queue(function()
		f:ClearAllPoints()
		for _, point in ipairs(original.points) do
			f:SetPoint(unpack(point))
		end
		if Plain(original.width) and Plain(original.height) then
			f:SetSize(original.width, original.height)
		end
		Hold(f, false)
		RestedXP.Chrome.Rest(f, false)
		Refresh(f)
	end)
end

local function Shifted(f, placed)
	local scale = Widgets.ScaleFactor(f)
	local root = K.Scale.Root()
	local l, t, rl, rb = f:GetLeft(), f:GetTop(), root:GetLeft(), root:GetBottom()
	if Plain(l) and Plain(t) and Plain(rl) and Plain(rb) then
		return math.abs((l - rl / scale) - placed.left) > MOVED or math.abs((t - rb / scale) - placed.top) > MOVED
	end
	local point, relative, relativePoint, x, y = f:GetPoint(1)
	if point ~= "TOPLEFT" or relative ~= UIParent or relativePoint ~= "BOTTOMLEFT" or not (Plain(x) and Plain(y)) then
		return true
	end
	return math.abs(x - K.Scale.Origin() / scale - placed.left) > MOVED or math.abs(y - placed.top) > MOVED
end

local function Moved(f)
	local placed = state.placed
	if not placed or not On() then
		return
	end
	local width, height = f:GetWidth(), f:GetHeight()
	local resized = Plain(width) and Plain(height) and (math.abs(width - placed.width) > MOVED or math.abs(height - placed.height) > MOVED)
	if Shifted(f, placed) or resized then
		state.placed, state.original = nil, nil
		Hold(f, false)
		RestedXP.Chrome.Rest(f, false)
		Fit(f, nil, nil)
		K.Options.Write(MODULE, KEY .. "." .. FIELD, false)
		Log("the player moved the guide; the story rail lets it be")
		K.Print(L["KstyleUI leaves the RestedXP guide where you put it. Turn Story rail back on in the RestedXP skin's settings."])
	end
end

local function OnHead(f)
	if state.placed and On() and IsTable(f) and f == Frame() then
		Fit(f, RestedXP.Chrome.Path(f), Rail.Band())
	end
	Schedule()
end

local function Hook(f)
	if state.hooked then
		return
	end
	state.hooked = true
	local function Check()
		Moved(f)
	end
	for _, part in ipairs({ f, f.CurrentStepFrame, f.GuideName, f.Footer }) do
		if IsTable(part) and type(part.HookScript) == "function" then
			part:HookScript("OnMouseUp", Check)
		end
	end
	f:HookScript("OnShow", Schedule)
	local rxp = state.rxp
	if type(rxp.SetStep) == "function" then
		hooksecurefunc(rxp, "SetStep", Schedule)
	end
	if type(rxp.SortTimers) == "function" then
		hooksecurefunc(rxp, "SortTimers", Schedule)
	end
	K.Events.Register(OWNER, "PLAYER_ENTERING_WORLD", Schedule)
	K.Callbacks.Register("LayoutChanged", OWNER, Schedule)
	K.Callbacks.Register("SettingChanged", OWNER, function(_, module, key)
		if module == "Layout" and key == "preset" then
			Schedule()
		end
	end)
end

function Rail.Start(rxp)
	state.rxp = rxp
	local f = Frame()
	if not f then
		return
	end
	Holder()
	Hook(f)
	RestedXP.Chrome.OnHead = OnHead
	if not state.tracked then
		state.tracked = { Restyle = Schedule }
		Widgets.Track(state.tracked)
	end
	K.Combat.Queue(Rail.Place)
end

function Rail.Switch(on)
	if on then
		Schedule()
	else
		Restore()
	end
end

function Rail.Placed()
	return state.placed
end

function Rail.Holder()
	return state.holder
end
