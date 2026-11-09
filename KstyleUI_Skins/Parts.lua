-- Parts.lua: the pieces skins draw on KstyleUI's own child frames: quality rims, accent lines, side tabs, the docked-tab treatment that grows a window's glass around the tabs Blizzard hangs past its edge, dropdowns, list rows and fill bars.
local _, ns = ...

local K = KstyleUI
local Skin, Tokens, Widgets = K.Skin, K.Tokens, K.Widgets

local Parts = {}
ns.Parts = Parts

local RIM_UNITS = 2
local RIM_SUBLEVEL = -7
local LEVEL_BELOW = 1
local LINE_UNITS = 2
local BAR_UNITS = 10
local GLYPH_UNITS = 10
local HOVER_ALPHA = 0.5
local TAB_IDLE_ALPHA = 0.6
local WASH_ALPHA = 0.12
local MODULE = "Skins"

local DOCK_GAP = "gapMedium"
local DOCK_CORNER = "radius"
local EDGES = { "LEFT", "RIGHT", "TOP", "BOTTOM" }
local EDGE_KEY = { LEFT = "left", RIGHT = "right", TOP = "top", BOTTOM = "bottom" }

local WEAK = { __mode = "k" }
local rims = setmetatable({}, WEAK)
local tabs = setmetatable({}, WEAK)
local fills = setmetatable({}, WEAK)
local docks = setmetatable({}, WEAK)
local painting = false
local rowOwner = {}

local function Log(message)
	K.DevTest.Log(MODULE, message)
end

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function IsTexture(region)
	return type(region) == "table" and type(region.GetObjectType) == "function" and region:GetObjectType() == "Texture"
end

Parts.IsTexture = IsTexture

local function LayoutRim(holder)
	local target = holder.target
	local outset = Widgets.Snap(holder, holder.outset)
	holder:ClearAllPoints()
	holder:SetPoint("TOPLEFT", target, "TOPLEFT", -outset, outset)
	holder:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", outset, -outset)
	Widgets.LayoutSlice(holder.rim, holder, holder.chrome:Chamfer(), RIM_UNITS)
end

local function PaintRim(holder)
	local color = holder.color
	if color then
		Widgets.ShowSlice(holder.rim, true)
		Widgets.ColorSlice(holder.rim, color[1], color[2], color[3], color[4] or 1)
		holder.chrome:SetRim(color[1], color[2], color[3], color[4] or 1)
	else
		Widgets.ShowSlice(holder.rim, false)
		holder.chrome:SetRim()
	end
end

local function RestyleRim(holder)
	if Widgets.MayMove(holder) then
		LayoutRim(holder)
	end
	holder.chrome:Restyle()
	PaintRim(holder)
end

local function SetRimColor(holder, r, g, b, a)
	if r == nil then
		holder.color = nil
	else
		holder.color = { r, g, b, a or 1 }
	end
	PaintRim(holder)
end

function Parts.Rim(frame, opts)
	opts = opts or {}
	if rims[frame] then
		return rims[frame]
	end
	local holder = CreateFrame("Frame", nil, frame)
	holder:SetFrameLevel(math.max(0, frame:GetFrameLevel() - LEVEL_BELOW))
	holder.target = opts.target or frame
	holder.outset = opts.outset or 0
	holder.chrome = Widgets.IconChrome(holder)
	holder.rim = Widgets.NineSlice(holder, "chamferTile", "BACKGROUND", RIM_SUBLEVEL)
	holder.Restyle = RestyleRim
	holder.SetRimColor = SetRimColor
	RestyleRim(holder)
	rims[frame] = holder
	return Widgets.Track(holder)
end

function Parts.RimOf(frame)
	return rims[frame]
end

local function RestyleLine(line)
	local owner, anchor = line.owner, line.anchor
	local inset = Widgets.Snap(owner, line.inset)
	line:ClearAllPoints()
	if anchor then
		line:SetPoint("LEFT", anchor, "LEFT")
		line:SetPoint("RIGHT", anchor, "RIGHT")
	elseif line.edge == "TOP" then
		line:SetPoint("TOPLEFT", owner, "TOPLEFT", inset, 0)
		line:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -inset, 0)
	else
		line:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", inset, 0)
		line:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -inset, 0)
	end
	line:SetHeight(Widgets.Snap(owner, line.units))
	ns.Style.TintAccent(line, line.alpha)
