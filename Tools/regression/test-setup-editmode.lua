-- test-setup-editmode.lua: Apply writes the objective tracker, Blizzard's damage meter and its tracked buff icon and bar viewers into a "KstyleUI <layout>" Edit Mode layout copied from the active one, out of combat, and falls back to the story hint (or a precise step) when Edit Mode cannot place them.
local W = dofile("Tools/regression/widget_env.lua")
local CoreEnv = W.CoreEnv

local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
local TRACKER, METER, CHAT, VIEWER = EditModeFake.TRACKER, EditModeFake.METER, EditModeFake.CHAT, EditModeFake.VIEWER
local BUFF_ICON, BUFF_BAR = EditModeFake.BUFF_ICON, EditModeFake.BUFF_BAR
local ICON_SIZE, ORIENTATION, ICON_DIRECTION = EditModeFake.ICON_SIZE, EditModeFake.ORIENTATION, EditModeFake.ICON_DIRECTION
local HEIGHT, FRAME_WIDTH, FRAME_HEIGHT = EditModeFake.HEIGHT, EditModeFake.FRAME_WIDTH, EditModeFake.FRAME_HEIGHT
local PRESET, ACCOUNT = EditModeFake.PRESET, EditModeFake.ACCOUNT
local Install, Modern = EditModeFake.Install, EditModeFake.Modern

local function Boot(state, screen)
	local opts = {
		boot = false,
		setup = function(env)
			Install(env, state)
		end,
	}
	for key, value in pairs(screen or {}) do
		opts[key] = value
	end
	local env, K = W.New(opts)
	CoreEnv.Boot(env)
	return env, K
end

local OWNER = { width = 2383, height = 1540, uiScale = 768 / 1080 }

local Find, Setting, Named = EditModeFake.Find, EditModeFake.Setting, EditModeFake.Named

local function near(a, b)
	return type(a) == "number" and math.abs(a - b) < 0.6
end

-- A new KstyleUI layout, copied from the active preset, with the tracker in the story slot and the meter on its card

