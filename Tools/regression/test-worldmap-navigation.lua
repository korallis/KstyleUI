-- test-worldmap-navigation.lua: smooth wheel zoom, boundary navigation, cursor-only preload and per-map saved zoom.
-- Canvas wheel, reset and lerp contract: MapCanvas_ScrollContainerMixin.lua at 9dc84f0.
local Windows = dofile("Tools/regression/skins_windows.lua")
local S = Windows.S

local function Clamp(value, low, high)
	assert(type(value) == "number" and value == value, "canvas scale and pan must be finite numbers")
	assert(low <= high, "canvas scroll extents must be ordered")
	return math.max(low, math.min(high, value))
end

local function New(saved, missing)
	local map, scroll
	local env, K, ns = S.New({ saved = saved, before = function(e)
		map = Windows.Build("worldmap", e, S.Blizzard(e))
		scroll = map.ScrollContainer
		e.MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_SMOOTH = 1
		e.MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_FULL = 2
		e._preloads = {}
		e._mapInfo = { [1] = { mapID = 1, parentMapID = 0 }, [2] = { mapID = 2, parentMapID = 1 }, [3] = { mapID = 3, parentMapID = 2 } }
		e.C_Map = {
			GetMapInfo = function(id) assert(type(id) == "number"); return e._mapInfo[id] end,
			GetMapInfoAtPosition = function(id, x, y)
				assert(type(id) == "number" and type(x) == "number" and type(y) == "number", "map queries require map id and coordinates")
				return e._mapInfo[e._hover or id]
			end,
			GetMapRectOnMap = function(id, parent)
				assert(e._mapInfo[id].parentMapID == parent, "rect must frame a child on its parent")
				return .2, .4, .3, .5
			end,
			RequestPreloadMap = function(id)
				assert(type(id) == "number", "preload requires a map id")
				e._preloads[#e._preloads + 1] = id
			end,
		}
		function scroll:SetMouseWheelZoomMode(mode) self.mouseWheelZoomMode = mode end
		function scroll:SetShouldZoomInstantly(on) self.shouldZoomInstantly = on end
		function scroll:GetScaleForMinZoom() return 1 end
		function scroll:GetScaleForMaxZoom() return 4 end
		function scroll:GetCanvasScale() return self.currentScale or self.targetScale or 1 end
		function scroll:SetZoomTarget(scale) self.targetScale = Clamp(scale, 1, 4) end
		function scroll:SetPanTarget(x, y) self.targetScrollX, self.targetScrollY = x, y end
		function scroll:InstantPanAndZoom(scale, x, y, ignoreScaleRatio)
			if not ignoreScaleRatio then
				local ratio = self:GetCanvasScale() / scale
				x = x + ((self.currentScrollX or self.targetScrollX or .5) - x) * ratio
				y = y + ((self.currentScrollY or self.targetScrollY or .5) - y) * ratio
			end
			self.currentScale, self.targetScale = scale, scale
			local offset = math.min(.5 / scale, .5)
			self.currentScrollX, self.currentScrollY = Clamp(x, offset, 1 - offset), Clamp(y, offset, 1 - offset)
			self:SetPanTarget(self.currentScrollX, self.currentScrollY)
		end
		function scroll:ResetZoom() self:InstantPanAndZoom(1, .5, .5) end
		function scroll:GetNormalizedCursorPosition() return e._cursorX or .3, e._cursorY or .4 end
		function scroll:ShouldAdjustTargetPanOnMouseWheel(delta)
			return self.mouseWheelZoomMode == 1 or (delta > 0 and self:GetCanvasScale() < 4) or (delta < 0 and self:GetCanvasScale() > 1)
		end
		function scroll:OnMouseWheel(delta)
			if self:ShouldAdjustTargetPanOnMouseWheel(delta) then self:SetPanTarget(e._cursorX or .3, e._cursorY or .4) end
			if self.mouseWheelZoomMode == 1 then
				self:SetZoomTarget(self:GetCanvasScale() + .075 * delta)
			else
				local scale = Clamp(self:GetCanvasScale() + (delta > 0 and 1 or -1), 1, 4)
				if self.shouldZoomInstantly then self:InstantPanAndZoom(scale, self.targetScrollX, self.targetScrollY)
				else self:SetZoomTarget(scale) end
			end
		end
		function scroll:OnUpdate()
			self.currentScale = self:GetCanvasScale() + (self.targetScale - self:GetCanvasScale()) * .15
			self.currentScrollX = (self.currentScrollX or self.targetScrollX) + (self.targetScrollX - (self.currentScrollX or self.targetScrollX)) * .15
			self.currentScrollY = (self.currentScrollY or self.targetScrollY) + (self.targetScrollY - (self.currentScrollY or self.targetScrollY)) * .15
		end
		function scroll:OnHide() self.currentScale, self.currentScrollX, self.currentScrollY = nil, nil, nil end
		function scroll:OnMouseUp(button)
			e._secure = true
			if button == "LeftButton" and e._hover then map:SetMapID(e._hover)
			elseif button == "RightButton" then map:NavigateToParentMap() end
			e._secure = false
		end
		local pin = e.CreateFrame("Button", nil, scroll)
		e._pinAcquires = 0
		function map:AcquirePin()
			e._pinAcquires = e._pinAcquires + 1
			pin:SetPassThroughButtons()
			pin:SetPassThroughButtons("RightButton")
		end
		function map:SetMapID(id)
			if self.mapID == id then return end
			self.mapID, scroll.mapID = id, id
			scroll:ResetZoom()
			self:AcquirePin()
		end
		function map:NavigateToParentMap()
			local info = e.C_Map.GetMapInfo(self.mapID)
			if info and info.parentMapID > 0 then self:SetMapID(info.parentMapID) end
		end
		scroll:SetMouseWheelZoomMode(2)
		scroll:SetShouldZoomInstantly(true)
		map:SetMapID(2)
		if missing then missing(e, map, scroll) end
	end })
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_WorldMap")
	S.Show(map)
	return env, K, ns, map, scroll
end

local function Near(a, b) assert(math.abs(a - b) < .00001, tostring(a) .. " ~= " .. tostring(b)) end
local function Clean(env, K) assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1])) end

