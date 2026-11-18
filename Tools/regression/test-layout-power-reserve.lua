-- test-layout-power-reserve.lua: only the Medallions player reserves the new power lane, below its unchanged body, with no movement of the portrait centre.
local C = dofile("Tools/regression/core_env.lua")
local _, K = C.New({ fit = true, size = "auto" })
local L = K.Setup.Layouts
for _, preset in ipairs(L.Names()) do
	for _, style in ipairs({ "frames", "orbs", "medallions" }) do
		local state = L.PrepareFits(preset, 1920, 1080, L.Enabled(preset), nil, style)
		for i, element in ipairs(L.ELEMENTS) do
			if element.key == "unitframes.player" then
				local box = state.sizes[i]
				if style == "medallions" then
					local place = L.Aspect("16:9", style, preset, element.key) or L.Style(style, preset, element.key)
					assert(box[2] == place.height + 22 and box[4] == -22, "H2: reserve 22 units below the Medallions body")
					assert(box[4] + box[2] == place.height, "the top of the reserve stays at the old body top")
				else
					assert(box[4] == nil, "Frames and Orbs gain no vertical reserve")
				end
			end
		end
	end
end
local _, bottom, _, top = L.Rect({ width = 300, height = 80, offsetY = -22 }, { anchor = "BOTTOM", x = 0, y = 100 }, 1920, 1080)
assert(bottom == 78 and top == 158, "a vertical reserve extends below the unchanged 58-unit body")
print("layout power reserve ok")
