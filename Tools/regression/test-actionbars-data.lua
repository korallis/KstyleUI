-- test-actionbars-data.lua: the action bars' pure parts: bar table, grid maths, slots, paging drivers, key text and the page snippet.
local Load = dofile("Tools/regression/load_files.lua")

local env = setmetatable({}, { __index = _G })
Load({ "KstyleUI_ActionBars/Data.lua" }, env)
local ns = env._addons.KstyleUI_ActionBars

-- The bars: six action bars on Blizzard's pages and binding names, then the pet and stance bars.
do
	local keys, pages, bindings = {}, {}, {}
	for i, def in ipairs(ns.BARS) do
		keys[i], pages[i], bindings[i] = def.key, def.page, def.binding
		assert(ns.BAR[def.key] == def, "BAR indexes every bar by key")
		assert(def.element == "actionbars." .. def.key, "element keys follow element-keys.md")
	end
	assert(table.concat(keys, " ") == "bar1 bar2 bar3 bar4 bar5 bar6 pet stance")
	assert(pages[1] == 1 and pages[2] == 6 and pages[3] == 5 and pages[4] == 3 and pages[5] == 4 and pages[6] == 13,
		"bars 2 to 6 show Blizzard's bottom left, bottom right, right, left and fifth bars")
	assert(bindings[1] == "ACTIONBUTTON" and bindings[2] == "MULTIACTIONBAR1BUTTON" and bindings[6] == "MULTIACTIONBAR5BUTTON")
	assert(bindings[7] == "BONUSACTIONBUTTON" and bindings[8] == "SHAPESHIFTBUTTON")
	assert(ns.BAR.bar1.paged and not ns.BAR.bar2.paged, "only bar 1 pages by default")
	assert(ns.BAR.pet.max == 10 and ns.BAR.stance.max == 10 and ns.BAR.bar1.max == 12)
end

-- GridSize: a shape of columns and rows measures its buttons and the gaps between them.
do
	local w, h = ns.GridSize(12, 1, 34, 3)
	assert(w == 441 and h == 34, "one row of 12 is the 441 by 34 footprint")
	w, h = ns.GridSize(1, 12, 34, 3)
	assert(w == 34 and h == 441, "twelve rows make the 34 by 441 column")
	w, h = ns.GridSize(10, 1, 30, 3)
	assert(w == 327 and h == 30, "the pet bar's 327 by 30 footprint")
	w, h = ns.GridSize(5, 3, 10, 2)
	assert(w == 58 and h == 34, "five per row in three rows")
end

-- Cell: the fill order and the growth direction place each button in its shape.
do
	local function cells(count, columns, rows, orientation, growth)
		local out = {}
		for i = 1, count do
			local col, row = ns.Cell(i, columns, rows, orientation, growth)
			out[i] = col .. "," .. row
		end
		return table.concat(out, " ")
	end
	assert(cells(6, 3, 2, "HORIZONTAL", "RIGHTDOWN") == "0,0 1,0 2,0 0,1 1,1 2,1", "across, then down")
	assert(cells(6, 3, 2, "VERTICAL", "RIGHTDOWN") == "0,0 0,1 1,0 1,1 2,0 2,1", "down the columns first")
	assert(cells(6, 3, 2, "HORIZONTAL", "LEFTDOWN") == "2,0 1,0 0,0 2,1 1,1 0,1", "growing left mirrors the columns")
	assert(cells(6, 3, 2, "HORIZONTAL", "RIGHTUP") == "0,1 1,1 2,1 0,0 1,0 2,0", "growing up mirrors the rows")
	assert(cells(3, 3, 1, "HORIZONTAL", "LEFTUP") == "2,0 1,0 0,0")
	assert(cells(3, 3, 1, "BOGUS", "BOGUS") == "0,0 1,0 2,0", "unknown values fall back to across and right-down")
	assert(cells(12, 5, 3, "HORIZONTAL", "RIGHTDOWN") == "0,0 1,0 2,0 3,0 4,0 0,1 1,1 2,1 3,1 4,1 0,2 1,2", "five per row leaves a short last row of two")
end