do
	local state = { saved = { { layoutName = "Mine", layoutType = ACCOUNT, systems = Modern().systems } }, active = 1 }
	local env, K = Boot(state)
	assert(K.Setup.EditMode and K.Setup.EditMode.Available(), "the writer finds Forever's Edit Mode API")
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	assert(state.saves == 1, "Apply saves the Edit Mode layouts once")
	local layout, index = Named(state, "KstyleUI DPS")
	assert(layout and layout.layoutType == ACCOUNT, "a KstyleUI DPS account layout is added")
	assert(state.activated == 2 + index, "and made the active layout, counting the two presets first")
	assert(Named(state, "Mine"), "the player's own layout is kept")
	assert(state.sent.layouts[1].layoutType == PRESET and #state.sent.layouts == 2 + #state.saved, "SaveLayouts takes the presets and the saved layouts, as Edit Mode sends them")
	local story = K.Setup.Story("DPS", false)
	local k = K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	local tracker = Find(layout, TRACKER)
	local a = tracker.anchorInfo
	assert(a.point == "TOPLEFT" and a.relativeTo == "UIParent" and a.relativePoint == "BOTTOMLEFT", "the tracker hangs from its top left, measured from the screen's bottom left")
	local place = K.Setup.EditMode.TrackerPlace(story.tracker)
	assert(near(a.offsetX, place.x * k) and near(a.offsetY, place.y * k), "at the story slot, in UIParent's units")
	assert(near(place.x - K.Setup.EditMode.TRACKER_LEFT, story.tracker.left) and near(place.y - K.Setup.EditMode.TRACKER_TOP, story.tracker.top), "so the tracker's glass starts at the slot's top left")
	assert(tracker.isInDefaultPosition == false, "and is no longer in its default position")
	assert(Setting(tracker, HEIGHT) == 0, "the tracker takes Edit Mode's lowest height, so a long list stays off chat")
	assert(Setting(tracker, 1) == 0, "its other settings are the copied layout's")
	local meter = Find(layout, METER)
	local rw, rh = K.Layout.RootSize()
	local spec = K.Setup.Layouts.Element("meters.damage")
	local w, h = K.Setup.Layouts.Footprint("DPS", "meters.damage")
	local l, _, _, t = K.Setup.Layouts.Rect({ width = w, height = h }, K.Setup.Layouts.Get("DPS")["meters.damage"], rw, rh)
	assert(spec and near(meter.anchorInfo.offsetX, l * k) and near(meter.anchorInfo.offsetY, t * k), "Blizzard's damage meter sits on the layout's damage card")
	assert(near(Setting(meter, FRAME_WIDTH), math.max(200, math.min(600, w * k)) - 200), "its width is the card's, as Edit Mode stores it (less the 200 minimum)")
	assert(near(Setting(meter, FRAME_HEIGHT), math.max(120, math.min(400, h * k)) - 120), "and its height (less the 120 minimum)")
	assert(Find(layout, CHAT).anchorInfo.offsetX == 35, "every other system keeps the copied layout's place")
	assert(Find(state.saved[1], TRACKER).anchorInfo.offsetX == -110, "the layout it copied is untouched")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The tracked buff viewers: on Forever the Cooldowns module's automatic path restyles Blizzard's own BuffIconCooldownViewer
-- and BuffBarCooldownViewer, so Apply places those viewers in the layout's tracked buff slots. The icons hang from the
-- slot's bottom right and grow left, away from the combat cluster; the bars stand on the slot's bottom left and grow
-- up. Their size comes from Edit Mode's IconSize, chosen so the whole row (every tracked item keeps a slot) fits
-- between the slot and the next element, never under 50% and never over KstyleUI's own buff size.

local function Overlaps(a, b)
	return a[1] < b[3] - 0.5 and b[1] < a[3] - 0.5 and a[2] < b[4] - 0.5 and b[2] < a[4] - 0.5
end

local function Collisions(K, name, box)
	local rw, rh = K.Layout.RootSize()
	local hits = {}
	for key, position in pairs(K.Setup.Layouts.Get(name)) do
		if not key:find("^cooldowns%.") and K.Setup.Layouts.Shown(name, key) ~= false then
			local w, h = K.Setup.Layouts.Footprint(name, key)
			if w then
				local l, b, r, t = K.Setup.Layouts.Rect({ width = w, height = h }, position, rw, rh)
				if Overlaps(box, { l, b, r, t }) then
					hits[#hits + 1] = key
				end
			end
		end
	end
	return hits
end

local function Slot(K, name, key)
	local rw, rh = K.Layout.RootSize()
	local w, h = K.Setup.Layouts.Footprint(name, key)
	return K.Setup.Layouts.Rect({ width = w, height = h }, K.Setup.Layouts.Get(name)[key], rw, rh)
end

local function Viewers(K, env, state, name, icons, bars)
	local k = K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	local layout = Named(state, "KstyleUI " .. name)
	local icon, bar = Find(layout, VIEWER, BUFF_ICON), Find(layout, VIEWER, BUFF_BAR)
	assert(icon and bar, "the KstyleUI layout carries both tracked buff viewers")
	return icon, bar, { EditModeFake.ViewerRect(icon, icons, k) }, { EditModeFake.ViewerRect(bar, bars, k, true) }, k
end

for _, name in ipairs({ "DPS", "Tank", "Healer" }) do
	for _, screen in ipairs({ OWNER, {} }) do
		local state = { saved = {}, active = 1 }
		local env, K = Boot(state, screen)
		K.Setup.EditMode.CountTracked(function(group)
			return ({ buffs = 5, bars = 2 })[group]
		end)
		assert(K.Setup.Apply({ layout = name, modules = {} }))
		local icon, bar, iconBox, barBox, k = Viewers(K, env, state, name, 5, 2)
		local where = name .. " at " .. tostring(screen.width or 1920)
		local l, b, r = Slot(K, name, "cooldowns.buffs")
		assert(icon.anchorInfo.point == "BOTTOMRIGHT" and near(icon.anchorInfo.offsetX, r * k) and near(icon.anchorInfo.offsetY, b * k), where .. ": the buff icons hang from the slot's bottom right")
		assert(Setting(icon, ORIENTATION) == EditModeFake.HORIZONTAL and Setting(icon, ICON_DIRECTION) == EditModeFake.LEFT, where .. ": in one row, the first buff beside the cluster")
		assert(icon.isInDefaultPosition == false and bar.isInDefaultPosition == false, where .. ": both leave their default places")
		local size = (iconBox[4] - iconBox[2])
		assert(size <= 30 + 0.5 and Setting(icon, ICON_SIZE) >= 0, where .. ": a buff icon is no larger than KstyleUI's 30-unit buff, got " .. size)
		assert(near(iconBox[3], r) and iconBox[1] >= l - 0.5, where .. ": five buffs fit inside the slot")
		local bl, bb, br = Slot(K, name, "cooldowns.bars")
		assert(bar.anchorInfo.point == "BOTTOMLEFT" and near(bar.anchorInfo.offsetX, bl * k) and near(bar.anchorInfo.offsetY, bb * k), where .. ": the bars stand on the bar slot's bottom left")
		assert(barBox[3] <= br + 0.5 and barBox[3] >= br - 3, where .. ": a bar spans the slot's width, whatever bar width the copied layout had, got " .. (barBox[3] - barBox[1]) .. " of " .. (br - bl))
		assert(#Collisions(K, name, iconBox) == 0, where .. ": the icons touch nothing: " .. table.concat(Collisions(K, name, iconBox), ", "))
		assert(#Collisions(K, name, barBox) == 0, where .. ": the bars touch nothing: " .. table.concat(Collisions(K, name, barBox), ", "))
		assert(not CoreEnv.Printed(env, "tracked"), where .. ": nothing to tell the player")
		assert(Find(Named(state, "KstyleUI " .. name), VIEWER, 1).anchorInfo.offsetY == 230, where .. ": the essential viewer keeps the copied layout's place")
		assert(#env._errors == 0, tostring(env._errors[1]))
	end
end

-- Sixteen tracked buffs and six tracked bars: the icons shrink to fit beside the action bars where they can; what
-- cannot fit at 50% gets one precise setup step naming the counts.

do
	local state = { saved = {}, active = 1 }
	local env, K = Boot(state, OWNER)
	K.Setup.EditMode.CountTracked(function(group)
		return ({ buffs = 16, bars = 6 })[group]
	end)
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	local icon, bar, iconBox, barBox = Viewers(K, env, state, "DPS", 16, 6)
	local fitIcons = #Collisions(K, "DPS", iconBox) == 0
	local iconLine = CoreEnv.Printed(env, "16 tracked buffs")
	assert(fitIcons or iconLine, "sixteen buffs either fit or the player is told")
	assert(fitIcons or Setting(icon, ICON_SIZE) == 0, "a row that cannot fit takes Edit Mode's smallest size")
	local barLine = CoreEnv.Printed(env, "6 tracked bars")
	assert(barLine and barLine:find("Cooldown Manager", 1, true), "six bars do not fit under the focus frame, and the step says where to change it: " .. tostring(barLine))
	assert(Setting(bar, ICON_SIZE) == 0, "the bars take the smallest size")
	assert(#Collisions(K, "DPS", barBox) > 0, "the step is printed because they really collide")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A client without the CooldownViewer system keeps the rest of the write

do
	local state = { saved = {}, active = 1, noViewers = true }
	local env, K = Boot(state)
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	local layout = Named(state, "KstyleUI DPS")
	assert(layout and Find(layout, TRACKER).isInDefaultPosition == false, "the tracker is still placed")
	assert(Find(layout, VIEWER, BUFF_ICON).isInDefaultPosition == true, "the viewers are left alone")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Applying again updates the KstyleUI layout in place; another layout gets its own

do
	local state = { saved = {}, active = 1 }
	local env, K = Boot(state)
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	local count = 0
	for _, layout in ipairs(state.saved) do
		if layout.layoutName == "KstyleUI DPS" then
			count = count + 1
		end
	end
	assert(count == 1, "a second Apply reuses the KstyleUI DPS layout")
	assert(K.Setup.Apply({ layout = "Healer", modules = {} }))
	local healer, index = Named(state, "KstyleUI Healer")
	assert(healer and state.activated == 2 + index, "Healer writes and activates its own layout")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- With RestedXP loaded, the tracker sits under the guide's half of the slot

do
	local state = { saved = {}, active = 1 }
	local env, K = Boot(state)
	env.C_AddOns = env.C_AddOns or {}
	env.C_AddOns.IsAddOnLoaded = function(name)
		return name == "RXPGuides"
	end
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	local story = K.Setup.Story("DPS", true)
	local slot = K.Setup.Story("DPS", false)
	assert(story.guide and near(story.guide.top, slot.story.top) and story.guide.left == slot.story.left, "the guide takes the top of the slot")
	assert(story.tracker.top < story.guide.bottom and near(story.guide.bottom - story.tracker.top, 16), "the tracker starts one rail gap under it")
	assert(near(story.tracker.bottom, slot.story.bottom), "and runs to the slot's bottom")
	local k = K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	local a = Find(Named(state, "KstyleUI DPS"), TRACKER).anchorInfo
	assert(near(a.offsetY, K.Setup.EditMode.TrackerPlace(story.tracker).y * k), "Apply places the tracker under the guide when RestedXP is loaded")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- In combat the write waits for combat to end

do
	local state = { saved = {}, active = 1 }
	local env, K = Boot(state)
	env.SetCombat(true)
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	assert(state.saves == nil, "nothing is saved in combat")
	env.SetCombat(false)
	assert(state.saves == 1 and Named(state, "KstyleUI DPS"), "the layout is written when combat ends")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Without Edit Mode, or with every account slot taken, Apply keeps the hint

local function Logged(env, text)
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.module == "Setup" and entry.message:find(text, 1, true) then
			return true
		end
	end
end

do
	local state = { saved = {}, active = 1, noEditMode = true }
	local env, K = Boot(state)
	assert(not K.Setup.EditMode.Available())
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }), "Apply still applies")
	assert(Logged(env, "Edit Mode"), "and logs that the tracker keeps the hint")
	assert(CoreEnv.Printed(env, "Edit Mode"), "the player is told to move the tracker in Edit Mode")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local full = {}
	for i = 1, 5 do
		full[i] = { layoutName = "Mine " .. i, layoutType = ACCOUNT, systems = Modern().systems }
	end
	local state = { saved = full, active = 3, max = 5 }
	local env, K = Boot(state)
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	assert(state.saves == nil and state.activated == nil, "a full set of account layouts is never overwritten")
	assert(Logged(env, "account layouts"), "the log says why")
	assert(CoreEnv.Printed(env, "Edit Mode"), "and the player gets the hint")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A broken API call is caught and logged; Apply still returns true

do
	local state = { saved = {}, active = 1 }
	local env, K = Boot(state)
	env.C_EditMode.SaveLayouts = function()
		error("blocked")
	end
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	assert(Logged(env, "SaveLayouts"), "a failed save is logged")
	assert(state.activated == nil, "and nothing is activated")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("setup editmode ok")
