-- test-minimap-coords-plate.lua: on the round Medallions map the coordinates plate sits centred under the map, and with the clock away from it the coordinates read centred in the plate with even padding; beside the clock they keep the left end.
local M = dofile("Tools/regression/minimap_env.lua")
local G = dofile("Tools/regression/geometry.lua")

local TEXT = "46.7, 61.2"

-- A font string with no width of its own is as wide as its text, as the game sizes it.
local function TextCentre(rect, text)
	local justify, width = text:GetJustifyH(), text:GetStringWidth()
	if justify == "CENTER" then
		return (rect.left + rect.right) / 2
	elseif justify == "RIGHT" then
		return rect.right - width / 2
	end
	return rect.left + width / 2
end

for _, screen in ipairs({ { 1920, 1080 }, { 3840, 2160 } }) do
	local env, K, ns = M.New({ enabled = true, width = screen[1], height = screen[2], size = "auto",
		setup = function(e) e.KstyleUIDB.profiles.Default.HudStyle = { style = "medallions" } end })
	env._textWidth = function(text, _, size) return #text * size * 0.55 end
	M.Settle(env)
	local face = ns.Map.face
	local pixel = K.Scale.Pixel(1)
	local function Rect(region) return assert(G.ScaledRect(region, env.UIParent, K.Scale.Root())) end
	for _, frame in ipairs({ "medallion", "ring", "classic" }) do
		for _, clock in ipairs({ false, true }) do
			local label = frame .. " clock=" .. tostring(clock) .. " " .. screen[1] .. "x" .. screen[2]
			K.Options.Write("Minimap", "frame", frame)
			K.Options.Write("Minimap", "clock.shown", clock)
			face:SetCoords(TEXT)
			ns.Map.Refresh()
			face:SetCoords(TEXT)
			M.Settle(env)
			local row, map = Rect(face.plaques[2]), Rect(face.mapArea)
			local text = face.coords
			local w, h = text._width, text._height
			text._width = w or text:GetStringWidth()
			text._height = h or text:GetStringHeight()
			local coords = Rect(text)
			text._width, text._height = w, h
			local rowMid, mapMid = (row.left + row.right) / 2, (map.left + map.right) / 2
			assert(math.abs(rowMid - mapMid) <= pixel, label .. ": centre the plate under the map: " .. rowMid .. " / " .. mapMid)
			local mid = TextCentre(coords, face.coords)
			local width = face.coords:GetStringWidth()
			assert(mid - width / 2 >= row.left + 6 - pixel and mid + width / 2 <= row.right - 6 + pixel, label .. ": keep the coordinates padded inside their plate")
			if clock then
				assert(face.coords:GetJustifyH() == "LEFT" and mid < rowMid, label .. ": beside the clock the coordinates keep the plate's left end")
			else
				assert(math.abs(mid - rowMid) <= pixel, label .. ": centre the coordinates in their plate without the clock: " .. mid .. " / " .. rowMid)
			end
		end
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
print("minimap coords plate ok: three frames, with and without the clock, two screens")
