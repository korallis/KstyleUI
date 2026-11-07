-- test-layout-options.lua: the real settings window against the real Layout: Layout's page and element rows on Elements, Layout.Set through the rows, and the Layout Mode button.
local O = dofile("Tools/regression/options_env.lua")
local W = O.W

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local env, K, ns = O.New({
	before = function(env, K)
		local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
		frame:SetSize(220, 46)
		K.Layout.Register(frame, "unitframes.player", { anchor = "BOTTOM", x = -200, y = 260 }, {
			label = "Player", resizable = true, scalable = true, minWidth = 100, maxWidth = 400, minHeight = 20, maxHeight = 100,
		})
		local sample = env.CreateFrame("Frame", nil, K.Scale.Root())
		sample:SetSize(120, 12)
		K.Layout.Register(sample, "test.sample", { anchor = "CENTER" }, {
			label = "Sample", resizable = true, minWidth = 40, maxWidth = 300, minHeight = 4, maxHeight = 60, fields = { "width", "height" },
		})
		local switched = env.CreateFrame("Frame", nil, K.Scale.Root())
		switched:SetSize(100, 20)
		K.Layout.Register(switched, "test.switched", { anchor = "TOP", y = -40 }, { label = "Switched off" })
		K.Layout.SetLive("test.switched", false)
		K.Modules.Register(O.W.CoreEnv.Module("Bags"))
		K.Modules.Enable("Bags")
		local bag = env.CreateFrame("Frame", nil, K.Scale.Root())
		bag:SetSize(100, 100)
		K.Layout.Register(bag, "bags.bag", { anchor = "BOTTOMRIGHT", x = -20, y = 20 }, { label = "Bag", module = "Bags" })
		K.Widgets.DialogHost()
	end,
})

assert(K.Options.Open("Elements"))
W.Settle(env)
local items = ns.Window.State().items
assert(items[1].kind == "header" and items[1].label == "Layout Mode", "Layout's own settings lead the Elements page")

local rows = {}
for _, item in ipairs(items) do
	if item.label and item.set and not rows[item.label] then
		rows[item.label] = item
	end
end
for _, label in ipairs({ "Shown", "Anchor", "X offset", "Y offset", "Width", "Height", "Scale", "Opacity in combat", "Opacity out of combat", "Strata" }) do
	assert(rows[label], "the element has a " .. label .. " row")
end

rows.Width.set(300)
rows.Shown.set("combat")
rows.Scale.set(1.2)
rows.Strata.set("HIGH")
local s = K.Layout.Get("unitframes.player")
assert(s.width == 300 and s.shown == "combat" and near(s.scale, 1.2) and s.strata == "HIGH", "the rows write through Layout.Set")
assert(K.Store.Layout()["unitframes.player"].width == 300, "and Layout saves them")

local registered = false
for _, element in ipairs(K.Layout.Elements()) do
	registered = registered or element.key == "Options.Window"
end
assert(registered, "the settings window registers itself with Layout")

-- An element can say which rows apply to it, and one its module switched off has no rows.
local function RowsOf(key)
	local out = {}
	for _, item in ipairs(ns.Window.State().items) do
		if item.element == key and item.set and item.label then
			out[#out + 1] = item.label
		end
	end
	return table.concat(out, ",")
end
assert(RowsOf("test.sample") == "Width,Height", "a proxy element lists only the rows that apply to it, got " .. RowsOf("test.sample"))
assert(RowsOf("test.switched") == "", "an element its module switched off has no rows")
K.Layout.SetLive("test.switched", true)
K.Options.Open("Profiles")
K.Options.Open("Elements")
W.Settle(env)
assert(RowsOf("test.switched") ~= "", "switched back on, it has rows again")

-- Resetting a module's page resets its elements, live or not, so they come back at their defaults.
assert(K.Layout.Set("bags.bag", "x", -250))
K.Layout.SetLive("bags.bag", false)
local bagsPage = ns.Pages.Find(ns.Pages.List(), "Bags")
assert(bagsPage and bagsPage.reset, "the Bags page can be reset")
bagsPage.reset(bagsPage)
assert(K.Layout.Get("bags.bag").x == -20, "the reset reaches an element its module switched off, got " .. tostring(K.Layout.Get("bags.bag").x))
K.Layout.SetLive("bags.bag", true)

-- Core windows keep a way back: no Shown row and an opacity floor, as the settings window has.
local dialog, setup = RowsOf("Widgets.Dialog"), RowsOf("setup.window")
assert(dialog ~= "" and not dialog:find("Shown", 1, true), "the dialog host cannot be hidden from the Elements page: " .. dialog)
for _, item in ipairs(ns.Window.State().items) do
	if item.element == "Widgets.Dialog" and item.label == "Opacity out of combat" then
		assert(item.min > 0, "the dialog host keeps an opacity floor")
	end
end
assert(not setup:find("Shown", 1, true), "the setup window cannot be hidden either")

local window = ns.Window.Frame()
W.Click(ns.Window.Parts().layoutButton)
W.Settle(env)
assert(K.Layout.IsActive(), "the Layout Mode button opens Layout Mode")
assert(not window:IsShown(), "and closes the settings window")
assert(K.Layout.Mode.Plate("unitframes.player"):IsShown(), "the element has a plate")
K.Layout.Exit(true)
assert(#env._errors == 0, "errors: " .. table.concat(env._errors, "\n"))

print("layout options ok")
