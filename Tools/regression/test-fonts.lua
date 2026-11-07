-- test-fonts.lua: the core asks for every font KstyleUI may use while the game is loading, and says when a font needs a /reload.
-- The client this models loads a font file only when it is first asked for during a loading screen. A file first
-- asked for later fails for the rest of the session, so SetFont returns false.
local CoreEnv = dofile("Tools/regression/core_env.lua")

local SHARED = "Interface\\AddOns\\SomeMedia\\Fonts\\Shared.ttf"
local DEEP = "Interface\\AddOns\\SomeMedia\\Fonts\\Deep.otf"
local LATE = "Interface\\AddOns\\SomeMedia\\Fonts\\Late.ttf"
local TEXTURE = "Interface\\AddOns\\SomeMedia\\Bars\\Bar.blp"

-- A client that loads font files only while env._loading is true. env._asked counts the requests per path.
local function client(env)
	env._loading = true
	env._asked = {}
	local loaded = {}
	local create = env.CreateFont
	env.CreateFont = function(name)
		local font = create(name)
		font.SetFont = function(self, path)
			env._asked[path] = (env._asked[path] or 0) + 1
			self._path = path
			if not loaded[path] and env._loading then
				loaded[path] = true
			end
			return loaded[path] == true
		end
		return font
	end
end

local function saved(profile)
	return { version = 1, profiles = { Default = profile } }
end

local function booted(profile)
	local env, K = CoreEnv.New({ saved = saved(profile), setup = client })
	CoreEnv.Boot(env)
	env._loading = false
	return env, K
end

-- Every bundled face, and every font path in the saved profile, is asked for while the game loads, once each.
do
	local env, K = booted({
		Appearance = { font = "InterSemiBold" },
		Nameplates = { font = SHARED, bar = TEXTURE },
		Bags = { font = SHARED },
		GroupFrames = { text = { nested = { font = DEEP } } },
	})
	for _, item in ipairs(K.Tokens.MediaList("font")) do
		assert(env._asked[item.path], "the bundled face " .. item.label .. " is asked for at load")
		assert(K.Fonts.IsLoaded(item.path), item.label .. " loads")
	end
	assert(env._asked[SHARED] and env._asked[DEEP], "saved font paths at any depth are asked for at load")
	assert(K.Fonts.IsLoaded(SHARED) and K.Fonts.IsLoaded(DEEP), "they load")
	assert(env._asked[TEXTURE] == nil, "a texture path is not a font")
	local asked = env._asked[SHARED]
	K.Fonts.Request(SHARED)
	assert(env._asked[SHARED] == asked, "a loaded font is not asked for again")
	assert(#env._printed == 0, "nothing is printed when every font loads: " .. tostring(env._printed[1]))
end

-- A font first chosen after loading needs a /reload; KstyleUI says so once and keeps it for the next load.
do
	local env, K = booted({})
	K.Options.Write("Appearance", "font", LATE)
	assert(env._asked[LATE], "a newly chosen font is asked for at once")
	assert(not K.Fonts.IsLoaded(LATE), "the client refuses it until the next load")
	local line = CoreEnv.Printed(env, "Late.ttf")
	assert(line and line:find("/reload", 1, true), "the player is told the font shows after a /reload")
	local printed = #env._printed
	K.Options.Write("Appearance", "font", "SourceSans3Semibold")
	K.Options.Write("Appearance", "font", LATE)
	assert(#env._printed == printed, "the note is printed once per font")
	K.Options.Write("Appearance", "font", "InterSemiBold")
	assert(#env._printed == printed, "a bundled face loaded at login needs no note")
end

-- Switching to a profile whose fonts were not loaded asks for them and says which need a /reload.
do
	local env, K = CoreEnv.New({
		saved = { version = 1, profiles = { Default = {}, Raid = { Bags = { font = LATE } } } },
		setup = client,
	})
	CoreEnv.Boot(env)
	env._loading = false
	assert(env._asked[LATE] == nil, "another profile's fonts wait until it is used")
	K.Store.SetProfile("Raid")
	assert(env._asked[LATE], "the new profile's font is asked for")
	assert(CoreEnv.Printed(env, "Late.ttf"), "and the player is told it shows after a /reload")
end

-- A font that fails while the game loads, such as a removed addon's, is logged, not printed.
do
	local env, K = CoreEnv.New({
		saved = saved({ Bags = { font = LATE } }),
		setup = function(e)
			client(e)
			e._loading = false
		end,
	})
	CoreEnv.Boot(env)
	assert(not K.Fonts.IsLoaded(LATE))
	assert(CoreEnv.Printed(env, "Late.ttf") == nil, "a load-time failure is not printed")
end

-- A client without CreateFont, or a value that is not a font path, raises nothing.
do
	local env, K = CoreEnv.New({
		saved = saved({}),
		setup = function(e)
			e.CreateFont = nil
		end,
	})
	CoreEnv.Boot(env)
	assert(K.Fonts.Request(SHARED) == false, "no CreateFont means nothing loads, quietly")
	assert(K.Fonts.Request(TEXTURE) == false and K.Fonts.Request(nil) == false and K.Fonts.Request(7) == false)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("fonts ok")
