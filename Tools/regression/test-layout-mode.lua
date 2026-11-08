-- test-layout-mode.lua: Layout Mode's screen, driven like a player: plates, dragging with guides and the grid, nudges, resize and scale handles, the wheel, the toolbar, Escape and combat.
local W = dofile("Tools/regression/widget_env.lua")

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 1e-6)
end

local function New(opts)
	local env, K = W.New(opts)
	return env, K
end

local function Element(env, K, key, position, w, h, opts)
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	frame:SetSize(w, h)
	K.Layout.Register(frame, key, position, opts or { label = key })
	return frame
end

-- Cursor(env, K, x, y) puts the pointer at root units x, y.
local function Cursor(env, K, x, y)
	local scale = K.Scale.Root():GetEffectiveScale()
	env._cursor = { x * scale, y * scale }
end

local function Tick(K)
	local overlay = K.Layout.Mode.Overlay()
	local update = overlay:GetScript("OnUpdate")
	assert(update, "a drag runs an OnUpdate on the overlay")
	update(overlay, 0.016)
end

-- Drag(env, K, frame, fromX, fromY, toX, toY) presses on the frame, moves the pointer and releases.
local function Drag(env, K, frame, fromX, fromY, toX, toY, keep)
	Cursor(env, K, fromX, fromY)
	frame:GetScript("OnDragStart")(frame, "LeftButton")
	Cursor(env, K, toX, toY)
	Tick(K)
	if not keep then
		frame:GetScript("OnDragStop")(frame)
	end
end

local function Key(K, key)
	local overlay = K.Layout.Mode.Overlay()
	overlay:GetScript("OnKeyDown")(overlay, key)
	return W.LastCall(overlay, "SetPropagateKeyboardInput")[1]
end

local function Shown(region)
	return region:IsShown() == true
end

-- Entering builds the overlay, one plate per element and the toolbar --------------------------------------------------

do
	local env, K = New()
	local Layout = K.Layout
	local a = Element(env, K, "Test.A", { anchor = "CENTER", x = 300, y = -100 }, 100, 40, { label = "Alpha" })
	Element(env, K, "Test.Off", { anchor = "CENTER" }, 50, 50, { label = "Off", module = "UnitFrames" })
	assert(Layout.Enter())
	local Mode = Layout.Mode
	local overlay = Mode.Overlay()
	assert(overlay and overlay:IsShown(), "the overlay shows")
	assert(W.LastCall(overlay, "SetFrameStrata")[1] == "FULLSCREEN", "above the HUD")
	assert(W.LastCall(overlay, "EnableKeyboard")[1] == true and W.LastCall(overlay, "SetPropagateKeyboardInput")[1] == true, "it takes the keyboard and passes keys on")
	local plate = Mode.Plate("Test.A")
	assert(plate and plate:IsShown(), "an element gets a mover plate")
	local p = plate._points[1]
	assert(p[1] == "CENTER" and p[2] == a and p[3] == "CENTER", "the plate sits over its element")
	assert(near(plate:GetWidth(), 100) and near(plate:GetHeight(), 40), "at the element's size")
	assert(plate.label:GetText() == "ALPHA", "with the element's name")
	assert(Mode.Plate("Test.Off") == nil or not Mode.Plate("Test.Off"):IsShown(), "an element of a module that is off has no plate")
	local toolbar = Mode.Toolbar()
	assert(toolbar and toolbar:IsShown(), "the toolbar shows")
	assert(W.LastCall(toolbar, "SetFrameStrata")[1] == "FULLSCREEN_DIALOG", "above the plates")
	local registered
	for _, element in ipairs(Layout.Elements()) do
		if element.key == "Layout.Toolbar" then
			registered = element
		end
	end
	assert(registered and registered.opts.scalable and registered.opts.plate == false, "the toolbar is a scalable element without a plate")
	assert(Mode.Plate("Layout.Toolbar") == nil, "so it has no plate")
	for _, name in ipairs({ "gridToggle", "snapToggle", "undo", "redo", "reset", "done" }) do
		assert(toolbar[name], "the toolbar has " .. name)
	end
	assert(toolbar.undo:IsEnabled() == false and toolbar.redo:IsEnabled() == false, "undo and redo start disabled")
	Layout.Exit(true)
	assert(not overlay:IsShown() and not toolbar:IsShown(), "leaving hides the overlay and the toolbar")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Dragging a plate moves the element, snaps to the screen centre, shows a guide and saves the nearest anchor ---------------

