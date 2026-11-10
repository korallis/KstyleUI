-- test-role-fonts.lua: per-role font choices in Appearance: precedence, clearing, saving, profiles, custom paths, numeric roles, every shipped face, and LibSharedMedia retries.
local Core = dofile("Tools/regression/core_env.lua")
local W = dofile("Tools/regression/widget_env.lua")

local ROLES = { "display", "heading", "title", "caps", "names", "unit", "body", "prose", "caption", "number", "time", "timer", "world" }
local FOLIO = {
	display = { "FolioDisplay-Regular.ttf", 22 }, heading = { "FolioDisplay-Regular.ttf", 16 },
	title = { "FolioCaps-SemiBold.ttf", 12 }, caps = { "FolioCaps-SemiBold.ttf", 10 },
	names = { "CinzelNames-SemiBold.ttf", 10 }, unit = { "CinzelUnit-SemiBold.ttf", 18 },
	body = { "PTSerif-Regular.ttf", 12 }, prose = { "PTSerif-Regular.ttf", 12 }, caption = { "PTSerif-Regular.ttf", 11 },
	number = { "PTSerif-Bold.ttf", 12 }, time = { "PTSerif-Bold.ttf", 12 }, timer = { "PTSerif-Regular.ttf", 11 },
	world = { "PTSerif-Regular.ttf", 13, "OUTLINE" },
}
local LUMEN = {
	display = "Cinzel-SemiBold.ttf", heading = "Cinzel-SemiBold.ttf", title = "Cinzel-SemiBold.ttf",
	caps = "CinzelCaps-Medium.ttf", names = "CinzelNames-Medium.ttf", unit = "CinzelUnit-Medium.ttf",
	body = "AlegreyaSansTabular-Regular.ttf", prose = "AlegreyaSans-Regular.ttf", caption = "AlegreyaSansTabular-Medium.ttf",
	number = "AlegreyaSansTabular-ExtraBold.ttf", time = "AlegreyaSansTabular-Bold.ttf", timer = "AlegreyaSansTabular-Medium.ttf",
	world = "AlegreyaSansTabular-Medium.ttf",
}
local SHIPPED = {
	"AlegreyaSans-Regular.ttf", "AlegreyaSansTabular-Bold.ttf", "AlegreyaSansTabular-ExtraBold.ttf", "AlegreyaSansTabular-Medium.ttf",
	"AlegreyaSansTabular-Regular.ttf", "Cinzel-SemiBold.ttf", "CinzelCaps-Medium.ttf", "CinzelNames-Medium.ttf",
	"CinzelNames-SemiBold.ttf", "CinzelUnit-Medium.ttf", "CinzelUnit-SemiBold.ttf", "FolioCaps-SemiBold.ttf",
	"FolioDisplay-Regular.ttf", "Inter-SemiBold.ttf", "PTSerif-Bold.ttf", "PTSerif-Regular.ttf",
	"SourceSans3-Regular.ttf", "SourceSans3-Semibold.ttf",
}
local CUSTOM = "Interface\\AddOns\\OtherMedia\\Font.ttf"
local OTHER = "Interface\\AddOns\\OtherMedia\\Second.otf"

local function file(path)
	return path:match("([^\\/]+)$")
end

local function key(role)
	return "roleFont" .. role:sub(1, 1):upper() .. role:sub(2)
end

local function expectDefaults(K, what, except)
	for _, role in ipairs(ROLES) do
		if role ~= except then
			local path, size, flags = K.Tokens.Font(role)
			local want = FOLIO[role]
			assert(file(path) == want[1] and size == want[2] and flags == (want[3] or ""), what .. ": " .. role .. " keeps the Folio default " .. want[1] .. " " .. want[2] .. ", got " .. file(path) .. " " .. tostring(size))
		end
	end
end

