-- Profiles.lua: scoped sharing, import previews and named recovery profiles before destructive profile operations.
local _, K = ...
local Store, Codec, L = K.Store, K.Codec, K.L
local Profiles = {}
K.Profiles = Profiles
Store.RegisterDefaults("ProfileTools", { review = true, backups = true })
K.Options.Register("ProfileTools", {
	{ type = "header", label = L["Profile tools"] },
	{ type = "toggle", key = "review", label = L["Scoped sharing and import review"], help = L["Share a layout or one module and review imports. Off shares and imports whole profiles directly."] },
	{ type = "toggle", key = "backups", label = L["Recovery backups"], help = L["Saves a restore point before setup, import or reset. Off keeps the previous direct changes."] },
})

local function Copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, child in pairs(value) do out[key] = Copy(child) end
	return out
end

local function Encode(payload)
	local body = Codec.Serialize(payload)
	return "KSUI1:" .. Codec.EncodeBase64("KSL1:" .. #body .. ":" .. Codec.Adler32(body) .. ":" .. body)
end

function Profiles.Backup(label, source)
	if not Store.IsLoaded() then return false end
	if not Store.Module("ProfileTools").backups then return true end
	local names, name, i = {}, label, 1
	for _, existing in ipairs(Store.ListProfiles()) do names[existing] = true end
	while names[name] do i = i + 1; name = label .. " " .. i end
	local ok, why = Store.CopyProfile(source or Store.ProfileName(), name)
	if ok then Store.Account().restoreProfile = name end
	return ok, ok and name or why
end

function Profiles.Restore()
	local name = Store.Account().restoreProfile
	if not name then return false, L["No backup is available."] end
	local ok, why = Store.CopyProfile(name, Store.ProfileName())
	local backup = Store.Account().editModeBackup
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

function Profiles.Export(scope)
	local text, why = Store.Export()
	if not text or not scope or scope == "everything" or not Store.Module("ProfileTools").review then return text, why end
	local payload, err = Store.Decode(text)
	if not payload then return nil, err end
	if scope == "layout" then
		payload.settings = {}
	elseif Store.Defaults(scope) then
		payload.settings, payload.layout = { [scope] = payload.settings[scope] or {} }, {}
	else
		return nil, L["Choose a module to share."]
	end
	return "KSS1:" .. Codec.EncodeBase64(Codec.Serialize({ scope = scope, profile = Encode(payload) }))
end

local function Decode(text)
	if type(text) == "string" and text:sub(1, 5) == "KSS1:" then
		if #text > 1048576 then return nil, L["This profile string is too large."] end
		local raw = Codec.DecodeBase64(text:sub(6):gsub("%s+", ""))
		local envelope = raw and Codec.Deserialize(raw)
		if type(envelope) ~= "table" or type(envelope.scope) ~= "string" or (envelope.scope ~= "layout" and not Store.Defaults(envelope.scope)) then
			return nil, L["This scoped profile is not valid."]
		end
		local payload, why = Store.Decode(envelope.profile)
		return payload, why, envelope.scope
	end
	return Store.Decode(text)
end

local function Equal(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for key, value in pairs(a) do if not Equal(value, b[key]) then return false end end
	for key in pairs(b) do if a[key] == nil then return false end end
	return true
end

local function Merge(base, values)
	local out = Copy(base or {})
	for key, value in pairs(values or {}) do
		out[key] = type(value) == "table" and Merge(out[key], value) or value
	end
	return out
end

function Profiles.Preview(text, scope)
	local payload, why, sharedScope = Decode(text)
	if not payload then return nil, why end
	scope = scope or "everything"
	if sharedScope then
		if scope ~= "everything" and scope ~= sharedScope then return nil, L["Choose the scope included in this profile."] end
		scope = sharedScope
	end
	if scope ~= "everything" and scope ~= "layout" and not payload.settings[scope] then return nil, L["This profile has no settings for that module."] end
	local changes, settings, layout = {}, Copy(Store.Profile()), Copy(Store.Layout())
	if scope ~= "layout" then
		if scope == "everything" then
			for module in pairs(settings) do
				local future = Merge(Store.Defaults(module), payload.settings[module])
				if not Equal(settings[module], future) then changes[#changes + 1] = module end
				settings[module] = future
			end
		end
		for module, values in pairs(payload.settings) do
			if scope == "everything" or scope == module then
				local future = Merge(Store.Defaults(module), values)
				if scope ~= "everything" and not Equal(settings[module], future) then changes[#changes + 1] = module end
				settings[module] = future
			end
		end
	end
	if scope == "everything" or scope == "layout" then
		if not Equal(layout, payload.layout) then changes[#changes + 1] = L["Layout"] end
		layout = Copy(payload.layout)
	end
	table.sort(changes)
	local labels = {}
	for _, module in ipairs(changes) do
		local label = module
		for _, entry in ipairs(K.Setup and K.Setup.PICKER or {}) do if entry.name == module then label = entry.label; break end end
		labels[#labels + 1] = label
	end
	payload.settings, payload.layout = settings, layout
	local encoded = Encode(payload)
	local valid, err = Store.Decode(encoded)
	if not valid then return nil, err end
	return { text = encoded, changes = changes, summary = #changes > 0 and table.concat(labels, ", ") or L["No changes"] }
end

local import, reset = Store.Import, Store.ResetProfile
function Store.Import(text, name)
	if not Store.IsLoaded() or not Store.Module("ProfileTools").backups then return import(text, name) end
	local payload, why = Store.Decode(text)
	if not payload then return false, why end
	local ok, err = Profiles.Backup(L["Before import"])
	if not ok then return false, err end
	return import(text, name)
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
	if readable then
		return Profiles.READABLE[role] or standard
	end
	return standard
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
