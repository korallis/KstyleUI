-- Mode.lua: Layout Mode's screen: mover plates, resize and scale handles, snapping guides, the grid, keyboard nudges and the toolbar.
local _, ns = ...

local Layout = ns.Layout
local G = Layout.Geometry
local Widgets, Tokens, Scale, L = ns.Widgets, ns.Tokens, ns.Scale, ns.L

local floor, max, min, format = math.floor, math.max, math.min, string.format

local Mode = {}
Layout.Mode = Mode

local TOOLBAR_KEY = "Layout.Toolbar"
local TOOLBAR_POSITION = { anchor = "TOP", x = 0, y = -96 }
local OVERLAY_STRATA = "FULLSCREEN"
local TOOLBAR_STRATA = "FULLSCREEN_DIALOG"
local GRID_STRATA = "BACKGROUND"
local PLATE_MIN = 16
local HANDLE_SIZE = 8
local HANDLE_LEVELS = 20
local FILL_REST, FILL_HOVER, FILL_SELECTED = 0.1, 0.18, 0.28
local EDGE_REST, EDGE_ACTIVE = 0.55, 1
local GRID_LINE_ALPHA, GRID_CENTRE_ALPHA = 0.07, 0.45
local GUIDE_ALPHA = 0.9
local NUDGE_SMALL, NUDGE_BIG = 1, 10
local EPSILON = 1e-4
local ARROWS = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }
local HANDLE_POINT = {
	TOPLEFT = "TOPLEFT", TOP = "TOP", TOPRIGHT = "TOPRIGHT", LEFT = "LEFT", RIGHT = "RIGHT",
	BOTTOMLEFT = "BOTTOMLEFT", BOTTOM = "BOTTOM", BOTTOMRIGHT = "BOTTOMRIGHT", SCALE = "BOTTOMRIGHT",
}

local overlay, grid, guideX, guideY, toolbar
local plates, handles, gridLines = {}, {}, {}
local selected, hoveredPlate, drag

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

local function IsNumber(v)
	return not IsSecret(v) and type(v) == "number" and v == v
end

local function Log(message)
	local devtest = ns.DevTest
	if devtest and devtest.Log then
		pcall(devtest.Log, "Layout", message)
	end
end

local function KeyDown(fn)
	return type(fn) == "function" and fn() == true
end

local function Cursor()
	local x, y = GetCursorPosition()
	local s = Scale.Root():GetEffectiveScale()
	if not (IsNumber(x) and IsNumber(y) and IsNumber(s)) or s <= 0 then
		return nil
	end
	return x / s, y / s
end

local function Describe(key)
	local s = Layout.Element(key).settings
	local el = Layout.Element(key)
	local text = format("%s  %d, %d", s.anchor, floor(s.x + 0.5), floor(s.y + 0.5))
	if el.opts.resizable then
		text = text .. format("  %d x %d", floor(s.width + 0.5), floor(s.height + 0.5))
	end
	if el.opts.scalable then
		text = text .. format("  %d%%", floor(s.scale * 100 + 0.5))
	end
	return text
end

local function PaintPlate(plate)
	local active = selected == plate.key
	local fill = active and FILL_SELECTED or (plate.hover and FILL_HOVER or FILL_REST)
	plate.chrome:SetFillRGBA(Widgets.Rgba("accent", fill))
	plate.chrome:SetEdgeRGBA(Widgets.Rgba("accent", (active or plate.hover) and EDGE_ACTIVE or EDGE_REST))
	Widgets.SetText(plate.info, active and Describe(plate.key) or "")
end

local function PaintHandle(handle)
	Widgets.Tint(handle.edge, "edgeOuter")
	Widgets.Tint(handle.fill, handle.hover and "textHover" or "accent")
end

