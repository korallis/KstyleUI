-- skins_env.lua: load the core and the KstyleUI_Skins addon into a stub environment, with stand-in Blizzard windows.
--
--   local S = dofile("Tools/regression/skins_env.lua")
--   local env, K, ns = S.New({ before = function(env, K, ns) ns.Skins.Add(def) end })
--   K.Modules.Enable("Skins")      -- runs Enable, which arms every skin
--
-- S.New(opts) takes the widget_env options plus:
--   before(env, K, ns)  runs after every skin file has loaded and before Module.lua registers the module
--   loaded              { [addonName] = true } for C_AddOns.IsAddOnLoaded; nil for a client without C_AddOns
-- The core is booted (saved data loaded, PLAYER_LOGIN fired) before the module's files load.
local W = dofile("Tools/regression/widget_env.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")

local S = { W = W }

local MODULE_FILE = "KstyleUI_Skins/Module.lua"

local files
function S.Files()
	if not files then
		files = {}
		for _, path in ipairs(TocFiles("%.lua$")) do
			if path:match("^KstyleUI_Skins/") then
				files[#files + 1] = path
			end
		end
		assert(#files > 0, "no KstyleUI_Skins files found")
		assert(files[#files] == MODULE_FILE, "Skins.xml must load Module.lua last, got " .. files[#files])
	end
	return files
end

function S.New(opts)
	opts = opts or {}
	local setup = opts.setup
	opts.setup = function(env)
		env._loaded = opts.loaded
		if opts.loaded ~= false then
			env._loaded = env._loaded or {}
			env.C_AddOns = {
				IsAddOnLoaded = function(name)
					local loaded = env._loaded[name] == true
					return loaded, loaded
				end,
			}
		end
		if setup then
			setup(env)
		end
	end
	local env, K = W.New(opts)
	local list = S.Files()
	local before = {}
	for i = 1, #list - 1 do
		before[i] = list[i]
	end
	Load(before, env)
	local ns = env._addons.KstyleUI_Skins
	if opts.before then
		opts.before(env, K, ns)
	end
	Load({ MODULE_FILE }, env)
	return env, K, ns
end

-- LoadAddOn(env, name) marks a Blizzard addon loaded and fires its ADDON_LOADED.
function S.LoadAddOn(env, name)
	env._loaded = env._loaded or {}
	env._loaded[name] = true
	env.FireEvent("ADDON_LOADED", name, false)
end

-- Show(frame) shows a stand-in Blizzard window and runs its OnShow scripts, as the game does.
function S.Show(frame)
	frame:Show()
	local fn = frame:GetScript("OnShow")
	if fn then
		fn(frame)
	end
end

-- Blizzard(env) -> a builder of stand-in Blizzard frames that remembers every object it made, and
-- check(snapshot, hooked) fails on a field written onto one since the snapshot, other than a method a
-- hook replaced, or a SetScript, Hide or SetParent call on one since the snapshot.
local HOOKED = { SetAlpha = true, SetTabSelected = true, SetChecked = true, SetStatusBarColor = true, SetVertexColor = true }

local function fields(object)
	local out = {}
	for k in pairs(object) do
		if type(k) ~= "string" or k:sub(1, 1) ~= "_" then
			out[k] = true
		end
	end
	return out
end

function S.Blizzard(env)
	local made = {}
	local b = { made = made }
	function b.add(object)
		made[#made + 1] = object
		return object
	end
	function b.frame(kind, parent, name)
		local f = env.CreateFrame(kind or "Frame", name, parent or env.UIParent)
		if name then
			env[name] = f
		end
		return b.add(f)
	end
	function b.texture(frame, layer)
		local t = frame:CreateTexture(nil, layer or "ARTWORK")
		t:SetTexture("Interface\\Blizzard\\Art")
		return b.add(t)
	end
	function b.text(frame)
		return b.add(frame:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
	end
	function b.snapshot()
		local snap = { calls = {} }
		for _, object in ipairs(made) do
			snap[object] = fields(object)
			snap.calls[object] = #object._calls
		end
		return snap
	end
	function b.check(snap, hooked)
		hooked = hooked or {}
		for _, object in ipairs(made) do
			local before = snap[object] or {}
			for k in pairs(fields(object)) do
				assert(before[k] or HOOKED[k] or hooked[k], "a field was written onto a Blizzard object: " .. tostring(k))
			end
			for i = (snap.calls[object] or 0) + 1, #object._calls do
				local call = object._calls[i]
				assert(call.method ~= "SetScript", "SetScript on a Blizzard object")
				assert(call.method ~= "Hide", "Hide on a Blizzard object")
				assert(call.method ~= "SetParent", "SetParent on a Blizzard object")
			end
		end
	end
	return b
end

-- ScrollBox(b, parent) -> a stand-in WowScrollBoxList. Rows are children of box.ScrollTarget, as in the
-- game; rows added with box.AddRow(row) show through
-- ForEachFrame, and box.Init(row, data) runs the callbacks ScrollUtil.AddInitializedFrameCallback added,
-- as the list does when it shows a row. S.UseScrollUtil(env) installs that ScrollUtil.
function S.ScrollBox(b, parent)
	local box = b.frame("Frame", parent)
	box.ScrollTarget = b.frame("Frame", box)
	local rows, callbacks = {}, {}
	box._rows, box._callbacks = rows, callbacks
	function box.ForEachFrame(self, fn)
		for _, row in ipairs(rows) do
			fn(row, row._data)
		end
	end
	function box.AddRow(row, data)
		rows[#rows + 1] = row
		row._data = data
		return row
	end
	function box.Init(row, data)
		row._data = data
		for _, entry in ipairs(callbacks) do
			entry.fn(entry.owner, row, data)
		end
	end
	return box
end

function S.UseScrollUtil(env)
	env.ScrollUtil = {
		AddInitializedFrameCallback = function(box, fn, owner, iterate)
			assert(owner ~= nil, "a ScrollBox callback needs an owner")
			assert(not iterate, "iterating existing frames passes no owner; call ForEachFrame instead")
			box._callbacks[#box._callbacks + 1] = { fn = fn, owner = owner }
		end,
	}
end

-- Logged(env, text) -> the first devlog message of the Skins module that contains text, or nil.
function S.Logged(env, text)
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.module == "Skins" and tostring(entry.message):find(text, 1, true) then
			return entry.message
		end
	end
end

return S