-- The defaults are PR1's Folio and Lumen tables, with no role choice saved or applied.
do
	local env, K = W.New()
	local defaults = K.Store.Defaults("Appearance")
	local count = 0
	for _, role in ipairs(ROLES) do
		assert(defaults[key(role)] == "", role .. " defaults to inherit")
		assert(K.Appearance.Get(key(role)) == "" and K.Theme.RoleFont(role) == "", role .. " has no override")
		count = count + 1
	end
	for name in pairs(defaults) do
		if name:find("^roleFont") then
			count = count - 1
		end
	end
	assert(count == 0, "exactly one default per role")
	assert(defaults.typeSet == "Folio" and defaults.font == "" and defaults.fontScale == 1 and defaults.motion == "full", "the older defaults are unchanged")
	expectDefaults(K, "Folio")
	K.Options.Write("Appearance", "typeSet", "Lumen")
	for _, role in ipairs(ROLES) do
		assert(file((K.Tokens.Font(role))) == LUMEN[role], "Lumen " .. role)
	end
	assert(#env._errors == 0)
end

-- A profile that never chose a role font saves nothing for it, and a choice then a clear leaves no record.
do
	local saved = { version = 18, profiles = { Default = {} } }
	local env, K = W.New({ saved = saved })
	K.Options.Write("Appearance", "roleFontBody", "InterSemiBold")
	K.Options.Write("Appearance", "roleFontBody", "")
	Core.Logout(env)
	local appearance = saved.profiles.Default.Appearance
	assert(appearance == nil or next(appearance) == nil, "an inherited role writes no Appearance record")
end

-- Precedence: explicit role font > whole-interface font > type set, and number roles keep Source Sans 3 only under a whole-interface font.
do
	local env, K = W.New()
	local Tokens, Theme = K.Tokens, K.Theme
	K.Options.Write("Appearance", "roleFontBody", "InterSemiBold")
	assert(file((Tokens.Font("body"))) == "Inter-SemiBold.ttf", "an explicit role font replaces the type set's face")
	assert(select(2, Tokens.Font("body")) == 12 and select(3, Tokens.Font("body")) == "", "its size and flags stay the role's")
	expectDefaults(K, "other roles", "body")

	K.Options.Write("Appearance", "font", "SourceSans3Regular")
	assert(file((Tokens.Font("body"))) == "Inter-SemiBold.ttf", "an explicit role font beats a whole-interface font")
	assert(file((Tokens.Font("caps"))) == "SourceSans3-Regular.ttf", "other roles follow the whole-interface font")
	assert(file((Tokens.Font("number"))) == "SourceSans3-Semibold.ttf", "numbers keep Source Sans 3 Semibold under a whole-interface font")
	assert(file((Tokens.Font("world"))) == "SourceSans3-Regular.ttf" and select(3, Tokens.Font("world")) == "OUTLINE", "world text follows it and keeps its outline")

	K.Options.Write("Appearance", "roleFontNumber", "CinzelCaps")
	K.Options.Write("Appearance", "roleFontTimer", CUSTOM)
	assert(file((Tokens.Font("number"))) == "CinzelCaps-Medium.ttf", "an explicit number role beats the numeric Source Sans 3 rule")
	assert(Tokens.Font("timer") == CUSTOM, "an explicit custom path wins on a numeric role")
	assert(file((Tokens.Font("time"))) == "SourceSans3-Semibold.ttf", "a sibling numeric role keeps the whole-interface rule")

	K.Options.Write("Appearance", "roleFontBody", "")
	assert(file((Tokens.Font("body"))) == "SourceSans3-Regular.ttf", "clearing a role inherits the whole-interface font")
	K.Options.Write("Appearance", "font", "")
	assert(file((Tokens.Font("body"))) == "PTSerif-Regular.ttf", "and then the type set, never a captured file")
	K.Options.Write("Appearance", "typeSet", "Lumen")
	assert(file((Tokens.Font("body"))) == "AlegreyaSansTabular-Regular.ttf", "a cleared role follows a later type-set change")
	assert(file((Tokens.Font("number"))) == "CinzelCaps-Medium.ttf", "a role that stays explicit survives a type-set change")
	assert(Theme.RoleFont("number") == "CinzelCaps" and Theme.RoleFont("body") == "", "Theme reports the choices")
	assert(#env._errors == 0)
end

-- Kit text takes a role font on a restyle, and gives it up when the role is cleared.
do
	local _, K = W.New()
	K.Options.Write("Appearance", "roleFontBody", "InterSemiBold")
	local text = K.Widgets.Text(K.Scale.Root(), "body")
	assert(file((text:GetFont())) == "Inter-SemiBold.ttf", "kit text takes the role font")
	K.Options.Write("Appearance", "roleFontBody", "")
	K.Widgets.StyleText(text, "body")
	assert(file((text:GetFont())) == "PTSerif-Regular.ttf", "a restyle after clearing returns to the type set")
	K.Options.Write("Appearance", "roleFontBody", OTHER)
	K.Widgets.StyleText(text, "body")
	assert((text:GetFont()) == OTHER, "a custom role font reaches the font string untouched")
	assert(K.Locale.TrackMode(OTHER) == nil and K.Tokens.FaceTracking(OTHER) == 0, "a custom font receives no synthetic tracking")
	assert(K.Tokens.FaceShadow(OTHER) == true, "and the standard soft shadow")
end

-- Custom, unknown and refused values; no tracking is synthesised for a face KstyleUI does not know.
do
	local _, K = W.New()
	assert(K.Theme.SetRoleFonts({ caps = CUSTOM }) == true)
	local path = K.Tokens.Font("caps")
	assert(path == CUSTOM, "a custom path is used as chosen")
	local tracking, upper = K.Tokens.TextStyle("caps")
	assert(upper == true and tracking == 0, "the role's capitals rule stays; a custom face gets no tracking")
	assert(K.Locale.TrackMode(path) == nil and K.Locale.CanTrack(path) == false, "no tracking mode for a custom path")
	K.Options.Write("Appearance", "roleFontTitle", CUSTOM)
	assert(select(1, K.Tokens.TextStyle("title")) == 0 and select(2, K.Tokens.TextStyle("title")) == true and K.Locale.TrackMode(K.Tokens.Font("title")) == nil, "an explicit choice carries no tracking hint, keeps the capitals rule, and no thin spaces follow for a custom face")

	local before = K.Tokens.Font("body")
	assert(K.Theme.SetRoleFonts({ body = "Comic" }) == false and K.Theme.SetRoleFonts({ body = "Folio" }) == false and K.Theme.SetRoleFonts({ body = "Lumen" }) == false, "a name that is no face, and a type set, are refused")
	assert(K.Theme.SetRoleFonts({ nothing = CUSTOM }) == false and K.Theme.SetRoleFonts({ body = 5 }) == false and K.Theme.SetRoleFonts("x") == false, "an unknown role, a number and a string are refused")
	assert(K.Theme.SetRoleFonts({ body = CUSTOM, caps = "Comic" }) == false and K.Tokens.Font("body") == before, "a refused table changes nothing")
	assert(K.Tokens.Font("title") == CUSTOM and K.Theme.RoleFont("title") == CUSTOM, "and leaves the earlier choice")
	assert(K.Theme.SetRoleFonts({}) == true and file((K.Tokens.Font("title"))) == "FolioCaps-SemiBold.ttf", "an empty table clears every role")

	local saved = { version = 18, profiles = { Default = { Appearance = { roleFontBody = "Comic", roleFontCaps = "Folio", roleFontNames = 7, roleFontNumber = "Interface\\bad|font.ttf", roleFontTimer = CUSTOM } } } }
	local env2, K2 = W.New({ saved = saved })
	for _, role in ipairs({ "body", "caps", "names", "number" }) do
		assert(K2.Appearance.Get(key(role)) == "", role .. ": a damaged saved value falls back to inherit")
	end
	assert(K2.Tokens.Font("timer") == CUSTOM and K2.Appearance.Get("roleFontTimer") == CUSTOM, "a valid saved custom path is kept")
	expectDefaults(K2, "damaged choices", "timer")
	assert(#env2._errors == 0)
end

-- One ThemeChanged per change, none when nothing changes.
do
	local _, K = W.New()
	local fired = 0
	K.Callbacks.Register("ThemeChanged", "role-test", function()
		fired = fired + 1
	end)
	K.Theme.SetRoleFonts({ body = CUSTOM, caps = OTHER, number = "InterSemiBold" })
	assert(fired == 1, "several roles change under one ThemeChanged")
	K.Theme.SetRoleFonts({ body = CUSTOM, caps = OTHER, number = "InterSemiBold" })
	assert(fired == 1, "setting the same choices again fires nothing")
	K.Theme.SetRoleFonts({})
	assert(fired == 2 and K.Theme.RoleFont("body") == "", "clearing fires once")
end

-- Saved choices apply before login, survive a reload and follow the profile.
do
	local saved = {
		version = 18,
		profiles = {
			Default = { Appearance = { roleFontCaps = "CinzelCaps", roleFontBody = CUSTOM, font = "InterSemiBold" } },
			Plain = {},
		},
	}
	local env, K = Core.New({ saved = saved })
	Core.LoadSaved(env)
	assert(file((K.Tokens.Font("caps"))) == "CinzelCaps-Medium.ttf" and K.Tokens.Font("body") == CUSTOM, "saved role fonts apply when the saved data loads")
	assert(file((K.Tokens.Font("names"))) == "Inter-SemiBold.ttf", "and the saved whole-interface font covers the rest")
	Core.Login(env)
	assert(K.Tokens.Font("body") == CUSTOM, "login keeps them")
	assert(K.Store.SetProfile("Plain"))
	assert(K.Theme.RoleFont("caps") == "" and K.Theme.RoleFont("body") == "" and file((K.Tokens.Font("body"))) == "PTSerif-Regular.ttf", "a profile with none clears every role")
	K.Options.Write("Appearance", "roleFontUnit", "CinzelUnit")
	assert(K.Store.SetProfile("Default"))
	assert(K.Theme.RoleFont("unit") == "" and file((K.Tokens.Font("caps"))) == "CinzelCaps-Medium.ttf", "switching back restores the first profile's choices, not the second's")
	assert(K.Store.SetProfile("Plain"))
	assert(file((K.Tokens.Font("unit"))) == "CinzelUnit-Medium.ttf", "and the second profile's own")
	Core.Logout(env)
	assert(saved.profiles.Default.Appearance.roleFontCaps == "CinzelCaps" and saved.profiles.Default.Appearance.roleFontBody == CUSTOM, "logout keeps the saved paths exactly")
	assert(saved.profiles.Default.Appearance.font == "InterSemiBold", "the whole-interface choice is untouched")
	assert(saved.profiles.Plain.Appearance.roleFontUnit == "CinzelUnit", "the other profile saved its own choice")
	local env2, K2 = Core.New({ saved = saved })
	Core.Boot(env2)
	assert(K2.Store.ProfileName() == "Plain" and file((K2.Tokens.Font("unit"))) == "CinzelUnit-Medium.ttf" and K2.Theme.RoleFont("caps") == "", "a reload applies the active profile's choices again")
	assert(K2.Store.SetProfile("Default") and file((K2.Tokens.Font("caps"))) == "CinzelCaps-Medium.ttf", "and the other profile's after a switch")
	assert(#env._errors == 0 and #env2._errors == 0)
end

-- Export and import carry the choices.
do
	local env, K = W.New()
	K.Options.Write("Appearance", "roleFontBody", "InterSemiBold")
	K.Options.Write("Appearance", "roleFontNames", "CinzelNames")
	local text = K.Store.Export()
	local env2, K2 = W.New()
	local ok, err = K2.Store.Import(text, "Shared")
	assert(ok, tostring(err))
	assert(K2.Store.Profile().Appearance.roleFontBody == "InterSemiBold" and K2.Store.Profile().Appearance.roleFontNames == "CinzelNames", "an imported profile keeps the role choices")
	assert(#env._errors == 0 and #env2._errors == 0)
end

-- A non-Latin client keeps the client's face for KstyleUI's Latin-only faces, but not for a custom path.
do
	local _, K = W.New({ setup = function(e)
		e.GetLocale = function()
			return "zhCN"
		end
	end })
	K.Options.Write("Appearance", "roleFontNames", "CinzelNames")
	assert(K.Tokens.Font("names") == "Fonts\\ARKai_T.ttf", "a Latin-only role face gives way to the client's font")
	K.Options.Write("Appearance", "roleFontNames", CUSTOM)
	assert(K.Tokens.Font("names") == CUSTOM, "a custom path is the player's own responsibility")
end

-- The settings rows: one per role, Inherit first, every shipped face once, shared media after.
do
	local shared = "Interface\\AddOns\\SharedMedia\\Fonts\\Handwriting.ttf"
	local lsm = {}
	function lsm:Register() return true end
	function lsm:List() return { "Handwriting" } end
	function lsm:Fetch() return shared end
	local env, K = W.New({ setup = function(e)
		e.LibStub = function(major)
			if major == "LibSharedMedia-3.0" then
				return lsm
			end
		end
	end })
	local schema = K.Options.Get("Appearance")
	local at
	for i, row in ipairs(schema) do
		if row.key == "fontScale" then
			at = i
		end
	end
	assert(schema[at + 1].type == "header" and schema[at + 1].label == K.L["Fonts by role"], "a Fonts by role section follows the text size")
	assert(schema[at + 2].type == "note" and schema[at + 2].label:find("equal%-width figures") and schema[at + 2].label:find("adds no spacing"), "the note says the font may lack glyphs and figures and gets no added spacing")
	for i, role in ipairs(ROLES) do
		local row = schema[at + 2 + i]
		assert(row.key == key(role) and row.type == "font" and #row.help < 100, role .. " has a font row with short help")
		local options = row.options()
		assert(options[1].value == "" and options[1].label == K.L["Interface font"], role .. " offers the Interface font first, as every module font row does")
		local plumbing = K.Widgets.InheritedFontOptions()
		assert(#plumbing == #options, role .. " lists what the shared font plumbing lists")
		for n, option in ipairs(plumbing) do
			assert(options[n].value == option.value and options[n].label == option.label, role .. " option " .. n .. " is the shared plumbing's")
		end
		assert(#options == 1 + 18 + 1 and options[#options].value == shared, role .. " offers 18 shipped faces then shared fonts")
		for _, option in ipairs(options) do
			assert(option.value ~= "Folio" and option.value ~= "Lumen", "no type set is a face")
		end
	end
	assert(schema[at + 3 + #ROLES].type == "header", "the roles end before the next section")
	K.Options.Write("Appearance", "roleFontProse", shared)
	assert(K.Tokens.Font("prose") == shared, "a shared font can be chosen for a role")
	local faces = K.Options.Row("Appearance", "font").options()
	assert(#faces == 1 + 18 + 1, "the whole-interface list offers every shipped face too")
	assert(#env._errors == 0)
end

-- Every shipped face is individually selectable, once.
do
	local _, K = W.New()
	local list = K.Tokens.MediaList("font")
	local seen, files, labels = {}, {}, {}
	for _, face in ipairs(list) do
		local id = face.path:lower():gsub("/", "\\")
		assert(not seen[id], "no duplicate path " .. face.path)
		seen[id] = true
		assert(face.key and face.label and face.label ~= "" and face.path:match("^Interface\\AddOns\\KstyleUI\\Media\\Fonts\\"), "each face has a key, a label and its own path")
		assert(not labels[face.label], "no duplicate label " .. face.label)
		labels[face.label] = true
		files[#files + 1] = file(face.path)
		assert(K.Theme.SetFontFace(face.key), face.key .. " is accepted as a face")
		assert(K.Theme.SetRoleFonts({ body = face.key }) and K.Tokens.Font("body") == face.path, face.key .. " is accepted as a role font")
	end
	K.Theme.SetFontFace("")
	K.Theme.SetRoleFonts({})
	assert(#list == 18, "all eighteen shipped faces are listed")
	table.sort(files)
	local want = {}
	for i, name in ipairs(SHIPPED) do
		want[i] = name
	end
	table.sort(want)
	assert(table.concat(files, ",") == table.concat(want, ","), "the list is exactly the shipped files: " .. table.concat(files, ","))
	local listing = io.popen and io.popen("ls Media/Fonts 2>/dev/null")
	if listing then
		local onDisk = {}
		for line in listing:lines() do
			if line:match("%.ttf$") then
				onDisk[#onDisk + 1] = line
			end
		end
		listing:close()
		if #onDisk > 0 then
			table.sort(onDisk)
			assert(table.concat(onDisk, ",") == table.concat(want, ","), "every .ttf in Media/Fonts is selectable and none listed is missing")
		end
	end
	assert(#K.Tokens.FontRoles() == 13)
end

-- LibSharedMedia: a refused or false registration is retried at the next loading screen, only for what failed, and never cached as done.
do
	local calls, refuse = {}, {}
	local lsm = {}
	function lsm:Register(kind, name)
		calls[#calls + 1] = kind .. ":" .. name
		if refuse[name] == "false" then
			return false
		end
		if refuse[name] == "error" then
			error("refused")
		end
		return true
	end
	local env = Core.New({ setup = function(e)
		e.LibStub = function(major)
			if major == "LibSharedMedia-3.0" then
				return lsm
			end
		end
	end })
	refuse["KstyleUI Cinzel Caps Medium"] = "false"
	refuse["KstyleUI Flat"] = "error"
	Core.Boot(env)
	local function count(name)
		local n = 0
		for _, call in ipairs(calls) do
			if call:find(name, 1, true) then
				n = n + 1
			end
		end
		return n
	end
	assert(#calls == 18 + 3, "login registers all eighteen fonts and three bars once: " .. #calls)
	assert(count("Cinzel Caps Medium") == 1 and count("KstyleUI Soft") == 1)
	local before = #calls
	env.FireEvent("PLAYER_ENTERING_WORLD")
	assert(#calls == before + 2 and count("Cinzel Caps Medium") == 2 and count("KstyleUI Flat") == 2, "a false or failed registration is tried again, and only that one")
	assert(count("KstyleUI Soft") == 1 and count("Inter SemiBold") == 1, "registrations that worked are not repeated")
	refuse["KstyleUI Cinzel Caps Medium"] = nil
	refuse["KstyleUI Flat"] = nil
	before = #calls
	env.FireEvent("PLAYER_ENTERING_WORLD")
	assert(#calls == before + 2 and count("Cinzel Caps Medium") == 3, "it keeps trying until the library accepts")
	before = #calls
	env.FireEvent("PLAYER_ENTERING_WORLD")
	env.FireEvent("PLAYER_ENTERING_WORLD")
	assert(#calls == before, "then stops")
	assert(#env._errors == 0, "a refusing library is never a KstyleUI error")
end

-- A library that is missing at login needs no retry and raises nothing.
do
	local env = Core.New({})
	Core.Boot(env)
	env.FireEvent("PLAYER_ENTERING_WORLD")
	assert(#env._errors == 0)
end

-- The tracking rule: no synthetic tracking for a face the kit did not build.
do
	local _, K = W.New()
	local L, T = K.Locale, K.Tokens
	assert(L.SPACED == true, "the test client is a Latin client")
	for _, face in ipairs({ "SourceSans3Semibold", "SourceSans3Regular", "InterSemiBold", "PTSerifRegular", "PTSerifBold", "FolioDisplay", "AlegreyaSansProse" }) do
		assert(L.TrackMode(T.FontPath(face)) == nil and L.CanTrack(T.FontPath(face)) == false, face .. " is no kit-built face and gets no thin spaces")
	end
	for _, face in ipairs({ "AlegreyaSansRegular", "AlegreyaSansMedium", "AlegreyaSansBold", "AlegreyaSansExtraBold" }) do
		assert(L.TrackMode(T.FontPath(face)) == "space", face .. " is the kit's tabular Alegreya and keeps its spacing")
	end
	for _, face in ipairs({ "CinzelCaps", "CinzelNames", "CinzelUnit", "FolioCaps" }) do
		assert(L.TrackMode(T.FontPath(face)) == "face", face .. " is kit-built tracked caps")
	end
	local cinzel = T.FontPath("CinzelCaps")
	local folder = #cinzel - #"CinzelCaps-Medium.ttf"
	assert(L.TrackMode(cinzel:sub(1, folder):lower() .. cinzel:sub(folder + 1)) == "face" and L.TrackMode((cinzel:gsub("\\", "/"))) == "face", "the folder compares without case or slash direction")
	assert(L.TrackMode("Interface\\AddOns\\OtherMedia\\KstyleUI\\Media\\Fonts\\CinzelCaps-Medium.ttf") == nil, "a look-alike file in another addon is not ours")
	assert(L.TrackMode("Interface\\AddOns\\KstyleUI\\Media\\Fonts\\Unknown.ttf") == nil, "nor is an unlisted file")

	assert(K.Theme.SetTypeSet("Lumen"))
	assert(select(1, T.TextStyle("caption")) == 0.6 and L.TrackMode((T.Font("caption"))) == "space", "Lumen keeps its built Alegreya caption tracking")
	K.Options.Write("Appearance", "roleFontCaption", "InterSemiBold")
	assert(select(1, T.TextStyle("caption")) == 0 and L.TrackMode((T.Font("caption"))) == nil, "an unmodified bundled face chosen for the role gets none")
	K.Options.Write("Appearance", "roleFontCaption", "")
	K.Options.Write("Appearance", "font", "SourceSans3Semibold")
	assert(select(1, T.TextStyle("caption")) == 0 and L.TrackMode((T.Font("caption"))) == nil, "nor does one chosen for the whole interface")
end

print("role fonts ok")
