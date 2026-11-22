-- test-ornament-guard.lua: missing Full art and later semantic overlap must fail the independent guard.
local G = dofile("Tools/regression/ornament_guard_lib.lua")
local texture, text = {}, {}
local handles = { cap = { used = 1, textures = { texture } } }
local item = { object = texture, file = "Media/Textures/ForgedOrnaments/SlimElite8.png", rect = { 0, 0, 5, 5 } }
local semantic = { object = text, rect = { 1, 1, 2, 2 } }
local function reject(items, expected)
	local ok, why = pcall(G.Check, items, handles, { [text] = "health text" }, "probe", { 10, 10 })
	assert(not ok and tostring(why):find(expected, 1, true), "expected " .. expected .. ": " .. tostring(why))
end
reject({}, "missing painted ornament")
reject({ semantic, item }, "covers health text")
G.Check({ item, semantic }, handles, { [text] = "health text" }, "behind", { 10, 10 })
item.rect = { 8, 0, 5, 5 }
reject({ item }, "ornament offscreen")
item.rect = { 0, 0, 5, 5 }
item.file = "malformed-texture-path"
reject({ item }, "wrong ornament texture")
item.file = "Media/Textures/ForgedOrnaments/SlimElite8.png"
item.missing = true
reject({ item }, "hidden or missing ornament")
item.missing = nil
local assets = { SlimElite8 = { 2, 8, 2, 8 } }
item.texCoord = { 0, 1, 0, 1 }
local function nativeReject(expected)
	local ok, why = pcall(G.Check, { item }, handles, {}, "native", { 10, 10 }, assets, 1)
	assert(not ok and tostring(why):find(expected, 1, true), "expected " .. expected .. ": " .. tostring(why))
end
nativeReject("stretched native art")
item.rect = { 0.25, 0, 2, 8 }
nativeReject("fractional physical origin")
item.rect = { 0, 0, 2, 8 }
item.texCoord = { 0, 1, 0, 1 }
G.Check({ item }, handles, {}, "native", { 10, 10 }, assets, 1)
item.texCoord = { 0, 0.5, 0, 1 }
nativeReject("stretched native crop")
item.texCoord = { 0, 1, 0, 1 }
assets.SlimElite8[3] = 0
nativeReject("malformed native metadata")
print("ok ornament guard negative controls")