local function PlaceHandles()
	if not overlay then
		return
	end
	local el = selected and Layout.Element(selected)
	local plate = selected and plates[selected]
	local resizable = el and plate and plate:IsShown() and el.opts.resizable
	local scalable = el and plate and plate:IsShown() and el.opts.scalable and not el.opts.resizable
	local size = Widgets.Snap(overlay, HANDLE_SIZE)
	local border = Widgets.Border(overlay)
	local level = overlay:GetFrameLevel() + HANDLE_LEVELS
	for name, handle in pairs(handles) do
		local show = (name == "SCALE" and scalable) or (name ~= "SCALE" and resizable)
		if show then
			handle:ClearAllPoints()
			handle:SetPoint("CENTER", plate, HANDLE_POINT[name])
			handle:SetSize(size, size)
			handle:SetFrameLevel(level)
			handle.fill:ClearAllPoints()
			handle.fill:SetPoint("TOPLEFT", handle, "TOPLEFT", border, -border)
			handle.fill:SetPoint("BOTTOMRIGHT", handle, "BOTTOMRIGHT", -border, border)
			PaintHandle(handle)
			handle:Show()
		else
			handle:Hide()
		end
	end
end

local function RefreshPlate(key)
	local plate = plates[key]
	local el = Layout.Element(key)
	if not overlay or not el or el.opts.plate == false or not Layout.Live(key) then
		if plate then
			plate:Hide()
		end
		return
	end
	plate = plate or Mode.NewPlate(key)
	local _, _, w, h = Layout.Rect(key)
	plate:ClearAllPoints()
	plate:SetPoint("CENTER", el.frame, "CENTER")
	plate:SetSize(max(PLATE_MIN, w), max(PLATE_MIN, h))
	Widgets.SetText(plate.label, el.label)
	plate.chrome:Restyle()
	PaintPlate(plate)
	plate:Show()
end

function Mode.Select(key)
	local old = selected
	selected = key
	if old and plates[old] then
		PaintPlate(plates[old])
	end
	if key and plates[key] then
		PaintPlate(plates[key])
	end
	PlaceHandles()
end

local function ShowGuide(guide, at, vertical)
	if at == nil then
		guide:Hide()
		return
	end
	local pixel, border = Scale.Pixel(1), Scale.Border()
	local pos = G.Align(at - border / 2, pixel)
	guide:ClearAllPoints()
	if vertical then
		guide:SetPoint("TOPLEFT", overlay, "TOPLEFT", pos, 0)
		guide:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", pos, 0)
		guide:SetWidth(border)
	else
		guide:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, pos)
		guide:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, pos)
		guide:SetHeight(border)
	end
	Widgets.Tint(guide, "accent", GUIDE_ALPHA)
	guide:Show()
end

