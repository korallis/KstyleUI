-- gallery_layout.lua: Layout Mode over stand-in elements, in two environments. The first holds the toolbar and
-- four plates of different sizes over glass stand-ins: the player frame's plate selected with its eight resize
-- handles, the target's under the mouse, the buffs and the chat at rest. The second holds a drag in progress: a
-- scalable minimap stand-in dragged onto the screen centre with the grid on, so both snap guides show and the
-- plate carries its scale handle. The overlay and the grid are full-screen containers, so the frames crop regions.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Scene = Common.Scene

local GRID_CROP_W, GRID_CROP_H = 420, 320

-- StandIn(env, K, key, label, x, y, w, h, opts) -> a glass panel the size of a HUD element, registered with
-- Layout at its top left (screen units), as a module's frame would be.
local function StandIn(env, K, key, label, x, y, w, h, opts)
	local frame = K.Widgets.Panel(K.Scale.Root(), { width = w, height = h, shape = "panel" })
	local text = K.Widgets.Text(frame, "body", "text")
	text:SetPoint("CENTER", frame, "CENTER")
	text:SetText(label)
	local options = { label = label }
	for k, v in pairs(opts or {}) do
		options[k] = v
	end
	K.Layout.Register(frame, key, { anchor = "TOPLEFT", x = x, y = -y }, options)
	return frame
end

-- Cursor(env, K, x, y) puts the pointer at root units x, y from the bottom left, as the game reports it.
local function Cursor(env, K, x, y)
	local scale = K.Scale.Root():GetEffectiveScale()
	env._cursor = { x * scale, y * scale }
end

-- LayOutToolbar(env, K, panel) places the toolbar's controls again with each toggle as wide as its label reads in
-- the kit font. The stub measures no text, so the toolbar packs its toggles over their labels; the game does not.
local function LayOutToolbar(env, K, panel)
	local Tokens, Widgets = K.Tokens, K.Widgets
	local content = panel.content
	local gap = Tokens.Size("gapMedium")
	local x, tallest = 0, 0
	for i, item in ipairs({ panel.gridToggle, panel.snapToggle, panel.undo, panel.redo, panel.reset, panel.done }) do
		local width = item:GetWidth() or 0
		if item.trackBox and item.label then
			local path, size = Scene.Font(env, item.label)
			width = item.trackBox:GetWidth() + gap + Scene.TextWidth(item.label:GetText() or "", size, path)
			item:SetWidth(Widgets.Snap(panel, width))
		end
		item:ClearAllPoints()
		item:SetPoint("LEFT", content, "LEFT", Widgets.Snap(panel, x), 0)
		x = x + width + (i == 2 and gap * 2 or gap)
		tallest = math.max(tallest, item:GetHeight() or 0)
	end
	local pad = Tokens.Size("panelPadding")
	panel.opts.width = x - gap + pad * 2
	panel.opts.height = pad + Tokens.Size("heading") + gap * 2 + tallest + pad
	panel:Restyle()
end

local function NewEnv(W)
	return W.New(Common.ScreenOpts({ saved = Gallery.Saved({}), setup = Gallery.Setup }))
end

