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

local window = ns.Window.Frame()
W.Click(ns.Window.Parts().layoutButton)
W.Settle(env)
assert(K.Layout.IsActive(), "the Layout Mode button opens Layout Mode")
assert(not window:IsShown(), "and closes the settings window")
assert(K.Layout.Mode.Plate("unitframes.player"):IsShown(), "the element has a plate")
K.Layout.Exit(true)
assert(#env._errors == 0, "errors: " .. table.concat(env._errors, "\n"))

print("layout options ok")
