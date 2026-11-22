-- test-card-material-options.lua: saved card material values validate, General offers no material picker, and cards keep the Medallions steel whatever is saved.
local O = dofile("Tools/regression/options_env.lua")
local W = O.W
local values = { "Glass", "Flat", "Slate", "ForgedTicks", "ForgedBrackets" }

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

local env, K = O.New({ before = function(_, core) core.Store.Account().setupSeen = true end })
local schema = K.Options.Get("Widgets")
assert(schema == K.Widgets.schema, "Options uses the real widget schema")
assert(K.Options.Row("Widgets", "cardMaterial") == nil, "General offers no material picker: Medallions cards are steel")

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
	assert(K.Widgets.Setting("cardMaterial") == value)
	local r, g, b, a = K.Widgets.Rgba("medCardFill")
	a = math.min(1, a * K.Widgets.Setting("panelOpacity") / 0.75)
	assert(W.SameColor(chrome.fill[5], r, g, b, a), value .. " keeps the steel fill at the panel opacity")
	assert(chrome.grain == nil and chrome.materialFrame == nil, value .. " draws no grain and no forged frame")
	assert(not chrome.gilt[1]:IsShown(), value .. " shows no gilt ticks")
end
painted("ForgedBrackets")

for _, value in ipairs(values) do
	settings.cardMaterial = value
	painted(value)
end
settings.cardMaterial = K.Widgets.defaults.cardMaterial

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
print("card material options: saved values validate, General offers no picker, cards keep the steel")
