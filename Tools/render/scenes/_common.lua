-- _common.lua: what every scene script shares: the owner's screen, the scene writer and the run-or-return switch.
--
--   local Common = dofile("Tools/render/scenes/_common.lua")
--   return Common.Run(function() ... return scene end)
--
-- Run(build) builds and writes the scene as JSON to arg[1] (or stdout) when the script runs as a program.
-- When a test loads the script with RENDER_SCENE_LIB set, Run returns the builder instead.
local Common = {}

Common.Scene = dofile("Tools/render/scene.lua")

function Common.PreviousFinish()
	return os.getenv("RENDER_FINISH") == "previous"
end

function Common.FinishSettings(profile)
	if os.getenv("RENDER_NEEDS_OFF") == "1" then
		profile.ActionBars = profile.ActionBars or {}
		profile.ActionBars.bindingHints = false
		profile.ActionBars.bar3 = profile.ActionBars.bar3 or {}
		profile.ActionBars.bar3.finished = false
		profile.ColorVision = profile.ColorVision or {}
		profile.ColorVision.mode = "standard"
	end
	for key, name in pairs({ vignette = "RENDER_VIGNETTE", ambient = "RENDER_AMBIENT" }) do
		if os.getenv(name) == "off" then
			profile.Medallions = profile.Medallions or {}
			profile.Medallions[key] = false
		end
	end
	if os.getenv("RENDER_SNAP_EDGES") == "0" then
		profile.Appearance = profile.Appearance or {}
		profile.Appearance.snapEdges = false
	end
	if not Common.PreviousFinish() then return profile end
	local previous = {
		Skins = { steelButtons = false, windowMetrics = false, quests = { continuation = false }, restedXP = { compose = false } },
		Meters = { fitCards = false },
		DataBars = { strip = { dockMeter = false } },
		Minimap = { clearPlaques = false },
		Bags = { separateFigures = false, readableHeaders = false },
		ActionBars = { crestJewels = false },
		UnitFrames = { slabCaps = false },
		Medallions = { restingCrest = false },
	}
	local function merge(target, values)
		for key, value in pairs(values) do
			if type(value) == "table" then
				target[key] = target[key] or {}
				merge(target[key], value)
			else
				target[key] = value
			end
		end
	end
	merge(profile, previous)
	return profile
end

-- The owner's Mac: the game renders 2383 by 1540, so one screen unit is 1540 / 1080 = 1.426 pixels. The UI
-- scale is WoW's default, 768 / 1080, so UIParent is 1080 units tall too and Blizzard's frames share the
-- root's units.
--
-- RENDER_SCREEN picks another screen: "1920x1080", or "3840x2160@0.65" to name UIParent's scale too (the default
-- is WoW's, 768 / 1080). RENDER_SIZE is the Interface size: a number, or "auto" for the automatic pixel-perfect size that ships; unset, scenes
-- draw the size KstyleUI shipped before it (16 / 19, exactly), which the reference measurements were taken at. A test
-- that builds several screens in one process sets the globals RENDER_SCREEN ({ width, height, uiScale, size })
-- before it loads the scene scripts, as it sets RENDER_SCENE_LIB.
Common.DEFAULT_SCREEN = { width = 2383, height = 1540, uiScale = 768 / 1080 }
do
	local picked
	local spec = os.getenv("RENDER_SCREEN")
	if spec and spec ~= "" then
		local w, h, s = spec:match("^(%d+)x(%d+)@?([%d%.]*)$")
		assert(w, "RENDER_SCREEN must be WIDTHxHEIGHT or WIDTHxHEIGHT@UISCALE, not " .. spec)
		picked = { width = tonumber(w), height = tonumber(h), uiScale = tonumber(s) }
	end
	local size = os.getenv("RENDER_SIZE") == "auto" and "auto" or tonumber(os.getenv("RENDER_SIZE") or "")
	if size then
		picked = picked or {}
		picked.size = size
	end
	if type(picked) == "table" then
		Common.DEFAULT_SCREEN = {
			width = picked.width or Common.DEFAULT_SCREEN.width, height = picked.height or Common.DEFAULT_SCREEN.height,
			uiScale = picked.uiScale or Common.DEFAULT_SCREEN.uiScale, size = picked.size,
		}
	end