end

function Parts.AccentLine(owner, opts)
	opts = opts or {}
	local layer = CreateFrame("Frame", nil, owner)
	layer:SetAllPoints(owner)
	layer:SetFrameLevel(owner:GetFrameLevel() + LEVEL_BELOW)
	local line = layer:CreateTexture(nil, "OVERLAY")
	line:SetTexture((Tokens.Texture("divider")))
	line.owner = owner
	line.anchor = opts.anchor
	line.edge = opts.edge or "BOTTOM"
	line.inset = opts.inset or 0
	line.units = opts.units or LINE_UNITS
	line.alpha = opts.alpha or 1
	line.Restyle = RestyleLine
	RestyleLine(line)
	ns.Style.Track(line)
	return Widgets.Track(line)
end

local hushHost

function Parts.Hush(region)
	if not IsTexture(region) then
		return false
	end
	hushHost = hushHost or CreateFrame("Frame")
	return Skin.Strip(hushHost, { children = { region }, watch = false }) == 1
end

function Parts.Divider(owner, region)
	if not IsTexture(region) then
		return nil
	end
	Parts.Hush(region)
	return Parts.AccentLine(owner, { anchor = region, alpha = HOVER_ALPHA })
end

local function PaintTab(state)
	local tab = state.tab
	local checked = state.checked
	if state.native then
		checked = tab:GetChecked() and true or false
	end
	if checked then
		local r, g, b = ns.Style.Accent()
		state.rim:SetRimColor(r, g, b, 1)
	elseif state.hover then
		state.rim:SetRimColor(Widgets.Rgba("text", HOVER_ALPHA))
	else
		state.rim:SetRimColor(nil)
	end
	if state.icon then
		state.icon:SetAlpha((checked or state.hover) and 1 or TAB_IDLE_ALPHA)
	end
end

function Parts.SideTab(tab)
	if type(tab) ~= "table" or tabs[tab] then
		return tabs[tab]
	end
	local keep = {}
	local icon = tab.Icon
	if IsTexture(icon) then
		keep[icon] = true
	end
	local selected = tab.SelectedTexture
	local wasChecked = tab.isSelected == true
	if IsTexture(selected) then
		local shown = selected:IsShown()
		wasChecked = wasChecked or (not IsSecret(shown) and shown == true)
	end
	Skin.Strip(tab, { keep = keep })
	local native = type(tab.IsObjectType) == "function" and tab:IsObjectType("CheckButton") and type(tab.GetChecked) == "function"
	local state = { tab = tab, checked = wasChecked, hover = false, native = native }
	state.rim = Parts.Rim(tab, { target = IsTexture(icon) and icon or tab, outset = Tokens.Size("gapTiny") })
	state.icon = IsTexture(icon) and icon or nil
	state.Restyle = PaintTab
	tabs[tab] = state
	for _, method in ipairs({ "SetChecked", "SetTabSelected" }) do
		if type(tab[method]) == "function" then
			hooksecurefunc(tab, method, function(_, checked)
				state.checked = checked and true or false
				PaintTab(state)
			end)
		end
	end
	tab:HookScript("OnEnter", function()
		state.hover = true
		PaintTab(state)
	end)
	tab:HookScript("OnLeave", function()
		state.hover = false
		PaintTab(state)
	end)
	if native then
		tab:HookScript("OnClick", function()
			PaintTab(state)
		end)
	end
	PaintTab(state)
	ns.Style.Track(state)
	return state
end

local function Plain(value)
	if IsSecret(value) or type(value) ~= "number" then
		return nil
	end
	return value
end

local function Edges(frame, scale)
	local left, right, top, bottom = Plain(frame:GetLeft()), Plain(frame:GetRight()), Plain(frame:GetTop()), Plain(frame:GetBottom())
	if not (left and right and top and bottom) then
		return nil
	end
	local own = Plain(frame:GetEffectiveScale())
	local f = (own and scale and own > 0 and scale > 0) and own / scale or 1
	return { left = left * f, right = right * f, top = top * f, bottom = bottom * f }
end

local function Shown(frame)
	local shown = frame:IsShown()
	return not IsSecret(shown) and shown == true
end

