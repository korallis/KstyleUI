-- test-devtest-editmode.lua: Edit Mode diagnostics are opt-in, read only native frames, record nil geometry and settings, and redact restricted values without invoking setters or hooks.
local C = dofile("Tools/regression/core_env.lua")

local function New()
	local env, K = C.New()
	K.Modules.Register(C.Module("Skins", { defaults = { enabled = false, quests = { enabled = true, shown = 3 } } }))
	C.Boot(env)
	local function Region(name, state)
		local methods = {
			GetDebugName = function() if state.nameRestricted then return state.name end return name end,
			GetName = function() if state.nameRestricted then return state.name end return name end,
			GetParent = function() return state.parent end,
			GetRect = function()
				if state.rectError then error("private getter failure") end
				if state.rect then return unpack(state.rect) end
			end,
			IsShown = function() return state.shown end,
			IsVisible = function() return state.shown end,
			GetScale = function() return state.scale or 1 end,
			GetEffectiveScale = function() return state.scale or 1 end,
			GetNumPoints = function() return state.count or #state.points end,
			GetPoint = function(_, index)
				state.readPoints = (state.readPoints or 0) + 1
				if state.pointError then error("private point failure") end
				return unpack(state.points[index] or state.points[1] or {})
			end,
		}
		for _, method in ipairs({ "SetScript", "HookScript", "SetParent", "SetPoint", "ClearAllPoints", "SetScale", "Show", "Hide", "SetShown" }) do
			methods[method] = function() error("a Blizzard mutator was called: " .. method) end
		end
		return setmetatable({}, {
			__index = function(_, key)
				if key == "Selection" then return state.selection end
				if key == "isDragging" then return state.dragging end
				return methods[key]
			end,
			__newindex = function() error("a Blizzard field was written") end,
		})
	end
	local trackerState = { rect = { 10, 20, 200, 400 }, points = { { "TOPRIGHT", env.UIParent, "TOPRIGHT", -10, -20 } }, shown = true, parent = env.UIParent }
	local selectionState = { rect = { 10, 20, 200, 400 }, points = { { "TOPLEFT", env.UIParent, "TOPLEFT", 10, 20 } }, shown = true }
	local otherState = { points = {}, shown = false, parent = env.UIParent }
	local otherSelection = { points = {}, shown = false }
	env.ObjectiveTrackerFrame = Region("ObjectiveTrackerFrame", trackerState)
	trackerState.selection = Region("ObjectiveTrackerFrame.Selection", selectionState)
	selectionState.parent = env.ObjectiveTrackerFrame
	local other = Region("OtherSystem", otherState)
	otherState.selection = Region("OtherSystem.Selection", otherSelection)
	env.Enum = env.Enum or {}
	env.Enum.EditModeLayoutType = { Preset = 0, Account = 1, Character = 2, Override = 3 }
	local edit = { active = false, info = { activeLayout = 3, layouts = {
		{ layoutName = "Blizzard preset A", layoutType = 0 },
		{ layoutName = "Blizzard preset B", layoutType = 0 },
		{ layoutName = "KstyleUI DPS", layoutType = 1 },
	} } }
	env.EditModeManagerFrame = setmetatable({}, {
		__index = {
			IsEditModeActive = function() return edit.active end,
			GetActiveLayoutInfo = function() return edit.info.layouts[edit.info.activeLayout] end,
			layoutInfo = edit.info,
			registeredSystemFrames = { env.ObjectiveTrackerFrame, other },
		},
		__newindex = function() error("the Edit Mode manager was written") end,
	})
	env.C_EditMode = {
		GetLayouts = function() error("saved layouts alone cannot identify the active built-in preset") end,
		SaveLayouts = function() error("the recorder saved a layout") end,
		SetActiveLayout = function() error("the recorder activated a layout") end,
	}
	local function Logs()
		local lines = {}
		for _, entry in ipairs(env.KstyleUIDB.devlog) do
			if entry.module == "EditModeRecorder" then
				assert(#entry.message <= 1000, "recorder entries respect the devlog message cap")
				lines[#lines + 1] = entry.message
			end
		end
		return table.concat(lines, "\n"), #lines
	end
	local function Start()
		local before = #env._frames
		env.SlashCmdList.KSTYLE("devlog on")
		assert(K.DevTest.EditModeLogging(), "the owner explicitly enables recording")
		assert(#env._frames == before + 1, "the recorder creates only its own polling frame")
		local poller = env._frames[#env._frames]
		assert(poller._scripts.OnUpdate, "only the addon-owned frame gets OnUpdate")
		return function(delta) poller._scripts.OnUpdate(poller, delta or 0.25) end
	end
	return env, K, edit, trackerState, selectionState, otherState, Logs, Start
end

do
	local env, K, edit, tracker, selection, _, logs, start = New()
	assert(not K.DevTest.EditModeLogging(), "recording is off unless explicitly enabled in this session")
	assert(select(2, logs()) == 0, "no geometry is logged while recording is off")
	K.Modules.Enable("Skins")
	local tick = start()
	assert(not logs():find("object=ObjectiveTrackerFrame", 1, true), "arming outside Edit Mode does not inspect geometry")
	edit.active = true
	tick()
	local text = logs()
	assert(text:find("phase=enter", 1, true), "opening Edit Mode captures the initial state")
	assert(text:find("object=ObjectiveTrackerFrame", 1, true) and text:find("object=ObjectiveTrackerFrame.Selection", 1, true))
	assert(text:find("parent=ObjectiveTrackerFrame", 1, true), "the selection's parent is named")
	assert(text:find("rect=10,20,200,400", 1, true) and text:find("point[1]=TOPRIGHT", 1, true), "rectangles and anchor tuples are recorded")
	assert(text:find("shown=true", 1, true) and text:find("scale=1", 1, true))
	assert(text:find("module=Skins enabled=true running=true", 1, true), "module state accompanies the geometry")
	assert(text:find("settings.Skins.quests.enabled=true", 1, true), "settings accompany the geometry")
	assert(text:find("mergedActiveIndex=3", 1, true) and text:find("activeName=KstyleUI DPS", 1, true) and text:find("presetCount=2", 1, true), "the merged layout name disambiguates placement from saved-layout indices")
	assert(text:find("object=OtherSystem", 1, true) and text:find("rect=nil,nil,nil,nil", 1, true), "other systems with missing rectangles are captured too")
	tracker.dragging = true
	selection.rect = nil
	tick()
	assert(logs():find("phase=drag selection object=ObjectiveTrackerFrame.Selection", 1, true), "dragging records the nil selection")
	local _, before = logs()
	for _ = 1, 100 do tick() end
	assert(select(2, logs()) == before, "unchanged frames do not flood the bounded devlog")
	tracker.points[1][4] = -30
	tick(0.1)
	assert(select(2, logs()) == before, "reads are throttled to four samples per second")
	tick(0.2)
	assert(select(2, logs()) > before, "changed anchors are captured while dragging")
	tracker.dragging = false
	tick()
	assert(logs():find("phase=release", 1, true), "the release state is captured after the drag flag clears")
	edit.info.activeLayout, tracker.dragging = 1, true
	tick()
	assert(logs():find("activeName=Blizzard preset A", 1, true), "the second drag names the built-in preset, not just an ambiguous saved index")
	edit.active = false
	tick()
	assert(logs():find("Edit Mode exited", 1, true))
	env.SlashCmdList.KSTYLE("devlog off")
	before = select(2, logs())
	edit.active, tracker.dragging = true, true
	tick()
	assert(not K.DevTest.EditModeLogging() and select(2, logs()) == before, "off stops all polling and geometry logging")
	local _, nextK = C.New({ saved = env.KstyleUIDB })
	assert(not nextK.DevTest.EditModeLogging(), "recording never persists across reload")
end

do
	local env, K, edit, tracker, selection, other, logs, start = New()
	K.Store.Profile().Skins.restricted = env.Secret("PRIVATE_SETTING")
	K.Store.Profile().Skins.cycle = K.Store.Profile().Skins
	selection.rect = { env.Secret(12345), env.Secret(23456), env.Secret(34567), env.Secret(45678) }
	selection.parent = env.Secret(env.ObjectiveTrackerFrame)
	selection.nameRestricted, selection.name = true, env.Secret("PRIVATE_NAME")
	selection.scale = env.Secret(1.2345)
	selection.shown = env.Secret(true)
	selection.count = env.Secret(3)
	tracker.points[1][1] = env.Secret("PRIVATE_POINT")
	tracker.points[1][4] = env.Secret(98765)
	other.rectError, other.pointError = true, true
	edit.active, tracker.dragging = true, true
	local tick = start()
	tick(env.Secret(0.25))
	tick()
	local text = logs()
	assert(text:find("<secret>", 1, true) and text:find("<unavailable>", 1, true), "restricted values and failed getters are explicit")
	assert(text:find("cycle/depth limit", 1, true), "a malformed settings cycle has an explicit safe limit")
	for _, value in ipairs({ "12345", "23456", "34567", "45678", "1.2345", "PRIVATE_POINT", "PRIVATE_NAME", "PRIVATE_SETTING", "98765", "private getter failure" }) do
		assert(not text:find(value, 1, true), "secret and error contents never enter the devlog: " .. value)
	end
end

do
	local _, _, edit, tracker, _, _, logs, start = New()
	tracker.count = 40
	tracker.points[1][1] = string.rep("P", 150)
	edit.active = true
	start()
	local text = logs()
	assert(tracker.readPoints == 32, "a broken point count has a bounded read budget")
	assert(text:find("point[32]", 1, true) and text:find("truncated after 32", 1, true), "chunked messages retain the final sampled points and an explicit limit")
end

do
	local env, _, edit, tracker, selection, _, logs, start = New()
	edit.active = true
	local tick = start()
	tracker.dragging = true
	tick()
	tracker.dragging, selection.rect = false, nil
	env.SlashCmdList.KSTYLE("devlog off")
	assert(logs():find("phase=release selection object=ObjectiveTrackerFrame.Selection", 1, true), "stopping immediately after release flushes its final geometry")
end

do
	local _, K, edit, _, _, _, logs, start = New()
	for i = 1, 120 do
		K.Store.Profile()["Extra" .. i] = { value = string.rep("x", 100) }
	end
	edit.active = true
	start()
	local text = logs()
	assert(not text:find("part=2/2", 1, true), "ordinary context chunks are not split a second time into tiny entries")
end

do
	local env, K = New()
	local before = #env._frames
	env.issecretvalue = nil
	assert(K.DevTest.SetEditModeLogging(true) == false and #env._frames == before, "without a secret-value guard diagnostics stay off")
end

print("devtest Edit Mode recorder ok")
