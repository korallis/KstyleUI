-- gallery_meters.lua: every frame KstyleUI_Meters draws, each cropped as one frame of the gallery: the damage
-- meter window with eight class-coloured rows, the threat meter with a party of five and the tank on top, the
-- swing timer's two bars mid-swing, the Meters page's live preview, and Blizzard's Damage Meter window restyled
-- in place (a second environment, since the restyle style hides KstyleUI's own window). The meter stand-ins
-- (meters_env.lua) hold a damage session, the party's threat and the swing speeds; Blizzard's window is a fake
-- with no layout of its own, so this scene places its header texts and rows.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Scene = Common.Scene

-- Blizzard's class colours, for the party's bars; the warrior's is the gallery's accent.
local CLASS_COLORS = {
	WARRIOR = Common.WARRIOR, MAGE = { 0.25, 0.78, 0.92 }, PRIEST = { 1, 1, 1 }, ROGUE = { 1, 0.96, 0.41 },
	HUNTER = { 0.67, 0.83, 0.45 }, PALADIN = { 0.96, 0.55, 0.73 }, DRUID = { 1, 0.49, 0.04 }, WARLOCK = { 0.53, 0.53, 0.93 },
}
local SOURCES = {
	{ "Kragar", "WARRIOR", 284200 },
	{ "Valerin", "WARRIOR", 247300 },
	{ "Sylaen", "PRIEST", 201400 },
	{ "Thargor", "ROGUE", 176200 },
	{ "Lunara", "MAGE", 158900 },
	{ "Brakk", "HUNTER", 142600 },
	{ "Elowen", "DRUID", 98400 },
	{ "Morgrim", "PALADIN", 61200 },
}
local PARTY = {
	{ "party1", "Kragar", "WARRIOR", { true, 3, 100, 100, 1240000 } },
	{ "player", "Valerin", "WARRIOR", { false, 1, 72, 68, 890000 } },
	{ "party2", "Thargor", "ROGUE", { false, 0, 66, 60, 820000 } },
	{ "party3", "Lunara", "MAGE", { false, 0, 58, 52, 720000 } },
	{ "party4", "Sylaen", "PRIEST", { false, 0, 41, 36, 510000 } },
}
local FIGHT_SECONDS = 100

local function abbreviate(n)
	if type(n) ~= "number" then
		return tostring(n)
	end
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fk", n / 1e3)
	end
	return tostring(math.floor(n + 0.5))
end

-- setup(env) gives the meter stand-ins the gallery's screen, the party's classes and readable numbers.
local function setup(env)
	Gallery.Setup(env)
	for class, c in pairs(CLASS_COLORS) do
		env.RAID_CLASS_COLORS[class] = { r = c[1], g = c[2], b = c[3] }
	end
	env.UnitClass = function(unit)
		local u = env._units[unit]
		if u and u.class then
			return u.class, u.class, 1
		end
		return "Warrior", "WARRIOR", 1
	end
	env.AbbreviateNumbers = abbreviate
	env.LOCALIZED_CLASS_NAMES_MALE = {
		WARRIOR = "Warrior", MAGE = "Mage", PRIEST = "Priest", ROGUE = "Rogue", HUNTER = "Hunter",
		PALADIN = "Paladin", DRUID = "Druid", WARLOCK = "Warlock",
	}
	env._units.player = { name = "Valerin", class = "WARRIOR" }
	env._speeds = { 2.6, 1.8, nil }
end

local function session()
	local sources, total = {}, 0
	for i, s in ipairs(SOURCES) do
		total = total + s[3]
		sources[i] = {
			name = s[1], classFilename = s[2], totalAmount = s[3], amountPerSecond = s[3] / FIGHT_SECONDS,
			sourceDisplayType = 1, isLocalPlayer = s[1] == "Valerin", deathRecapID = 0, deathTimeSeconds = 0,
		}
	end
	return { combatSources = sources, maxAmount = SOURCES[1][3], totalAmount = total, durationSeconds = FIGHT_SECONDS }
end

local function party(env)
	env._group = { raid = false, size = 4 }
	env._units.target = { name = "Riverglade Crocolisk", hostile = true }
	for _, member in ipairs(PARTY) do
		if member[1] ~= "player" then
			env._units[member[1]] = { name = member[2], class = member[3] }
		end
		env._threat[member[1]] = member[4]
	end
end

-- move(K, key, x, y, w, h) puts a Layout element at a screen position, through Layout so the element's own
-- Resized path runs and fits its rows.
local function move(K, key, x, y, w, h)
	local ok, why = K.Layout.Update(key, { anchor = "TOPLEFT", x = x, y = -y, width = w, height = h })
	assert(ok, key .. ": " .. tostring(why))
end

local function at(frame, x, y, w, h)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
	if w then
		frame:SetSize(w, h)
	end
end

-- The live meters, and the Meters page's preview, in one environment ------------------------------------------

local function live(frames)
	local M = dofile("Tools/regression/meters_env.lua")
	-- The saved profile starts the module at login, so the session and the party are in place before the boot.
	local env, K, ns = M.New(Common.ScreenOpts({
		saved = Gallery.Saved({ "Meters" }),
		setup = function(env)
			setup(env)
			env._session = session()
			party(env)
		end,
	}))
	if not K.Modules.IsRunning("Meters") then
		K.Modules.Enable("Meters")
	end
	env.RunTimers()
	env.FireEvent("GROUP_ROSTER_UPDATE")
	env.RunTimers()
	M.Write(env, K, "swing.time", true)

	-- The damage meter: eight rows of the current fight.
	move(K, "meters.damage", 60, 80, 260, 200)
	env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
	env.RunTimers()
	frames:Add(env, ns.Damage.holder, {
		name = "meters_damage", title = "Damage meter", grade = "panel", reference = "player",
		caption = "KstyleUI's damage meter window (BarList on Widgets.Panel): DAMAGE DONE and the CURRENT column over eight class-coloured rows with names, values and shares, on the glass panel grade; each row's track is the buttonFill body, as the unit frames' tracks.",
		match = "Surface fill, dark outer and light inner line, drop shadow and the 8-unit panel chamfer as the mockup's unit frame glass; the mockup has no meter, so the rows are KstyleUI's own.",
	})

	-- The threat meter: the tank on top, the player second.
	move(K, "meters.threat", 60, 330, 260, 150)
	env.FireEvent("PLAYER_TARGET_CHANGED")
	env.RunTimers()
	frames:Add(env, ns.Threat.holder, {
		name = "meters_threat", title = "Threat meter", grade = "panel", reference = "player",
		caption = "The threat meter: the party's threat on the crocolisk, the tanking warrior first with a full bar, the player at 72% under the 80% warning, threat points and the percentage column, on the glass panel grade.",
		match = "The same glass as the damage meter: surface fill, two-line edge, shadow, 8-unit chamfer; a warning would recolour only the light line (neutral, then hostile).",
	})

	-- The swing timer: main hand and off hand mid-swing, in combat, with the time left.
	move(K, "meters.swing", 60, 530, 260, 24)
	env.SetCombat(true)
	env.RunTimers()
	env.FireEvent("UNIT_INVENTORY_CHANGED", "player")
	env.SetTime(100)
	env.FireEvent("PLAYER_SWING", 2.6, M.SWING.MainHand)
	env.FireEvent("PLAYER_SWING", 1.8, M.SWING.OffHand)
	env.SetTime(101.1)
	M.Tick(env)
	frames:Add(env, ns.Swing.holder, {
		name = "meters_swing", title = "Swing timer", grade = "bar", reference = "cast",
		caption = "The swing timer's main-hand and off-hand bars 1.1 s into their swings, the class-colour fill over the kit's track, the seconds left at the right, each on the bar grade's surface tile with the faint edgeBar line.",
		match = "Fill, faint one-border line and 3.5-unit tile chamfer as the mockup's cast bar and buff bars, no shadow; the bars are thinner (11 units each) than the mockup's 18-unit buff bars.",
	})

	-- The Meters page's live preview: sample damage and threat meters and a swing bar.
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	at(parent, 400, 80, 420, 220)
	local preview = K.Options.Preview("Meters")(parent)
	preview:Refresh()
	frames:Add(env, parent, {
		name = "meters_preview", title = "Meters preview", grade = "panel", reference = "player",
		caption = "The Meters page's live preview (Preview.Build): a sample damage meter and threat meter side by side, five classes each, the threat sample's warning lighting its edge neutral, and the sample swing bar across the bottom on the bar grade.",
		match = "The two sample windows are the glass panel grade as the live meters; the swing sample is the bar grade's surface tile with the edgeBar line.",
	})

	Gallery.Ticks(M.W, env, 20)
	return env, K
end

-- Blizzard's Damage Meter window, restyled in place -------------------------------------------------------------

local SKIN_X, SKIN_Y, SKIN_W, SKIN_H = 400, 360, 260, 180
local SKIN_PAD, SKIN_HEADER, SKIN_ROW, SKIN_GAP = 10, 26, 16, 4

local function skin(frames)
	local M = dofile("Tools/regression/meters_env.lua")
	local window
	local env, K, ns = M.New(Common.ScreenOpts({
		saved = Gallery.Saved({ "Meters" }),
		setup = setup,
		game = function(env)
			local owner = env.DamageMeter
			window = env.CreateFrame("Frame", "DamageMeterSessionWindow1", owner)
			window.Header = window:CreateTexture(nil, "BACKGROUND")
			window.SessionTimer = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			window.DamageMeterTypeDropdown = { TypeName = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") }
			local container = env.CreateFrame("Frame", nil, window)
			container.Background = container:CreateTexture(nil, "BACKGROUND")
			window.MinimizeContainer = container
			local scroll = env.CreateFrame("Frame", nil, container)
			local box = env.CreateFrame("Frame", nil, container)
			window.entries = {}
			for i, s in ipairs(SOURCES) do
				if i <= 6 then
					local entry = env.CreateFrame("Button", nil, box)
					local bar = env.CreateFrame("StatusBar", nil, entry)
					bar:SetStatusBarTexture("blizzard-bar")
					bar.Background = bar:CreateTexture(nil, "BACKGROUND")
					bar.Name = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
					bar.Value = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
					entry.StatusBar = bar
					entry.classFilename = s[2]
					entry.sourceDisplayType = 1
					entry.UpdateStatusBarColor = function(self)
						self.StatusBar:GetStatusBarTexture():SetVertexColor(1, 0, 0)
					end
					window.entries[i] = entry
				end
			end
			function box.ForEachFrame(_, fn)
				for _, entry in ipairs(window.entries) do
					fn(entry, {})
				end
			end
			function window.GetScrollBox()
				return box
			end
			function window.GetScrollBar()
				return scroll
			end
			function window.InitEntry(_, frame)
				frame:UpdateStatusBarColor()
			end
			function window.Refresh(self)
				for _, entry in ipairs(self.entries) do
					entry:UpdateStatusBarColor()
				end
			end
			window.container, window.scroll, window.box = container, scroll, box
			owner.windows = { window }
			function owner.GetSessionWindow(self, index)
				return self.windows[index]
			end
			function owner.SetupSessionWindow() end
		end,
	}))
	M.Write(env, K, "damage.mode", "skin")
	if not K.Modules.IsRunning("Meters") then
		K.Modules.Enable("Meters")
	end
	env.RunTimers()
	assert(ns.DamageSkin.active, "the restyle style is active")

	-- Blizzard lays its window out itself; the fake has no layout, so the scene places the header and the rows.
	local root = K.Scale.Root()
	window:ClearAllPoints()
	window:SetPoint("TOPLEFT", root, "TOPLEFT", SKIN_X, -SKIN_Y)
	window:SetSize(SKIN_W, SKIN_H)
	window.SessionTimer:SetPoint("TOPLEFT", window, "TOPLEFT", SKIN_PAD, -SKIN_PAD)
	window.SessionTimer:SetText("1:40")
	window.DamageMeterTypeDropdown.TypeName:SetPoint("TOPRIGHT", window, "TOPRIGHT", -SKIN_PAD, -SKIN_PAD)
	window.DamageMeterTypeDropdown.TypeName:SetText("Damage Done")
	window.container:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -SKIN_HEADER)
	window.container:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, 0)
	window.scroll:SetPoint("TOPRIGHT", window.container, "TOPRIGHT", -SKIN_PAD / 2, -SKIN_PAD)
	window.scroll:SetSize(SKIN_PAD / 2, SKIN_H - SKIN_HEADER - 2 * SKIN_PAD)
	window.box:SetPoint("TOPLEFT", window.container, "TOPLEFT", SKIN_PAD, -SKIN_PAD)
	window.box:SetPoint("BOTTOMRIGHT", window.container, "BOTTOMRIGHT", -2 * SKIN_PAD, SKIN_PAD)
	local top = SOURCES[1][3]
	for i, entry in ipairs(window.entries) do
		local s = SOURCES[i]
		entry:SetPoint("TOPLEFT", window.box, "TOPLEFT", 0, -(i - 1) * (SKIN_ROW + SKIN_GAP))
		entry:SetPoint("RIGHT", window.box, "RIGHT", 0, 0)
		entry:SetHeight(SKIN_ROW)
		local bar = entry.StatusBar
		bar:SetAllPoints(entry)
		bar:SetMinMaxValues(0, top)
		bar:SetValue(s[3])
		bar.Name:SetPoint("LEFT", bar, "LEFT", SKIN_GAP, 0)
		bar.Name:SetText(s[1])
		bar.Value:SetPoint("RIGHT", bar, "RIGHT", -SKIN_GAP, 0)
		bar.Value:SetText(abbreviate(s[3]))
	end
	window:Refresh()
	env.RunTimers()
	frames:Add(env, window, {
		name = "meters_damage_skin", title = "Blizzard's Damage Meter, restyled", grade = "panel", reference = "player",
		caption = "Blizzard's Damage Meter session window restyled in place (DamageSkin): the header art stripped, KstyleUI glass behind the window, and each row's bar on a buttonFill tile with the meter's texture, font and class colour.",
		match = "The window's glass is the panel grade (surface, two lines, shadow, 8-unit chamfer) as KstyleUI's own meter; each row tile is the button body with the edgeInner hairline, the brief's bar track, since a surface track would vanish against the window's glass.",
	})
	Gallery.Ticks(M.W, env, 20)
	return env, K
end

return Common.Run(function()
	local frames = Gallery.Frames()
	local env1, K1 = live(frames)
	local env2, K2 = skin(frames)
	local scene = Scene.Merge({ Gallery.Build(env1), Gallery.Build(env2) })
	scene.log[#scene.log + 1] = "the restyled Blizzard window is a fake laid out by the scene; the game lays out its own Damage Meter"
	local err = Common.Errors(env2, K2)
	if err then
		scene.log[#scene.log + 1] = "error: " .. err
	end
	return frames:Finish(scene, env1, K1, "gallery meters")
end)