local env, K, _, map, scroll = New()
assert(scroll.mouseWheelZoomMode == 1 and scroll.shouldZoomInstantly == false)
scroll:OnMouseWheel(1)
Near(scroll.currentScale, 1)
Near(scroll.targetScale, 1.075)
scroll:OnUpdate()
assert(scroll.currentScale > 1 and scroll.currentScale < scroll.targetScale, "canvas's existing update eases zoom")
K.Options.Write("Skins", "worldMap.smoothZoom", false)
assert(scroll.mouseWheelZoomMode == 2 and scroll.shouldZoomInstantly == true)
K.Options.Write("Skins", "worldMap.wheelMaps", false)
scroll:InstantPanAndZoom(2, .5, .5, true)
scroll:OnMouseWheel(1)
Near(scroll.currentScale, 3)
K.Options.Write("Skins", "worldMap.smoothZoom", true)
K.Options.Write("Skins", "worldMap.wheelMaps", true)

-- The wheel that reaches a boundary stays on the current map, including instant mode.
K.Options.Write("Skins", "worldMap.smoothZoom", false)
scroll:InstantPanAndZoom(2, .5, .5, true)
scroll:OnMouseWheel(-1)
assert(map.mapID == 2)
scroll:OnMouseWheel(-1)
assert(map.mapID == 1)
K.Options.Write("Skins", "worldMap.smoothZoom", true)
map:SetMapID(2)
scroll:InstantPanAndZoom(1, .5, .5, true)
scroll:OnMouseWheel(-1)
assert(map.mapID == 1, "wheel out at min navigates to the parent")
Near(scroll.currentScale, 4)
Near(scroll.currentScrollX, .3)
Near(scroll.currentScrollY, .4)
Near(scroll.targetScale, 1)
Near(scroll.targetScrollX, .5)
scroll:OnUpdate()
assert(scroll.currentScale < 4 and scroll.currentScale > 1, "parent opens framed on the child then eases out")