end
Common.SCREEN = setmetatable({}, {
	__index = function(_, key)
		local screen = rawget(_G, "RENDER_SCREEN")
		if type(screen) == "table" and screen[key] ~= nil then
			return screen[key]
		end
		return Common.DEFAULT_SCREEN[key]
	end,
})

-- The warrior's class colour, as the game's RAID_CLASS_COLORS gives it.
Common.WARRIOR = { 0.78, 0.61, 0.43 }

-- Stand-ins Tools/render/standins.py cuts out of the owner's mockup: the portraits, the minimap's
-- terrain and the backdrop. A scene uses one when its file exists and falls back to a flat colour.
Common.STANDINS = "Tools/render/out/standins"

local function fileExists(path)
	local f = io.open(path, "rb")
	if f then
		f:close()
		return true
	end
	return false
end

-- StandIn(name) -> the stand-in's repository-relative path, or nil when standins.py has not made it.
function Common.StandIn(name)
	local path = Common.STANDINS .. "/" .. name
	if fileExists(path) then
		return path
	end
	return nil
end

-- ImageAspect(path) -> width / height of a PNG, read from its IHDR chunk, or nil when the file is not a PNG.
function Common.ImageAspect(path)
	local file = io.open(path, "rb")
	if not file then
		return nil
	end
	local head = file:read(24)
	file:close()
	if type(head) ~= "string" or #head < 24 or head:sub(1, 8) ~= "\137PNG\r\n\26\n" then
		return nil
	end
	local function u32(at)
		local a, b, c, d = head:byte(at, at + 3)
		return ((a * 256 + b) * 256 + c) * 256 + d
	end
	local width, height = u32(17), u32(21)
	if width <= 0 or height <= 0 then
		return nil
	end
	return width / height
end

-- Icons: one rule for every scene. A numeric icon file ID draws set B's repaint when the pack has it
-- (Tools/icons/setB/Icons, what a player with the pack installed sees for every icon, the aura tiles
-- included), else Blizzard's own icon from the extract cache; CI has neither folder and draws a flat box.
local BLIZZARD_ICONS = (os.getenv("HOME") or "") .. "/.local/share/wow-dev/icons/blizzard"

function Common.IconDirs()
	return { "Tools/icons/setB/Icons", BLIZZARD_ICONS }
end

function Common.ScreenOpts(extra)
	local opts = { width = Common.SCREEN.width, height = Common.SCREEN.height, uiScale = Common.SCREEN.uiScale, size = Common.SCREEN.size or "default" }
	for k, v in pairs(extra or {}) do
		opts[k] = v
	end
	return opts
end

