-- Profiles.lua: scoped sharing, import previews, named recovery profiles before destructive profile operations, account sharing with account choices, presets, profile hotkeys and KstyleUI.API, the profile calls WagoUI's LibAddonProfiles makes.
local _, K = ...
local Store, Codec, L = K.Store, K.Codec, K.L
local format = string.format
local Profiles = {}
K.Profiles = Profiles
Store.RegisterDefaults("ProfileTools", { review = true, backups = true, scaleWarning = true, accountChoices = true })
K.Options.Register("ProfileTools", function() return {
	{ type = "header", label = L["Profile tools"] },
	{ type = "toggle", key = "review", label = L["Scoped sharing and import review"], help = L["Choose what to share and review imports. Off shares and imports whole profiles directly."] },
	{ type = "toggle", key = "backups", label = L["Recovery backups"], help = L["Saves a restore point before setup, import or reset. Off keeps the previous direct changes."] },
	{ type = "toggle", key = "scaleWarning", label = L["Warn about imported interface size"], help = L["Adds a note to import review when the shared settings change your interface size."] },
	{ type = "toggle", key = "accountChoices", label = L["Import account choices"], help = L["Account imports bring their preferences, hotkeys and specialization choices. Off keeps yours."] },
} end)

local Copy, Equal = K.Options.Copy, K.Options.Equal
local SetAccount, HotkeyButton

local function Selection(scope)
	if type(scope) ~= "table" then return end
	local selected = {}
	for module, on in pairs(scope) do
		if type(module) ~= "string" or type(on) ~= "boolean" or not Store.Defaults(module) then return end
		if on then selected[module] = true end
	end
	return next(selected) and selected or nil
end