do
	local env, K = New()
	local Layout = K.Layout
	Element(env, K, "Test.A", { anchor = "CENTER", x = 300, y = -100 }, 100, 40)
	assert(Layout.Enter())
	local Mode = Layout.Mode
	local plate = Mode.Plate("Test.A")
	-- The rect is left 1210, bottom 420. Moving by -296, +98 puts the centre at 964, 538: within 8 of the screen centre.
	Drag(env, K, plate, 1260, 440, 964, 538, true)
	local gx, gy = Mode.Guides()
	assert(gx:IsShown() and gy:IsShown(), "both guides show while snapped")
	local s = Layout.Get("Test.A")
	assert(s.x == 300, "nothing is saved during the drag")
	plate:GetScript("OnDragStop")(plate)
	assert(not gx:IsShown() and not gy:IsShown(), "the guides hide on release")
	assert(K.Layout.Mode.Overlay():GetScript("OnUpdate") == nil, "and the OnUpdate stops")
	s = Layout.Get("Test.A")
	assert(s.anchor == "CENTER" and near(s.x, 0) and near(s.y, 0), "the element snapped to the centre, got " .. s.anchor .. " " .. s.x .. " " .. s.y)
	assert(Layout.CanUndo() and Layout.Undo())
	assert(Layout.Get("Test.A").x == 300, "the drag is one undo step")

	-- Without snapping the element lands where it was dropped.
	K.Options.Write("Layout", "snap", false)
	Drag(env, K, plate, 1260, 440, 964, 538)
	s = Layout.Get("Test.A")
	assert(near(s.x, 4) and near(s.y, -2), "snapping off keeps the drop point, got " .. s.x .. " " .. s.y)
	K.Options.Write("Layout", "snap", true)

	-- A drop near the top left corner anchors there.
	Drag(env, K, plate, 1260, 440, 60, 1040)
	s = Layout.Get("Test.A")
	assert(s.anchor == "TOPLEFT", "a drop near a corner anchors to it, got " .. s.anchor)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The grid draws lines from the centre and the drag snaps to them --------------------------------------------------------

do
	local env, K = New()
	local Layout = K.Layout
	Element(env, K, "Test.A", { anchor = "BOTTOMLEFT", x = 300, y = 300 }, 100, 40)
	assert(Layout.Enter())
	local grid = Layout.Mode.Grid()
	assert(not grid or not grid:IsShown(), "the grid starts hidden")
	K.Options.Write("Layout", "grid", true)
	grid = Layout.Mode.Grid()
	assert(grid:IsShown(), "the grid setting shows it")
	local lines = 0
	for _, region in ipairs(W.Regions(grid, "Texture")) do
		if Shown(region) then
			lines = lines + 1
		end
	end
	-- 16-unit spacing from the centre of a 1920 by 1080 root: 121 vertical and 67 horizontal lines.
	assert(lines == 121 + 67, "grid lines every 16 units, got " .. lines)
	-- Dropped at left 333, bottom 303: the centre, 383, is 1 from the line at 384, and the bottom 3 from 300.
	Drag(env, K, Layout.Mode.Plate("Test.A"), 350, 320, 383, 323)
	local s = Layout.Get("Test.A")
	assert(s.anchor == "BOTTOMLEFT" and near(s.x, 334) and near(s.y, 300), "the drop snaps to the grid, got " .. s.x .. " " .. s.y)
	K.Options.Write("Layout", "grid", false)
	assert(not grid:IsShown(), "turning the setting off hides the grid")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Selecting and nudging with the arrow keys -----------------------------------------------------------------------------