map:SetMapID(2)
env._hover = 3
env._preloads = {}
scroll:InstantPanAndZoom(2, .5, .5, true)
scroll:OnMouseWheel(1)
scroll:OnMouseWheel(1)
assert(#env._preloads == 1 and env._preloads[1] == 3, "preload only the map under the cursor, once")
scroll:InstantPanAndZoom(4, .5, .5, true)
env.SetCombat(true)
local acquired = env._pinAcquires
for _, smooth in ipairs({ true, false }) do
	K.Options.Write("Skins", "worldMap.smoothZoom", smooth)
	scroll:InstantPanAndZoom(4, .5, .5, true)
	scroll:OnMouseWheel(1)
	assert(map.mapID == 2, "combat wheel at max must stay on the current map")
	scroll:InstantPanAndZoom(1, .5, .5, true)
	scroll:OnMouseWheel(-1)
	assert(map.mapID == 2 and env._pinAcquires == acquired, "combat wheel must never acquire pins or call protected SetPassThroughButtons")
	scroll:OnMouseWheel(1)
	assert(scroll.targetScale > 1, "combat wheel still zooms within the current map")
end
scroll:OnMouseUp("LeftButton")
assert(map.mapID == 3, "Blizzard's secure left click still navigates in combat")
scroll:OnMouseUp("RightButton")
assert(map.mapID == 2 and env._pinAcquires == acquired + 2, "Blizzard's secure right click still acquires pins in combat")
env.SetCombat(false)
K.Options.Write("Skins", "worldMap.smoothZoom", true)
scroll:InstantPanAndZoom(4, .5, .5, true)
scroll:OnMouseWheel(1)
assert(map.mapID == 3, "wheel in at max navigates outside combat")
scroll:InstantPanAndZoom(1, .5, .5, true)
scroll:OnMouseWheel(-1)
assert(map.mapID == 2, "wheel out navigates outside combat")

K.Options.Write("Skins", "worldMap.wheelMaps", false)
scroll:InstantPanAndZoom(1, .5, .5, true)
scroll:OnMouseWheel(-1)
assert(map.mapID == 2)
scroll:InstantPanAndZoom(4, .5, .5, true)
scroll:OnMouseWheel(1)
assert(map.mapID == 2 and #env._preloads == 1, "off disables transitions and preloading")
scroll:OnMouseUp("LeftButton")
assert(map.mapID == 3, "left click still navigates")
scroll:OnMouseUp("RightButton")
assert(map.mapID == 2, "right click still navigates to parent")

scroll:InstantPanAndZoom(2.5, .35, .6, true)
scroll:OnMouseUp("MiddleButton")
local beforeUpdate = K.Store.Module("Skins").worldMap.zooms[2]
scroll:OnUpdate()
assert(K.Store.Module("Skins").worldMap.zooms[2] == beforeUpdate, "OnUpdate must not save or allocate zoom state; save on wheel, drag end, map change or hide")
map:SetMapID(3)
scroll:InstantPanAndZoom(3, .7, .25, true)
scroll:OnMouseUp("MiddleButton")
map:SetMapID(2)
Near(scroll.currentScale, 2.5)
Near(scroll.currentScrollX, .35)
Near(scroll.currentScrollY, .6)
scroll:ResetZoom()
Near(scroll.currentScale, 2.5)
scroll:OnHide()
local saved = env.KstyleUIDB
Clean(env, K)

local reload, RK, _, rmap, rscroll = New(saved)
Near(rscroll.currentScale, 2.5)
Near(rscroll.currentScrollX, .35)
rmap:SetMapID(3)
Near(rscroll.currentScale, 3)
Near(rscroll.currentScrollX, .7)
Near(rscroll.currentScrollY, .25)
RK.Options.Write("Skins", "worldMap.rememberZoom", false)
rmap:SetMapID(2)
Near(rscroll.currentScale, 1)
rscroll:InstantPanAndZoom(4, .5, .5, true)
rscroll:OnUpdate()
RK.Options.Write("Skins", "worldMap.rememberZoom", true)
rscroll:ResetZoom()
Near(rscroll.currentScale, 2.5)
RK.Options.Write("Skins", "worldMap.enabled", false)
assert(rscroll.mouseWheelZoomMode == 2 and rscroll.shouldZoomInstantly == true)
rscroll:ResetZoom()
Near(rscroll.currentScale, 1)
RK.Options.Write("Skins", "worldMap.enabled", true)
assert(rscroll.mouseWheelZoomMode == 1 and rscroll.shouldZoomInstantly == false)
RK.Modules.Disable("Skins")
assert(rscroll.mouseWheelZoomMode == 2 and rscroll.shouldZoomInstantly == true)
Clean(reload, RK)

for _, missing in ipairs({ "C_Map", "GetMapInfoAtPosition", "RequestPreloadMap", "GetMapRectOnMap", "GetMapInfo", "ResetZoom", "GetNormalizedCursorPosition", "SetMouseWheelZoomMode", "SetShouldZoomInstantly" }) do
	local e, k, _, m, s = New(nil, function(e, _, s)
		if missing == "C_Map" then e.C_Map = nil
		elseif e.C_Map[missing] then e.C_Map[missing] = nil
		else s[missing] = nil end
	end)
	s:OnMouseWheel(-1)
	assert(m.mapID == 1 or m.mapID == 2)
	Clean(e, k)
end

local e, k, _, m, s = New()
e.C_Map.GetMapRectOnMap = function() return nil end
s:OnMouseWheel(-1)
assert(m.mapID == 1, "a missing rectangle still allows parent navigation")
s:OnMouseWheel(-1)
assert(m.mapID == 1, "the world has no parent")
e.C_Map.GetMapInfoAtPosition = function() return nil end
s:InstantPanAndZoom(4, .5, .5, true)
s:OnMouseWheel(1)
assert(m.mapID == 1 and #e._preloads == 0, "empty map positions do not preload or navigate")
k.Store.Module("Skins").worldMap.zooms[1] = { e.Secret(3), .5, .5 }
s:ResetZoom()
Near(s.currentScale, 1)
k.Store.Module("Skins").worldMap.zooms[1] = false
s:OnUpdate()
assert(k.Store.Module("Skins").worldMap.zooms[1] == false, "OnUpdate must not write saved zoom; save on wheel, drag end, map change or hide")
s:OnHide()
assert(type(k.Store.Module("Skins").worldMap.zooms[1]) == "table", "invalid saved entries recover on the next save")
Clean(e, k)
print("world map navigation ok: smooth/full, parent/child, preload, combat, clicks, saved reload, toggles and missing APIs")