local function Targets(key)
	local rects = {}
	for _, element in ipairs(Layout.Elements()) do
		local other = element.key
		local plate = plates[other]
		if other ~= key and plate and plate:IsShown() then
			local l, b, w, h = Layout.Rect(other)
			rects[#rects + 1] = { left = l, bottom = b, width = w, height = h }
		end
	end
	local rw, rh = Layout.RootSize()
	return G.Targets(rw, rh, rects)
end

local function GridSpec()
	if not Layout.Setting("grid") then
		return nil
	end
	local rw, rh = Layout.RootSize()
	return { size = Layout.Setting("gridSize"), cx = rw / 2, cy = rh / 2 }
end

local function UpdateDrag()
	local d = drag
	local x, y = Cursor()
	if not d or not x then
		return
	end
	local dx, dy = x - d.cx, y - d.cy
	local pixel = Scale.Pixel(1)
	local rw, rh = Layout.RootSize()
	local l, b, w, h, s = d.left, d.bottom, d.width, d.height, d.scale
	if d.kind == "move" then
		local gx, gy
		l, b = G.ClampToRoot(l + dx, b + dy, w, h, rw, rh)
		if Layout.Setting("snap") then
			l, b, gx, gy = G.SnapMove(l, b, w, h, d.targets, Layout.Setting("snapDistance"), d.grid)
		end
		l, b = G.Align(l, pixel), G.Align(b, pixel)
		ShowGuide(guideX, gx, true)
		ShowGuide(guideY, gy, false)
	elseif d.kind == "resize" then
		d.limits.pixel = pixel
		l, b, w, h = G.Resize(d, d.handle, dx, dy, d.limits)
	else
		s = G.Rescale(d, d.scale, dx, dy, Layout.SCALE_MIN, Layout.SCALE_MAX)
		w, h = d.width * s / d.scale, d.height * s / d.scale
		b = d.bottom + d.height - h
	end
	d.moved = true
	d.l, d.b, d.w, d.h, d.s = l, b, w, h, s
	Layout.Preview(d.key, l, b, w, h, s)
	local plate = plates[d.key]
	if plate and d.kind ~= "move" then
		plate:SetSize(max(PLATE_MIN, w), max(PLATE_MIN, h))
	end
end

local function Begin(kind, key, handle)
	if drag or not overlay or not Layout.IsActive() or not key then
		return
	end
	local el = Layout.Element(key)
	if not el then
		return
	end
	local cx, cy = Cursor()
	if not cx then
		Log("GetCursorPosition gave no usable position; the drag did not start")
		return
	end
	local l, b, w, h = Layout.Rect(key)
	drag = { kind = kind, key = key, handle = handle, cx = cx, cy = cy, left = l, bottom = b, width = w, height = h, scale = el.settings.scale }
	if kind == "move" then
		drag.targets = Targets(key)
		drag.grid = GridSpec()
	elseif kind == "resize" then
		local f = Widgets.ScaleFactor(el.frame)
		local limits = el.limits
		drag.factor = f
		drag.limits = {
			minWidth = limits.minWidth * f, maxWidth = limits.maxWidth * f,
			minHeight = limits.minHeight * f, maxHeight = limits.maxHeight * f,
			aspect = el.aspect,
		}
	end
	overlay:SetScript("OnUpdate", UpdateDrag)
end

local function EndDrag(commit)
	local d = drag
	if not d then
		return
	end
	drag = nil
	overlay:SetScript("OnUpdate", nil)
	guideX:Hide()
	guideY:Hide()
	local ok = false
	if commit and d.moved then
		local rw, rh = Layout.RootSize()
		local anchor, x, y = G.Position(d.l, d.b, d.w, d.h, rw, rh)
		local values = { anchor = anchor, x = x, y = y }
		if d.kind == "resize" then
			values.width, values.height = d.w / d.factor, d.h / d.factor
		elseif d.kind == "scale" then
			values.scale = d.s
		end
		ok = Layout.Update(d.key, values)
	end
	if not ok then
		Layout.Restore(d.key)
	end
	RefreshPlate(d.key)
	if d.key == selected then
		PlaceHandles()
	end
end

local function DragStop()
	EndDrag(true)
end

local function Nudge(dx, dy)
	local key = selected
	local l, b, w, h = Layout.Rect(key)
	if not l then
		return
	end
	local step = Scale.Pixel(KeyDown(IsShiftKeyDown) and NUDGE_BIG or NUDGE_SMALL)
	local rw, rh = Layout.RootSize()
	l, b = G.ClampToRoot(l + dx * step, b + dy * step, w, h, rw, rh)
	local _, x, y = G.Position(l, b, w, h, rw, rh, Layout.Element(key).settings.anchor)
	Layout.Update(key, { x = x, y = y }, "nudge:" .. key)
end

local function OnKeyDown(self, key)
	if InCombatLockdown() then
		return
	end
	local consume = true
	local arrow = ARROWS[key]
	local ctrl = KeyDown(IsControlKeyDown)
	if arrow and selected then
		Nudge(arrow[1], arrow[2])
	elseif key == "ESCAPE" then
		if drag then
			EndDrag(false)
		elseif selected then
			Mode.Select(nil)
		else
			Layout.Exit(true)
		end
	elseif ctrl and key == "Z" then
		if KeyDown(IsShiftKeyDown) then
			Layout.Redo()
		else
			Layout.Undo()
		end
	elseif ctrl and key == "Y" then
		Layout.Redo()
	else
		consume = false
	end
	self:SetPropagateKeyboardInput(not consume)
end

local function PlateTooltip(tip, plate)
	local el = Layout.Element(plate.key)
	if not el then
		return
	end
	tip:AddTitle(el.label)
	if el.module then
		tip:AddCaption(el.module)
	end
	tip:AddLine(L["Drag to move. The arrow keys nudge it one pixel, or ten with Shift."])
	if el.opts.resizable then
		tip:AddLine(L["Click it, then drag a handle to resize it."])
	end
	if el.opts.scalable then
		tip:AddLine(L["Scroll to scale it, or click it and drag the corner handle."])
	end
	tip:AddLine(L["Right-click to reset it."])
end

local function PlateDown(plate, button)
	if button == nil or button == "LeftButton" then
		Mode.Select(plate.key)
	end
end

local function PlateClick(plate, button)
	if button == "RightButton" then
		Layout.Reset(plate.key)
	end
end

local function PlateDragStart(plate)
	Mode.Select(plate.key)
	Begin("move", plate.key)
end

local function PlateWheel(plate, delta)
	local el = Layout.Element(plate.key)
	if not el or not el.opts.scalable or not IsNumber(delta) or delta == 0 then
		return
	end
	local scale = el.settings.scale + (delta > 0 and 1 or -1) * Layout.SCALE_STEP
	scale = min(max(floor(scale * 100 + 0.5) / 100, Layout.SCALE_MIN), Layout.SCALE_MAX)
	Layout.Update(plate.key, { scale = scale }, "wheel:" .. plate.key)
end

local function PlateEnter(plate)
	plate.hover = true
	hoveredPlate = plate
	PaintPlate(plate)
end

local function PlateLeave(plate)
	plate.hover = false
	if hoveredPlate == plate then
		hoveredPlate = nil
	end
	PaintPlate(plate)
end

local function RestylePlate(plate)
	if plate:IsShown() then
		RefreshPlate(plate.key)
	end
end

function Mode.NewPlate(key)
	local plate = CreateFrame("Button", nil, overlay)
	plate.key = key
	plate.chrome = Widgets.Chrome(plate, { shape = "tile", fill = "raised", shadow = false })
	plate.label = Widgets.Text(plate, "caption", "textEmphasis")
	plate.label:SetPoint("CENTER", plate, "CENTER")
	plate.info = Widgets.Text(plate, "caption", "text")
	plate.info:SetPoint("TOP", plate.label, "BOTTOM", 0, -Widgets.Snap(plate, Tokens.Size("gapTiny")))
	plate:EnableMouse(true)
	plate:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	plate:RegisterForDrag("LeftButton")
	plate:EnableMouseWheel(true)
	plate:SetScript("OnMouseDown", PlateDown)
	plate:SetScript("OnClick", PlateClick)
	plate:SetScript("OnDragStart", PlateDragStart)
	plate:SetScript("OnDragStop", DragStop)
	plate:SetScript("OnMouseWheel", PlateWheel)
	plate:SetScript("OnEnter", PlateEnter)
	plate:SetScript("OnLeave", PlateLeave)
	Widgets.AttachTooltip(plate, PlateTooltip)
	plate.Restyle = RestylePlate
	Widgets.Track(plate)
	plates[key] = plate
	return plate
end

local function HandleDragStart(handle)
	if handle.name == "SCALE" then
		Begin("scale", selected)
	else
		Begin("resize", selected, handle.name)
	end
end

local function NewHandle(name)
	local handle = CreateFrame("Button", nil, overlay)
	handle.name = name
	handle.edge = handle:CreateTexture(nil, "BORDER")
	handle.edge:SetAllPoints(handle)
	handle.edge:SetColorTexture(Tokens.Color("white"))
	handle.fill = handle:CreateTexture(nil, "ARTWORK")
	handle.fill:SetColorTexture(Tokens.Color("white"))
	handle:EnableMouse(true)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", HandleDragStart)
	handle:SetScript("OnDragStop", DragStop)
	handle:SetScript("OnEnter", function(self)
		self.hover = true
		PaintHandle(self)
	end)
	handle:SetScript("OnLeave", function(self)
		self.hover = false
		PaintHandle(self)
	end)
	handle:Hide()
	handles[name] = handle
end

local function PlaceLine(i, vertical, at, centre, pixel, border)
	local line = gridLines[i]
	if not line then
		line = grid:CreateTexture(nil, "BACKGROUND")
		line:SetColorTexture(Tokens.Color("white"))
		gridLines[i] = line
	end
	local pos = G.Align(at - border / 2, pixel)
	line:ClearAllPoints()
	if vertical then
		line:SetPoint("TOPLEFT", grid, "TOPLEFT", pos, 0)
		line:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", pos, 0)
		line:SetWidth(border)
	else
		line:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", 0, pos)
		line:SetPoint("BOTTOMRIGHT", grid, "BOTTOMRIGHT", 0, pos)
		line:SetHeight(border)
	end
	if centre then
		Widgets.Tint(line, "accent", GRID_CENTRE_ALPHA)
	else
		Widgets.Tint(line, "white", GRID_LINE_ALPHA)
	end
	line:Show()
end

local function DrawGrid()
	if not grid then
		return
	end
	if not Layout.IsActive() or not Layout.Setting("grid") then
		grid:Hide()
		return
	end
	local size = Layout.Setting("gridSize")
	local rw, rh = Layout.RootSize()
	local pixel, border = Scale.Pixel(1), Scale.Border()
	local cx, cy = rw / 2, rh / 2
	local n = 0
	for k = -floor(cx / size + EPSILON), floor((rw - cx) / size + EPSILON) do
		n = n + 1
		PlaceLine(n, true, cx + k * size, k == 0, pixel, border)
	end
	for k = -floor(cy / size + EPSILON), floor((rh - cy) / size + EPSILON) do
		n = n + 1
		PlaceLine(n, false, cy + k * size, k == 0, pixel, border)
	end
	for i = n + 1, #gridLines do
		gridLines[i]:Hide()
	end
	grid:Show()
end

function Mode.HistoryChanged()
	if toolbar then
		toolbar.undo:SetEnabled(Layout.CanUndo())
		toolbar.redo:SetEnabled(Layout.CanRedo())
	end
end

local function BuildToolbar()
	local panel = Widgets.Panel(Scale.Root(), { title = L["Layout Mode"], strata = TOOLBAR_STRATA, hidden = true, width = 200, height = 100 })
	local content = panel.content
	panel.gridToggle = Widgets.Toggle(content, {
		label = L["Grid"], value = Layout.Setting("grid"),
		tooltip = L["Show the grid, and snap to its lines."],
		onChange = function(value)
			ns.Options.Write("Layout", "grid", value)
		end,
	})
	panel.snapToggle = Widgets.Toggle(content, {
		label = L["Snap"], value = Layout.Setting("snap"),
		tooltip = L["Snap to other elements, the screen edges and the centre."],
		onChange = function(value)
			ns.Options.Write("Layout", "snap", value)
		end,
	})
	panel.undo = Widgets.Button(content, {
		text = L["Undo"], tooltip = L["Undo the last change. Ctrl+Z."],
		onClick = function()
			Layout.Undo()
		end,
	})
	panel.redo = Widgets.Button(content, {
		text = L["Redo"], tooltip = L["Redo the change you undid. Ctrl+Y."],
		onClick = function()
			Layout.Redo()
		end,
	})
	panel.reset = Widgets.Button(content, {
		text = L["Reset"], tooltip = L["Move every element back to its default place and size. Undo brings them back."],
		onClick = function()
			Layout.ResetAll()
		end,
	})
	panel.done = Widgets.Button(content, {
		text = L["Done"], primary = true, tooltip = L["Keep the layout and leave Layout Mode."],
		onClick = function()
			Layout.Exit(true)
		end,
	})
	local gap = Tokens.Size("gapMedium")
	local x, tallest = 0, 0
	for i, item in ipairs({ panel.gridToggle, panel.snapToggle, panel.undo, panel.redo, panel.reset, panel.done }) do
		item:ClearAllPoints()
		item:SetPoint("LEFT", content, "LEFT", Widgets.Snap(panel, x), 0)
		x = x + (item:GetWidth() or 0) + (i == 2 and gap * 2 or gap)
		tallest = max(tallest, item:GetHeight() or 0)
	end
	local pad = Tokens.Size("panelPadding")
	local top = pad + Tokens.Size("heading") + gap * 2
	panel.opts.width = x - gap + pad * 2
	panel.opts.height = top + tallest + pad
	panel:Restyle()
	local bar = panel.titleBar
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function()
		Begin("move", TOOLBAR_KEY)
	end)
	bar:SetScript("OnDragStop", DragStop)
	toolbar = panel
	Layout.Register(panel, TOOLBAR_KEY, TOOLBAR_POSITION, { label = L["Layout Mode toolbar"], scalable = true, plate = false, window = true })
