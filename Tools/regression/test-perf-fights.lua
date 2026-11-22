-- test-perf-fights.lua: KstyleUI's hooks on frames and functions it does not own settle. For every hooksecurefunc KstyleUI installs on another addon's or Blizzard's object or table (RestedXP, Questie, Zygor, the quest tracker, LibDBIcon buttons on the minimap, the Blizzard windows it skins), the test replays the hooked call's last arguments: the owner setting again the value it last set, or calling its function again with nothing changed. After the first replay KstyleUI must write nothing more, and ten scoped restyles of an unrelated frame must write nothing, except where CEILINGS lists today's measured cost with its why; lower a ceiling as that work goes, never raise it. This is the guard for the #685 Zygor loop: an unguarded hook makes the owner's redraw cadence KstyleUI's cost.
rawset(_G, "PIXEL_AUDIT", true)
local S = dofile("Tools/regression/skins_env.lua")
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local Questie = dofile("Tools/regression/questie_fake.lua")
local Zygor = dofile("Tools/regression/zygor_fake.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local Measure = dofile("Tools/regression/databars_env.lua")
local M = dofile("Tools/regression/minimap_env.lua")
local Windows = dofile("Tools/regression/skins_windows.lua")

local REPLAYS = 10

-- KstyleUI widget writes allowed per replayed call, by the file that installs the hook and the hooked method (or per
-- scoped restyle, by environment), measured on 2026-11-22 with why. Anything not listed must write nothing.
local CEILINGS = {
	["Core/Skin.lua SetVertexColor"] = { 1, "a colour's alpha replaces a hushed texture's alpha (texture alpha is one value), so the hush answers each recolour once" },
	["Core/Skin.lua SetColorTexture"] = { 1, "as SetVertexColor" },
	["Core/Skin.lua SetChecked"] = { 2, "a skinned check box repaints its mark on every SetChecked" },
	["KstyleUI_Skins/Addons/RestedXP/Chrome.lua SetStep"] = { 530, "RestedXP rebuilds its step frames on every SetStep and the chrome re-skins every step, caption and heading instead of only what changed; the rail's Place returns on its unchanged key" },
	["KstyleUI_Skins/Addons/RestedXP/Chrome.lua UpdateItemFrame"] = { 425, "RestedXP re-lists its item buttons and resets the box width on every UpdateItemFrame (BAG_UPDATE_DELAYED): the chrome re-skins every icon button and the box's glass and heading relay out twice, for RestedXP's width and for the width the rail docks back" },
	["KstyleUI_Skins/Addons/RestedXP/Chrome.lua UpdateTargetFrame"] = { 221, "as UpdateItemFrame, for the target box" },
	["KstyleUI_Skins/Addons/RestedXP/Chrome.lua UpdateText"] = { 52, "RestedXP rewrites every step line and the chrome re-aligns and recolours the steps without comparing" },
	["KstyleUI_Skins/Addons/RestedXP/Chrome.lua SetText"] = { 22, "a same-text SetText refits the guide heading (SetHeading) and repaints a step caption (Worded, PaintCaption)" },
	["KstyleUI_Skins/Addons/RestedXP/Chrome.lua SetFont"] = { 25, "PaintCaption restyles the caption, its colour and its heading, and PaintReadable re-measures the line pitch on its ruler and sets the outline again, on every RestedXP font set" },
	["KstyleUI_Skins/Addons/RestedXP/Chrome.lua SetTexture"] = { 4, "mirrors RestedXP's texture into KstyleUI's own art and shows it, each call" },
	["KstyleUI_Skins/Addons/Questie.lua SetText"] = { 3, "Refresh hushes Questie's label and shows the section cap again on every label SetText" },
	["KstyleUI_Skins/Quests/Quests.lua HideWatchFrame"] = { 1, "SyncQuestie calls Questie's HideWatchFrame again to keep the two trackers in step" },
	["KstyleUI_Skins/Tracker.lua SetText"] = { 2, "mirrors the objective line's text into its count label, each call" },
	["KstyleUI_Skins/Lumen.lua SetChecked"] = { 3, "the Lumen ring repaints its fill and ring on every SetChecked, changed or not" },
	["KstyleUI_Skins/Parts.lua SetText"] = { 5, "a window title's section cap places itself again on every SetText, same text or not" },
	["KstyleUI_Skins/Parts.lua SetChecked"] = { 1, "a skinned tab sets its wash alpha on every SetChecked" },
	["KstyleUI_Skins/Parts.lua SetVertexColor"] = { 1, "a skinned fill follows the owner's colour, each call" },
	["KstyleUI_Skins/Style.lua SetStatusBarColor"] = { 1, "a skinned status bar follows the owner's colour, each call" },
	["KstyleUI_Skins/PartC/Kit.lua Hide"] = { 1, "mirrors the bar's shown state onto KstyleUI's own bar, each call" },
	["KstyleUI_Skins/PartC/Kit.lua SetShown"] = { 1, "mirrors the bar's shown state onto KstyleUI's own bar, each call" },
	["KstyleUI_Skins/PartC/Kit.lua SetMinMaxValues"] = { 1, "mirrors the bar's range onto KstyleUI's own bar, each call" },
	["KstyleUI_Skins/PartC/Kit.lua SetValue"] = { 1, "mirrors the bar's value onto KstyleUI's own bar, each call" },
	["KstyleUI_Skins/PartC/Kit.lua SetStatusBarColor"] = { 4, "mirrors the bar's colour onto KstyleUI's own bar and its edge, each call" },
	["KstyleUI_Skins/Addons/Zygor.lua ResizeFrame"] = { 325, "Fit re-fits the guide after every Zygor ResizeFrame without comparing" },
	["KstyleUI_Skins/Addons/Zygor.lua ReanchorFrame"] = { 8, "Assert re-anchors and re-clamps Zygor's window on every ReanchorFrame" },
	["KstyleUI_Skins/Addons/Zygor.lua SetFrameScale"] = { 2, "Place returns on its unchanged key but Follow re-anchors Zygor's action bar each call" },
	["KstyleUI_Skins/Addons/Zygor.lua ShowTraveling"] = { 2, "FlatArrow sets the arrow's colour and sheen alpha on every ShowTraveling, which Zygor calls every frame" },
	["KstyleUI_Skins/Addons/Zygor.lua SetFontSize"] = { 4, "Zygor sets Friz Quadrata on the arrow text every time, so ArrowText sets KstyleUI's face, colour and shadow back each call" },
	["Zygor RestyleUnder"] = { 2, "the Zygor rail's tracked Restyle has no region, so Follow re-anchors Zygor's action bar on every scoped restyle" },
	["KstyleUI_Minimap/Drawer.lua SetPoint"] = { 6, "Drawer:Place re-anchors and resizes a LibDBIcon button the library moves, even when it is already in its slot" },
}

local function Addon(source)
	return source:find("^@Core/") ~= nil or source:find("^@KstyleUI_") ~= nil
end

local function Ours(object)
	local origin = rawget(object, "_origin")
	return type(origin) == "string" and (origin:find("^Core/") ~= nil or origin:find("^KstyleUI_") ~= nil)
end

-- Cost(env, run) -> ok, err, writes, by, instructions: the widget calls other than reads made while KstyleUI code is
-- on the stack (directly, or through another addon's function or a hooked method it called), by method, and the
-- addon VM instructions, sampled every 100.
local function Cost(env, run)
	local writes, by, instructions = 0, {}, 0
	env._onCall = function(_, method)
		for level = 3, 80 do
			local info = debug.getinfo(level, "S")
			if not info then
				return
			end
			if Addon(info.source) then
				writes = writes + 1
				by[method] = (by[method] or 0) + 1
				return
			end
		end
	end
	debug.sethook(function()
		if Addon(debug.getinfo(2, "S").source) then
			instructions = instructions + 100
		end
	end, "", 100)
	local ok, err = pcall(run)
	debug.sethook()
	env._onCall = nil
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

-- Record(env, hooks): every hooksecurefunc KstyleUI installs from here on is listed with its target, method, site and
-- the arguments of the last call it saw.
local function Record(env, hooks)
	local hook = env.hooksecurefunc
	env.hooksecurefunc = function(a, b, c)
		local target, name, fn = a, b, c
		if type(a) == "string" then
			target, name, fn = env, a, b
		end
		local info = debug.getinfo(2, "Sl")
		if not Addon(info.source) then
			info = debug.getinfo(fn, "S")
			info.currentline = info.linedefined
		end
		if not Addon(info.source) then
			return hook(a, b, c)
		end
		local file = info.short_src:gsub("^%./", "")
		local rec = { target = target, name = name, file = file, site = file .. ":" .. info.currentline }
		hooks[#hooks + 1] = rec
		local function recorded(...)
			rec.args = { n = select("#", ...), ... }
			return fn(...)
		end
		if target == env then
			return hook(name, recorded)
		end
		return hook(target, name, recorded)
	end
end

local failures, checked = {}, 0

-- Last(object, method) -> the arguments of the object's last call of method, the object first, or nil.
local function Last(object, method)
	local calls = object._calls
	for i = #calls, 1, -1 do
		local call = calls[i]
		if call.method == method then
			local args = { n = call.args.n + 1, object }
			for k = 1, call.args.n do
				args[k + 1] = call.args[k]
			end
			return args
		end
	end
	return nil
end

-- Settle(label, env, K, hooks): replay every foreign hook and run scoped restyles of an unrelated frame.
local function Settle(label, env, K, hooks)
	local groups, order = {}, {}
	for _, rec in ipairs(hooks) do
		local t = rec.target
		local widget = rawget(t, "_calls") ~= nil
		local args = rec.args or widget and Last(t, rec.name)
		if args and not (widget and Ours(t)) and t ~= K then
			local key = tostring(t) .. "." .. rec.name
			local group = groups[key]
			if not group then
				group = { target = t, name = rec.name, sites = {}, floor = 0 }
				groups[key] = group
				order[#order + 1] = group
			end
			group.args = args
			group.sites[#group.sites + 1] = rec.site
			local ceiling = CEILINGS[rec.file .. " " .. rec.name]
			group.floor = group.floor + (ceiling and ceiling[1] or 0)
		end
	end
	for _, group in ipairs(order) do
		local t, args = group.target, group.args
		local function Once()
			t[group.name](unpack(args, 1, args.n))
			env.RunTimers()
		end
		if pcall(Once) then
			checked = checked + 1
			local ok, err, writes, by, instructions = Cost(env, function()
				for _ = 2, REPLAYS do
					Once()
				end
			end)
			local per = writes / (REPLAYS - 1)
			if not ok then
				failures[#failures + 1] = string.format("%s: replaying %s raised %s", label, group.name, tostring(err))
			elseif per > group.floor then
				failures[#failures + 1] = string.format("%s: %s hooks %s on %s; replaying the owner's last call wrote %.1f times per call from KstyleUI (%s), %d addon instructions per call, allowed %d. A hook on a frame KstyleUI does not own must return when what it wants is already in place: add an unchanged-value return (compare the value or a key of the inputs before writing, as Zygor's Face and Place do since #685), or, for work that is not yours to fix here, list today's cost in CEILINGS with its why.",
					label, table.concat(group.sites, ", "), group.name, t.GetName and tostring(t:GetName()) or "a table", per, List(by), math.floor(instructions / (REPLAYS - 1)), group.floor)
			end
		end
	end
	local probe = env.CreateFrame("Frame")
	local ok, err, writes, by = Cost(env, function()
		for _ = 1, REPLAYS do
			K.Widgets.RestyleUnder({ [probe] = true })
			env.RunTimers()
		end
	end)
	assert(ok, err)
	local ceiling = CEILINGS[label .. " RestyleUnder"]
	if writes / REPLAYS > (ceiling and ceiling[1] or 0) then
		failures[#failures + 1] = string.format("%s: %d scoped restyles of an unrelated frame wrote %d times (%s). A tracked widget with no region runs on every scoped restyle: give the handle the frame it styles (owner, holder, frame, bar, button or target) so Widgets.RestyleUnder skips it (#685).", label, REPLAYS, writes, List(by))
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, label .. ": " .. tostring(env._errors[1]))
end

-- The RestedXP guide and Questie's tracker beside the quest card and Blizzard's tracker.
do
	local hooks = {}
	local R = Boot({ width = 1920, height = 1080, uiScale = 768 / 1080 }, nil, nil, nil, function(e, log)
		Record(e, hooks)
		return Questie.Install(e, log)
	end)
	R.K.Options.Write("Integrations", "questTracker", "questie")
	R.rxp:SortTimers()
	R.settle()
	Settle("RestedXP and Questie", R.env, R.K, hooks)
end

-- Zygor's guide window at 1600x900 and size 0.53, where the #685 loop showed in the stub.
do
	local hooks, zygor = {}, nil
	local env, K = S.New({
		width = 1600, height = 900, size = 0.53,
		saved = { version = 12, profiles = { Default = { Layout = { preset = "DPS" } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} },
		setup = function(e)
			Record(e, hooks)
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
	Settle("Zygor", env, K, hooks)
end

-- Other addons' LibDBIcon buttons in the minimap's drawer.
do
	local hooks, lib = {}, nil
	local env, K = M.New({ enabled = true, setup = function(e)
		Record(e, hooks)
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
	Settle("Minimap drawer", env, K, hooks)
end

-- Every Blizzard window KstyleUI_Skins restyles, open.
do
	local hooks, B, shown = {}, nil, {}
	local env, K = S.New({
		setup = function(e)
			Record(e, hooks)
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
	env.RunTimers()
	S.W.Settle(env)
	Settle("Blizzard windows", env, K, hooks)
end

assert(checked > 0, "the fight detector replayed no hooks")
assert(#failures == 0, #failures .. " fight(s):\n" .. table.concat(failures, "\n"))
print(string.format("perf fights ok: %d hooked calls replayed on frames and tables KstyleUI does not own", checked))
