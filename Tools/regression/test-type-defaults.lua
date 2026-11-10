-- test-type-defaults.lua: type-set defaults that follow the kit (chat size and spacing, the small-note size, the follow-kit helper), projected slider rows and their validation.
local C = dofile("Tools/regression/chat_env.lua")
local CoreEnv = dofile("Tools/regression/core_env.lua")
local Raises, Module = CoreEnv.Raises, CoreEnv.Module

local function chat(env, K)
	return K.Store.Module("Chat")
end

-- Never-chosen size and spacing follow the type set, and the sliders paint the value that is drawn.
do
	local env, K, ns = C.New()
	assert(K.Theme.TypeSet() == "Folio")
	local s = chat(env, K)
	assert(s.fontSize == ns.FOLLOW and s.lineSpacing == ns.FOLLOW, "the stored defaults are the inheritance sentinel")
	assert(ns.TextSize(s) == 12 and ns.LineSpacing(s) == 6.5, "Folio draws 12 and 6.5")
	local size, spacing = K.Options.Row("Chat", "fontSize"), K.Options.Row("Chat", "lineSpacing")
	assert(size.shown(s.fontSize) == 12 and spacing.shown(s.lineSpacing) == 6.5, "the sliders paint Folio's values")
	assert(size.shown(15) == 15 and spacing.shown(0) == 0, "a chosen value paints as itself, a chosen zero included")
	assert(K.Theme.SetTypeSet("Lumen"))
	assert(ns.TextSize(s) == 14 and ns.LineSpacing(s) == 4.5, "Lumen draws the values it had before Folio: 14 and 4.5")
	assert(size.shown(s.fontSize) == 14 and spacing.shown(s.lineSpacing) == 4.5, "and the sliders follow")
	assert(K.Tokens.TypeDefault("chatSize") == 14 and K.Tokens.TypeDefault("noteSize") == 12)
	assert(K.Tokens.TypeDefault("tooltipTitle") == "heading" and K.Tokens.TypeDefault("tooltipName") == "heading", "Lumen's tooltip titles keep the heading role")
	assert(K.Theme.SetTypeSet("Folio"))
	assert(K.Tokens.TypeDefault("noteSize") == 10)
	assert(K.Tokens.TypeDefault("tooltipTitle") == "body" and K.Tokens.TypeDefault("tooltipName") == "names", "Folio's tooltip titles are body, its names the names role")
	Raises(function() K.Tokens.TypeDefault("nothing") end, "unknown name")
end

-- A chosen value wins on its own, equal to a default or not, with the module off, across logout, reload and profiles.
do
	local env, K, ns = C.New()
	assert(not K.Modules.IsRunning("Chat"), "the module is off")
	K.Options.Write("Chat", "fontSize", 12)
	local s = chat(env, K)
	assert(s.fontSize == 12 and s.lineSpacing == ns.FOLLOW, "a write while the module is off persists, and only that value is chosen")
	CoreEnv.Logout(env)
	local saved = env.KstyleUIDB.profiles.Default
	assert(saved.Chat and saved.Chat.fontSize == 12 and saved.Chat.lineSpacing == nil, "the chosen 12 is saved though it equals Folio's size; spacing is not")
	local _, K2, ns2 = C.New({ saved = env.KstyleUIDB })
	local s2 = K2.Store.Module("Chat")
	assert(s2.fontSize == 12 and s2.lineSpacing == ns2.FOLLOW, "reload keeps the choice and the inheritance")
	assert(K2.Theme.SetTypeSet("Lumen"))
	assert(ns2.TextSize(s2) == 12 and ns2.LineSpacing(s2) == 4.5, "Lumen keeps the chosen 12 and draws its own spacing")
	K2.Options.Write("Chat", "lineSpacing", 6.5)
	assert(ns2.LineSpacing(s2) == 6.5, "a chosen 6.5 beats Lumen's 4.5 independently")
	K2.Options.Write("Chat", "fontSize", ns2.FOLLOW)
	assert(ns2.TextSize(s2) == 14, "writing the sentinel back resets to inheritance")
end

