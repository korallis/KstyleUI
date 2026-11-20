-- test-cooldowns-bar-height.lua: restyled tracked bars share the mirror's height on every screen without moving a saved viewer.
local C = dofile("Tools/regression/cooldowns_env.lua")
local Common = dofile("Tools/render/scenes/_common.lua")
local F = dofile("Tools/regression/editmode_fake.lua")

local previous = rawget(_G, "RENDER_SCREEN")
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], uiScale = 768 / 1080, size = "auto" })
	local env, K, ns = C.New({ setup = function(e)
		C.Game(e)
		Common.ForceScreen(e)
	end })
	local edit = { saved = {}, active = 1 }
	F.Install(env, edit)
	env.EditModeManagerFrame = setmetatable({ IsShown = function() return true end, IsEditModeActive = function() return true end }, {
		__newindex = function() error("restyling bars must not write the Edit Mode manager") end,
	})
	local pooled = env._viewers.BuffBarCooldownViewer._items[2]
	assert(pooled:GetHeight() == 30 and pooled.Icon:GetHeight() == 30 and pooled.Bar:GetHeight() == 19, "initialize pooled tracked bars with Forever's XML dimensions before native layout")
	C.Enable(env, K)
	local entry = F.Find(F.Modern(), F.VIEWER, F.BUFF_BAR)
	entry.anchorInfo = { point = "TOPRIGHT", relativePoint = "TOPRIGHT", offsetX = -137, offsetY = -219 }
	local viewer = C.Native(env, "BuffBarCooldownViewer", entry, {
		{ id = 401, icon = 135000, name = "Battle Shout", left = 24, total = 120 },
		{ id = 402, icon = 135001, name = "Enrage", left = 8, total = 12 },
	}, tostring)
	local function Check()
		for _, item in ipairs(viewer._items) do
			local factor = K.Widgets.ScaleFactor(item)
			local height = K.Scale.Snap(ns.Settings.current.bars.height)
			assert(C.W.Near(item:GetHeight() * factor, height), "size restyled tracked bars to the shared bar height on " .. screen[1] .. "x" .. screen[2])
			assert(C.W.Near(item.Icon:GetHeight() * factor, height) and C.W.Near(item.Icon:GetWidth() * factor, height), "match the tracked icon tile to the shared bar height")
			assert(C.W.Near((item.Bar:GetHeight() + 2 * K.Widgets.Border(item.Bar)) * factor, height), "fit the tracked fill and its black edge inside the shared bar height")
			assert(item.Bar.Pip:GetAlpha() == 0, "keep tracked bars spark-free, like tooltip and group bars")
		end
		local point, relative, relativePoint, x, y = viewer:GetPoint()
		assert(point == "TOPRIGHT" and relative == env.UIParent and relativePoint == "TOPRIGHT" and x == -137 and y == -219, "resizing tracked bars must preserve the saved viewer anchor")
		local first, second = viewer._items[1], viewer._items[2]
		local offset = select(5, second:GetPoint()) * second:GetScale()
		assert(C.W.Near(-offset, first:GetHeight() * first:GetScale() + viewer._nativePadding), "relayout native tracked bars after resizing so their rows keep Edit Mode spacing")
	end
	Check()
	env.SetCombat(true)
	viewer:SetScale(1.3)
	viewer._items[1]:SetScale(0.7)
	Check()
	K.Options.Write("Cooldowns", "bars.height", 18)
	Check()
	K.Options.Write("Cooldowns", "path", "reskin")
	local fresh = C.Item(env, viewer, 403)
	viewer:OnAcquireItemFrame(fresh)
	viewer._nativeCount = #viewer._items
	viewer:Layout()
	Check()
	local function Restored()
		for _, item in ipairs(viewer._items) do
			assert(item:GetHeight() == 30 and item.Bar:GetHeight() == 19, "restore Blizzard's tracked-bar heights immediately when native restyling stops")
			assert(item.Icon:GetHeight() == 30 and item.Icon:GetWidth() == 30, "restore Blizzard's tracked icon dimensions immediately when native restyling stops")
		end
		local first, second = viewer._items[1], viewer._items[2]
		local offset = select(5, second:GetPoint()) * second:GetScale()
		assert(C.W.Near(-offset, first:GetHeight() * first:GetScale() + viewer._nativePadding), "reflow restored native bar heights immediately so Blizzard's rows do not overlap")
	end
	K.Options.Write("Cooldowns", "path", "mirror")
	Restored()
	viewer:SetScale(0.9)
	fresh:SetScale(0.8)
	Restored()
	K.Options.Write("Cooldowns", "path", "reskin")
	Check()
	env.SetCombat(false)
	K.Modules.Disable("Cooldowns")
	Restored()
	assert(not edit.saves and not edit.activated, "tracked-bar resize and restore must not save or activate an Edit Mode layout")
	assert(#env._errors == 0 and K.ErrorCount() == 0, "tracked bars must resize and restore safely in combat and Edit Mode")
	C.Clean(env, { SetPoint = true, ClearAllPoints = true, SetSize = true, SetParent = true, Hide = true, SetScript = true })
end
rawset(_G, "RENDER_SCREEN", previous)
print("cooldowns bar height ok")