end

local function Build()
	if overlay then
		return
	end
	local root = Scale.Root()
	overlay = CreateFrame("Frame", nil, root)
	overlay:SetAllPoints(root)
	overlay:SetFrameStrata(OVERLAY_STRATA)
	overlay:Hide()
	overlay:SetScript("OnKeyDown", OnKeyDown)
	guideX = overlay:CreateTexture(nil, "OVERLAY")
	guideX:SetColorTexture(Tokens.Color("white"))
	guideX:Hide()
	guideY = overlay:CreateTexture(nil, "OVERLAY")
	guideY:SetColorTexture(Tokens.Color("white"))
	guideY:Hide()
	grid = CreateFrame("Frame", nil, root)
	grid:SetAllPoints(root)
	grid:SetFrameStrata(GRID_STRATA)
	grid:Hide()
	for _, name in ipairs(G.HANDLES) do
		NewHandle(name)
	end
	NewHandle("SCALE")
	Widgets.Track({
		Restyle = function()
			DrawGrid()
			PlaceHandles()
		end,
	})
	BuildToolbar()
end

function Mode.Show()
	Build()
	overlay:Show()
	overlay:EnableKeyboard(true)
	overlay:SetPropagateKeyboardInput(true)
	Mode.Select(nil)
	for _, element in ipairs(Layout.Elements()) do
		RefreshPlate(element.key)
	end
	toolbar.gridToggle:SetValue(Layout.Setting("grid"), true)
	toolbar.snapToggle:SetValue(Layout.Setting("snap"), true)
	DrawGrid()
	Mode.HistoryChanged()
	toolbar:Open()