-- Profiles keep the sentinel and the chosen values apart, through export, import and a switch.
do
	local _, K = C.New()
	K.Options.Write("Chat", "lineSpacing", 4.5)
	local text = K.Store.Export("Default")
	local _, K2, ns2 = C.New()
	assert(K2.Store.Import(text, "Copy"))
	assert(K2.Store.SetProfile("Copy"))
	local s = K2.Store.Module("Chat")
	assert(s.lineSpacing == 4.5 and s.fontSize == ns2.FOLLOW, "an imported profile carries the chosen value and the inheritance")
	assert(K2.Theme.SetTypeSet("Lumen") and ns2.LineSpacing(s) == 4.5 and ns2.TextSize(s) == 14)
	assert(K2.Store.SetProfile("Default"))
	assert(ns2.LineSpacing(K2.Store.Module("Chat")) == 6.5 and K2.Theme.TypeSet() == "Folio", "the profile with nothing chosen follows its own type set, Folio, when it becomes active")
end

-- A tab-menu pick (Forever calls FCF_SetChatWindowFontSize(nil, frame, height)) is a choice, even equal to the inherited size.
-- Blizzard's own copy and reset of a window are not.
do
	local env, K, ns = C.New()
	C.Enable(env, K)
	local s = chat(env, K)
	env.FCF_CopyChatSettings(env.ChatFrame2, env.ChatFrame1)
	env.FCF_ResetChatWindow(env.ChatFrame1)
	env.FCF_ResetChatWindows()
	env.RunTimers()
	assert(s.fontSize == ns.FOLLOW, "copying and resetting windows choose nothing")
	env.FCF_SetChatWindowFontSize(nil, env.ChatFrame1, 12)
	env.RunTimers()
	assert(s.fontSize == 12, "a menu pick equal to the inherited size is still a choice")
	K.Options.Write("Appearance", "typeSet", "Lumen")
	assert(ns.TextSize(s) == 12, "and Lumen no longer changes it")
	CoreEnv.Logout(env)
	assert(env.KstyleUIDB.profiles.Default.Chat.fontSize == 12, "it is saved")
	local _, K2, ns2 = C.New({ saved = env.KstyleUIDB })
	assert(K2.Theme.TypeSet() == "Lumen" and ns2.TextSize(K2.Store.Module("Chat")) == 12, "and survives a reload under Lumen")
	K.Options.Write("Chat", "fontSize", ns.FOLLOW)
	K.Options.Write("Appearance", "typeSet", "Folio")
	env.FCF_SetChatWindowFontSize(nil, env.ChatFrame1, 16)
	env.RunTimers()
	assert(s.fontSize == 16, "a menu pick that differs is the player's choice")
	env.FCF_SetChatWindowFontSize({ value = 18 }, env.ChatFrame1, nil)
	env.RunTimers()
	assert(s.fontSize == 18, "the legacy button signature still works")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Import accepts the declared sentinel for a projected row and nothing else out of range.
do
	local _, K, ns = C.New()
	local function try(chatSettings)
		return K.Store.Import(CoreEnv.CraftLua({ kind = "KstyleUI profile", version = K.Store.DB_VERSION, name = "Probe", settings = { Chat = chatSettings } }))
	end
	assert(try({ fontSize = ns.FOLLOW, lineSpacing = ns.FOLLOW }), "the exact sentinel imports")
	assert(try({ fontSize = 12, lineSpacing = 0 }), "in-range values import")
	local ok, err = try({ fontSize = -2 })
	assert(not ok and err:find("out of range", 1, true), "-2 is refused: " .. tostring(err))
	ok, err = try({ lineSpacing = -2 })
	assert(not ok and err:find("out of range", 1, true), "-2 spacing is refused: " .. tostring(err))
	ok = try({ fontSize = 1e9 })
	assert(not ok, "a huge size is refused")
	ok = try({ fontSize = 7 })
	assert(not ok, "an out-of-range size is refused")
	ok = try({ fontSize = 0 / 0 })
	assert(not ok, "NaN is refused")
end

