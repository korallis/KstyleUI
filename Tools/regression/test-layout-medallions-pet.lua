-- test-layout-medallions-pet.lua: pet slab clearance above the player at 16:9 and outboard at wider aspects.
local W = dofile("Tools/regression/widget_env.lua")

local _, K = W.New()
local Layouts = K.Setup.Layouts
local NEAR = K.Tokens.Size("gapLarge")
-- The hub's footprint: a square the ring wide centred on the slots' top edge; the plate reaches the slab's pad over
-- the slots (Layouts.MEDALLIONS_SLAB).
local RING, PLATE = Layouts.MEDALLIONS_RING, Layouts.MEDALLIONS_SLAB.pad
-- KstyleUI_UnitFrames/Geometry.lua SLAB: the medallion's diameter for the slab's height, centred 2 in from its outer end.
local MEDAL = { pet = 56 / 34, player = 86 / 58 }

local function Box(place, kind)
	local left, bottom = place.x - place.width / 2, place.y
	local d = MEDAL[kind] * place.height
	local cx, cy = left + 2 * place.height / (kind == "pet" and 34 or 58), bottom + place.height / 2
	return {
		math.min(left, cx - d / 2), math.min(bottom, cy - d / 2), place.x + place.width / 2, math.max(bottom + place.height, cy + d / 2),
	}
end

local function Clear(a, b, gap)
	return a[3] + gap <= b[1] + 1e-6 or b[3] + gap <= a[1] + 1e-6 or a[4] + gap <= b[2] + 1e-6 or b[4] + gap <= a[2] + 1e-6
end

local checked = 0
for _, name in ipairs(Layouts.Names()) do
	for _, class in ipairs(Layouts.ASPECTS) do
		local function Place(key)
			local place = Layouts.Aspect(class, "medallions", name, key) or Layouts.Style(name, key)
			local styled = Layouts.Style(name, key)
			assert(place and place.anchor == "BOTTOM", name .. " " .. class .. ": " .. key .. " hangs from the bottom centre")
			place.width, place.height = place.width or styled.width, place.height or styled.height
			return place
		end
		local pet, player, bar = Place("unitframes.pet"), Place("unitframes.player"), Place("actionbars.bar1")
		local _, _, _, groupHeight = Layouts.MedallionsGroup(class)
		local top = bar.y + groupHeight
		local box = Box(pet, "pet")
		local label = name .. " " .. class
		local hub = { -RING / 2, top - RING / 2, RING / 2, top + RING / 2 }
		assert(Clear(box, hub, NEAR), string.format("%s: the pet slab (%.1f..%.1f, %.1f..%.1f) is inside the hub's footprint", label, box[1], box[3], box[2], box[4]))
		assert(box[2] >= top + PLATE + NEAR - 1e-6, string.format("%s: the pet medallion's foot %.1f sits on the slab's plate at %.1f", label, box[2], top + PLATE))
		assert(Clear(box, Box(player, "player"), NEAR), label .. ": the pet slab crowds the player's slab or medallion")
		checked = checked + 1
	end
end
assert(checked == #Layouts.Names() * #Layouts.ASPECTS, "every preset and aspect class")
print("layout medallions pet ok")
