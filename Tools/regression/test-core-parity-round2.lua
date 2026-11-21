-- test-core-parity-round2.lua: Options round 2, switched on: account strings carry account choices, profile hotkeys and specialization assignments, Restore puts them back, older strings leave them alone; KstyleUI.API answers WagoUI's LibAddonProfiles calls; About lists the release highlights.
local O = dofile("Tools/regression/options_env.lua")
local env, K, ns = O.New({ saved = { version = 42, profiles = { Default = {}, Other = {} } },
	setup = function(e) e.GameMenuFrame = e.CreateFrame("Frame", "GameMenuFrame", e.UIParent) end })
env.C_AddOns.IsAddOnLoaded = function(name) return env._addons[name] ~= nil, env._addons[name] ~= nil end
local Store, Profiles, API, Codec = K.Store, K.Profiles, K.API, K.Codec
local account = Store.Account()
local function Decode(text) return Codec.Deserialize(Codec.DecodeBase64(text:sub(6))) end
local function Encode(data) return "KSA1:" .. Codec.EncodeBase64(Codec.Serialize(data)) end

-- The sender's account choices, hotkeys and specialization assignments travel in the account string.
local font = env.STANDARD_TEXT_FONT
account.gameFont, account.gameTextScale, account.gameMenuOptions, account.layoutGridLight, account.optionsCpuMetric = true, 1.25, true, true, 2
Profiles.SetHotkey(1, "Other")
account.specializationProfiles = { ["Alt-Realm"] = { enabled = false, profiles = { ["role:HEALER"] = "Other", ["role:TANK"] = "Gone" }, layouts = { ["role:HEALER"] = "Nowhere" } } }
local exported = assert(Profiles.ExportAccount())
local data = Decode(exported)
assert(data.prefs.gameFont == true and data.prefs.gameTextScale == 1.25 and data.keys[1] == "Other" and data.specs["Alt-Realm"].enabled == false, "the account string carries the choices")
assert(data.prefs.optionsSearchPicks == nil and data.restoreProfile == nil, "search history and backups stay at home")

-- The recipient starts elsewhere; the import mirrors the sender and maps profile names.
account.gameFont, account.gameTextScale, account.gameMenuOptions, account.layoutGridLight, account.optionsCpuMetric = nil, nil, nil, nil, nil
account.profileKeys, account.specializationProfiles = nil, { ["Mine-Realm"] = { profiles = { ["role:TANK"] = "Default" } } }
K.Appearance.ApplyGameText()
assert(Profiles.ImportAccount(exported))
assert(account.gameFont == true and account.gameTextScale == 1.25 and account.layoutGridLight == true and account.optionsCpuMetric == 2, "account choices arrive")
assert(env.STANDARD_TEXT_FONT == K.Tokens.Font("body") and env.STANDARD_TEXT_FONT ~= font, "game text applies at once, not on the next reload")
local menu = env.GameMenuFrame:GetChildren()
assert(menu and menu.options and menu.options:IsShown(), "the game menu button arrives")
assert(account.profileKeys[1] == "Other (2)" and env.KstyleUI_Profile1, "the hotkey follows the imported copy of its profile and gets its key button")
local alt = account.specializationProfiles["Alt-Realm"]
assert(alt.enabled == false and alt.profiles["role:HEALER"] == "Other (2)", "specialization assignments follow the imported profiles")
assert(alt.profiles["role:TANK"] == nil and next(alt.layouts) == nil, "an assignment to a profile or layout the string lacks is dropped")
assert(account.specializationProfiles["Mine-Realm"].profiles["role:TANK"] == "Default", "characters the string does not name keep their assignments")

-- Restore puts every account choice back, including the game's own fonts.
assert(Profiles.Restore())
assert(account.gameFont == nil and account.gameTextScale == nil and account.optionsCpuMetric == nil and account.profileKeys == nil, "Restore puts the account choices back")
assert(env.STANDARD_TEXT_FONT == font, "Restore gives the game its own font back")
assert(not menu.options:IsShown(), "Restore takes the game menu button away")
assert(account.specializationProfiles["Alt-Realm"] == nil and account.specializationProfiles["Mine-Realm"], "Restore puts the assignments back")

-- An older account string has no choices, so the recipient's stay as they are.
data.prefs, data.keys, data.specs = nil, nil, nil
account.gameFont = true
Profiles.SetHotkey(3, "Default")
assert(Profiles.ImportAccount(Encode(data)))
assert(account.gameFont == true and account.profileKeys[3] == "Default", "an older string changes no account choice")
assert(Profiles.Restore())
account.gameFont, account.profileKeys = nil, nil
K.Appearance.ApplyGameText()

-- Values out of range or of the wrong kind fall back to the defaults.
data = Decode(exported)
data.prefs.gameTextScale, data.prefs.optionsCpuMetric, data.prefs.gameFont, data.keys = 9, 4, "yes", { "Other", [9] = "Other" }
assert(Profiles.ImportAccount(Encode(data)))
assert(account.gameTextScale == nil and account.optionsCpuMetric == nil and account.gameFont == nil and account.profileKeys[9] == nil, "bad values are refused")
assert(Profiles.Restore())

-- KstyleUI.API answers WagoUI's LibAddonProfiles calls, with its colon syntax.
assert(API:GetProfileKeys().Default and API:GetProfileKeys().Other, "GetProfileKeys lists every profile")
local text = assert(API:ExportProfile("Other"))
assert(API:DecodeProfileString(text).name == "Other", "DecodeProfileString reads an exported profile")
assert(API:DecodeProfileString("nonsense") == nil, "DecodeProfileString refuses a string that is not a profile")
local ok, name = API:ImportProfile(text, "Wago")
assert(ok and name == "Wago" and API:GetCurrentProfileKey() == "Wago", "ImportProfile adds the named profile and switches to it")
assert(API:GetProfileAssignments()[Store.CharacterKey()] == "Wago", "GetProfileAssignments lists each character's profile")
env.SetCombat(true)
API:SetProfile("Default")
assert(Store.ProfileName() == "Wago", "SetProfile waits for combat to end")
env.SetCombat(false)
assert(Store.ProfileName() == "Default", "SetProfile switches after combat")
API:SetProfile("Nope")
assert(Store.ProfileName() == "Default", "SetProfile ignores a profile that does not exist")
API:CloseConfig()
assert(not (ns.Window.Frame() and ns.Window.Frame():IsShown()), "CloseConfig never opens a closed window")
API:OpenConfig()
env.RunTimers()
assert(ns.Window.Frame():IsShown() and ns.Window.State().page == "Profiles", "OpenConfig opens the settings on Profiles")
API:OpenConfig()
assert(ns.Window.Frame():IsShown() and not ns.Window.Frame().closing, "OpenConfig on an open window keeps it open")
API:CloseConfig()
O.W.Tick(env, 1)
assert(not ns.Window.Frame():IsShown(), "CloseConfig closes the window")

-- About lists each version's highlights under its heading.
local about = ns.Pages.Find(ns.Pages.List(), "About").Items()
local heading = O.Find(about, function(item) return item.kind == "header" and item.label == ns.NOTES[1][1] end)
local line = O.Find(about, function(item) return item.kind == "note" and item.label == ns.NOTES[1][2][1] end)
assert(heading and heading.level == 2 and line, "About shows the newest version's highlights")

assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("core parity round 2 ok: account choices, hotkeys and assignments with restore, older strings, bad values, LibAddonProfiles API, About highlights")