local function Reaches(dock)
	local window = dock.window
	local scale = Plain(window:GetEffectiveScale())
	local box = Edges(window, scale)
	if not box then
		return nil
	end
	local reach = { LEFT = 0, RIGHT = 0, TOP = 0, BOTTOM = 0 }
	local straddle = {}
	for _, frame in ipairs(dock.frames) do
		if Shown(frame) then
			local rect = Edges(frame, scale)
			if not rect then
				return nil
			end
			local past = { LEFT = box.left - rect.left, RIGHT = rect.right - box.right, TOP = rect.top - box.top, BOTTOM = box.bottom - rect.bottom }
			local inner = { LEFT = box.left - rect.right, RIGHT = rect.left - box.right, TOP = rect.bottom - box.top, BOTTOM = box.bottom - rect.top }
			for _, edge in ipairs(EDGES) do
				if past[edge] > 0 then
					reach[edge] = math.max(reach[edge], past[edge])
					if inner[edge] < 0 then
						straddle[edge] = true
					end
				end
			end
		end
	end
	return reach, straddle
end

local function Seam(dock, edge)
	local seam = dock.seams[edge]
	if not seam then
		seam = dock.panel:CreateTexture(nil, "ARTWORK")
		seam:SetTexture((Tokens.Texture("divider")))
		dock.seams[edge] = seam
	end
	return seam
end

local function PlaceSeam(dock, edge, reach, straddle)
	local window = dock.window
	if reach <= 0 and not dock.seams[edge] then
		return
	end
	local seam = Seam(dock, edge)
	if reach <= 0 or straddle then
		seam:Hide()
		return
	end
	local corner = Widgets.Snap(window, Tokens.Size(DOCK_CORNER))
	local border = Widgets.Border(window)
	seam:ClearAllPoints()
	if edge == "BOTTOM" then
		seam:SetPoint("TOPLEFT", window, "BOTTOMLEFT", corner, 0)
		seam:SetPoint("TOPRIGHT", window, "BOTTOMRIGHT", -corner, 0)
		seam:SetHeight(border)
	elseif edge == "TOP" then
		seam:SetPoint("BOTTOMLEFT", window, "TOPLEFT", corner, 0)
		seam:SetPoint("BOTTOMRIGHT", window, "TOPRIGHT", -corner, 0)
		seam:SetHeight(border)
	elseif edge == "RIGHT" then
		seam:SetPoint("TOPLEFT", window, "TOPRIGHT", 0, -corner)
		seam:SetPoint("BOTTOMLEFT", window, "BOTTOMRIGHT", 0, corner)
		seam:SetWidth(border)
	else
		seam:SetPoint("TOPRIGHT", window, "TOPLEFT", 0, -corner)
		seam:SetPoint("BOTTOMRIGHT", window, "BOTTOMLEFT", 0, corner)
		seam:SetWidth(border)
	end
	Widgets.Tint(seam, "edgeInner")
	seam:Show()
end

local function ShiftTitle(dock)
	local title = dock.title
	if not title or type(title.AdjustPointsOffset) ~= "function" then
		return
	end
	local shift = (dock.reach.RIGHT - dock.reach.LEFT) / 2
	local delta = shift - (dock.shift or 0)
	if math.abs(delta) > 0 then
		title:AdjustPointsOffset(delta, 0)
		dock.shift = shift
	end
end

local function PlaceDock(dock)
	local reach, straddle = Reaches(dock)
	if not reach then
		return false
	end
	local gap = Tokens.Size(DOCK_GAP)
	local panel = dock.panel
	local inset = panel.inset
	if type(inset) ~= "table" then
		inset = { left = inset or 0, right = inset or 0, top = inset or 0, bottom = inset or 0 }
		panel.inset = inset
	end
	for _, edge in ipairs(EDGES) do
		local past = reach[edge] > 0 and Widgets.Snap(panel, reach[edge] + gap) or 0
		reach[edge] = past
		inset[EDGE_KEY[edge]] = dock.base[edge] - past
		PlaceSeam(dock, edge, past, straddle[edge])
	end
	dock.reach = reach
	panel:Restyle()
	ShiftTitle(dock)
	return true
end

local function WatchFrame(dock, frame)
	if dock.watched[frame] then
		return
	end
	dock.watched[frame] = true
	if type(frame.HookScript) == "function" then
		frame:HookScript("OnShow", dock.Refresh)
		frame:HookScript("OnHide", dock.Refresh)
	end
