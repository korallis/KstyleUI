-- test-layout.lua: Layout Mode's pure parts: position maths, snapping, resize clamping, undo history and the shown rules.
local CoreEnv = dofile("Tools/regression/core_env.lua")

local _, K = CoreEnv.New()
assert(type(K.Layout) == "table", "KstyleUI.Layout must exist")
local G, History, Rules = K.Layout.Geometry, K.Layout.History, K.Layout.Rules
assert(type(G) == "table" and type(History) == "table" and type(Rules) == "table", "Layout exposes Geometry, History and Rules")

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 1e-6)
end

local function check(label, cond, ...)
	if not cond then
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		error(label .. (#parts > 0 and (": " .. table.concat(parts, ", ")) or ""), 2)
	end
end

-- Anchors ------------------------------------------------------------------------------------------

do
	check("nine anchors", #G.ANCHORS == 9)
	for _, anchor in ipairs({ "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }) do
		check("anchor " .. anchor, G.IsAnchor(anchor))
	end
	check("not an anchor", not G.IsAnchor("MIDDLE") and not G.IsAnchor(nil) and not G.IsAnchor(5))
	local fx, fy = G.Fraction("TOPRIGHT")
	check("TOPRIGHT is the right and top fraction", fx == 1 and fy == 1)
	fx, fy = G.Fraction("BOTTOM")
	check("BOTTOM is the middle bottom", fx == 0.5 and fy == 0)
end

-- Rect and Position are inverses for every anchor ----------------------------------------------------

do
	local W, H = 1920, 1080
	-- A 220 by 46 frame centred 100 units right of and 200 units below the centre.
	local left, bottom = G.Rect("CENTER", 100, -200, 220, 46, W, H)
	check("CENTER rect left", near(left, 960 + 100 - 110), left)
	check("CENTER rect bottom", near(bottom, 540 - 200 - 23), bottom)
	left, bottom = G.Rect("TOPLEFT", 10, -20, 100, 50, W, H)
	check("TOPLEFT rect", near(left, 10) and near(bottom, 1080 - 20 - 50), left, bottom)
	left, bottom = G.Rect("BOTTOMRIGHT", -5, 7, 100, 50, W, H)
	check("BOTTOMRIGHT rect", near(left, 1920 - 5 - 100) and near(bottom, 7), left, bottom)
	for _, anchor in ipairs(G.ANCHORS) do
		local l, b = G.Rect(anchor, 33.5, -12.25, 140, 60, W, H)
		local a, x, y = G.Position(l, b, 140, 60, W, H, anchor)
		check("Position keeps the anchor it is given", a == anchor, a)
		check("Position inverts Rect for " .. anchor, near(x, 33.5) and near(y, -12.25), x, y)
	end
end

-- Position picks the nearest of the nine anchors by the element's centre -------------------------------

do
	local W, H = 1920, 1080
	local cases = {
		{ 10, 1000, "TOPLEFT" }, { 900, 1000, "TOP" }, { 1800, 1000, "TOPRIGHT" },
		{ 10, 500, "LEFT" }, { 900, 500, "CENTER" }, { 1800, 500, "RIGHT" },
		{ 10, 10, "BOTTOMLEFT" }, { 900, 10, "BOTTOM" }, { 1800, 10, "BOTTOMRIGHT" },
	}
	for _, case in ipairs(cases) do
		local anchor, x, y = G.Position(case[1], case[2], 40, 40, W, H)
		check("nearest anchor for " .. case[3], anchor == case[3], anchor)
		local l, b = G.Rect(anchor, x, y, 40, 40, W, H)
		check("the nearest anchor keeps the element in place", near(l, case[1]) and near(b, case[2]), l, b)
	end
	check("NearestAnchor agrees", G.NearestAnchor(900, 500, 40, 40, W, H) == "CENTER")
end

-- Whole physical pixels -------------------------------------------------------------------------------

do
	check("Align to whole pixels at 1080p", G.Align(10.4, 1) == 10 and G.Align(10.6, 1) == 11)
	check("Align at 1440p (0.75 units a pixel)", near(G.Align(10.4, 0.75), 10.5))
	check("Align at 4K", near(G.Align(-3.3, 0.5), -3.5))
	-- SnapSize: the size on the root (size times factor) is a whole number of pixels.
	local size = G.SnapSize(100.3, 1, 0.75)
	check("SnapSize at 1440p", near(size / 0.75, math.floor(size / 0.75 + 0.5)) and near(size, 100.5), size)
	size = G.SnapSize(100, 1.3, 0.5)
	check("SnapSize keeps whole pixels on the root at another scale", near(size * 1.3 / 0.5, math.floor(size * 1.3 / 0.5 + 0.5)), size)
	check("SnapSize is at least one pixel", near(G.SnapSize(0.01, 1, 0.75), 0.75))
end

-- Clamping to the screen ---------------------------------------------------------------------------------

do
	local l, b = G.ClampToRoot(-50, 2000, 100, 40, 1920, 1080)
	check("an element pulled off the top left stays on screen", l == 0 and b == 1040, l, b)
	l, b = G.ClampToRoot(1900, -10, 100, 40, 1920, 1080)
	check("off the bottom right", l == 1820 and b == 0, l, b)
	l = G.ClampToRoot(-50, 10, 3000, 40, 1920, 1080)
	check("an element wider than the screen keeps its left edge on screen", l == 0, l)
end

-- Snapping guides ---------------------------------------------------------------------------------------

do
	local W, H = 1920, 1080
	local other = { left = 500, bottom = 300, width = 200, height = 100 }
	local targets = G.Targets(W, H, { other })
	-- Screen edges, the centre, and the other element's edges and centre on both axes.
	for _, x in ipairs({ 0, 960, 1920, 500, 600, 700 }) do
		local found = false
		for _, t in ipairs(targets.xs) do
			found = found or t == x
		end
		check("x target " .. x, found)
	end
	for _, y in ipairs({ 0, 540, 1080, 300, 350, 400 }) do
		local found = false
		for _, t in ipairs(targets.ys) do
			found = found or t == y
		end
		check("y target " .. y, found)
	end

	-- S(...) -> { left, bottom, guideX, guideY } from G.SnapMove.
	local function S(...)
		return { G.SnapMove(...) }
	end
	-- A left edge 4 units right of the other element's right edge snaps onto it.
	local r = S(704, 820, 100, 40, targets, 8)
	check("snaps the left edge to the other's right edge", r[1] == 700 and r[3] == 700, unpack(r))
	check("y far from every target stays", r[2] == 820 and r[4] == nil, unpack(r))
	-- The element's centre snaps to the screen's centre.
	r = S(913, 515, 100, 40, targets, 8)
	check("centre snaps to the screen centre", r[1] == 910 and r[3] == 960, unpack(r))
	check("vertical centre snaps too", r[2] == 520 and r[4] == 540, unpack(r))
	-- The right edge snaps to the screen's right edge.
	r = S(1815, 900, 100, 40, targets, 8)
	check("right edge snaps to the screen edge", r[1] == 1820, unpack(r))
	-- Out of reach: no snap.
	r = S(1300, 900, 100, 40, targets, 8)
	check("no target in reach leaves the rect", r[1] == 1300 and r[2] == 900 and r[3] == nil and r[4] == nil)
	-- The nearest target wins.
	r = S(104, 0, 50, 50, { xs = { 100, 106 }, ys = {} }, 8)
	check("the nearest target wins", r[1] == 106, unpack(r))
	-- The grid: lines every 16 units from the centre.
	local grid = { size = 16, cx = 960, cy = 540 }
	local none = { xs = {}, ys = {} }
	-- Left 1300 is 4 from the line at 1296; the top, 940, lies on a line already.
	r = S(1300, 900, 100, 40, none, 4, grid)
	check("the left edge snaps to the grid", r[1] == 1296 and r[3] == 1296, unpack(r))
	check("an edge on a grid line stays and reports it", r[2] == 900 and r[4] == 940, unpack(r))
	-- Bottom 903: the centre, 923, is 1 from the line at 924, nearer than either edge.
	r = S(1299, 903, 100, 40, none, 4, grid)
	check("grid snap moves to the nearest line", r[1] == 1296 and r[2] == 904 and r[4] == 924, unpack(r))
	-- Element targets and grid lines compete; the nearer wins.
	r = S(1299, 903, 100, 40, { xs = { 1298 }, ys = {} }, 4, grid)
	check("an element edge nearer than the grid wins", r[1] == 1298, unpack(r))
end

-- Resize clamping ---------------------------------------------------------------------------------------

do
	-- R(...) -> { left, bottom, width, height } from G.Resize.
	local function R(rect, handle, dx, dy, limits)
		return { G.Resize(rect, handle, dx, dy, limits) }
	end
	local rect = { left = 100, bottom = 200, width = 220, height = 46 }
	local limits = { minWidth = 120, maxWidth = 400, minHeight = 30, maxHeight = 80, pixel = 1 }
	local r = R(rect, "RIGHT", 50, 0, limits)
	check("the right handle widens and keeps the left edge", r[1] == 100 and r[2] == 200 and r[3] == 270 and r[4] == 46, unpack(r))
	r = R(rect, "LEFT", 30, 0, limits)
	check("the left handle keeps the right edge", r[3] == 190 and r[1] == 130, unpack(r))
	r = R(rect, "TOP", 0, 10, limits)
	check("the top handle keeps the bottom edge", r[4] == 56 and r[2] == 200, unpack(r))
	r = R(rect, "BOTTOM", 0, -10, limits)
	check("the bottom handle keeps the top edge", r[4] == 56 and r[2] == 190, unpack(r))
	r = R(rect, "TOPRIGHT", 1000, 1000, limits)
	check("max limits clamp both sizes", r[3] == 400 and r[4] == 80 and r[1] == 100 and r[2] == 200, unpack(r))
	r = R(rect, "BOTTOMLEFT", 1000, 1000, limits)
	check("min limits clamp, and the top right corner stays", r[3] == 120 and r[4] == 30 and r[1] == 200 and r[2] == 216, unpack(r))
	r = R(rect, "RIGHT", 10.4, 0, { minWidth = 1, maxWidth = 999, minHeight = 1, maxHeight = 999, pixel = 0.75 })
	check("sizes snap to whole pixels", near(r[3] / 0.75, math.floor(r[3] / 0.75 + 0.5)), unpack(r))

	-- Aspect locking: a 2:1 element.
	local wide = { left = 0, bottom = 0, width = 100, height = 50 }
	local locked = { minWidth = 40, maxWidth = 300, minHeight = 20, maxHeight = 100, aspect = 2, pixel = 1 }
	r = R(wide, "RIGHT", 40, 0, locked)
	check("an edge handle drives the other size", r[3] == 140 and r[4] == 70, unpack(r))
	check("a width handle keeps the top edge", r[2] == -20, unpack(r))
	r = R(wide, "TOP", 0, 20, locked)
	check("a height handle drives the width and keeps the left edge", r[3] == 140 and r[4] == 70 and r[1] == 0 and r[2] == 0, unpack(r))
	r = R(wide, "TOPRIGHT", 10, 40, locked)
	check("a corner follows the larger change", r[4] == 90 and r[3] == 180, unpack(r))
	r = R(wide, "TOPRIGHT", 500, 0, locked)
	check("aspect and max together: max height limits the width", r[3] == 200 and r[4] == 100, unpack(r))
	r = R(wide, "BOTTOMLEFT", 90, 90, locked)
	check("aspect and min together", r[3] == 40 and r[4] == 20, unpack(r))
end

-- Rescale from the corner handle -----------------------------------------------------------------------

do
	local rect = { left = 0, bottom = 0, width = 100, height = 100 }
	check("dragging out grows the scale", near(G.Rescale(rect, 1, 50, -50, 0.5, 2), 1.5))
	check("dragging in shrinks it", near(G.Rescale(rect, 1, -30, 30, 0.5, 2), 0.7))
	check("clamped to the max", G.Rescale(rect, 1.5, 500, -500, 0.5, 2) == 2)
	check("clamped to the min", G.Rescale(rect, 1, -99, 99, 0.5, 2) == 0.5)
	check("a zero-sized rect keeps its scale", G.Rescale({ left = 0, bottom = 0, width = 0, height = 0 }, 1.2, 5, 5, 0.5, 2) == 1.2)
end

-- Undo history -----------------------------------------------------------------------------------------

do
	local h = History.New(3)
	check("empty history", not h:CanUndo() and not h:CanRedo() and h:Undo() == nil and h:Redo() == nil)
	h:Push({ id = 1 })
	h:Push({ id = 2 })
	check("can undo", h:CanUndo() and not h:CanRedo())
	check("undo returns the newest entry", h:Undo().id == 2)
	check("then redo is possible", h:CanRedo())
	check("redo returns it again", h:Redo().id == 2)
	h:Undo()
	h:Push({ id = 3 })
	check("a new entry clears the redo stack", not h:CanRedo())
	h:Push({ id = 4 })
	h:Push({ id = 5 })
	check("the limit drops the oldest entry", h:Size() == 3)
	check("newest first", h:Undo().id == 5 and h:Undo().id == 4 and h:Undo().id == 3 and h:Undo() == nil)
	h:Clear()
	check("Clear empties both stacks", not h:CanUndo() and not h:CanRedo())

	-- Merging: consecutive entries with the same merge key fold into one, keeping the first before.
	local m = History.New(10)
	m:Push({ merge = "nudge:A", changes = { A = { before = { x = 0 }, after = { x = 1 } } } })
	m:Push({ merge = "nudge:A", changes = { A = { before = { x = 1 }, after = { x = 2 } } } })
	m:Push({ merge = "nudge:A", changes = { A = { before = { x = 2 }, after = { x = 3 } } } })
	check("merged nudges are one entry", m:Size() == 1)
	local e = m:Undo()
	check("the merged entry keeps the first before and the last after", e.changes.A.before.x == 0 and e.changes.A.after.x == 3)
	m:Redo()
	m:Push({ merge = "nudge:B", changes = { B = { before = { x = 0 }, after = { x = 1 } } } })
	check("another key does not merge", m:Size() == 2)
	m:Undo()
	m:Push({ merge = "nudge:A", changes = { A = { before = { x = 3 }, after = { x = 4 } } } })
	check("an undone entry is never merged into", m:Size() == 2)
end

-- Shown rules ------------------------------------------------------------------------------------------

do
	local SHOWN = { "always", "combat", "noCombat", "target", "mouseover", "never" }
	check("six rules", #Rules.SHOWN == 6)
	for i, rule in ipairs(SHOWN) do
		check("rule " .. rule, Rules.SHOWN[i] == rule and Rules.IsRule(rule))
	end
	check("not a rule", not Rules.IsRule("sometimes") and not Rules.IsRule(nil))

	-- Secure frames get a visibility state driver; always and mouseover leave visibility alone.
	check("always has no driver", Rules.Driver("always") == nil)
	check("mouseover has no driver", Rules.Driver("mouseover") == nil)
	check("combat driver", Rules.Driver("combat") == "[combat] show; hide")
	check("out of combat driver", Rules.Driver("noCombat") == "[combat] hide; show")
	check("target driver", Rules.Driver("target") == "[@target,exists] show; hide")
	check("never driver", Rules.Driver("never") == "hide")

	-- The drivers mean what the Lua rule means, through the stub's macro option parser.
	local env = dofile("Tools/regression/stubs/wow.lua").NewEnv()
	for _, rule in ipairs(SHOWN) do
		for _, combat in ipairs({ false, true }) do
			for _, target in ipairs({ false, true }) do
				env._combat, env._target = combat, target
				local driver = Rules.Driver(rule)
				local secureShows = driver == nil or env.SecureCmdOptionParse(driver) == "show"
				check("driver and Lua rule agree for " .. rule, secureShows == Rules.Visible(rule, combat, target), combat, target)
			end
		end
	end

	-- Lua frames: visibility.
	check("always visible", Rules.Visible("always", false, false) and Rules.Visible("always", true, true))
	check("combat", Rules.Visible("combat", true, false) and not Rules.Visible("combat", false, true))
	check("out of combat", Rules.Visible("noCombat", false, false) and not Rules.Visible("noCombat", true, false))
	check("with a target", Rules.Visible("target", false, true) and not Rules.Visible("target", true, false))
	check("mouseover stays shown so the pointer can find it", Rules.Visible("mouseover", false, false))
	check("never", not Rules.Visible("never", true, true))

	-- Opacity: the combat or idle alpha; mouseover is 0 until hovered.
	check("idle alpha out of combat", Rules.Alpha("always", false, false, 0.4, 0.8) == 0.8)
	check("combat alpha in combat", Rules.Alpha("always", true, false, 0.4, 0.8) == 0.4)
	check("mouseover without the pointer is 0", Rules.Alpha("mouseover", false, false, 1, 1) == 0)
	check("mouseover under the pointer", Rules.Alpha("mouseover", true, true, 0.6, 0.9) == 0.6)

	-- Which rules need which events.
	check("combat rules need combat events", Rules.NeedsCombat("combat", 1, 1) and Rules.NeedsCombat("noCombat", 1, 1))
	check("different opacities need combat events", Rules.NeedsCombat("always", 0.5, 1))
	check("always at one opacity needs nothing", not Rules.NeedsCombat("always", 1, 1))
	check("target needs the target event", Rules.NeedsTarget("target") and not Rules.NeedsTarget("combat"))
end

print("layout maths ok")