-- BarShape (Core/Setup/Layouts.lua, the plan for per-bar Buttons per row): Along rows first, every Buttons per row
-- stop from 1 to the button count is its own shape; Down columns first, every Rows stop is. The shapes are typed
-- from the rule: columns = per row, rows = ceil(buttons / columns), or rows, then columns = ceil(buttons / rows).
do
	local K = select(2, dofile("Tools/regression/core_env.lua").New())
	local BarShape = K.Setup.Layouts.BarShape
	local ALONG = {
		[12] = { "1x12", "2x6", "3x4", "4x3", "5x3", "6x2", "7x2", "8x2", "9x2", "10x2", "11x2", "12x1" },
		[10] = { "1x10", "2x5", "3x4", "4x3", "5x2", "6x2", "7x2", "8x2", "9x2", "10x1" },
	}
	local DOWN = {
		[12] = { "12x1", "6x2", "4x3", "3x4", "3x5", "2x6", "2x7", "2x8", "2x9", "2x10", "2x11", "1x12" },
		[10] = { "10x1", "5x2", "4x3", "3x4", "2x5", "2x6", "2x7", "2x8", "2x9", "1x10" },
	}
	for count, shapes in pairs(ALONG) do
		for stop = 1, count do
			local columns, rows = BarShape(count, stop, 99, "HORIZONTAL")
			assert(columns .. "x" .. rows == shapes[stop], count .. " buttons at " .. stop .. " per row: " .. columns .. "x" .. rows)
			local downColumns, downRows = BarShape(count, 99, stop, "VERTICAL")
			assert(downColumns .. "x" .. downRows == DOWN[count][stop], count .. " buttons in " .. stop .. " rows: " .. downColumns .. "x" .. downRows)
		end
	end
	local columns, rows = BarShape(8, 12, 1, "HORIZONTAL")
	assert(columns == 8 and rows == 1, "a saved Buttons per row above the button count draws as the button count")
	columns, rows = BarShape(0, 0, 0, "VERTICAL")
	assert(columns == 1 and rows == 1, "an empty bar keeps one button's footprint")
end

-- Slot: a button's action slot on a page.
do
	assert(ns.Slot(1, 1) == 1 and ns.Slot(12, 1) == 12)
	assert(ns.Slot(1, 6) == 61 and ns.Slot(12, 13) == 156 and ns.Slot(3, 7) == 75)
end

-- PagingDriver: possess, vehicle and override first, then Blizzard's page keys, then stance, form and stealth bonus bars.
do
	local all = { pageForms = true, pageStealth = true, pagePossess = true, pageKeys = true, paging = "" }
	local warrior = ns.PagingDriver(all, "WARRIOR")
	assert(warrior:find("^%[vehicleui%] vehicle; %[overridebar%] override; %[possessbar%] possess; %[shapeshift%] shapeshift; %[bonusbar:5%] possess; "),
		"special bars come first: " .. warrior)
	assert(warrior:find("%[bar:2%] 2; %[bar:3%] 3; %[bar:4%] 4; %[bar:5%] 5; %[bar:6%] 6; ", 1), "then the page keys")
	assert(warrior:find("%[bonusbar:1%] 7; %[bonusbar:2%] 8; %[bonusbar:3%] 9; %[bonusbar:4%] 10; 1$"), "stances page to 7 to 10: " .. warrior)
	local rogue = ns.PagingDriver({ pageForms = true, pageStealth = false, pagePossess = false, pageKeys = false, paging = "" }, "ROGUE")
	assert(rogue == "1", "a rogue with stealth paging off stays on page 1: " .. rogue)
	rogue = ns.PagingDriver({ pageForms = false, pageStealth = true, pagePossess = false, pageKeys = false, paging = "" }, "ROGUE")
	assert(rogue == "[bonusbar:1] 7; [bonusbar:2] 8; 1", "a rogue's bonus bars are stealth: " .. rogue)
	local druid = ns.PagingDriver({ pageForms = true, pageStealth = false, pagePossess = false, pageKeys = false, paging = "" }, "DRUID")
	assert(druid == "[bonusbar:1] 7; [bonusbar:3] 9; [bonusbar:4] 10; 1", "a druid's prowl bar follows the stealth rule: " .. druid)
	druid = ns.PagingDriver({ pageForms = false, pageStealth = true, pagePossess = false, pageKeys = false, paging = "" }, "DRUID")
	assert(druid == "[bonusbar:2] 8; 1")
	assert(ns.PagingDriver({ pageForms = true, pageStealth = true, pagePossess = true, pageKeys = true, paging = "  [mod:alt] 2; 1 " }, "MAGE") == "[mod:alt] 2; 1",
		"custom conditions replace the rules")
	assert(ns.PagingDriver({}, nil) == "1", "missing settings page nothing")
end

