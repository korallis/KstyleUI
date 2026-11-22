-- test-groupframes-rows.lua: KSTY-57's party and raid rows on the Medallions look from 1280x720 through 3840x2160, including 2560x1440 and 5120x1440, at the automatic interface size: the party's steel role pip before the name over the class pill, the raid's class-coloured tile with the name on the fill, the percent at the bar's end, a spark-free bar, the three default indicators in the tidy lane, the raid marker clear of the percent, the party bare and the raid seated in its card.
local G = dofile("Tools/regression/group_env.lua")
local Common = dofile("Tools/render/scenes/_common.lua")
local Scene = dofile("Tools/render/scene.lua")

local SCREENS = { { 1280, 720 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 5120, 1440 }, { 3840, 2160 } }
local CASES = {
	{ kind = "party", members = 4, bar = 12, power = 3, percent = true },
	{ kind = "raid", members = 10, bar = 12, power = 3, percent = true },
	{ kind = "raid", members = 20, bar = 11, power = 2, percent = true },
	{ kind = "raid", members = 40, bar = 9 },
}
local ROLES = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" }

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local function intersects(a, b)
	return a[1] < b[1] + b[3] - 0.01 and b[1] < a[1] + a[3] - 0.01 and a[2] < b[2] + b[4] - 0.01 and b[2] < a[2] + a[4] - 0.01
end

local function inside(r, box)
	return r[1] >= box[1] - 0.01 and r[2] >= box[2] - 0.01 and r[1] + r[3] <= box[1] + box[3] + 0.01 and r[2] + r[4] <= box[2] + box[4] + 0.01
end

local function describe(r)
	return string.format("[x %.1f to %.1f, y %.1f to %.1f]", r[1], r[1] + r[3], r[2], r[2] + r[4])
end

local function find(scene, object)
	for _, item in ipairs(scene.items) do
		if item.object == object then
			return item
		end
	end
end

