-- test-core-parity-round2-review.lua: the PR #620 review's probes: account import settles the specialization and resolves renamed layouts, Restore and older strings, the import prompts, the installer's key and combat, the CPU metric and About's grouping and language.
local O = dofile("Tools/regression/options_env.lua")
local failed = {}
local function Check(ok, why) if not ok then failed[#failed + 1] = why end end
local function New()
	local env, K, ns = O.New({ setup = function(e) e.UnitGroupRolesAssigned = function() return "HEALER" end end })
	assert(K.Store.CreateProfile("Other"))
	return env, K, ns
end
local function Encode(K, data) return "KSA1:" .. K.Codec.EncodeBase64(K.Codec.Serialize(data)) end
local function Data(K) return K.Codec.Deserialize(K.Codec.DecodeBase64(assert(K.Profiles.ExportAccount()):sub(6))) end

do
	local env, K, ns = New()
	local Store, Profiles, API = K.Store, K.Profiles, K.API
	local me, account = Store.CharacterKey(), Store.Account()
	account.namedLayouts = { Position = { ["spec.sample"] = { anchor = "CENTER", x = 25, y = 0 } } }
	local data = Data(K)
	data.characters[me] = "Default"
	data.specs[me] = { enabled = true, profiles = { ["role:HEALER"] = "Other" }, layouts = { ["role:HEALER"] = "Position" } }
	account.namedLayouts.Position["spec.sample"].x = 85
	assert(Profiles.ImportAccount(Encode(K, data)))
	Check(Store.ProfileName() == "Other (2)", "account import settles the specialization: on " .. tostring(Store.ProfileName()) .. ", assigned Other (2)")
	local layout = account.namedLayouts[K.Specialization.Layout("role:HEALER")]
	Check(layout and layout["spec.sample"].x == 25, "a renamed imported layout keeps the sender's positions: x=" .. tostring(layout and layout["spec.sample"].x))
	assert(Profiles.Restore())
	Check(Store.ProfileName() == "Default", "Restore puts this character back on its profile: on " .. tostring(Store.ProfileName()))

	local text = assert(API:ExportProfile("Other"))
	env.SetCombat(true)
	local before = Store.ProfileName()
	assert(API:ImportProfile(text, "Pack"))
	Check(Store.ProfileName() == before, "an installer import waits for combat to end: on " .. tostring(Store.ProfileName()))
	env.SetCombat(false)
	Check(Store.ProfileName() == "Pack", "an installer import switches after combat: on " .. tostring(Store.ProfileName()))
	assert(API:ImportProfile(text, "Pack"))
	Check(API:GetCurrentProfileKey() == "Pack" and not API:GetProfileKeys()["Pack (2)"], "a repeated installer import keeps the requested key: on " .. tostring(API:GetCurrentProfileKey()))

	local confirm = K.Widgets.Confirm
	local asked
	K.Widgets.Confirm = function(opts) asked = opts end
	ns.Pages.ReviewImport(Encode(K, Data(K)))
	K.Widgets.Confirm = confirm
	Check(asked and asked.text:find("profile hotkeys", 1, true), "the account import prompt says it replaces account preferences and hotkeys")
	local export = O.Find(ns.Pages.Find(ns.Pages.List(), "Profiles").Items(), function(item) return item.label == K.L["Export every profile"] end)
	Check(export and export.help:find("profile hotkeys", 1, true), "Export every profile says the string carries account preferences and hotkeys")
	data = Data(K)
	data.prefs.layoutToolbarHover, data.keys[2] = true, "Other"
	account.layoutToolbarHover = nil
	K.Store.Module("ProfileTools").accountChoices = false
	assert(Profiles.ImportAccount(Encode(K, data)))
	Check(account.layoutToolbarHover == nil and not (account.profileKeys or {})[2], "Import account choices off keeps this account's choices")
end

do
	local _, K = New()
	local account = K.Store.Account()
	local data = Data(K)
	data.prefs.optionsCpuMetric = 1.5
	assert(K.Profiles.ImportAccount(Encode(K, data)))
	Check(account.optionsCpuMetric == nil, "a fractional CPU metric falls back to Off: " .. tostring(account.optionsCpuMetric))
	data = Data(K)
	data.prefs, data.keys, data.specs = nil, nil, nil
	assert(K.Profiles.ImportAccount(Encode(K, data)))
	account.layoutGridLight = true
	assert(K.Profiles.Restore())
	Check(account.layoutGridLight == true, "Restore after an older string leaves account choices made since")
end

do
	local _, K, ns = O.New({ setup = function(e) e.GetLocale = function() return "deDE" end end })
	local about = ns.Pages.Find(ns.Pages.List(), "About")
	for _, item in ipairs(ns.Model.Search({ about }, K.L["CPU readout"])) do
		Check(not item.label:find("v0.", 1, true), "CPU readout stays under Tools, not " .. item.label)
	end
	local english, notes = {}, assert(loadfile("KstyleUI_Options/Notes.lua"))
	setfenv(notes, { KstyleUI = { L = setmetatable({}, { __index = function(_, key) return key end }) } })("KstyleUI_Options", english)
	Check(not O.Find(about.Items(), function(item) return item.label == english.NOTES[1][2][1] end), "About shows the highlights in the player's language")
end

assert(#failed == 0, "\n" .. table.concat(failed, "\n"))
print("core parity round 2 review ok: specialization settle, renamed layouts, Restore, prompts, installer key and combat, CPU metric, About")
