-- test-reference-plates-tank.lua: the Tank reference scene seats its fixture plates clear of the threat card the mock-up size raises over them (#347, KSTY-60 item 23), so the strict Tank frame at 1920 by 1080 passes the render guard.
local Reference = dofile("Tools/render/scenes/_reference.lua")
local Guard = dofile("Tools/render/guard.lua")

local plates = { { x = 500, y = 100 }, { x = 1000, y = 576 }, { x = 1700, y = 576 } }
local seated = Reference.SeatAround(plates, 950, 1150, 540, 650)
assert(seated and seated[1].x == 500 and seated[3].x == 1700, "plates off the card stay")
assert(seated[2].x + 90 <= 950, "the plate on the card moves to its left: " .. seated[2].x)
assert(Reference.SeatAround(plates, 2000, 2200, 540, 650) == nil, "nothing moves when no plate lies on the card")

local saved = Reference.SCREEN
Reference.SCREEN = { width = 1920, height = 1080, uiScale = 768 / 1080, size = "auto" }
local scene = Reference.Build({ layout = "Tank" })
Reference.SCREEN = saved
local fresh = Guard.Sort(Guard.Check(scene), Guard.LoadAllow(), "hud_reference")
local detail = fresh[1] and (fresh[1].subject or "") .. " " .. (fresh[1].detail or "") or ""
assert(#fresh == 0, "1920x1080 Tank at the automatic size fails the render guard: " .. detail)

print("reference plates tank ok")
