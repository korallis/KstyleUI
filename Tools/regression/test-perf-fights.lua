-- test-perf-fights.lua: KstyleUI's hooks on frames and functions it does not own settle. From each environment's first line the test keeps every call another addon, Blizzard's code or the fixture makes (KstyleUI's own corrective calls are never kept) and lists every hooksecurefunc and HookScript KstyleUI installs on an object or table it does not own (RestedXP, Questie, Zygor, the quest tracker, LibDBIcon buttons in the minimap drawer, every Blizzard window KstyleUI_Skins restyles). Each one is replayed with the owner's own last call: the owner setting again the value it set, calling its function again, or the client firing the script again, with nothing changed. A hook with no owner call to replay fails with its site, so every hook is covered. After the first replay KstyleUI must write nothing more, and ten scoped restyles of an unrelated frame must write nothing, except where CEILINGS lists today's measured cost with its why; lower a ceiling as that work goes, never raise it. This is the guard for the #685 Zygor loop: an unguarded hook makes the owner's redraw cadence KstyleUI's cost.
rawset(_G, "PIXEL_AUDIT", true)
local S = dofile("Tools/regression/skins_env.lua")
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local Questie = dofile("Tools/regression/questie_fake.lua")
local Zygor = dofile("Tools/regression/zygor_fake.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local Measure = dofile("Tools/regression/databars_env.lua")
local M = dofile("Tools/regression/minimap_env.lua")
local Windows = dofile("Tools/regression/skins_windows.lua")

local REPLAYS = 4
local STUB = "@Tools/regression/stubs/wow.lua"

-- The owner's call for a widget setter the fixture never makes on that object: the client's default for it, or what
-- the owner keeps (its parent, its template's font object).
local OWNER = {
	SetAlpha = { 1 }, SetVertexColor = { 1, 1, 1, 1 }, SetColorTexture = { 1, 1, 1, 1 }, SetDesaturated = { false },
	Show = {}, Hide = {}, SetShown = { true }, SetChecked = { false }, SetScale = { 1 }, SetIgnoreParentScale = { false },
	SetTextColor = { 1, 0.82, 0, 1 }, SetText = { "Owner text" }, SetFormattedText = { "%d", 1 }, SetTabSelected = { false },
	SetValue = { 0 }, SetMinMaxValues = { 0, 1 }, SetRotation = { 0 }, SetTexCoord = { 0, 1, 0, 1 }, SetBackdropColor = { 0, 0, 0, 1 },
	SetParent = function(t) return { t:GetParent() } end, SetZoom = function(t) return { t:GetZoom() } end,
	SetFontObject = function(t) return { t:GetFontObject() or t } end,
}

-- The arguments the client passes each script, the frame first.
local SCRIPTS = {
	OnShow = {}, OnHide = {}, OnEnter = { true }, OnLeave = { true }, OnMouseDown = { "LeftButton" }, OnMouseUp = { "LeftButton" },
	OnClick = { "LeftButton", false }, OnEnable = {}, OnDisable = {}, OnDragStart = { "LeftButton" }, OnDragStop = {},
	OnEditFocusGained = {}, OnEditFocusLost = {}, OnEvent = { "BAG_UPDATE_COOLDOWN" },
}

-- KstyleUI widget writes allowed per replayed call, by the file that installs the hook and the hooked method or script,
-- measured on 2026-11-22, each file with its why. Anything not listed must write nothing, and a scoped restyle of an
-- unrelated frame must write nothing in any environment.
local CEILINGS = {
	["Core/Skin.lua"] = { OnClick = 2, OnDisable = 6, OnEnable = 6, OnEnter = 30, OnHide = 1, OnLeave = 30, OnMouseDown = 6, OnMouseUp = 6, OnShow = 224, SetAlpha = 1, SetChecked = 2, SetColorTexture = 1, SetTabSelected = 5, SetVertexColor = 1,
		why = "a hushed texture answers each owner alpha or recolour once (texture alpha is one value); skinned buttons, tabs and check boxes repaint on each hover, press, enable and check; a skinned window re-places its metrics each time it shows, and the trainer relays out its list" },
	["Core/Widgets/Base.lua"] = { OnSizeChanged = 7,
		why = "chrome on another addon's frame relays out on each OnSizeChanged" },
	["Core/Widgets/StatusBar.lua"] = { OnSizeChanged = 12,
		why = "a bar edge relays out on each OnSizeChanged" },
	["KstyleUI_Minimap/Drawer.lua"] = { Play = 1, SetAlpha = 1, SetPoint = 2,
		why = "Fit puts back a LibDBIcon button the library moves out of its slot, and KeepOpaque answers each fade" },
	["KstyleUI_Minimap/Map.lua"] = { OnEnter = 1, OnLeave = 1, SetAlpha = 1, SetZoom = 2, UpdateDisplay = 124, UpdateMinimapConfig = 2,
		why = "the map puts its shape, zoom and fades back after each of Blizzard's minimap updates" },
	["KstyleUI_Skins/Addons/Questie.lua"] = { OnShow = 4, OnSizeChanged = 3, SetColorTexture = 1, SetFont = 1, SetText = 3, SetVertexColor = 1, Update = 4,
		why = "Questie's font and art are set back once per Questie write, and Refresh shows the card's cap again on each label SetText, resize and Update" },
	["KstyleUI_Skins/Addons/RestedXP/Chrome.lua"] = { CreateGui = 45, CreateGuideConfigurator = 19, CreateGuideImporter = 67, CreateLevelSplits = 4, LoadGuide = 5, OnEnter = 6, OnLeave = 6, OnShow = 45, OpenBrandedExport = 1255, OpenBugReport = 1338, RenderSplitsBackground = 4, RenderTargetFrameBackground = 2, SetAlpha = 1, SetFont = 23, SetFontObject = 4, SetMinMaxValues = 1, SetRotation = 2, SetStep = 150, SetTexCoord = 2, SetText = 41, SetTexture = 4, SetValue = 5, SetupArrow = 34, ShowMenu = 3, UpdateItemFrame = 83, UpdateTargetFrame = 80, UpdateSubTheme = 29, UpdateText = 32, UpdateTheme = 50, UpdateVisuals = 29,
		why = "RestedXP re-anchors its step lines, resets a docked box's width and redraws its arrow and art, and the chrome puts them back; UpdateSubTheme is 4.11.39's name for UpdateVisuals at the same cost, since each call re-sets the box title's font, the arrow's font and colour and the guide's art, and the skin owes one correction; a caption re-fits when RestedXP sets its font or text (its same-text SetText re-snaps what is anchored to it); new windows (CreateGui, the importer, the bug report and export dialogs) are dressed when made" },
	["KstyleUI_Skins/Addons/RestedXP/Rail.lua"] = { OnMouseUp = 83, SetStep = 150, UpdateItemFrame = 83, UpdateTargetFrame = 80,
		why = "RestedXP's item and target updates reset a docked box's width; the rail docks it back and the box's glass follows both widths" },
	["KstyleUI_Skins/Addons/Zygor.lua"] = { AssignTextures = 3, ReanchorFrame = 1, ResizeFrame = 294, SetFontSize = 4,
		why = "Zygor's ResizeFrame sets its window's height on every call and Fit puts the card's height back, the glass following both; ReanchorFrame resets the window's clamp insets; ArrowText answers Zygor's own arrow font and AssignTextures re-tints" },
	["KstyleUI_Skins/Character.lua"] = { PaperDollFrame_UpdateSidebarTabLayout = 4, UpdateRightPaneToggleButton = 1,
		why = "the sidebar tabs and the pane toggle restyle after Blizzard lays them out" },
	["KstyleUI_Skins/Lumen.lua"] = { OnClick = 3, OnEnter = 6, OnLeave = 6, OnShow = 3, SetChecked = 3,
		why = "the Lumen ring repaints on each check, click, show and hover" },
	["KstyleUI_Skins/PartB/GameMenu.lua"] = { InitButtons = 64, Setup = 19,
		why = "the game menu buttons restyle after Blizzard sets them up" },
	["KstyleUI_Skins/PartB/Kit.lua"] = { SetVertexColor = 1,
		why = "kit parts follow the owner's colour" },
	["KstyleUI_Skins/PartB/Merchant.lua"] = { MerchantFrame_UpdateMerchantInfo = 57,
		why = "the merchant page restyles after each Blizzard update" },
	["KstyleUI_Skins/PartB/Trainer.lua"] = { ClassTrainerFrame_SetTrainButtonEnabled = 2, ClassTrainerFrame_Update = 156,
		why = "the trainer list restyles after each Blizzard update" },
	["KstyleUI_Skins/PartC/Legacy.lua"] = { Init = 8,
		why = "the Legacy track restyles on Init" },
	["KstyleUI_Skins/Parts.lua"] = { OnClick = 1, OnDisable = 1, OnEnable = 1, OnEnter = 1, OnHide = 14, OnLeave = 1, OnShow = 224, OnSizeChanged = 7, SetChecked = 1, SetFormattedText = 5, SetText = 5, SetVertexColor = 1, UpdateTabLayout = 6,
		why = "caps, tabs, docks and dropdowns restyle on the client's show, hide, size and hover, and a window title places its section cap again on each SetText" },
	["KstyleUI_Skins/Quests/Quests.lua"] = { HideWatchFrame = 1, OnShow = 4, Update = 4, UpdateHeaderPosition = 2,
		why = "SyncQuestie keeps the two trackers in step on each Questie and tracker update" },
	["KstyleUI_Skins/Registry.lua"] = { OnShow = 224,
		why = "a skinned window re-places its metrics each time it shows" },
	["KstyleUI_Skins/Style.lua"] = { OnShow = 224, SetFontObject = 1, SetStatusBarColor = 1, SetTextColor = 1,
		why = "a skinned window re-places its metrics each time it shows, and swept text and bars follow the owner's font and colour each call" },
	["KstyleUI_Skins/Tracker.lua"] = { EndLayout = 18, OnEnter = 3, OnLeave = 3, SetAlpha = 1, SetCollapsed = 1, SetFontObject = 1, SetHeader = 2, SetText = 2, UpdateHeaderPosition = 2, UpdateHighlight = 2,
		why = "the tracker restyles its lines, headers and highlights after each Blizzard layout, text and hover" },
}

local function Addon(source)
	return source:find("^@Core/") ~= nil or source:find("^@KstyleUI_") ~= nil
end

local function Ours(object)
	local origin = rawget(object, "_origin")
	return type(origin) == "string" and (origin:find("^Core/") ~= nil or origin:find("^KstyleUI_") ~= nil)
end

-- Caller(level) -> the debug info of the first function at or above level (1 is the function calling Caller) that is
-- not the stub's.
local function Caller(level)
	for at = level + 1, 80 do
		local info = debug.getinfo(at, "Sl")
		if not info or info.source ~= STUB then
			return info
		end
	end
end

local function Site(info)
	local file = info.short_src:gsub("^%./", "")
	return file, file .. ":" .. info.currentline
end

-- Watch(env) -> w: w.owned[object][method] keeps the arguments of the last call not made by KstyleUI, w.hooks lists
-- every hooksecurefunc and HookScript KstyleUI installs, and w.count(method), while set, sees each widget call other
-- than a read made while KstyleUI code is on the stack (directly, or through another addon's function or a hook). The
-- stub's shared method lookup is wrapped once, from the first environment's first line, so a method hooked later
-- still passes through the watch.
local watches, wrapped = setmetatable({}, { __mode = "k" }), {}
local function Watch(env)
	local w = { owned = setmetatable({}, { __mode = "k" }), hooks = {} }
	watches[env] = w
	local meta = getmetatable(env.UIParent)
	if not wrapped[meta] then
		local index = meta.__index
		wrapped[meta] = true
		meta.__index = function(object, key)
			local fn = index(object, key)
			if type(fn) ~= "function" or key:find("^Get") or key:find("^Is") or key:find("^Has") or key:find("^Can") then
				return fn
			end
			local watched = wrapped[fn]
			if not watched then
				watched = function(self, ...)
					local watch = watches[rawget(self, "_env")]
					if watch then
						watch.call(self, key, { n = select("#", ...), ... })
					end
					return fn(self, ...)
				end
				wrapped[fn] = watched
			end
			return watched
		end
	end
	w.call = function(object, method, args)
		if w.count then
			for level = 3, 80 do
				local info = debug.getinfo(level, "S")
				if not info then
					break
				end
				if Addon(info.source) then
					w.count(method)
					break
				end
			end
		end
		local info = Caller(3)
		if info and Addon(info.source) then
			if method == "HookScript" then
				local file, site = Site(info)
				w.hooks[#w.hooks + 1] = { target = object, name = args[1], script = true, file = file, site = site }
			end
			return
		end
		local calls = w.owned[object] or {}
		w.owned[object] = calls
		calls[method] = args
	end
	local hook = env.hooksecurefunc
	env.hooksecurefunc = function(a, b, c)
		local target, name, fn = a, b, c
		if type(a) == "string" then
			target, name, fn = env, a, b
		end
		local info = Caller(2)
		if not (info and Addon(info.source)) then
			return hook(a, b, c)
		end
		local file, site = Site(info)
		local rec = { target = target, name = name, file = file, site = site, env = env }
		w.hooks[#w.hooks + 1] = rec
		local function recorded(...)
			local caller = Caller(2)
			if not (caller and Addon(caller.source)) then
				rec.args = { n = select("#", ...), ... }
			end
			return fn(...)
		end
		if target == env then
			return hook(name, recorded)
		end
		return hook(target, name, recorded)
	end
	return w
end

-- Cost(w, run) -> ok, err, writes, by, instructions: KstyleUI's widget writes by method, and the addon VM instructions
-- sampled every 100.
local function Cost(w, run)
	local writes, by, instructions = 0, {}, 0
	w.count = function(method)
		writes = writes + 1
		by[method] = (by[method] or 0) + 1
	end
	debug.sethook(function()
		if Addon(debug.getinfo(2, "S").source) then
			instructions = instructions + 100
		end
	end, "", 100)
	local ok, err = pcall(run)
	debug.sethook()
	w.count = nil
	return ok, err, writes, by, instructions
end

local function List(by)
	local out = {}
	for method, n in pairs(by) do
		out[#out + 1] = method .. "=" .. n
	end
	table.sort(out)
	return table.concat(out, ", ")
end

-- Replays(w, rec) -> the owner's calls to try, best first: the owner's own last call, the client's default for a
-- widget setter, the arguments the client passes a script, or a plain call of the owner's function (as a method,
-- then as a dot function).
local function Replays(w, rec)
	local t, name = rec.target, rec.name
	local function Call(args)
		return function()
			t[name](unpack(args, 1, args.n))
		end
	end
	if rec.script then
		local args = name == "OnSizeChanged" and { t:GetWidth(), t:GetHeight() } or SCRIPTS[name]
		return args and { function() t:GetScript(name)(t, unpack(args)) end } or {}
	end
	local meta = getmetatable(t)
	if rawget(t, "_calls") and type(meta.__index) == "function" and meta.__index(t, name) then
		local owned, default = w.owned[t] and w.owned[t][name], OWNER[name]
		if type(default) == "function" then
			default = default(t)
		end
		local args = owned and { n = owned.n + 1, t, unpack(owned, 1, owned.n) } or default and { n = #default + 1, t, unpack(default) }
		return args and { Call(args) } or {}
	end
	if rec.args then
		return { Call(rec.args) }
	end
	if t == rec.env then
		return { Call({ n = 0 }) }
	end
	return { Call({ n = 1, t }), Call({ n = 0 }) }
end

local failures, total = {}, 0

-- Settle(label, env, K, w): replay every foreign hook and run scoped restyles of an unrelated frame.
local function Settle(label, env, K, w)
	local groups, order, hooks = {}, {}, {}
	for i = 1, #w.hooks do
		hooks[i] = w.hooks[i]
	end
	for _, rec in ipairs(hooks) do
		local t = rec.target
		if not (rawget(t, "_calls") and Ours(t)) and t ~= K then
			local key = tostring(t) .. (rec.script and ":" or ".") .. rec.name
			local group = groups[key]
			if not group then
				group = { rec = rec, sites = {}, floor = 0 }
				groups[key] = group
				order[#order + 1] = group
			end
			group.sites[#group.sites + 1] = rec.site
			local ceiling = CEILINGS[rec.file]
			group.floor = math.max(group.floor, ceiling and ceiling[rec.name] or 0)
		end
	end
	for _, group in ipairs(order) do
		local rec = group.rec
		local where = string.format("%s: %s hooks %s%s on %s", label, table.concat(group.sites, ", "), rec.name, rec.script and " (script)" or "", rec.target.GetName and tostring(rec.target:GetName()) or "a table")
		local replay, warm, err
		local function Once()
			replay()
			env.RunTimers()
		end
		for _, candidate in ipairs(Replays(w, rec)) do
			replay = candidate
			warm, err = pcall(Once)
			if warm then
				break
			end
		end
		if not replay then
			failures[#failures + 1] = where .. ", and no owner call was made to replay: have the fixture make the owner's call (or give the setter's client default in OWNER, or the script's arguments in SCRIPTS)"
		elseif not warm then
			failures[#failures + 1] = where .. ", and replaying the owner's call raised " .. tostring(err)
		else
			total = total + 1
			local ok, raised, writes, by, instructions = Cost(w, function()
				for _ = 2, REPLAYS do
					Once()
				end
			end)
			local per = writes / (REPLAYS - 1)
			if not ok then
				failures[#failures + 1] = where .. ", and replaying the owner's call raised " .. tostring(raised)
			elseif per > group.floor then
				failures[#failures + 1] = string.format("%s; replaying the owner's last call wrote %.1f times per call from KstyleUI (%s), %d addon instructions per call, allowed %d. A hook on a frame KstyleUI does not own must return when what it wants is already in place: add an unchanged-value return (compare the value or a key of the inputs before writing, as Zygor's Face and Place do since #685), or, for work that is not yours to fix here, list today's cost in CEILINGS with its why.",
					where, per, List(by), math.floor(instructions / (REPLAYS - 1)), group.floor)
			end
		end
	end
	local probe = env.CreateFrame("Frame")
	local ok, err, writes, by = Cost(w, function()
		for _ = 1, 10 do
			K.Widgets.RestyleUnder({ [probe] = true })
			env.RunTimers()
		end
	end)
	assert(ok, err)
	if writes > 0 then
		failures[#failures + 1] = string.format("%s: 10 scoped restyles of an unrelated frame wrote %d times (%s). A tracked widget with no region runs on every scoped restyle: give the handle the frame it styles (owner, holder, frame, bar, button or target) so Widgets.RestyleUnder skips it (#685).", label, writes, List(by))
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, label .. ": " .. tostring(env._errors[1]))
	print(string.format("%s: %d foreign hooks replayed", label, #order))
end

-- The RestedXP guide and Questie's tracker beside the quest card and Blizzard's tracker, in both RestedXP shapes.
for _, release in ipairs({ "4.11.35", "4.11.39" }) do
	local w
	local R = Boot({ width = 1920, height = 1080, uiScale = 768 / 1080, release = release, setup = function(e) w = Watch(e) end }, nil, nil, nil, Questie.Install)
	R.K.Options.Write("Integrations", "questTracker", "questie")
	R.rxp:SortTimers()
	R.rxp:LoadGuide(R.rxp.currentGuide)
	R.rxp.RXPFrame.ScrollChild:SetHeight(120)
	R.rxp.RXPFrame.ScrollFrame.ScrollBar:SetValue(0)
	R.settle()
	Settle("RestedXP " .. release .. " and Questie", R.env, R.K, w)
end

-- Zygor's guide window at 1600x900 and size 0.53, where the #685 loop showed in the stub.
do
	local w, zygor
	local env, K = S.New({
		width = 1600, height = 900, size = 0.53,
		saved = { version = 12, profiles = { Default = { Layout = { preset = "DPS" } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} },
		setup = function(e)
			w = Watch(e)
			e._textWidth = Measure.TextWidth
			Quests.Install(e, Quests.List(8))
			zygor = Zygor.Install(e, {})
		end,
		before = function(e)
			Quests.Tracker(e, S.Blizzard(e))
		end,
	})
	K.Modules.Enable("Skins")
	env.RunTimers()
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	env.RunTimers()
	zygor.Show()
	env.RunTimers()
	S.W.Settle(env)
	local z = env.ZygorGuidesViewer
	z:SetFrameScale()
	z.Tabs:ReanchorTabs()
	z.Pointer.ArrowFrame:ShowTraveling()
	z.Pointer:SetFontSize(14)
	env.RunTimers()
	Settle("Zygor", env, K, w)
end

-- Other addons' LibDBIcon buttons in the minimap's drawer.
do
	local w, lib
	local env, K = M.New({ enabled = true, setup = function(e)
		w = Watch(e)
		lib = M.FakeLibDBIcon(e)
		lib:Add("Bravo")
		lib:Add("Alpha")
	end })
	M.Settle(env)
	for _ = 1, 2 do
		lib:Move("Alpha")
		lib.objects.Bravo:SetAlpha(0)
		env.RunTimers()
	end
	Settle("Minimap drawer", env, K, w)
end

-- Every Blizzard window KstyleUI_Skins restyles, open.
do
	local w, B, shown = nil, nil, {}
	local env, K = S.New({
		setup = function(e)
			w = Watch(e)
		end,
		before = function(e)
			B = S.Blizzard(e)
			for _, spec in ipairs(Windows.LIST) do
				local _, parts = Windows.Build(spec.key, e, B)
				shown[#shown + 1] = parts.show
			end
		end,
	})
	K.Modules.Enable("Skins")
	for _, spec in ipairs(Windows.LIST) do
		if spec.addon then
			S.LoadAddOn(env, spec.addon)
		end
	end
	for _, list in ipairs(shown) do
		for _, frame in ipairs(list) do
			S.Show(frame)
		end
	end
	env.ProfessionsFrame.CraftingPage.RankBar:Update({ skillLevel = 262, maxSkillLevel = 300 })
	env.RunTimers()
	S.W.Settle(env)
	Settle("Blizzard windows", env, K, w)
end

assert(#failures == 0, #failures .. " fight(s):\n" .. table.concat(failures, "\n"))
print(string.format("perf fights ok: %d foreign hooks replayed with their owners' own calls", total))