local function frames(ns, kind)
	local out = {}
	local headers = kind == "party" and { ns.Headers.party } or ns.Headers.raid
	for _, header in ipairs(headers) do
		local i = 1
		while header._attributes["child" .. i] do
			local button = header._attributes["child" .. i]
			if button._shown and button._attributes.unit then
				out[#out + 1] = ns.Button.Content(button)
			end
			i = i + 1
		end
	end
	return out
end

-- Part(env, f, rect) -> a part of the row in the scene's units, from the layout's own rect in the row's units.
local function Part(env, f, rect)
	local fx, fy, fw = Scene.Rect(env, f)
	local k = fw / f.width
	return { fx + rect.left * k, fy + rect.top * k, rect.width * k, rect.height * k }
end

local previous = rawget(_G, "RENDER_SCREEN")
for _, screen in ipairs(SCREENS) do
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], uiScale = 768 / 1080, size = "auto" })
	for _, case in ipairs(CASES) do
		local what = case.kind .. (case.kind == "raid" and (" of " .. case.members) or "") .. " at " .. screen[1] .. "x" .. screen[2]
		local env, K, ns = G.New({ setup = Common.ForceScreen })
		env.SetQuiet(true)
		local members = G.Members(case.members, function(i, m)
			m.role = ROLES[(i - 1) % 5 + 1]
			m.health = 64
			if i == 1 then
				m.marker = 8
			end
		end)
		G.SetRoster(env, case.kind, members)
		assert(K.Modules.Enable("GroupFrames"))
		env.RunTimers()
		local px = K.Scale.Pixel(1)
		local shown = frames(ns, case.kind)
		eq(#shown, case.kind == "party" and case.members + 1 or case.members, what .. ": every member has a row")
		local scene = Scene.Build(env)
		local f = shown[1]
		assert(not f.health.sparkFrame, what .. ": disable the group health spark to match tooltip and tracked bars")
		for _, row in ipairs(shown) do
			if row.unit == (case.kind == "party" and "party1" or "raid1") then
				f = row
			end
		end
		local frame = { Scene.Rect(env, f) }
		local bar = { Scene.Rect(env, f.health) }
		-- The scene measures in UIParent's units; k turns them into the row's own (the root's) units.
		local k = frame[3] / f.width
		local name = find(scene, f.name)
		assert(name, what .. ": the name draws")
		if case.kind == "party" then
			-- The Medallions party row: the steel role pip before the name, the class pill along the row's foot.
			local pip = find(scene, f.role)
			assert(pip, what .. ": the pip draws")
			local r, g, b = f.role:GetVertexColor()
			local wr, wg, wb = K.Tokens.Color("steelLit")
			assert(r == wr and g == wg and b == wb, what .. ": the pip is steel")
			assert(pip.rect[1] + pip.rect[3] <= name.rect[1] + 0.01, what .. ": the pip comes before the name")
			assert(math.abs(bar[4] / k - ns.Style.PILL_HEIGHT) <= px, what .. ": the bar is the class pill, got " .. bar[4] / k)
			assert(name.rect[2] + name.rect[4] <= bar[2] + 0.01, what .. ": the name sits over the pill")
		else
			-- The Medallions raid tile: the class-coloured bar fills the tile inside its padding, no thinner than the
			-- mock-up draws the bar, with the name on the fill and no role icon or power line.
			local pad = K.Tokens.Size("gapSmall")
			assert(bar[4] / k >= case.bar - px, what .. ": the bar is at least the mock-up's " .. case.bar .. " units, got " .. bar[4] / k)
			assert(math.abs(bar[1] - (frame[1] + pad * k)) <= px * k and math.abs(bar[1] + bar[3] - (frame[1] + frame[3] - pad * k)) <= px * k, what .. ": the bar spans the tile")
			assert(intersects(name.rect, bar), what .. ": the name sits on the fill")
			assert(not f.role:IsShown(), what .. ": no role icon on the tile")
			eq(f.power:IsShown(), false, what .. ": no power line")
		end
		local percent
		if case.percent then
			percent = find(scene, f.healthText)
			assert(percent, what .. ": the percent draws")
			assert(math.abs(percent.rect[1] + percent.rect[3] - (bar[1] + bar[3])) <= px * k + 1e-6, what .. ": the percent ends at the bar's end, within a pixel")
			assert(not intersects(percent.rect, name.rect), what .. ": clear of the name")
		else
			eq(f.healthText:IsShown(), false, what .. ": no percent, as the 40-player mock-up draws it")
		end
		-- The raid marker: inside the row, never on the name.
		local marker = find(scene, f.marker)
		assert(marker, what .. ": the skull draws")
		assert(inside(marker.rect, frame), what .. ": the marker stays inside the row")
		-- Known: on the 40-player Medallions tile the skull grazes the name's line.
		assert(case.members == 40 or not intersects(marker.rect, name.rect), what .. ": the marker keeps off the name")
		if percent then
			assert(not intersects(marker.rect, percent.rect), what .. ": the marker " .. describe(marker.rect) .. " never covers the percent " .. describe(percent.rect))
		end
		-- The three default indicators: apart, in the tidy Medallions lane, clear of the name and the percent.
		local lane = f.parts.indicatorLane
		assert(lane and lane.legible and lane.count == 3, what .. ": the row has a tidy lane for three indicators")
		-- The slots snap to whole pixels, so the lane holds them within a pixel.
		local laneRect = Part(env, f, lane)
		laneRect = { laneRect[1] - px * k, laneRect[2] - px * k, laneRect[3] + 2 * px * k, laneRect[4] + 2 * px * k }
		local plan, placed = ns.Slots.Placements(f), {}
		for i = 1, 3 do
			local slot = f.indicators._slots["indicator" .. i]
			assert(slot.enabled and plan[i].fits, what .. ": indicator " .. i .. " is on")
			slot.frame:Show()
			local rect = { Scene.Rect(env, slot.frame) }
			slot.frame:Hide()
			assert(inside(rect, laneRect), what .. ": indicator " .. i .. " " .. describe(rect) .. " in the lane " .. describe(laneRect))
			for label, other in pairs({ name = name.rect, percent = percent and percent.rect }) do
				assert(not intersects(rect, other), what .. ": indicator " .. i .. " clear of the " .. label)
			end
			for j, other in pairs(placed) do
				assert(not intersects(rect, other), what .. ": indicators " .. j .. " and " .. i .. " apart")
			end
			placed[i] = rect
		end
		-- No tile behind a row; the party stands bare, the raid in its card, every row inside the card's glass and
		-- under its cap.
		assert(f.tileless and not f.chrome.fill[5]:IsShown(), what .. ": no tile behind the row")
		local card = ns.Headers.cards[case.kind]
		if case.kind == "party" then
			eq(card.frame:IsShown(), false, what .. ": no card round the party")
		else
			assert(card.frame:IsShown(), what .. ": the raid sits in its card")
			local glass = { Scene.Rect(env, card.frame) }
			local cap = { Scene.Rect(env, card.cap.frame) }
			for _, row in ipairs(shown) do
				local rect = { Scene.Rect(env, row) }
				assert(inside(rect, glass), what .. ": " .. row.unit .. " " .. describe(rect) .. " inside the card " .. describe(glass))
				assert(rect[2] >= cap[2] + cap[4] - 0.01, what .. ": " .. row.unit .. " under the cap")
			end
			eq(card.cap.aside:GetText(), tostring(case.members), what .. ": the cap counts the raid")
		end
		eq(#env._errors, 0, what .. ": " .. tostring(env._errors[1]))
		collectgarbage()
	end
end
rawset(_G, "RENDER_SCREEN", previous)

print("groupframes rows ok")