end

function Parts.Dock(window, frames, opts)
	opts = opts or {}
	local parts = Skin.Parts(window)
	local panel = parts and parts.backdrop
	if not panel then
		Log("a window without glass cannot dock its tabs")
		return nil
	end
	local dock = docks[window]
	if not dock then
		local inset = panel.inset
		local base = {}
		for _, edge in ipairs(EDGES) do
			if type(inset) == "table" then
				base[edge] = inset[EDGE_KEY[edge]] or 0
			else
				base[edge] = inset or 0
			end
		end
		dock = { window = window, panel = panel, frames = {}, seams = {}, watched = {}, base = base, reach = { LEFT = 0, RIGHT = 0, TOP = 0, BOTTOM = 0 } }
		dock.Refresh = function()
			PlaceDock(dock)
		end
		dock.Restyle = dock.Refresh
		docks[window] = dock
		window:HookScript("OnShow", dock.Refresh)
		window:HookScript("OnSizeChanged", dock.Refresh)
		Widgets.Track(dock)
	end
	for _, frame in ipairs(frames) do
		if type(frame) == "table" and type(frame.GetLeft) == "function" and not dock.watched[frame] then
			dock.frames[#dock.frames + 1] = frame
			WatchFrame(dock, frame)
		end
	end
	if opts.title and type(opts.title) == "table" then
		dock.title = opts.title
	end
	if opts.relayout and type(window[opts.relayout]) == "function" then
		hooksecurefunc(window, opts.relayout, dock.Refresh)
	end
	PlaceDock(dock)
	return dock
end

function Parts.DockOf(window)
	return docks[window]
end

local function PaintGlyph(state)
	local button, glyph = state.button, state.glyph
	local enabled = type(button.IsEnabled) ~= "function" or button:IsEnabled() ~= false
	if not enabled then
		Widgets.Tint(glyph, "textDisabled")
	else
		Widgets.Tint(glyph, state.hover and "textHover" or "text")
	end
end

local function LayoutGlyph(state)
	Widgets.Size(state.glyph, state.size, state.size)
	PaintGlyph(state)
end

function Parts.Glyph(button, textureName, opts)
	if type(button) ~= "table" or type(button.GetRegions) ~= "function" then
		return nil
	end
	opts = opts or {}
	Skin.Strip(button)
	local overlay = CreateFrame("Frame", nil, button)
	overlay:SetAllPoints(button)
	overlay:SetFrameLevel(button:GetFrameLevel() + LEVEL_BELOW)
	local glyph = overlay:CreateTexture(nil, "OVERLAY")
	glyph:SetTexture((Tokens.Texture(textureName)))
	glyph:SetPoint("CENTER", overlay, "CENTER")
	if opts.flip then
		glyph:SetTexCoord(0, 1, 1, 0)
	end
	if opts.rotation then
		glyph:SetRotation(opts.rotation)
	end
	local state = { button = button, glyph = glyph, size = opts.size or GLYPH_UNITS, hover = false, Restyle = LayoutGlyph }
	button:HookScript("OnEnter", function()
		state.hover = true
		PaintGlyph(state)
	end)
	button:HookScript("OnLeave", function()
		state.hover = false
		PaintGlyph(state)
	end)
	if type(button.IsEnabled) == "function" then
		button:HookScript("OnEnable", function()
			PaintGlyph(state)
		end)
		button:HookScript("OnDisable", function()
			PaintGlyph(state)
		end)
	end
	LayoutGlyph(state)
	Widgets.Track(state)
	return glyph
end

function Parts.Dropdown(drop)
	if type(drop) ~= "table" or type(drop.GetRegions) ~= "function" then
		return nil
	end
	local keep = {}
	if IsTexture(drop.Arrow) then
		keep[drop.Arrow] = true
	end
	Skin.Strip(drop, { keep = keep })
	local panel = Skin.Backdrop(drop, { shape = "tile", fill = "buttonFill", shadow = false })
	if drop.Text then
		ns.Style.Text(drop.Text, "body")
	end
	return panel
end

function Parts.StripLeaves(frame)
	if type(frame) ~= "table" or type(frame.GetChildren) ~= "function" then
		return 0
	end
	local count = 0
	for _, child in ipairs({ frame:GetChildren() }) do
		if select("#", child:GetChildren()) == 0 then
			count = count + (Skin.Strip(child) or 0)
		end
	end
	return count
end

function Parts.Wash(highlight)
	if type(highlight) ~= "table" or type(highlight.GetRegions) ~= "function" then
		return nil
	end
	Skin.Strip(highlight)
	local layer = CreateFrame("Frame", nil, highlight)
	layer:SetAllPoints(highlight)
	local wash = layer:CreateTexture(nil, "BACKGROUND")
	wash:SetAllPoints(layer)
	wash:SetColorTexture(Tokens.Color("white"))
	wash.Restyle = function(self)
		ns.Style.TintAccent(self, WASH_ALPHA)
	end
	wash:Restyle()
	ns.Style.Track(wash)
	return wash
end

function Parts.EachRow(scrollBox, fn)
	if type(scrollBox) ~= "table" or type(scrollBox.ForEachFrame) ~= "function" then
		Log("a list has no ForEachFrame; its rows keep Blizzard's look")
		return false
	end
	local function Each(frame, elementData)
		K.Call(fn, frame, elementData)
		ns.Style.Sweep(frame)
	end
	scrollBox:ForEachFrame(Each)
	local util = ScrollUtil
	if util and type(util.AddInitializedFrameCallback) == "function" then
		util.AddInitializedFrameCallback(scrollBox, function(_, frame, elementData)
			Each(frame, elementData)
		end, rowOwner, false)
		return true
	end
	if type(scrollBox.Update) == "function" then
		hooksecurefunc(scrollBox, "Update", function(box)
			box:ForEachFrame(Each)
		end)
		Log("ScrollUtil.AddInitializedFrameCallback is missing; list rows are skinned after each update")
		return true
	end
	return false
end

local function SetFillColor(state)
	local fill = state.fill
	fill:SetVertexColor(ns.Style.BarColor(state.r, state.g, state.b, state.a))
end

local function PaintFill(state)
	painting = true
	local ok, err = pcall(SetFillColor, state)
	painting = false
	if not ok then
		Log("a bar fill colour could not be set: " .. tostring(err))
	end
end

local function RestyleFill(state)
	local bar, fill, area, track = state.bar, state.fill, state.area, state.track
	local border = Widgets.Border(bar)
	local height = Widgets.Snap(bar, BAR_UNITS)
	fill:SetTexture(ns.Style.BarTexture())
	if Widgets.MayMove(bar) then
		fill:SetHeight(height)
		local point = ns.Style.ReverseFill() and "RIGHT" or "LEFT"
		fill:ClearAllPoints()
		fill:SetPoint(point, area, point)
		track:ClearAllPoints()
		track:SetPoint("LEFT", area, "LEFT", -border, 0)
		track:SetPoint("RIGHT", area, "RIGHT", border, 0)
		track:SetHeight(height + 2 * border)
	end
	track.chrome:Restyle()
	PaintFill(state)
	if bar.Text then
		ns.Style.Text(bar.Text, "caption", "textEmphasis")
	end
end

function Parts.FillBar(bar)
	if type(bar) ~= "table" or fills[bar] then
		return fills[bar]
	end
	local fill = bar.Fill
	if not IsTexture(fill) then
		Log("a bar has no Fill texture; it keeps Blizzard's look")
		return nil
	end
	Skin.Strip(bar, { keep = { [fill] = true } })
	if bar.Mask and type(fill.RemoveMaskTexture) == "function" then
		pcall(fill.RemoveMaskTexture, fill, bar.Mask)
	end
	local track = CreateFrame("Frame", nil, bar)
	track:SetFrameLevel(math.max(0, bar:GetFrameLevel() - LEVEL_BELOW))
	track.chrome = Widgets.Chrome(track, { shape = "tile", fill = "surface", edge = "edgeBar", shadow = false })
	local state = { bar = bar, fill = fill, track = track, area = bar.FillArea or bar }
	state.r, state.g, state.b, state.a = fill:GetVertexColor()
	state.Restyle = RestyleFill
	hooksecurefunc(fill, "SetVertexColor", function(_, r, g, b, a)
		if painting then
			return
		end
		state.r, state.g, state.b, state.a = r, g, b, a
		PaintFill(state)
	end)
	fills[bar] = state
	RestyleFill(state)
	ns.Style.Track(state)
	Widgets.Track(state)
	return state
end
