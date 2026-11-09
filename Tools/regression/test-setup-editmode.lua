-- test-setup-editmode.lua: Apply writes the objective tracker and Blizzard's damage meter into a "KstyleUI <layout>" Edit Mode layout copied from the active one, out of combat, and falls back to the story hint when Edit Mode is missing.
local W = dofile("Tools/regression/widget_env.lua")
local CoreEnv = W.CoreEnv

local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
local TRACKER, METER, CHAT = EditModeFake.TRACKER, EditModeFake.METER, EditModeFake.CHAT
local HEIGHT, FRAME_WIDTH, FRAME_HEIGHT = EditModeFake.HEIGHT, EditModeFake.FRAME_WIDTH, EditModeFake.FRAME_HEIGHT
local PRESET, ACCOUNT = EditModeFake.PRESET, EditModeFake.ACCOUNT
local Install, Modern = EditModeFake.Install, EditModeFake.Modern

local function Boot(state)
	local env, K = W.New({
		boot = false,
		setup = function(env)
			Install(env, state)
		end,
	})
	CoreEnv.Boot(env)
	return env, K
end

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
