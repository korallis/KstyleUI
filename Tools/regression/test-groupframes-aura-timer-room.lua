-- test-groupframes-aura-timer-room.lua: on Medallions (or the HUD style passed in, as the -frames file does) and the four test screens, a party debuff's time left at its automatic size, or a raid debuff's at automatic, 12 and 24 and as wide as 59m, sits inside its frame (or its row beside it) and its clip, clear of its stack count, dispel letter, power strip (raid power bar off and on), name and health text, after the row has moved; Medallions keeps it under the icon by lifting the row, and the settings preview does the same.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local A = dofile("Tools/regression/auras_env.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = dofile("Tools/render/scene.lua")
local G = H.G
local check = assert
local style = ... or "medallions"

local function box(env, region)
	local x, y, w, h = Scene.Rect(env, region)
	return { x, y, x + w, y + h }
end

local function within(env, region, room, what)
	local r, q = box(env, region), box(env, room)
	check(r[1] >= q[1] - 1e-3 and r[2] >= q[2] - 1e-3 and r[3] <= q[3] + 1e-3 and r[4] <= q[4] + 1e-3,
		what .. " [" .. table.concat(r, ", ") .. "] leaves [" .. table.concat(q, ", ") .. "]")
end

local function apart(env, a, b, what, slack)
	if not (b and b:IsShown()) then return end
	local dx, dy = H.overlap(env, a, b)
	slack = slack or 1e-3
	check(dx <= slack or dy <= slack, what .. " overlap by " .. dx .. " x " .. dy)
end

do
	for _, size in ipairs(H.SCREENS) do
		local env, K, ns = H.boot(H.screen(size))
		if style == "frames" then K.Options.Write("HudStyle", "style", "frames") end
		H.write(env, K, "raid.auraY", 15)
		H.write(env, K, "auras.timers", true)
		H.write(env, K, "raid.auraY", 0)
		for _, case in ipairs({ { "party", false }, { "raid", false }, { "raid", true } }) do
			local kind, power = case[1], case[2]
			H.write(env, K, "raid.power", power)
			G.SetRoster(env, kind, G.Members(kind == "raid" and 10 or 4))
			env.RunTimers()
			for _, font in ipairs(kind == "raid" and { 0, 12, 24 } or { 0 }) do
				H.write(env, K, "auras.timerSize", font)
				local f = H.frame(ns, kind .. "1")
				A.Assign(env, f.auras, "debuffs", 1)
				local debuffs = f.auras._groups.debuffs
				Hud.PlaceAuras(f.auras, debuffs, debuffs.active, 1)
				local button = debuffs.active[1]
				local aura = button._aura
				A.Remaining(env, button, 3)
				if kind == "raid" then aura.timer:SetText("59m") end
				aura.count:SetText("3")
				A.Dispel(button, "Magic")
				local letter = ns.Auras.Parts(button).dispelLetter
				local at = style .. " " .. kind .. (power and " with power" or "") .. " " .. size[1] .. "x" .. size[2] .. " size " .. font .. ": "
				local dx, dy = H.overlap(env, f.auraClip, f)
				local beside = dx <= 1e-3 or dy <= 1e-3
				within(env, aura.timer, f.auraClip, at .. "time left inside its clip")
				for name, region in pairs({ ["time left"] = aura.timer, ["stack count"] = aura.count }) do
					within(env, region, beside and f.auraClip or f, at .. name .. " inside " .. (beside and "the debuff row beside the frame" or "its frame"))
					apart(env, region, f.power, at .. name .. " and the power strip")
					apart(env, region, f.healthText, at .. name .. " and the health text")
				end
				apart(env, aura.timer, aura.count, at .. "time left and stack count")
				apart(env, aura.timer, letter, at .. "time left and dispel letter")
				apart(env, aura.timer, f.name, at .. "time left and the name")
				apart(env, button, f.healthText, at .. "the debuff icon and the health text")
				apart(env, button, f.name, at .. "the debuff icon and the name")
				if style == "medallions" and font == 0 then
					check(box(env, aura.timer)[2] >= box(env, button)[4] - 1e-3, at .. "the time left stays under its icon")
				end
			end
		end
		H.write(env, K, "auras.timerSize", 0)
		local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
		parent:SetSize(300, 420)
		parent:SetPoint("CENTER", K.Scale.Root(), "CENTER")
		local preview = K.Options.Preview("GroupFrames")(parent)
		for _, pf in ipairs(preview.raidFrames) do
			local sample = pf.sampleAuras[1]
			if sample:IsShown() and sample.timer and sample.timer:IsShown() then
				apart(env, sample.timer, pf.power, style .. " " .. size[1] .. "x" .. size[2] .. ": the preview's time left and power strip")
				break
			end
		end
		H.noErrors(env, K)
		collectgarbage()
	end
end

print("groupframes aura timer room ok on " .. style .. ": time left inside its frame and clip, clear of stacks, dispel letter, power strip, name and health text, at three sizes, four screens and the preview")