do
	local env, K = New()
	local Layout = K.Layout
	Element(env, K, "Test.A", { anchor = "CENTER", x = 10, y = 20 }, 100, 40)
	assert(Layout.Enter())
	local Mode = Layout.Mode
	local plate = Mode.Plate("Test.A")
	assert(Key(K, "RIGHT") == true, "with nothing selected the arrows reach the game")
	W.Down(plate)
	assert(Mode.Selected() == "Test.A", "pressing a plate selects it")
	assert(Key(K, "RIGHT") == false, "an arrow is kept from the game while an element is selected")
	assert(near(Layout.Get("Test.A").x, 11), "RIGHT moves one physical pixel")
	env._modifiers.shift = true
	Key(K, "UP")
	env._modifiers.shift = false
	assert(near(Layout.Get("Test.A").y, 30), "Shift moves ten")
	Key(K, "LEFT")
	Key(K, "DOWN")
	assert(near(Layout.Get("Test.A").x, 10) and near(Layout.Get("Test.A").y, 29))
	assert(Key(K, "W") == true and near(Layout.Get("Test.A").y, 29), "other keys reach the game")
	assert(Layout.Undo())
	assert(near(Layout.Get("Test.A").x, 10) and near(Layout.Get("Test.A").y, 20), "a run of nudges is one undo step")
	assert(not Layout.CanUndo())
	env._modifiers.ctrl = true
	Key(K, "Y")
	assert(near(Layout.Get("Test.A").y, 29), "Ctrl+Y redoes")
	Key(K, "Z")
	env._modifiers.ctrl = false
	assert(near(Layout.Get("Test.A").y, 20), "Ctrl+Z undoes")

	-- At 1440p a nudge is one physical pixel: 0.75 units.
	local env2, K2 = New({ width = 2560, height = 1440 })
	Element(env2, K2, "Test.B", { anchor = "CENTER" }, 100, 40)
	assert(K2.Layout.Enter())
	W.Down(K2.Layout.Mode.Plate("Test.B"))
	local before = K2.Layout.Rect("Test.B")
	Key(K2, "RIGHT")
	local after = K2.Layout.Rect("Test.B")
	assert(near(after - before, 0.75), "one physical pixel at 1440p, got " .. (after - before))

	-- Escape deselects, then leaves.
	assert(Key(K, "ESCAPE") == false, "Escape is kept from the game")
	assert(Mode.Selected() == nil and Layout.IsActive(), "the first Escape deselects")
	Key(K, "ESCAPE")
	assert(not Layout.IsActive(), "the second leaves Layout Mode")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Resize handles: corners and edges, limits, whole pixels -------------------------------------------------------------------