-- A slider row with shown is validated when it registers.
do
	local function fresh(defaults)
		local _, K = CoreEnv.New()
		K.Modules.Register(Module("UnitFrames", { defaults = defaults }))
		return K
	end
	local function row(extra)
		local out = { type = "slider", key = "size", label = "Size", help = "A size.", min = 8, max = 24, step = 1 }
		for k, v in pairs(extra) do
			out[k] = v
		end
		return out
	end
	local K = fresh({ size = -1 })
	assert(pcall(K.Options.Register, "UnitFrames", { row({ shown = function() return 12 end }) }), "a projected default registers")
	K = fresh({ size = -1 })
	Raises(function() K.Options.Register("UnitFrames", { row({}) }) end, "outside the slider's range")
	K = fresh({ size = -1 })
	Raises(function() K.Options.Register("UnitFrames", { row({ shown = 12 }) }) end, "shown must be a function")
	K = fresh({ size = -1 })
	Raises(function() K.Options.Register("UnitFrames", { row({ shown = function() return 99 end }) }) end, "painted default")
	K = fresh({ size = -1 })
	Raises(function() K.Options.Register("UnitFrames", { row({ shown = function() return 0 / 0 end }) }) end, "finite number")
	K = fresh({ size = -1 })
	Raises(function() K.Options.Register("UnitFrames", { row({ shown = function() return math.huge end }) }) end, "finite number")
	K = fresh({ size = -1 })
	Raises(function() K.Options.Register("UnitFrames", { row({ shown = function() return "12" end }) }) end, "finite number")
	K = fresh({ size = -1 })
	Raises(function() K.Options.Register("UnitFrames", { row({ shown = function() error("boom") end }) }) end, "finite number")
end

-- The small-note size is data of the type set, scaled and floored by the same rules as the roles, and independent of role fonts.
do
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	local T = K.Tokens
	local function note()
		local path, size, flags = T.NoteFont()
		return path, size, flags
	end
	local path, size, flags = note()
	assert(size == 10 and path == T.Font("body") and flags == "", "Folio draws notes at 10 in its body face")
	K.Options.Write("Appearance", "roleFontBody", "InterSemiBold")
	K.Options.Write("Appearance", "roleFontCaps", "CinzelCaps")
	path, size = note()
	assert(size == 10 and path:find("Inter%-SemiBold"), "a role font changes the face and never the declared size")
	K.Options.Write("Appearance", "font", "SourceSans3Semibold")
	assert(select(2, note()) == 10, "nor does a whole-interface font")
	K.Options.Write("Appearance", "typeSet", "Lumen")
	assert(select(2, note()) == 12, "Lumen draws notes at its 12")
	local low, high = K.Theme.MIN_FONT_SCALE, K.Theme.MAX_FONT_SCALE
	assert(K.Theme.SetFontScale(low))
	assert(select(2, note()) == math.max(10, 12 * low), "the scaled size never goes below the text floor")
	assert(K.Theme.SetFontScale(high))
	assert(select(2, note()) == 12 * high, "and scales with the text size setting")
	K.Options.Write("Appearance", "typeSet", "Folio")
	assert(K.Theme.SetFontScale(low))
	assert(select(2, note()) == 10, "Folio's 10 is the floor itself, so no scale lowers it")
end

-- No module reads the type set's name to size its notes, and the loot feed's short label is data.
do
	for _, file in ipairs({ "Core/Setup/Window.lua", "KstyleUI_Skins/PartB/Merchant.lua" }) do
		local handle = assert(io.open(file, "rb"))
		local text = handle:read("*a")
		handle:close()
		assert(not text:find('FontFace%(%)'), file .. " must not branch on the type set's name")
		assert(not text:find('"qol%.lootfeed"'), file .. " must not special-case an element")
	end
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	local element = K.Setup.Layouts.Element("qol.lootfeed")
	assert(element and element.short == K.L["Loot"], "the loot feed declares its short label")
end

-- One helper decides whether a saved font follows the kit.
do
	local env, K = CoreEnv.New()
	local follows = K.Theme.FollowsKit
	assert(follows(env.Secret("Interface\\AddOns\\Other\\Font.ttf")) == true and follows(env.Secret("theme")) == true, "a secret value is never compared: it inherits")
	for _, value in ipairs({ "", "theme", "kit" }) do
		assert(follows(value) == true, "the saved " .. string.format("%q", value) .. " follows the kit")
	end
	assert(follows(nil) == true and follows(5) == true and follows(false) == true and follows({}) == true, "a malformed value is no path")
	assert(follows("Interface\\AddOns\\Other\\Font.ttf") == false and follows("Fonts\\FRIZQT__.TTF") == false and follows("Theme") == false and follows("Kit") == false, "a path, and a name that only looks like a keyword, is a choice")
end

print("type defaults ok")