local function Encode(payload)
	local body = Codec.Serialize(payload)
	return "KSUI1:" .. Codec.EncodeBase64("KSL1:" .. #body .. ":" .. Codec.Adler32(body) .. ":" .. body)
end

function Profiles.Backup(label, source)
	if not Store.IsLoaded() then return false end
	if not Store.Module("ProfileTools").backups then return true end
	local names, name, i = K.API:GetProfileKeys(), label, 1
	while names[name] do i = i + 1; name = label .. " " .. i end
	local ok, why = Store.CopyProfile(source or Store.ProfileName(), name)
	if ok then Store.Account().restoreProfile = name end
	return ok, ok and name or why
end

function Profiles.Restore()
	local name = Store.Account().restoreProfile
	if not name then return false, L["No backup is available."] end
	local backup, characters = Store.Account().editModeBackup, Store.Account().restoreCharacters
	if characters and characters.profile == name and Store.Data().profiles[characters.current] then Store.SetProfile(characters.current) end
	local ok, why = Store.CopyProfile(name, Store.ProfileName())
	if ok and characters and characters.profile == name then
		for key, profile in pairs(characters.characters) do Store.Data().characters[key] = profile or nil end
		if characters.account then SetAccount(Copy(characters.account)) end
	end
	if ok and backup and backup.profile == name then
		local saved = Copy(backup)
		K.Combat.Queue(function()
			local api = C_EditMode
			if api and type(api.SaveLayouts) == "function" and type(api.SetActiveLayout) == "function" then
				local restored = pcall(api.SaveLayouts, { layouts = saved.layouts, activeLayout = saved.activeLayout })
				if restored then pcall(api.SetActiveLayout, saved.activeLayout) end
			end
		end)
	end
	return ok, why
end

function Profiles.Layouts()
	return Store.Account().namedLayouts or {}
end

function Profiles.SaveLayout(name)
	if type(name) ~= "string" then return false, L["Name the layout."] end
	name = name:match("^%s*(.-)%s*$")
	if name == "" or #name > 48 or name:find("[%c|]") then return false, L["Choose a layout name of 1 to 48 characters without control characters or pipes."] end
	if Profiles.Layouts()[name] then return false, L["A layout with that name already exists."] end
	local account = Store.Account()
	account.namedLayouts = account.namedLayouts or {}
	account.namedLayouts[name] = K.Layout.CapturePositions()
	return true, name
end

function Profiles.DeleteLayout(name)
	local positions = Profiles.Layouts()[name]
	if not positions then return false end
	Store.Account().namedLayouts[name] = nil
	for _, config in pairs(Store.Account().specializationProfiles or {}) do
		for key, assigned in pairs(config.layouts or {}) do
			if assigned == name then config.layouts[key] = nil end
		end
	end
	K.Layout.ApplyNamed(nil, positions)
	return true
end

local function EditModeLayouts()
	local api, manager = C_EditMode, rawget(_G, "EditModePresetLayoutManager")
	if not (type(api) == "table" and type(api.GetLayouts) == "function" and type(manager) == "table" and type(manager.GetCopyOfPresetLayouts) == "function") then return end
	local ok, info = pcall(api.GetLayouts)
	local copied, all = pcall(manager.GetCopyOfPresetLayouts, manager)
	if not (ok and copied and type(info) == "table" and type(info.layouts) == "table" and type(all) == "table") then return end
	for _, layout in ipairs(info.layouts) do all[#all + 1] = layout end
	return all, type(info.activeLayout) == "number" and info.activeLayout or 1
end

local function EditModeChunks()
	local all, active = EditModeLayouts()
	local layout = all and all[active]
	if not layout or type(C_EditMode.ConvertLayoutInfoToString) ~= "function" then return end
	local ok, text = pcall(C_EditMode.ConvertLayoutInfoToString, layout)
	if not ok or type(text) ~= "string" or text == "" then return end
	local chunks = {}
	for i = 1, #text, 1000 do chunks[#chunks + 1] = text:sub(i, i + 999) end
	return chunks
end

local function SpecKeys()
	local config = (Store.Account().specializationProfiles or {})[Store.CharacterKey() or ""]
	local keys = {}
	for key, name in pairs(type(config) == "table" and type(config.profiles) == "table" and config.profiles or {}) do
		if name == Store.ProfileName() and type(key) == "string" then keys[#keys + 1] = key end
	end
	table.sort(keys)
	return keys[1] and keys or nil
end

local function SpecCooldowns()
	local config = (Store.Account().specializationProfiles or {})[Store.CharacterKey() or ""]
	local out = {}
	for key, name in pairs(type(config) == "table" and type(config.profiles) == "table" and config.profiles or {}) do
		local payload = type(key) == "string" and Store.Decode((Store.Export(name)))
		if payload then
			payload.settings, payload.layout, payload.namedLayouts = { Cooldowns = { rules = (payload.settings.Cooldowns or {}).rules } }, {}, nil
			out[key] = Encode(payload)
		end
	end
	return next(out) and out or nil
end

local function Envelope(scope, profile, includeLayout, cooldowns)
	return "KSS1:" .. Codec.EncodeBase64(Codec.Serialize({ scope = scope, profile = profile, includeLayout = includeLayout, cooldowns = cooldowns }))
end

function Profiles.Export(scope, includeLayout, extras)
	local text, why = Store.Export()
	if not text or not Store.Module("ProfileTools").review then return text, why end
	scope = scope or "everything"
	extras = extras or {}
	if scope == "everything" and includeLayout ~= false and not (extras.specs or extras.editMode or extras.cooldowns) then return text, why end
	local payload, err = Store.Decode(text)
	if not payload then return nil, err end
	payload.specs = extras.specs and SpecKeys() or nil
	payload.editMode = extras.editMode and EditModeChunks() or nil
	if extras.editMode and not payload.editMode then return nil, L["Edit Mode's active layout could not be read."] end
	local cooldowns = extras.cooldowns and SpecCooldowns() or nil
	if extras.cooldowns and not cooldowns then return nil, L["No specialization has a profile assigned yet."] end
	if scope == "everything" and includeLayout ~= false then return cooldowns and Envelope("everything", Encode(payload), nil, cooldowns) or Encode(payload) end
	if scope == "everything" then scope = "settings" end
	local selected = Selection(scope)
	if type(scope) == "table" then
		if not selected then return nil, L["Choose at least one module to share."] end
		for module in pairs(payload.settings) do
			if not selected[module] then payload.settings[module] = nil end
		end
		if includeLayout == false then payload.layout, payload.namedLayouts = {}, nil end
		scope = "modules"
	elseif scope == "layout" then
		payload.settings = {}
	elseif scope == "settings" then
		payload.layout, payload.namedLayouts = {}, nil
	elseif Store.Defaults(scope) then
		payload.settings, payload.layout, payload.namedLayouts = { [scope] = payload.settings[scope] or {} }, {}, nil
	else
		return nil, L["Choose a module to share."]
	end
	return Envelope(scope, Encode(payload), scope == "modules" and includeLayout ~= false or nil, cooldowns)
end

local function Decode(text)
	if type(text) == "string" and text:sub(1, 5) == "KSS1:" then
		if #text > 1048576 then return nil, L["This profile string is too large."] end
		local raw = Codec.DecodeBase64(text:sub(6):gsub("%s+", ""))
		local envelope = raw and Codec.Deserialize(raw)
		local scopes = { layout = true, settings = true, modules = true, everything = true }
		if type(envelope) ~= "table" or type(envelope.scope) ~= "string" or not (scopes[envelope.scope] or Store.Defaults(envelope.scope)) then
			return nil, L["This scoped profile is not valid."]
		end
		local cooldowns = envelope.cooldowns
		for key, value in pairs(type(cooldowns) == "table" and cooldowns or {}) do
			if type(key) ~= "string" or not key:find("^%a+:%w+$") or type(value) ~= "string" then cooldowns = nil break end
		end
		local payload, why = Store.Decode(envelope.profile)
		return payload, why, envelope.scope, envelope.includeLayout == true, type(cooldowns) == "table" and cooldowns or nil
	end
	return Store.Decode(text)
end

local function Merge(base, values)
	local out = Copy(base or {})
	for key, value in pairs(values or {}) do
		out[key] = type(value) == "table" and Merge(out[key], value) or value
	end
	return out
end

function Profiles.Preview(text, scope, includeLayout, extras)
	local payload, why, sharedScope, sharedLayout, cooldowns = Decode(text)
	if not payload then return nil, why end
	extras = extras or {}
	local specs, editMode = extras.specs and payload.specs, extras.editMode and payload.editMode
	cooldowns = extras.cooldowns and cooldowns
	if sharedScope == "everything" then sharedScope = nil end
	scope = scope or "everything"
	if sharedScope == "modules" then
		if scope == "everything" then
			scope = {}
			for module in pairs(payload.settings) do scope[module] = true end
		elseif type(scope) ~= "table" then return nil, L["Choose the scope included in this profile."] end
		includeLayout = includeLayout ~= false and sharedLayout
	elseif sharedScope then
		if type(scope) == "table" and sharedScope ~= "layout" then
			includeLayout = false
		else
			if scope ~= "everything" and scope ~= sharedScope then return nil, L["Choose the scope included in this profile."] end
			scope = sharedScope
		end
	end
	local selected = Selection(scope)
	if type(scope) == "table" then
		if not selected then return nil, L["Choose at least one module to share."] end
		for module in pairs(selected) do
			if not payload.settings[module] then return nil, L["This profile has no settings for that module."] end
		end
	end
	if scope == "everything" and includeLayout == false then scope = "settings" end
	if not selected and scope ~= "everything" and scope ~= "layout" and scope ~= "settings" and not payload.settings[scope] then return nil, L["This profile has no settings for that module."] end
	local changes, settings, layout = {}, Copy(Store.Profile()), Copy(Store.Layout())
	if scope ~= "layout" then
		for module in pairs(settings) do
			if scope == "everything" or scope == "settings" or scope == module or selected and selected[module] then
				local future = Merge(Store.Defaults(module), payload.settings[module])
				if not Equal(settings[module], future) then changes[#changes + 1] = module end
				settings[module] = future
			end
		end
	end
	if scope == "everything" or scope == "layout" or selected and includeLayout ~= false then
		if not Equal(layout, payload.layout) then changes[#changes + 1] = L["Layout"] end
		layout = Copy(payload.layout)
		if payload.namedLayouts and not Equal(Profiles.Layouts(), payload.namedLayouts) then changes[#changes + 1] = L["Saved layouts"] end
	else
		payload.namedLayouts = nil
	end
	if specs then changes[#changes + 1] = L["Specializations"] end
	if editMode then changes[#changes + 1] = L["Edit Mode"] end
	if cooldowns then changes[#changes + 1] = L["Cooldowns per specialization"] end
	table.sort(changes)
	payload.settings, payload.layout, payload.specs, payload.editMode = settings, layout, specs or nil, editMode or nil
	local encoded = Encode(payload)
	local valid, err = Store.Decode(encoded)
	if not valid then return nil, err end
	local current, future = Store.Module("Appearance"), settings.Appearance
	local scaleChanged = Store.Module("ProfileTools").scaleWarning and future
		and ((future.uiScaleGame == true) ~= (current.uiScaleGame == true) or future.uiScaleAuto ~= current.uiScaleAuto or future.uiScaleAuto == false and future.uiScale ~= current.uiScale)
	return { text = cooldowns and Envelope("everything", encoded, nil, cooldowns) or encoded, changes = changes, summary = #changes > 0 and table.concat(changes, ", ") or L["No changes"],
		warning = scaleChanged and L["This import changes your interface size. Review Size in General after applying."] or nil }
end

local function ImportEditMode(chunks, name)
	K.Combat.Queue(function()
		local all, active = EditModeLayouts()
		local api, types = C_EditMode, Enum and Enum.EditModeLayoutType
		if not (all and types and type(api.ConvertStringToLayoutInfo) == "function" and type(api.SaveLayouts) == "function" and type(api.SetActiveLayout) == "function") then
			return K.Print(L["Edit Mode did not take the shared layout."])
		end
		local ok, layout = pcall(api.ConvertStringToLayoutInfo, table.concat(chunks))
		if not ok or type(layout) ~= "table" then return K.Print(L["Edit Mode did not take the shared layout."]) end
		if Store.Module("ProfileTools").backups then
			Store.Account().editModeBackup = { name = L["Before import"], profile = Store.Account().restoreProfile, layouts = Copy(all), activeLayout = active }
		end
		layout.layoutName, layout.layoutType = ("KstyleUI " .. name):sub(1, 32), types.Account
		all[#all + 1] = layout
		if not pcall(api.SaveLayouts, { layouts = all, activeLayout = #all }) then return K.Print(L["Edit Mode did not take the shared layout."]) end
		if not pcall(api.SetActiveLayout, #all) then K.Print(L["Edit Mode saved it but did not switch to it. Try again, or pick it in Edit Mode."]) end
	end)
end

local function ImportCooldowns(cooldowns, payload, target)
	local names, defaults = K.API:GetProfileKeys(), (Store.Defaults("Cooldowns") or {}).rules
	local own = Merge(defaults, (payload.settings.Cooldowns or {}).rules)
	for _, choice in ipairs(K.Specialization.Choices()) do
		local shared = cooldowns[choice.key] and Store.Decode(cooldowns[choice.key])
		local rules = shared and (shared.settings.Cooldowns or {}).rules or {}
		if shared and Equal(Merge(defaults, rules), own) then
			K.Specialization.Assign(choice.key, target)
		elseif shared then
			local name, i
			repeat
				local suffix = format(i and " (%s %d)" or " (%s)", choice.label, i)
				name, i = target:sub(1, 48 - #suffix) .. suffix, (i or 1) + 1
			until not names[name]
			if Store.CopyProfile(target, name) then
				local copy = Store.Data().profiles[name]
				copy.Cooldowns = copy.Cooldowns or {}
				copy.Cooldowns.rules, names[name] = rules, true
				K.Specialization.Assign(choice.key, name)
			end
		end
	end
end

local import, reset = Store.Import, Store.ResetProfile
function Store.Import(text, name, extras)
	if not Store.IsLoaded() then return import(text, name) end
	local payload, why, scope, _, cooldowns = Decode(text)
	if scope == "everything" then
		text = payload and Encode(payload)
	elseif scope then
		payload, why, cooldowns = Store.Decode(text)
	end
	if not payload then return false, why end
	if Store.Module("ProfileTools").backups then
		local ok, err = Profiles.Backup(L["Before import"])
		if not ok then return false, err end
	end
	local ok, target = import(text, name)
	extras = ok and extras or {}
	for _, key in ipairs(extras.specs and payload.specs or {}) do K.Specialization.Assign(key, target) end
	if extras.editMode and payload.editMode then ImportEditMode(payload.editMode, target) end
	if extras.cooldowns and cooldowns then ImportCooldowns(cooldowns, payload, target) end
	return ok, target
end

local PREFS = { gameFont = "boolean", gameTextScale = { 0.8, 1.5 }, combatFont = "boolean", nameFont = "boolean", combatTextScale = { 0.8, 1.5 },
	optionsSearchPage = "boolean", optionsRailSections = "boolean", optionsSearchMemory = "boolean", optionsFold = "boolean", gameMenuOptions = "boolean",
	gameMenuLayout = "boolean", moverOptions = "boolean", layoutGridLight = "boolean", layoutToolbarHover = "boolean", optionsCpuMetric = { 0, 3, true } }

local function AccountChoices()
	local account, prefs = Store.Account(), {}
	for key in pairs(PREFS) do prefs[key] = account[key] end
	return { prefs = prefs, keys = Copy(account.profileKeys or {}), specs = Copy(account.specializationProfiles or {}) }
end

function SetAccount(choices)
	local account = Store.Account()
	for key in pairs(PREFS) do account[key] = choices.prefs[key] end
	account.profileKeys = next(choices.keys) and choices.keys or nil
	account.specializationProfiles = next(choices.specs) and choices.specs or nil
	for i in pairs(choices.keys) do HotkeyButton(i) end
	K.Appearance.ApplyGameText()
	K.OptionsEntry.GameMenu()
	K.Specialization.SetEnabled(K.Specialization.Enabled())
end

function Profiles.ExportAccount()
	local out = AccountChoices()
	out.profiles, out.characters = {}, Store.Characters()
	for _, name in ipairs(Store.ListProfiles()) do
		local text, why = Store.Export(name)
		if not text then return nil, why end
		out.profiles[name] = text
	end
	return "KSA1:" .. Codec.EncodeBase64(Codec.Serialize(out))
end

local function ValidKey(key)
	return type(key) == "string" and #key <= 64 and not key:find("[%c|]")
end

local function ImportedChoices(data, names, sent)
	local out = { prefs = {}, keys = {}, specs = {} }
	for key, kind in pairs(PREFS) do
		local value = data.prefs[key]
		if type(kind) == "table" and type(value) == "number" and value >= kind[1] and value <= kind[2] and (not kind[3] or value % 1 == 0) or type(value) == kind then out.prefs[key] = value end
	end
	for i = 1, Profiles.HOTKEYS do out.keys[i] = names[data.keys[i] or ""] end
	for character, config in pairs(data.specs) do
		if ValidKey(character) and type(config) == "table" then
			local mapped = { profiles = {}, layouts = {} }
			if config.enabled == false then mapped.enabled = false end
			for spec, name in pairs(type(config.profiles) == "table" and config.profiles or {}) do
				if ValidKey(spec) then mapped.profiles[spec] = names[name] end
			end
			for spec, title in pairs(type(config.layouts) == "table" and config.layouts or {}) do
				local positions, name, i = ValidKey(spec) and ValidKey(title) and sent[title], title, 1
				while positions and Profiles.Layouts()[name] and not Equal(Profiles.Layouts()[name], positions) do i = i + 1; name = title:sub(1, 40) .. " " .. i end
				mapped.layouts[spec] = positions and name or nil
			end
			out.specs[character] = mapped
		end
	end
	return out
end

function Profiles.ImportAccount(text)
	if not Store.IsLoaded() then return false, L["KstyleUI has not loaded its saved settings yet."] end
	local raw = type(text) == "string" and #text <= 4194304 and text:sub(1, 5) == "KSA1:" and Codec.DecodeBase64((text:sub(6):gsub("%s+", "")))
	local data = raw and Codec.Deserialize(raw)
	if type(data) ~= "table" or type(data.profiles) ~= "table" or type(data.characters or {}) ~= "table" then return false, L["This account string is not valid."] end
	local payloads = {}
	for name, profile in pairs(data.profiles) do
		local payload, why = Store.Decode(profile)
		if type(name) ~= "string" or not payload then return false, why or L["This account string is not valid."] end
		payloads[name] = payload
	end
	local tools, before = Store.Module("ProfileTools"), {}
	local choices = tools.accountChoices and type(data.prefs) == "table" and type(data.keys) == "table" and type(data.specs) == "table"
	if tools.backups then
		local ok, backup = Profiles.Backup(L["Before import"])
		if not ok then return false, backup end
		Store.Account().restoreCharacters = { profile = backup, characters = before, current = Store.ProfileName(), account = choices and AccountChoices() or nil }
	end
	local names, count, sent = {}, 0, {}
	for name, payload in pairs(payloads) do
		names[name], count, sent = Store.AddProfile(payload, payload.name), count + 1, payload.namedLayouts or sent
	end
	local characters, me, assignments = Store.Data().characters, Store.CharacterKey(), 0
	for key, name in pairs(data.characters or {}) do
		if ValidKey(key) and names[name] then
			if key ~= me then before[key] = characters[key] or false end
			characters[key] = names[name]
			assignments = assignments + 1
		end
	end
	local mine = names[(data.characters or {})[Store.CharacterKey() or ""] or ""]
	if mine then Store.SetProfile(mine) end
	if choices then
		choices = ImportedChoices(data, names, sent)
		for character, config in pairs(Store.Account().specializationProfiles or {}) do choices.specs[character] = choices.specs[character] or Copy(config) end
		SetAccount(choices)
	end
	return true, count, assignments
end

function Profiles.Presets()
	local out, layouts = {}, K.Setup and K.Setup.Layouts
	for _, layout in ipairs(layouts and layouts.Names() or {}) do
		out[#out + 1] = { value = layout, label = layouts.Label(layout) or layout }
	end
	return out
end

function Profiles.FromPreset(layout, name)
	local setup = K.Setup
	if not (setup and setup.Layouts.Get(layout)) then return false, L["Choose a preset."] end
	local style = K.HudStyle.Current()
	local ok, result = Store.CreateProfile(name)
	if not ok then return false, result end
	Store.SetProfile(result)
	local choice = setup.NewChoice(true)
	choice.layout, choice.hudStyle = layout, style
	return setup.Apply(choice), result
end

Profiles.HOTKEYS = 5
_G["BINDING_NAME_CLICK KstyleUI_Profile1:LeftButton"] = format(L["Switch to profile hotkey %d"], 1)
_G["BINDING_NAME_CLICK KstyleUI_Profile2:LeftButton"] = format(L["Switch to profile hotkey %d"], 2)
_G["BINDING_NAME_CLICK KstyleUI_Profile3:LeftButton"] = format(L["Switch to profile hotkey %d"], 3)
_G["BINDING_NAME_CLICK KstyleUI_Profile4:LeftButton"] = format(L["Switch to profile hotkey %d"], 4)
_G["BINDING_NAME_CLICK KstyleUI_Profile5:LeftButton"] = format(L["Switch to profile hotkey %d"], 5)

function HotkeyButton(i)
	local name = "KstyleUI_Profile" .. i
	if _G[name] or type(CreateFrame) ~= "function" then return end
	CreateFrame("Button", name, UIParent):SetScript("OnClick", function()
		K.Combat.Queue(function()
			local target = Profiles.Hotkey(i)
			if Store.Data().profiles[target] then Store.SetProfile(target) end
		end)
	end)
end

local function Keys()
	local keys = Store.IsLoaded() and Store.Account().profileKeys
	return type(keys) == "table" and keys or {}
end

function Profiles.Hotkey(i)
	return Keys()[i] or ""
end

function Profiles.SetHotkey(i, name)
	local keys = Keys()
	keys[i] = name ~= "" and name or nil
	Store.Account().profileKeys = next(keys) and keys or nil
	if keys[i] then HotkeyButton(i) end
end

K.Events.Register("ProfileKeys", "PLAYER_LOGIN", function()
	for i in pairs(Keys()) do HotkeyButton(i) end
end)

K.API = {}
function K.API:ExportProfile(key) return (Store.Export(key)) end
function K.API:ImportProfile(text, key)
	local valid, why = Store.Decode(text)
	if not valid then return false, why end
	K.Combat.Queue(function()
		local ok, added = Store.Import(text, key)
		if ok and added ~= key and Store.CopyProfile(added, key) and Store.SetProfile(key) then Store.DeleteProfile(added) end
	end)
	return true, key
end
function K.API:DecodeProfileString(text) return (Store.Decode(text)) end
function K.API:GetProfileAssignments() return Store.Characters() end
function K.API:GetCurrentProfileKey() return Store.ProfileName() end
function K.API:OpenConfig() K.Options.Open("Profiles") end
function K.API:CloseConfig()
	local ok, _, loaded = pcall(C_AddOns and C_AddOns.IsAddOnLoaded, "KstyleUI_Options")
	if ok and loaded == true then K.Options.Open(false) end
end
function K.API:GetProfileKeys()
	local out = {}
	for _, name in ipairs(Store.ListProfiles()) do out[name] = true end
	return out
end
function K.API:SetProfile(key)
	K.Combat.Queue(function() if Store.IsLoaded() and Store.Data().profiles[key] then Store.SetProfile(key) end end)
end

function Store.ResetProfile(name)
	if not Store.IsLoaded() or not Store.Module("ProfileTools").backups then return reset(name) end
	local ok, why = Profiles.Backup(L["Before reset"], name)
	if not ok then return false, why end
	return reset(name)
end

Profiles.READABLE = { body = 14, prose = 14, names = 14, unit = 14, title = 14, caption = 12, caps = 12, number = 16, time = 14, timer = 14 }
Store.RegisterDefaults("Readability", { preset = "Standard" })
local readable = false
local function ReadPreset()
	readable = Store.IsLoaded() and Store.Module("Readability").preset == "Readable"
end
K.Callbacks.Register("ProfileChanged", "Readability", function()
	local before = readable
	ReadPreset()
	if before ~= readable then K.Callbacks.Fire("ThemeChanged") end
end)
K.Callbacks.Register("SettingChanged", "Readability", function(_, module) if module == "Readability" then ReadPreset() end end)
K.Events.Register("Readability", "PLAYER_LOGIN", ReadPreset)
function Profiles.TextSize(role, standard)
	return readable and Profiles.READABLE[role] or standard
end

function Profiles.Readable(value)
	K.Options.Write("Readability", "preset", value)
	local sizes = { name = 14, health = 16, power = 16, level = 12, cast = 14, cooldown = 14, hotkey = 12, count = 12 }
	local function Walk(module, defaults, path)
		for key, child in pairs(defaults) do
			local full = path == "" and key or path .. "." .. key
			if type(child) == "table" then Walk(module, child, full)
			elseif type(child) == "number" then
				local role = full:match("fonts%.(%w+)%.size$") or full:match("text%.(%w+)%.size$")
				local wanted = sizes[role] or key == "nameSize" and 14 or key == "healthTextSize" and 16
				if key == "timerSize" or key == "cooldownSize" then wanted = 14 end
				if wanted then K.Options.Write(module, full, value == "Readable" and wanted or child) end
			end
		end
	end
	for _, module in ipairs(K.Modules.List()) do
		local defaults = Store.Defaults(module)
		if defaults then Walk(module, defaults, "") end
	end
	K.Callbacks.Fire("ThemeChanged")
end