end

function Mode.Hide()
	if not overlay then
		return
	end
	EndDrag(false)
	Mode.Select(nil)
	if hoveredPlate then
		local tip = Widgets.Tooltip()
		if tip:IsOwned(hoveredPlate) then
			tip:Hide()
		end
		hoveredPlate.hover = false
		hoveredPlate = nil
	end
	if not InCombatLockdown() then
		overlay:SetPropagateKeyboardInput(true)
		overlay:EnableKeyboard(false)
	end
	overlay:Hide()
	grid:Hide()
	toolbar:Hide()
end

function Mode.Refresh()
	if not overlay or not Layout.IsActive() then
		return
	end
	toolbar.gridToggle:SetValue(Layout.Setting("grid"), true)
	toolbar.snapToggle:SetValue(Layout.Setting("snap"), true)
	for _, element in ipairs(Layout.Elements()) do
		RefreshPlate(element.key)
	end
	DrawGrid()
	PlaceHandles()
end

function Mode.Changed(key)
	if overlay and Layout.IsActive() and not (drag and drag.key == key) then
		RefreshPlate(key)
		if key == selected then
			local plate = plates[key]
			if plate and plate:IsShown() then
				PlaceHandles()
			else
				Mode.Select(nil)
			end
		end
	end
end

function Mode.Added(key)
	if overlay and Layout.IsActive() then
		RefreshPlate(key)
	end
end

function Mode.Overlay()
	return overlay
end

function Mode.Plate(key)
	return plates[key]
end

function Mode.Toolbar()
	return toolbar
end

function Mode.Grid()
	return grid
end

function Mode.Guides()
	return guideX, guideY
end

function Mode.Handle(name)
	return handles[name]
end

function Mode.Selected()
	return selected
end