-- ForceScreen(env) gives any environment the owner's screen, whatever options its loader passed on. Call it
-- from the loader's setup hook, after Stubs.NewEnv has made UIParent and before the addon loads.
function Common.ForceScreen(env, completePreset)
	-- RENDER_HUD_STYLE (Frames or Medallions) is the saved HUD style of every profile the scene loads that names none.
	local style = rawget(_G, "RENDER_HUD_STYLE") or os.getenv("RENDER_HUD_STYLE")
	local db = rawget(env, "KstyleUIDB")
	if os.getenv("RENDER_SLAB_FINISH") == "off" and type(db) == "table" and type(db.profiles) == "table" then
		for _, profile in pairs(db.profiles) do
			profile.ActionBars = profile.ActionBars or {}
			for _, key in ipairs({ "quietSockets", "quietCooldown", "readableCountdown", "seatedCrest" }) do profile.ActionBars[key] = false end
			profile.Cooldowns = profile.Cooldowns or {}
			for _, key in ipairs({ "quietCooldown", "readableCountdown", "medallionsIcons" }) do profile.Cooldowns[key] = false end
			profile.Auras = profile.Auras or {}
			profile.Auras.medallionsIcons = false
			profile.GroupFrames = profile.GroupFrames or {}
			profile.GroupFrames.layout = { tidyLanes = false }
		end
	end
	if os.getenv("RENDER_CAST_ON_FRAME") == "off" and type(db) == "table" and type(db.profiles) == "table" then
		for _, profile in pairs(db.profiles) do
			profile.UnitFrames = profile.UnitFrames or {}
			profile.UnitFrames.castbarOnFrame = false
		end
	end
	local readability = rawget(_G, "RENDER_READABILITY") or os.getenv("RENDER_READABILITY")
	if readability == "off" and type(db) == "table" and type(db.profiles) == "table" then
		for _, profile in pairs(db.profiles) do
			profile.Appearance = profile.Appearance or {}
			for _, key in ipairs({ "readableBars", "worldText", "chatTabs", "barColors" }) do profile.Appearance[key] = false end
		end
	end
	if style and style ~= "" and type(db) == "table" and type(db.profiles) == "table" then
		for _, profile in pairs(db.profiles) do
			if type(profile) == "table" and profile.HudStyle == nil then
				profile.HudStyle = { style = style:lower() }
			end
		end
	end
	env._materialChromes = env._materialChromes or {}
	local material = os.getenv("RENDER_CARD_MATERIAL")
	env._renderCardMaterial = material and material ~= "" and material or nil
	-- RENDER_CHAT_FRAMING (auto, card or bare) is the chat's saved framing, so a scene shows the bare chat the Orbs
	-- HUD style gives it, or a framing the player picked.
	local framing = os.getenv("RENDER_CHAT_FRAMING")
	env._renderChatFraming = framing and framing ~= "" and framing or nil
	-- RENDER_ARRANGEMENT (centred or spread) is the saved ultrawide arrangement, as a global or in the environment.
	local arrangement = rawget(_G, "RENDER_ARRANGEMENT") or os.getenv("RENDER_ARRANGEMENT")
	env._renderArrangement = arrangement and arrangement ~= "" and arrangement or nil
	-- RENDER_ORNAMENTS (Off, Subtle or Full) is the ornament level a scene draws at. A scene draws Off unless it
	-- names a level, so hud_reference, the measurements and the galleries keep their meaning; a test that builds
	-- several levels in one process sets the global RENDER_ORNAMENTS instead. env._ornamentHandles collects every
	-- ornament the addon attaches, for Scene.Build to restyle at the rects it solves.
	local ornaments = rawget(_G, "RENDER_ORNAMENTS") or os.getenv("RENDER_ORNAMENTS")
	env._renderOrnaments = ornaments and ornaments ~= "" and ornaments or "Off"
	env._ornamentHandles = env._ornamentHandles or {}
	local width, height, uiScale = Common.SCREEN.width, Common.SCREEN.height, Common.SCREEN.uiScale
	-- A scene shows the HUD at the Interface size KstyleUI ships, not the tests' size 1 (Stubs.NewEnv).
	env._size = Common.SCREEN.size or "default"
	env._fitScale = true
	if env._size == "auto" and completePreset then
		local fire = env.FireEvent
		env.FireEvent = function(...)
			local K = env.KstyleUI
			if K and K.Setup and K.Setup.Layouts then
				local layouts = K.Setup.Layouts
				local limit = layouts.ScaleLimit
				layouts.ScaleLimit = function(w, h, preset, _, hudStyle)
					local enabled = layouts.Enabled(preset)
					local choice = rawget(_G, "RENDER_METER_CHOICE") or os.getenv("RENDER_METER_CHOICE")
					if choice then
						enabled["meters.damage"], enabled["meters.threat"] = choice ~= "threat", choice ~= "damage"
					end
					if (rawget(_G, "RENDER_BAR3") or os.getenv("RENDER_BAR3")) == "1" then
						enabled["actionbars.bar3"] = true
					end
					return limit(w, h, preset, enabled, hudStyle)
				end
				env.FireEvent = fire
			end
			return fire(...)
		end
	end
	env.GetPhysicalScreenSize = function()
		return width, height
	end
	env.UIParent._scale = uiScale
	env.UIParent._width, env.UIParent._height = 768 * width / height / uiScale, 768 / uiScale
	-- RENDER_LOCALE (deDE, frFR, esES, zhCN, ...) renders the scene as a client of that locale sees it; a test
	-- that builds several locales in one process sets the global RENDER_LOCALE instead, as it sets RENDER_SCENE_LIB.
	local locale = rawget(_G, "RENDER_LOCALE") or os.getenv("RENDER_LOCALE")
	if locale and locale ~= "" then
		env.GetLocale = function()
			return locale
		end
	end
	-- Font strings measure their text as the page draws it (the kit fonts' glyph advances, escapes such as
	-- colour codes and links skipped, as the game skips them), so a module that sizes to GetUnboundedStringWidth
	-- lays out in the render as it does in the game.
	env._textWidth = function(text, fontPath, size)
		return Common.Scene.TextWidth(Common.Scene.PlainText(text), size, fontPath)
	end