return Common.Run(function()
	local W = dofile("Tools/regression/widget_env.lua")
	local frames = Gallery.Frames()
	local scenes = {}

	-- Environment 1: the toolbar, and plates at rest, under the mouse and selected.
	local env, K = NewEnv(W)
	local Layout, Mode = K.Layout, K.Layout.Mode
	StandIn(env, K, "gallery.chat", "Chat", 60, 170, 360, 180, { resizable = true })
	StandIn(env, K, "gallery.player", "Player", 60, 380, 220, 60, { resizable = true, minWidth = 120, minHeight = 30 })
	StandIn(env, K, "gallery.target", "Target", 320, 380, 220, 60, { resizable = true })
	StandIn(env, K, "gallery.buffs", "Buffs", 60, 460, 300, 36, { scalable = true })
	assert(Layout.Enter(), "Layout Mode opens")
	local toolbar = Mode.Toolbar()
	LayOutToolbar(env, K, toolbar)
	assert(Layout.Set("Layout.Toolbar", "anchor", "TOPLEFT"))
	assert(Layout.Set("Layout.Toolbar", "x", 60))
	assert(Layout.Set("Layout.Toolbar", "y", -40))
	Mode.Select("gallery.player")
	local target = Mode.Plate("gallery.target")
	W.Enter(target)
	K.Widgets.Tooltip():Hide()
	W.Settle(env)
	frames:Add(env, toolbar, {
		name = "layout_toolbar", title = "Layout Mode toolbar", grade = "window", reference = "chat",
		caption = "The Layout Mode toolbar: a titled glass window with the Grid and Snap toggles, Undo and Redo disabled before any change, Reset and the primary Done button.",
		match = "Window grade as the mockup's chat panel: surface fill, the dark outer and light inner lines, the 12-unit chamfer and the drop shadow; the toggles and buttons inside are the bar and button grades.",
	})
	local plates = { Mode.Plate("gallery.chat"), Mode.Plate("gallery.player"), target, Mode.Plate("gallery.buffs") }
	local union = Gallery.Union(env, plates)
	assert(union, "the plates resolve")
	frames:Add(env, nil, {
		name = "layout_plates", title = "Mover plates", grade = "button", reference = "datastrip", pad = 24,
		rect = { x = union.x - 10, y = union.y - 10, w = union.w + 20, h = union.h + 20 },
		caption = "Four mover plates over glass stand-ins of different sizes: Player selected with its eight resize handles and its anchor, offsets and size; Target under the mouse; Chat and Buffs at rest. The plate is the button body at a translucent alpha with the accent on its edge, so the element shows through.",
		match = "Body #101214 and the one-border line as the mockup's data strip pill, drawn translucent (0.6 at rest, 0.72 hovered, 0.85 selected) because a plate must show the element under it; the edge is the accent instead of the neutral hairline, and the handles are flat white-tinted squares, not backdrops.",
	})
	local selected = Mode.Plate("gallery.player")
	frames:Add(env, selected, {
		name = "layout_handles", title = "Resize handles", grade = "button", reference = "datastrip", pad = 20,
		caption = "The selected Player plate close up: eight 8-unit resize handles on its corners and edges, each a white square with a one-border dark rim, in the accent, on the plate's translucent button body with the accent edge.",
		match = "The plate's body and line as the mockup's data strip pill at a translucent alpha; the handles are affordances drawn as flat tinted textures by design, not backdrops.",
	})
	scenes[#scenes + 1] = Scene.Build(env)
	assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))

	-- Environment 2: a drag in progress with the grid on, snapped to the screen centre.
	local env2, K2 = NewEnv(W)
	local Layout2, Mode2 = K2.Layout, K2.Layout.Mode
	local rw, rh = Layout2.RootSize()
	local size = 180
	local startX, startY = 1000, 640
	local minimap = StandIn(env2, K2, "gallery.minimap", "Minimap", startX, startY, size, size, { scalable = true })
	assert(Layout2.Enter(), "Layout Mode opens")
	K2.Options.Write("Layout", "grid", true)
	Mode2.Toolbar():Hide()
	local plate = Mode2.Plate("gallery.minimap")
	-- Press at the plate's centre (root units from the bottom left), then move it so its centre lands within the
	-- snap distance of the screen centre: both guides show and the frame snaps onto them.
	local l, b, w, h = Layout2.Rect("gallery.minimap")
	Cursor(env2, K2, l + w / 2, b + h / 2)
	plate:GetScript("OnDragStart")(plate, "LeftButton")
	Cursor(env2, K2, rw / 2 + 1, rh / 2 - 1)
	Mode2.Overlay():GetScript("OnUpdate")(Mode2.Overlay(), 0.016)
	local gx, gy = Mode2.Guides()
	assert(gx:IsShown() and gy:IsShown(), "both guides show while the drag is snapped")
	assert(Mode2.Handle("SCALE"):IsShown(), "the dragged scalable plate carries its scale handle")
	assert(Mode2.Grid():IsShown(), "the grid shows")
	local x, y = Scene.Rect(env2, minimap)
	assert(x, "the dragged stand-in resolves")
	frames:Add(env2, nil, {
		name = "layout_grid", title = "Grid and guides", grade = "button", reference = "datastrip", pad = 0,
		rect = { x = x + size / 2 - GRID_CROP_W / 2, y = y + size / 2 - GRID_CROP_H / 2, w = GRID_CROP_W, h = GRID_CROP_H },
		caption = "A drag in progress with the grid on: the Minimap plate snapped onto the screen centre, the two accent snap guides crossing it, its scale handle at the bottom right corner, and the 16-unit grid with its accent centre lines behind.",
		match = "The plate is the button body at a translucent alpha with the accent edge; the grid lines (white 7%, centre lines accent 45%) and the guides (accent 90%) are one-border flat lines, not backdrops, by design.",
	})
	scenes[#scenes + 1] = Scene.Build(env2)
	assert(not Common.Errors(env2, K2), tostring(Common.Errors(env2, K2)))

	-- The grid and guides are drawn first so the first environment's frames sit over them, as plates do in the game.
	return frames:Finish(Scene.Merge({ scenes[2], scenes[1] }), env, K, "gallery layout")
end)
