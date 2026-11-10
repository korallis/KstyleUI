-- test-card-material-options.lua: the registered material dropdown, saved-value validation and immediate setting/profile repaint.
local O = dofile("Tools/regression/options_env.lua")
local W = O.W
local values = { "Glass", "Flat", "Slate", "ForgedTicks", "ForgedBrackets" }
local labels = { "Glass", "Flat", "Slate", "Forged iron, gilt ticks", "Forged iron, brackets" }

do
	local _, K = W.New({ boot = false })
	assert(K.Store.Defaults("Widgets").cardMaterial == "ForgedBrackets", "the owner's bracket choice is the registered default")
	assert(K.Widgets.Setting("cardMaterial") == "ForgedBrackets", "the default is available before saved data loads")
	assert(K.Widgets.Setting("panelOpacity") == 0.75, "the existing opacity default is preserved")
	local saved = {
		version = K.Store.DB_VERSION,
		profiles = {
			Default = { Widgets = { panelOpacity = 0.6 } },
			OriginalGlass = { Widgets = { cardMaterial = "Glass" } },
		},
		characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {},
	}
	local savedEnv, savedK = W.New({ saved = saved })
	assert(savedK.Widgets.Setting("cardMaterial") == "ForgedBrackets", "an existing unselected profile inherits the new default")
	assert(savedK.Widgets.Setting("panelOpacity") == 0.6, "an existing opacity override is preserved")
	assert(savedK.Store.SetProfile("OriginalGlass"))
	assert(savedK.Widgets.Setting("cardMaterial") == "Glass", "an explicit saved Glass choice is preserved")
	assert(savedK.Store.SetProfile("Default"))
	assert(savedK.Widgets.Setting("cardMaterial") == "ForgedBrackets", "switching back restores the inherited default")
	W.CoreEnv.Logout(savedEnv)
	assert(savedEnv.KstyleUIDB.profiles.Default.Widgets.cardMaterial == nil, "the inherited default is not saved as an explicit choice")
	assert(savedEnv.KstyleUIDB.profiles.OriginalGlass.Widgets.cardMaterial == "Glass", "Glass remains an explicit choice after saving")
	local reloadedEnv, reloadedK = W.New({ saved = savedEnv.KstyleUIDB })
	assert(reloadedK.Widgets.Setting("cardMaterial") == "ForgedBrackets", "the inherited default survives reloading saved data")
	assert(reloadedK.Store.SetProfile("OriginalGlass"))
	assert(reloadedK.Widgets.Setting("cardMaterial") == "Glass", "the explicit Glass choice survives reloading saved data")
	assert(#savedEnv._errors == 0 and #reloadedEnv._errors == 0)
end

local env, K, ns = O.New({ before = function(_, core) core.Store.Account().setupSeen = true end })
local schema = K.Options.Get("Widgets")
assert(schema == K.Widgets.schema, "Options uses the real widget schema")
local material, index = O.Find(schema, function(row) return row.key == "cardMaterial" end)
assert(material and material == K.Options.Row("Widgets", "cardMaterial"))
assert(material.type == "dropdown" and material.label == K.L["Material"])
assert(schema[index - 1].type == "header" and schema[index - 1].label == K.L["Card material"])
assert(schema[index + 1].type == "header", "the material dropdown has its own isolated section")
assert(#material.options == #values, "the dropdown offers exactly the five approved materials")
for i, value in ipairs(values) do
	assert(material.options[i].value == value and material.options[i].label == K.L[labels[i]])
end

local settings = K.Store.Module("Widgets")
assert(settings.cardMaterial == "ForgedBrackets", "a new profile starts on the forged default")
for _, value in ipairs(values) do
	settings.cardMaterial = value
	assert(K.Widgets.Setting("cardMaterial") == value, "each approved stored value validates")
end
for _, invalid in ipairs({ "", "glass", "missing", 42, false, true, {} }) do
	settings.cardMaterial = invalid
	assert(K.Widgets.Setting("cardMaterial") == "ForgedBrackets", "invalid saved values fall back to the selected default")
end
settings.cardMaterial = env.Secret("Slate")
assert(K.Widgets.Setting("cardMaterial") == "ForgedBrackets", "a secret saved value falls back without inspection")
settings.cardMaterial = nil
assert(K.Widgets.Setting("cardMaterial") == "ForgedBrackets", "profiles with no material inherit the new default")
local issecretvalue = env.issecretvalue
env.issecretvalue = nil
assert(K.Widgets.Setting("cardMaterial") == "ForgedBrackets", "the setting works when secret detection is unavailable")
env.issecretvalue = issecretvalue
settings.cardMaterial = K.Widgets.defaults.cardMaterial

local panel = K.Widgets.Panel(K.Scale.Root(), { width = 320, height = 200, title = "Material" })
local chrome = panel.chrome
local function painted(value)
	local spec = K.Tokens.Material(value)
	assert(K.Widgets.Setting("cardMaterial") == value)
	local r, g, b, a = K.Tokens.Color(spec.fill or "surface")
	if spec.fill then
		a = math.min(1, a * K.Widgets.Setting("panelOpacity") / 0.75)
	else
		a = K.Widgets.Setting("panelOpacity")
	end
	assert(W.SameColor(chrome.fill[5], r, g, b, a), value .. " repaints the existing fill immediately")
	assert((chrome.grain ~= nil and chrome.grain:IsShown()) == (spec.texture ~= nil), value .. " updates grain visibility")
	assert((chrome.materialFrame ~= nil and chrome.materialFrame[1]:IsShown()) == (spec.frame == true), value .. " updates the frame")
	assert(chrome.gilt[1]:IsShown() == (value ~= "ForgedBrackets"), value .. " updates gilt tick visibility")
end
painted("ForgedBrackets")
assert(chrome.grain:GetTexture() == K.Tokens.Texture("materialForged"), "the default uses the forged grain")
assert(#chrome.materialBrackets == 4, "the default has four brackets")
for _, bracket in ipairs(chrome.materialBrackets) do
	assert(bracket:IsShown(), "every default bracket is visible")
end

assert(K.Options.Open("General"))
env.RunTimers()
W.Settle(env)
env.RunTimers()
local items = ns.Window.State().items
local item, itemIndex = O.Find(items, function(row)
	return row.module == "Widgets" and row.key == "cardMaterial"
end)
assert(item and item.kind == "dropdown" and item.options == material.options, "General exposes the registered dropdown")
assert(items[itemIndex - 1].label == K.L["Card material"], "General keeps the material header")
local content = ns.Window.Parts().content
content:ScrollToIndex(itemIndex - 1, true, "TOP")
env.RunTimers()
W.Settle(env)
local row = O.Find(content.rows, function(candidate)
	return candidate:IsShown() and candidate.item == item
end)
assert(row and row.controls.dropdown, "the real Options row creates a dropdown control")
local dropdown = row.controls.dropdown
assert(dropdown:GetValue() == "ForgedBrackets", "the control displays the new default")
assert(not dropdown:SetValue("missing"), "the dropdown rejects unlisted values")
for i = 2, #values do
	assert(dropdown:SetValue(values[i]))
	assert(settings.cardMaterial == values[i], "the dropdown writes through Options to the active profile")
	painted(values[i])
end
assert(dropdown:SetValue("Glass"))
painted("Glass")

K.Options.Write("Widgets", "cardMaterial", "Slate")
painted("Slate")
K.Options.Write("Widgets", "panelOpacity", 0.6)
painted("Slate")
K.Options.Write("Widgets", "panelOpacity", 0.75)
painted("Slate")
K.Options.Write("Widgets", "cardMaterial", "missing")
assert(settings.cardMaterial == "missing", "validation does not rewrite saved settings")
painted("ForgedBrackets")

local original = K.Store.ProfileName()
assert(K.Store.CreateProfile("Material options"))
assert(K.Store.SetProfile("Material options"))
painted("ForgedBrackets")
K.Options.Write("Widgets", "cardMaterial", "Glass")
painted("Glass")
assert(K.Store.SetProfile(original))
painted("ForgedBrackets")
K.Options.Write("Widgets", "cardMaterial", "ForgedTicks")
painted("ForgedTicks")
assert(K.Store.SetProfile("Material options"))
painted("Glass")
assert(K.Store.SetProfile(original))
painted("ForgedTicks")

assert(#env._errors == 0, "errors: " .. table.concat(env._errors, "\n"))
print("card material options: five registered choices, validation and immediate dropdown/profile repaint passed")