end

-- Errors(env, K) -> the first error the stubs or KstyleUI caught, or nil.
-- ChatSettings(env, K): RENDER_CHAT_SETTINGS ("key=value;key=value") writes chat options the way the settings window
-- does, so a render shows options switched on. Values are true, false, numbers or text; nested keys use dots.
function Common.ChatSettings(env, K)
	-- The stand-in chat buttons have no art, so each gets a flat tile to show its slot. The voice toggles stay hidden,
	-- as the game keeps them while the player is logged out of voice chat (VoiceToggleButton.lua:17-21), from before
	-- the settings so the column is laid out without them, as the game's OnHide reflow leaves it.
	if os.getenv("RENDER_CHAT_SETTINGS") then
		for name, rgb in pairs({ QuickJoinToastButton = { 0.25, 0.6, 1 }, ChatFrameChannelButton = { 0.95, 0.7, 0.2 }, ChatFrameMenuButton = { 0.4, 0.85, 0.4 } }) do
			local tile = env[name] and env[name]:CreateTexture(nil, "ARTWORK")
			if tile then
				tile:SetAllPoints(env[name])
				tile:SetColorTexture(rgb[1], rgb[2], rgb[3], 0.7)
			end
		end
		for _, name in ipairs({ "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }) do
			if env[name] then env[name]:Hide() end
		end
	end
	for key, value in (os.getenv("RENDER_CHAT_SETTINGS") or ""):gmatch("([%w%.]+)=([^;]+)") do
		local parsed = value == "true" or (value ~= "false" and (tonumber(value) or value))
		assert(K.Options.Write("Chat", key, parsed) ~= false, "RENDER_CHAT_SETTINGS: Chat." .. key .. " did not write")
		env.RunTimers()
	end
end

function Common.Errors(env, K)
	if env._errors and env._errors[1] then
		return tostring(env._errors[1])
	end
	if K and type(K.ErrorCount) == "function" and K.ErrorCount() > 0 and type(K.Errors) == "function" then
		local list = K.Errors()
		return list and list[1] and tostring(list[1].message or list[1]) or "KstyleUI caught an error"
	end
	return nil
end

function Common.Write(scene, path)
	local json = Common.Scene.ToJSON(scene)
	if path then
		local f = assert(io.open(path, "wb"))
		f:write(json)
		f:close()
	else
		io.write(json)
	end
end

function Common.Run(build)
	if rawget(_G, "RENDER_SCENE_LIB") then
		return build
	end
	local scene = build()
	local path = arg and arg[1]
	if path then
		local Guard = dofile("Tools/render/guard.lua")
		Guard.WriteRaw(Guard.Check(scene), (path:gsub("%.json$", "")) .. ".guard.tsv")
	end
	Common.Write(scene, path)
	for _, line in ipairs(scene.log or {}) do
		io.stderr:write("log: " .. line .. "\n")
	end
	return scene
end

return Common