-- ShortKey (the kit's, Core/Widgets/Text.lua, shared with the Cooldowns keybinds): compact keybind text from the raw key, with the binding text as the fallback.
do
	local core = setmetatable({ _addons = { KstyleUI = { Widgets = {}, L = {} } } }, { __index = _G })
	Load({ "Core/Widgets/Text.lua" }, core)
	local ShortKey = core._addons.KstyleUI.Widgets.ShortKey
	local cases = {
		["1"] = "1", Q = "Q", ["SHIFT-1"] = "S1", ["CTRL-Q"] = "CQ", ["ALT-CTRL-SHIFT-F"] = "ACSF",
		BUTTON4 = "M4", ["SHIFT-BUTTON5"] = "SM5", MIDDLEBUTTON = "M3", BUTTON3 = "M3",
		MOUSEWHEELUP = "WU", MOUSEWHEELDOWN = "WD", NUMPAD5 = "N5", NUMPADPLUS = "N+", NUMPADMINUS = "N-",
		NUMPADMULTIPLY = "N*", NUMPADDIVIDE = "N/", NUMPADDECIMAL = "N.", SPACE = "Sp", PAGEUP = "PU",
		PAGEDOWN = "PD", BACKSPACE = "Bs", INSERT = "Ins", DELETE = "Del", HOME = "Hm", ["END"] = "End",
		CAPSLOCK = "Cap", TAB = "Tab", ENTER = "Ent", ESCAPE = "Esc", UP = "Up", DOWN = "Dn", LEFT = "Lt",
		RIGHT = "Rt", F12 = "F12", ["META-K"] = "CmK",
	}
	for key, want in pairs(cases) do
		local got = ShortKey(key)
		assert(got == want, "ShortKey(" .. key .. ") = " .. tostring(got) .. ", want " .. want)
	end
	assert(ShortKey("PADLSHOULDER", function(key)
		return "LB:" .. key
	end) == "LB:PADLSHOULDER", "an unknown key uses the fallback")
	assert(ShortKey("PADLSHOULDER") == "PADLSHOULDER", "and without one, the key itself")
	assert(ShortKey(nil) == "" and ShortKey("") == "", "no key, no text")
end

-- FontFlags: the outline setting becomes SetFont flags.
do
	assert(ns.FontFlags("NONE") == "" and ns.FontFlags("OUTLINE") == "OUTLINE" and ns.FontFlags("THICK") == "THICKOUTLINE")
	assert(ns.FontFlags("BOGUS") == "", "an unknown outline draws none")
end

-- PAGE_SNIPPET: the secure page handler, run here against a fake restricted environment.
do
	local function run(newstate, game)
		local attrs = {}
		local handle = {
			SetAttribute = function(_, name, value)
				attrs[name] = value
			end,
		}
		local fake = {
			tonumber = tonumber,
			HasVehicleActionBar = function() return game.vehicle ~= nil end,
			GetVehicleBarIndex = function() return game.vehicle end,
			HasOverrideActionBar = function() return game.override ~= nil end,
			GetOverrideBarIndex = function() return game.override end,
			HasTempShapeshiftActionBar = function() return game.temp ~= nil end,
			GetTempShapeshiftBarIndex = function() return game.temp end,
			HasBonusActionBar = function() return game.bonus ~= nil end,
			GetBonusBarIndex = function() return game.bonus end,
			GetActionBarPage = function() return game.page or 1 end,
		}
		local chunk = assert(loadstring("local self, stateid, newstate = ...\n" .. ns.PAGE_SNIPPET))
		setfenv(chunk, fake)
		chunk(handle, "page", newstate)
		return attrs.actionpage
	end
	assert(run("7", {}) == 7, "a numeric state is the page")
	assert(run("1", { bonus = 11 }) == 1)
	assert(run("vehicle", { vehicle = 16, override = 18 }) == 16, "a vehicle wins")
	assert(run("override", { override = 18, bonus = 11 }) == 18, "then an override bar")
	assert(run("shapeshift", { temp = 17 }) == 17, "then a temporary shapeshift bar")
	assert(run("possess", { bonus = 11 }) == 11, "then the bonus bar a possess gives")
	assert(run("possess", { page = 2 }) == 2, "and Blizzard's own page when nothing else applies")
	assert(run("bogus", {}) == 1 and run(nil, {}) == 1, "anything else is page 1")
	assert(run("0", {}) == 1, "a page below 1 is page 1")
end

print("action bars data ok")