do
	local env, K = New()
	local Layout = K.Layout
	Element(env, K, "Test.B", { anchor = "TOPLEFT", x = 100, y = -100 }, 200, 50, {
		label = "Bar", resizable = true, minWidth = 100, maxWidth = 300, minHeight = 30, maxHeight = 80,
	})
	Element(env, K, "Test.Fixed", { anchor = "CENTER" }, 60, 60, { label = "Fixed" })
	assert(Layout.Enter())
	local Mode = Layout.Mode
	W.Down(Mode.Plate("Test.Fixed"))
	assert(not Mode.Handle("RIGHT"):IsShown(), "an element that cannot resize shows no handles")
	W.Down(Mode.Plate("Test.B"))
	for _, name in ipairs({ "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }) do
		assert(Mode.Handle(name):IsShown(), "a resizable element shows the " .. name .. " handle")
	end
	assert(not Mode.Handle("SCALE"):IsShown(), "but no scale handle")
	-- The rect: left 100, top 980, so bottom 930.
	Drag(env, K, Mode.Handle("RIGHT"), 300, 955, 350, 955)
	local s = Layout.Get("Test.B")
	assert(s.width == 250 and s.height == 50, "the right handle widens, got " .. s.width)
	assert(s.anchor == "TOPLEFT" and near(s.x, 100) and near(s.y, -100), "and the left edge stays")
	Drag(env, K, Mode.Handle("RIGHT"), 350, 955, 900, 955)
	assert(Layout.Get("Test.B").width == 300, "maxWidth holds")
	Drag(env, K, Mode.Handle("BOTTOM"), 250, 930, 250, 910)
	s = Layout.Get("Test.B")
	assert(s.height == 70 and near(s.y, -100), "the bottom handle grows down and the top edge stays")
	Drag(env, K, Mode.Handle("TOPLEFT"), 100, 980, 400, 700)
	s = Layout.Get("Test.B")
	assert(s.width == 100 and s.height == 30, "minWidth and minHeight hold")
	assert(Layout.Undo() and Layout.Get("Test.B").width == 300, "a resize is one undo step")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The scale handle, the wheel and right-click reset ----------------------------------------------------------------------------

do
	local env, K = New()
	local Layout = K.Layout
	local frame = Element(env, K, "Test.D", { anchor = "CENTER" }, 100, 100, { label = "Dial", scalable = true })
	assert(Layout.Enter())
	local Mode = Layout.Mode
	local plate = Mode.Plate("Test.D")
	W.Down(plate)
	assert(Mode.Handle("SCALE"):IsShown() and not Mode.Handle("RIGHT"):IsShown(), "a scalable element shows the scale handle")
	-- The bottom right corner is at 1010, 490. Dragging it 50 out on both axes makes the diagonal 1.5 times longer.
	Drag(env, K, Mode.Handle("SCALE"), 1010, 490, 1060, 440)
	local s = Layout.Get("Test.D")
	assert(near(s.scale, 1.5), "the scale handle scales, got " .. s.scale)
	assert(frame:GetScale() == 1.5)
	assert(near(s.x, 25) and near(s.y, -25), "and the top left corner stays, got " .. s.x .. " " .. s.y)
	plate:GetScript("OnMouseWheel")(plate, 1)
	assert(near(Layout.Get("Test.D").scale, 1.55), "the wheel scales up one step")
	plate:GetScript("OnMouseWheel")(plate, -1)
	plate:GetScript("OnMouseWheel")(plate, -1)
	assert(near(Layout.Get("Test.D").scale, 1.45), "and down")
	for _ = 1, 40 do
		plate:GetScript("OnMouseWheel")(plate, -1)
	end
	assert(near(Layout.Get("Test.D").scale, 0.5), "down to 0.5")
	plate:GetScript("OnClick")(plate, "RightButton")
	s = Layout.Get("Test.D")
	assert(s.scale == 1 and s.x == 0 and s.y == 0, "right-click resets the element")
	assert(Layout.Undo() and near(Layout.Get("Test.D").scale, 0.5), "and the reset can be undone")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A scale drag on a widget redraws its chrome in whole pixels at the new scale ---------------------------------------------------

do
	local env, K = New()
	local Layout, Widgets, Scale = K.Layout, K.Widgets, K.Scale
	local panel = Widgets.Panel(Scale.Root(), {
		width = 100, height = 100,
		layout = { key = "Test.Panel", position = { anchor = "CENTER" }, options = { label = "Panel", scalable = true } },
	})
	assert(Layout.Enter())
	W.Down(Layout.Mode.Plate("Test.Panel"))
	Drag(env, K, Layout.Mode.Handle("SCALE"), 1010, 490, 1060, 440)
	env.RunTimers()
	assert(near(Layout.Get("Test.Panel").scale, 1.5))
	assert(near(panel.chrome.outer[5]:GetHeight(), Scale.Border() / 1.5), "the bevel is redrawn for the new scale")
	Layout.Exit(true)
end

-- A module that stops or starts while Layout Mode is open hides or shows its plates ---------------------------------------------

do
	local env, K = New()
	local Layout = K.Layout
	local frame
	K.Modules.Register(W.CoreEnv.Module("UnitFrames", {
		onEnable = function()
			if not frame then
				frame = Element(env, K, "UnitFrames.Test", { anchor = "CENTER" }, 80, 30, { label = "Unit", module = "UnitFrames" })
			end
			frame:Show()
		end,
		onDisable = function()
			frame:Hide()
		end,
	}))
	K.Modules.Enable("UnitFrames")
	assert(Layout.Enter())
	local plate = Layout.Mode.Plate("UnitFrames.Test")
	assert(plate and plate:IsShown())
	W.Down(plate)
	K.Modules.Disable("UnitFrames")
	assert(not plate:IsShown(), "a stopped module's plate hides")
	assert(Layout.Mode.Selected() == nil, "and is no longer selected")
	K.Modules.Enable("UnitFrames")
	assert(plate:IsShown(), "it shows again when the module starts")
	Layout.Exit(true)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The toolbar: grid and snap switches, undo, redo, reset and done ----------------------------------------------------------------

do
	local env, K = New()
	local Layout = K.Layout
	Element(env, K, "Test.A", { anchor = "CENTER" }, 100, 40)
	assert(Layout.Enter())
	local toolbar = Layout.Mode.Toolbar()
	W.Click(toolbar.gridToggle)
	assert(K.Store.Module("Layout").grid == true and Layout.Mode.Grid():IsShown(), "the grid switch saves and shows the grid")
	W.Click(toolbar.snapToggle)
	assert(K.Store.Module("Layout").snap == false, "the snap switch saves")
	assert(Layout.Set("Test.A", "x", 50))
	assert(toolbar.undo:IsEnabled() and not toolbar.redo:IsEnabled(), "a change enables undo")
	W.Click(toolbar.undo)
	assert(Layout.Get("Test.A").x == 0 and toolbar.redo:IsEnabled(), "undo reverts and enables redo")
	W.Click(toolbar.redo)
	assert(Layout.Get("Test.A").x == 50, "redo applies again")
	W.Click(toolbar.reset)
	assert(Layout.Get("Test.A").x == 0, "reset reverts every element")
	assert(Layout.CanUndo(), "and can be undone")
	W.Click(toolbar.done)
	assert(not Layout.IsActive(), "done leaves Layout Mode")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The toolbar moves by its title bar and keeps its place --------------------------------------------------------------------------

do
	local env, K = New()
	local Layout = K.Layout
	assert(Layout.Enter())
	local toolbar = Layout.Mode.Toolbar()
	local before = Layout.Get("Layout.Toolbar")
	local l, b, w, h = Layout.Rect("Layout.Toolbar")
	Drag(env, K, toolbar.titleBar, l + w / 2, b + h - 10, l + w / 2 - 300, b + h - 210)
	local after = Layout.Get("Layout.Toolbar")
	assert(after.anchor ~= before.anchor or not near(after.x, before.x) or not near(after.y, before.y), "dragging the title bar moves the toolbar")
	local l2, b2 = Layout.Rect("Layout.Toolbar")
	assert(near(l2, l - 300, 8.5) and near(b2, b - 200, 8.5), "to where it was dropped, give or take a snap")
	Layout.Exit(true)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Combat during a drag leaves Layout Mode, stops the drag and restores the saved positions -------------------------------------------

do
	local env, K = New()
	local Layout = K.Layout
	local frame = Element(env, K, "Test.A", { anchor = "CENTER", x = 300, y = -100 }, 100, 40)
	assert(Layout.Enter())
	local overlay = Layout.Mode.Overlay()
	Drag(env, K, Layout.Mode.Plate("Test.A"), 1260, 440, 600, 700, true)
	assert(overlay:GetScript("OnUpdate"), "the drag is running")
	env.SetCombat(true)
	assert(not Layout.IsActive() and not overlay:IsShown(), "combat leaves Layout Mode")
	assert(overlay:GetScript("OnUpdate") == nil, "and stops the drag")
	assert(Layout.Get("Test.A").x == 300, "nothing from the drag is saved")
	local p = frame._points[1]
	assert(p[1] == "CENTER" and near(p[4], 300) and near(p[5], -100), "the element is back at its saved position")
	assert(not Layout.Enter(), "Layout Mode stays shut in combat")
	env.SetCombat(false)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Plates follow a size change and a new element registered while Layout Mode is open -------------------------------------------------

do
	local env, K = New()
	local Layout = K.Layout
	Element(env, K, "Test.A", { anchor = "CENTER" }, 100, 40, { label = "A", resizable = true, maxWidth = 500 })
	assert(Layout.Enter())
	assert(Layout.Set("Test.A", "width", 300))
	assert(near(Layout.Mode.Plate("Test.A"):GetWidth(), 300), "the plate follows the element's size")
	Element(env, K, "Test.Late", { anchor = "TOP" }, 80, 20, { label = "Late" })
	assert(Layout.Mode.Plate("Test.Late") and Layout.Mode.Plate("Test.Late"):IsShown(), "an element registered in Layout Mode gets a plate")
	assert(K.Scale.SetUserScale(1.25))
	local _, _, w = Layout.Rect("Test.A")
	assert(near(Layout.Mode.Plate("Test.A"):GetWidth(), w), "plates follow a new interface size")
	Layout.Exit(true)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A plate's body is the button grade's tone at rest, under the mouse and selected: translucent so the element shows through ---------

do
	local env, K = New()
	local Layout = K.Layout
	Element(env, K, "Test.A", { anchor = "CENTER", x = 300, y = -100 }, 100, 40, { label = "Alpha" })
	assert(Layout.Enter())
	local Mode = Layout.Mode
	local plate = Mode.Plate("Test.A")
	local br, bg, bb = K.Tokens.Color("buttonFill")
	local function body(state)
		local r, g, b, a = plate.chrome.fill[5]:GetVertexColor()
		assert(near(r, br) and near(g, bg) and near(b, bb), "the plate body " .. state .. " is the button grade's tone, got " .. r .. " " .. g .. " " .. b)
		assert(a > 0.5 and a < 1, "and translucent so the element shows through, got " .. a)
		return a
	end
	local rest = body("at rest")
	W.Enter(plate)
	local hover = body("under the mouse")
	W.Down(plate)
	local active = body("selected")
	assert(rest < hover and hover < active, "the body deepens from rest to hover to selected")
	local er, eg, eb = K.Tokens.Color("accent")
	local r, g, b = plate.chrome.inner[5]:GetVertexColor()
	assert(near(r, er) and near(g, eg) and near(b, eb), "the plate's edge is the accent")
	Layout.Exit(true)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("layout mode ok")
