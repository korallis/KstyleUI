-- test-groupframes-aura-timer-room.lua: on both HUD styles and the four test screens, a party or raid debuff's time left and stack count sit inside the debuff's own space (inside the member's frame, or wholly beside it), clear of its power strip (raid power bar off and on) and health text.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local A = dofile("Tools/regression/auras_env.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = dofile("Tools/render/scene.lua")
local G = H.G

local function box(env, region)
	local x, y, w, h = Scene.Rect(env, region)
	return { x, y, x + w, y + h }
end

local function within(r, q)
	return r[1] >= q[1] - 1e-3 and r[2] >= q[2] - 1e-3 and r[3] <= q[3] + 1e-3 and r[4] <= q[4] + 1e-3
end

local function crossing(r, q)
	return math.min(r[3], q[3]) - math.max(r[1], q[1]), math.min(r[4], q[4]) - math.max(r[2], q[2])
end

local function apart(env, a, b, what)
	if not (b and b:IsShown()) then return end
	local dx, dy = crossing(box(env, a), box(env, b))
	assert(dx <= 1e-3 or dy <= 1e-3, what .. " overlap by " .. dx .. " x " .. dy)
end

for _, style in ipairs({ "medallions", "frames" }) do
	for _, size in ipairs(H.SCREENS) do
		local env, K, ns = H.boot(H.screen(size))
		if style == "frames" then K.Options.Write("HudStyle", "style", "frames") end
		H.write(env, K, "auras.timers", true)
		for _, case in ipairs({ { "party", false }, { "raid", false }, { "raid", true } }) do
			local kind, power = case[1], case[2]
			H.write(env, K, "raid.power", power)
			G.SetRoster(env, kind, G.Members(kind == "raid" and 10 or 4))
			env.RunTimers()
			local f = H.frame(ns, kind .. "1")
			A.Assign(env, f.auras, "debuffs", 1)
			local debuffs = f.auras._groups.debuffs
			Hud.PlaceAuras(f.auras, debuffs, debuffs.active, 1)
			local aura = debuffs.active[1]._aura
			A.Remaining(env, debuffs.active[1], 3)
			aura.count:SetText("3")
			local at = style .. " " .. kind .. (power and " with power" or "") .. " " .. size[1] .. "x" .. size[2] .. ": "
			local frame, clip = box(env, f), box(env, f.auraClip)
			local dx, dy = crossing(clip, frame)
			local room, where = frame, "its frame"
			if dx <= 1e-3 or dy <= 1e-3 then room, where = clip, "the debuff row beside the frame" end
			for name, region in pairs({ ["time left"] = aura.timer, ["stack count"] = aura.count }) do
				local r = box(env, region)
				assert(within(r, room), at .. name .. " [" .. table.concat(r, ", ") .. "] leaves " .. where .. " [" .. table.concat(room, ", ") .. "]")
				apart(env, region, f.power, at .. name .. " and the power strip")
				apart(env, region, f.healthText, at .. name .. " and the health text")
			end
		end
		H.noErrors(env, K)
		collectgarbage()
	end
end

print("groupframes aura timer room ok: time left and stacks inside their frame or their row beside it, clear of the power strip and health text, on both styles and four screens")
