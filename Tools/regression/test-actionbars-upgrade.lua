-- test-actionbars-upgrade.lua: released profiles and extra-bars snapshots acquire new per-bar defaults on restore, and store migration 50 gives every saved bar a Buttons per row that keeps each button where it was.
local AB = dofile("Tools/regression/actionbars_env.lua")
local env, K = AB.New({})
AB.Enable(env, K)
K.Options.Write("ActionBars", "extraBarsLayout", "rows")
env.RunTimers(); AB.W.Settle(env)
local saved = AB.CoreEnv.DeepCopy(env.KstyleUIDB)
local settings = saved.profiles.Default.ActionBars
local fields = { "placement", "swipeOpacity", "desaturateCooldown", "rarityBorder", "moverOptions" }
for _, bar in pairs(settings) do
	if type(bar) == "table" then for _, field in ipairs(fields) do bar[field] = nil end end
end
for _, snapshot in pairs(settings.extraBarsPrevious) do
	for _, field in ipairs(fields) do snapshot.settings[field] = nil end
end
local reload, RK, ns = AB.New({ saved = saved })
AB.Enable(reload, RK)
RK.Options.Write("ActionBars", "extraBarsLayout", "off")
reload.RunTimers(); AB.W.Settle(reload)
assert(#reload._errors == 0 and RK.ErrorCount() == 0, AB.Errors(reload))
local restored = RK.Store.Module("ActionBars")
for _, key in ipairs({ "bar4", "bar5" }) do
	for _, field in ipairs(fields) do
		assert(RK.Options.Equal(restored[key][field], ns.defaults[key][field]), key .. ": restore missing " .. field .. " from defaults")
	end
	assert(restored[key].placement ~= ns.defaults[key].placement, "restored tables must not alias defaults")
end
assert(restored.extraBarsApplied == "off", "old extra bars snapshot restores successfully")

-- Migration 50 (the per-bar Buttons per row plan): every button keeps the place the rows-only maths gave it, for
-- Buttons 1 to 12, Rows 1 to 12, both fill orders and all four growths. Before is the rows-only ns.Cell as it
-- stood before Buttons per row; after runs the saved bar through the real ActionBarGrid, BarShape and ns.Cell.
local function BeforeCell(index, count, rows, orientation, growth)
	rows = math.min(count, math.max(1, math.floor(rows)))
	local cols = math.ceil(count / rows)
	local used = math.ceil(count / cols)
	local col, row
	if orientation == "VERTICAL" then
		row, col = (index - 1) % used, math.floor((index - 1) / used)
	else
		col, row = (index - 1) % cols, math.floor((index - 1) / cols)
	end
	if growth == "LEFTDOWN" or growth == "LEFTUP" then col = cols - 1 - col end
	if growth == "RIGHTUP" or growth == "LEFTUP" then row = used - 1 - row end
	return col, row
end
local Layouts, migrate = RK.Setup.Layouts, RK.Store.migrations[50]
local placed = 0
for count = 1, 12 do
	for rows = 1, 12 do
		for _, orientation in ipairs({ "HORIZONTAL", "VERTICAL" }) do
			for _, growth in ipairs({ "RIGHTDOWN", "RIGHTUP", "LEFTDOWN", "LEFTUP" }) do
				local data = { profiles = { P = { ActionBars = { bar3 = { buttons = count, rows = rows, orientation = orientation, growth = growth } } } } }
				migrate(data)
				local cfg = data.profiles.P.ActionBars.bar3
				local _, savedRows, _, _, _, _, _, _, perRow = Layouts.ActionBarGrid(RK.Scale.Aspect(), "actionbars.bar3", cfg, "frames")
				local columns, lines = Layouts.BarShape(count, perRow, savedRows, orientation)
				for i = 1, count do
					local col, row = ns.Cell(i, columns, lines, orientation, growth)
					local wasCol, wasRow = BeforeCell(i, count, rows, orientation, growth)
					assert(col == wasCol and row == wasRow, string.format("%d buttons in %d rows, %s %s: button %d moved from %d,%d to %d,%d", count, rows, orientation, growth, i, wasCol, wasRow, col, row))
					placed = placed + 1
				end
			end
		end
	end
end
assert(placed == 7488, "every button of every shape was compared, got " .. placed)

-- The style default (0) stays 0 on the pet and stance bars; a bar with no saved Rows takes its old default; the
-- consumables bar (two rows of its Buttons) and an extra-bars snapshot upgrade too.
do
	local data = { profiles = { P = { ActionBars = {
		pet = { rows = 0 }, stance = { buttons = 6 }, bar4 = { buttons = 8 }, bar1 = { buttons = 7, rows = "bad" },
		consumables = { buttons = 8 }, extraBarsPrevious = { bar5 = { settings = { buttons = 12, rows = 5 } } },
	} } } }
	migrate(data)
	local bars = data.profiles.P.ActionBars
	assert(bars.pet.perRow == 0 and bars.pet.rows == 0 and bars.stance.perRow == nil and bars.stance.rows == nil, "the HUD style's default stays the default")
	assert(bars.bar4.perRow == nil and bars.bar4.rows == nil, "bar 4 at its default rows keeps the defaults, whose 1 per row draws its old column")
	assert(bars.bar1.perRow == 7 and bars.bar1.rows == nil, "an unreadable Rows resets to the default one row, here 7 per row")
	assert(bars.consumables.perRow == 4 and bars.consumables.rows == nil, "8 consumables at the default 2 rows keep 4 per row")
	local snapshot = bars.extraBarsPrevious.bar5.settings
	assert(snapshot.perRow == 3 and snapshot.rows == 4, "an extra-bars snapshot restores its old shape: " .. snapshot.perRow .. "x" .. snapshot.rows)
	migrate(data)
	assert(bars.consumables.perRow == 4 and bars.consumables.rows == nil and bars.bar4.perRow == nil, "running the upgrade twice changes nothing")
end

-- The consumables bar lays out its Buttons live but reserves twelve slots for Layout Mode and its attached anchor.
-- Before Buttons per row both came from Rows alone: the reserve was ceil(12 / Rows) wide, the live bar
-- ceil(Buttons / Rows) wide. After migration 50 each Buttons from 1 to 12 keeps the live shape it drew and, in both
-- fill orders, the reserve and attached anchor that twelve buttons at the same Rows give. In 18 shapes, such as 7
-- buttons in 7 rows, the old live bar was taller than its reserve; the reserve now holds the live bar instead.
do
	local live = RK.Store.Module("ActionBars").consumables
	local class, compared, overflowed = RK.Scale.Aspect(), 0, 0
	for rows = 1, 12 do
		for _, orientation in ipairs({ "HORIZONTAL", "VERTICAL" }) do
			local anchors = {}
			for count = 12, 1, -1 do
				local data = { profiles = { P = { ActionBars = { consumables = { buttons = count, rows = rows, orientation = orientation } } } } }
				migrate(data)
				local cfg = data.profiles.P.ActionBars.consumables
				live.buttons, live.rows, live.perRow, live.orientation = count, cfg.rows, cfg.perRow, orientation
				local _, size, gap = Layouts.ConsumableGrid(class, "medallions")
				local columns, used = Layouts.BarShape(count, cfg.perRow, cfg.rows, orientation)
				local wasColumns = math.ceil(count / math.min(count, rows))
				assert(columns == wasColumns and used == math.ceil(count / wasColumns), string.format("%d consumables in %d rows %s: the live bar changed shape", count, rows, orientation))
				local wasWide = math.ceil(12 / rows)
				local wasTall = math.ceil(12 / wasWide)
				local width, height = Layouts.ConsumableFootprint(class, "medallions")
				local over = used > wasTall
				local wantTall = over and used or wasTall
				assert(width == wasWide * (size + gap) - gap and height == wantTall * (size + gap) - gap,
					string.format("%d consumables in %d rows %s: the reserve changed size", count, rows, orientation))
				for _, style in ipairs({ "medallions", "frames" }) do
					local at = Layouts.Attached("DPS", "consumables.bar", class, style)
					anchors[style] = anchors[style] or at
					assert(over or at.x == anchors[style].x and at.y == anchors[style].y, string.format("%d consumables in %d rows %s: the %s anchor moved", count, rows, orientation, style))
				end
				compared, overflowed = compared + 1, overflowed + (over and 1 or 0)
			end
		end
	end
	assert(compared == 288 and overflowed == 36, "every consumables shape was compared, got " .. compared .. " with " .. overflowed .. " taller than the old reserve")
	live.buttons, live.rows, live.perRow, live.orientation = 12, 2, 6, "HORIZONTAL"
end

-- A profile saved before Buttons per row upgrades on reload and on import.
do
	local old = AB.CoreEnv.DeepCopy(reload.KstyleUIDB)
	old.version = 49
	local bars = old.profiles.Default.ActionBars
	for _, bar in pairs(bars) do if type(bar) == "table" then bar.perRow = nil end end
	bars.bar3.buttons, bars.bar3.rows = 12, 5
	local loaded, LK, LN = AB.New({ saved = old })
	AB.Enable(loaded, LK)
	assert(#loaded._errors == 0 and LK.ErrorCount() == 0, AB.Errors(loaded))
	assert(LN.Config("bar3").perRow == 3 and LN.Config("bar3").rows == 4, "a reload upgrades 12 buttons in 5 rows to 3 per row in 4 rows")
	assert(LN.Config("bar1").perRow == 12 and LN.Config("pet").perRow == 0, "default bars keep their default shape")
	local live = LK.Store.Module("ActionBars")
	live.bar3.perRow, live.bar3.rows = nil, 6
	LK.Store.DB_VERSION = 49
	local text = assert(LK.Store.Export())
	LK.Store.DB_VERSION = 50
	assert(LK.Store.Import(text, "Imported"))
	local imported = LK.Store.Module("ActionBars").bar3
	assert(imported.perRow == 2 and imported.rows == 6, "an imported older profile upgrades too: " .. tostring(imported.perRow) .. "x" .. tostring(imported.rows))
end
-- An existing 10-button stance bar, Down columns first in Rows 5, with five forms known: the upgrade keeps Rows 5,
-- and Down columns first fills the chosen rows, so all five forms stand in the first column of a bar two columns wide.
do
	local old = AB.CoreEnv.DeepCopy(reload.KstyleUIDB)
	old.version = 49
	local bars = old.profiles.Default.ActionBars
	for _, bar in pairs(bars) do if type(bar) == "table" then bar.perRow = nil end end
	bars.stance.buttons, bars.stance.rows, bars.stance.orientation, bars.stance.growth, bars.stance.spacing = 10, 5, "VERTICAL", "RIGHTDOWN", 3
	local loaded, LK, LN = AB.New({ saved = old, setup = function(e)
		e._game.forms = {}
		for i = 1, 5 do e._game.forms[i] = { texture = 132349, spellID = 2457 + i } end
	end })
	AB.Enable(loaded, LK)
	LK.Options.Write("HudStyle", "style", "frames")
	AB.W.Settle(loaded)
	assert(#loaded._errors == 0 and LK.ErrorCount() == 0, AB.Errors(loaded))
	local cfg = LN.Config("stance")
	assert(cfg.rows == 5 and cfg.perRow == 2, "the upgrade keeps Rows 5 and gives 2 per row, got " .. tostring(cfg.perRow) .. "x" .. tostring(cfg.rows))
	local buttons, pitch = LN.bars.stance.buttons, cfg.size + 3
	local function near(a, b) return math.abs(a - b) < 0.01 end
	for i = 2, 5 do
		assert(near(buttons[i]:GetLeft(), buttons[1]:GetLeft()) and near(buttons[1]:GetTop() - buttons[i]:GetTop(), (i - 1) * pitch), "form " .. i .. " stands in the first column, row " .. i)
	end
	assert(near(LN.bars.stance.holder:GetWidth(), pitch + cfg.size), "the bar keeps two columns of width")
end

print("actionbars upgrade ok: v0.2.7 profile and snapshots load and apply without errors; migration 50 keeps " .. placed .. " button places")
