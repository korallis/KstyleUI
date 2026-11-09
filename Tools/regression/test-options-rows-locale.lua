-- test-options-rows-locale.lua: a translated settings label wider than its column stacks above its control instead of
-- truncating, a long selected dropdown value widens its control up to the row, a short label keeps its place beside
-- the control, and a label or rail entry too long even then shows its full text on hover (round 5: Astra #3, U1).
local Scene = dofile("Tools/render/scene.lua")
local O = dofile("Tools/regression/options_env.lua")
local D = dofile("Tools/regression/databars_env.lua")
local W = O.W
local Module = W.CoreEnv.Module

local LONG = "Namensplaketten aktivieren"
local LONGER = "Réduire les barres d'info lointaines"
local HUGE = "Schwächungszauber, die Ihr bannen könnt, und dazu noch eine Erklärung, die niemals in eine Zeile passt"
local VALUE = "Schwächungszauber, die Ihr bannen könnt"
local SHORT = "Grid size"
local LONGER_SECTION = "Eintreffende Heilungen und Absorptionen"
local RAIL_MODULE = "Cooldowns"
local RAIL_LABEL = "Abklingzeiten, Zauberbereitschaft und sonstige Anzeigen der verbleibenden Wartezeit auf jede Fähigkeit"

local env, K, ns = O.New({
	before = function(_, K)
		K.Modules.Register(Module("Nameplates", { defaults = { shrink = true, dispel = "mine", size = 20, big = true, huge = true, heal = 3 } }))
		K.Options.Register("Nameplates", {
			{ type = "header", label = "Namensplaketten" },
			{ type = "toggle", key = "shrink", label = LONG, help = "Zeigt KstyleUI-Namensplaketten." },
			{ type = "toggle", key = "big", label = LONGER, help = "Les barres lointaines sont plus petites." },
			{ type = "dropdown", key = "dispel", label = "Hervorheben", help = "Welche Schwächungszauber leuchten.", options = {
				{ value = "mine", label = VALUE }, { value = "none", label = "Keine" },
			} },
			{ type = "slider", key = "size", label = SHORT, help = "Grid size in units.", min = 10, max = 40, step = 1 },
			{ type = "toggle", key = "huge", label = HUGE, help = "Ein sehr langer Text." },
			{ type = "header", label = LONGER_SECTION },
			{ type = "slider", key = "heal", label = "Heilung", help = "Eintreffende Heilung.", min = 0, max = 10, step = 1 },
		})
		rawset(K.L, "Cooldowns", RAIL_LABEL)
		K.Modules.Register(Module(RAIL_MODULE, { defaults = { on = true } }))
		K.Options.Register(RAIL_MODULE, {
			{ type = "header", label = "Rail" },
			{ type = "toggle", key = "on", label = "On", help = "A row." },
		})
	end,
})
env._textWidth = D.TextWidth

local function settle()
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

local function rect(object)
	local x, y, w, h = Scene.Rect(env, object)
	assert(x, "the rect of " .. tostring(object) .. " resolves")
	return { left = x, top = y, right = x + w, bottom = y + h }
end

local EPS = 0.01

-- The window takes its size from the Layout service, as a player's drag or the setup does.
local function resize(width, height)
	assert(K.Layout.Set("Options.Window", "width", width))
	assert(K.Layout.Set("Options.Window", "height", height))
	settle()
	local win = ns.Window.Frame()
	assert(win:GetWidth() == width, "the window is " .. width .. " wide, got " .. tostring(win:GetWidth()))
end

local function rowFor(label)
	for _, row in ipairs(ns.Window.Parts().content.rows) do
		if row:IsShown() and row.item and row.item.label == label then
			return row
		end
	end
	error("no row on screen labelled " .. label)
end

local function describe(r)
	return string.format("(%.1f, %.1f to %.1f, %.1f)", r.left, r.top, r.right, r.bottom)
end

K.Options.Open("Nameplates")
settle()
resize(880, 520)
Scene.Build(env)

-- A label wider than the column beside its control stacks above the control, whole.
for _, label in ipairs({ LONG, LONGER }) do
	local row = rowFor(label)
	local control = row.controls.toggle
	assert(control and control:IsShown(), label .. ": the toggle shows")
	assert(row.label:IsTruncated() == false, label .. ": the label is not truncated at the window's minimum width")
	local text, box = rect(row.label), rect(row)
	local ctrl = rect(control)
	assert(text.bottom <= ctrl.top + EPS, label .. ": the label " .. describe(text) .. " sits above its control " .. describe(ctrl))
	assert(text.left >= box.left and text.right <= box.right + EPS and ctrl.right <= box.right + EPS and ctrl.bottom <= box.bottom + EPS, label .. ": label and control stay inside the row " .. describe(box))
	assert(text.right - text.left >= D.TextWidth(label, (row.label:GetFont()), (select(2, row.label:GetFont()))) - EPS, label .. ": the label gets its full measure")
	local help = rect(row.help)
	assert(help.top >= ctrl.bottom - EPS and help.top >= text.bottom - EPS, label .. ": the help sits under the label and the control")
end

-- A short label keeps its place beside the control, on the control's band.
do
	local row = rowFor(SHORT)
	local text, ctrl = rect(row.label), rect(row.controls.slider)
	assert(text.top < ctrl.bottom and text.bottom > ctrl.top, SHORT .. ": a label that fits stays beside its control " .. describe(text) .. " / " .. describe(ctrl))
end

-- A long selected value widens the dropdown past the control width, up to the row, and the value is whole.
do
	local row = rowFor("Hervorheben")
	local dd = row.controls.dropdown
	assert(dd and dd:IsShown(), "the dropdown shows")
	assert(dd:GetValue() == "mine", "the long value is selected")
	local box, ctrl = rect(row), rect(dd)
	assert(ctrl.right - ctrl.left > ns.Rows.CONTROL_WIDTH + EPS, string.format("the dropdown grows for its value: %.1f wide against the %d control width", ctrl.right - ctrl.left, ns.Rows.CONTROL_WIDTH))
	assert(ctrl.left >= box.left - EPS and ctrl.right <= box.right + EPS, "the dropdown stays inside its row " .. describe(ctrl) .. " / " .. describe(box))
	assert(dd.text:IsTruncated() == false, "the selected value reads whole")
	local text = rect(row.label)
	assert(text.right <= ctrl.left + EPS or text.bottom <= ctrl.top + EPS, "the label clears a widened dropdown " .. describe(text) .. " / " .. describe(ctrl))
	assert(row.label:IsTruncated() == false, "the label beside a widened dropdown reads whole")
end

-- A label too long even for the whole row truncates and shows its full text on hover; leaving hides it.
do
	local row = rowFor(HUGE)
	assert(row.label:IsTruncated() == true, "the huge label truncates even on its own line")
	W.Enter(row)
	local tip = K.Widgets.Tooltip()
	assert(tip:IsShown() and tip:IsOwned(row), "hovering the row opens the tooltip")
	assert(tip.used[1] and tip.used[1].left:GetText() == HUGE, "the tooltip reads the full label, got " .. tostring(tip.used[1] and tip.used[1].left:GetText()))
	W.Leave(row)
	W.Settle(env)
	assert(tip:IsShown() == false, "leaving the row hides the tooltip")
	local short = rowFor(SHORT)
	W.Enter(short)
	assert(not tip:IsOwned(short), "a label that reads whole opens no tooltip")
	W.Leave(short)
	W.Settle(env)
end

-- A rail section label wider than the rail wraps onto a second line, in a taller row, and reads whole.
do
	local rail = ns.Window.Parts().rail
	local section, short
	for _, row in ipairs(rail.rows) do
		if row:IsShown() and row.entry and row.entry.section then
			if row.entry.label == "Namensplaketten" then
				short = row
			end
		end
	end
	assert(short, "the short section sits in the rail")
	K.Options.Open("Nameplates")
	settle()
	for _, row in ipairs(rail.rows) do
		if row:IsShown() and row.entry and row.entry.section and row.entry.label == LONGER_SECTION then
			section = row
		end
	end
	assert(section, "the long section sits in the rail")
	assert(section.label:IsTruncated() == false, "a long section label is not truncated")
	assert(section:GetHeight() > short:GetHeight(), string.format("the long section's row is taller than a one-line section's: %.1f against %.1f", section:GetHeight(), short:GetHeight()))
	local wrap = W.LastCall(section.label, "SetWordWrap")
	assert(wrap and wrap[1] == true, "the long section label wraps")
	local text, box = rect(section.label), rect(section)
	assert(text.bottom <= box.bottom + EPS and text.top >= box.top - EPS, "the wrapped label stays inside its row " .. describe(text) .. " / " .. describe(box))
	W.Enter(section)
	assert(not K.Widgets.Tooltip():IsOwned(section), "a wrapped section label needs no tooltip")
	W.Leave(section)
	W.Settle(env)
end

-- A rail entry too long for the rail even on two lines shows its full label on hover.
do
	local target = ns.Pages.ModuleLabel(RAIL_MODULE)
	assert(target == RAIL_LABEL, "the rail reads the translated page name")
	local hit
	for _, row in ipairs(ns.Window.Parts().rail.rows) do
		if row:IsShown() and row.entry and row.entry.label == target then
			hit = row
		end
	end
	assert(hit, "the long page sits in the rail")
	assert(hit.label:IsTruncated() == true, "the rail label truncates")
	W.Enter(hit)
	local tip = K.Widgets.Tooltip()
	assert(tip:IsShown() and tip:IsOwned(hit) and tip.used[1].left:GetText() == target, "hovering the rail row shows the full page name")
	W.Leave(hit)
	W.Settle(env)
	assert(tip:IsShown() == false, "leaving the rail row hides the tooltip")
	local general
	for _, row in ipairs(ns.Window.Parts().rail.rows) do
		if row:IsShown() and row.entry and row.entry.id == "General" then
			general = row
		end
	end
	assert(general, "General is in the rail")
	W.Enter(general)
	assert(not tip:IsOwned(general), "a rail label that fits opens no tooltip")
	W.Leave(general)
	W.Settle(env)
end

assert(#env._errors == 0, "errors: " .. table.concat(env._errors, "\n"))
print("options rows locale ok")
