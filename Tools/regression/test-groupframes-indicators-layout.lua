-- test-groupframes-indicators-layout.lua: the role icon, the leader icon, the raid marker and the health text never overlap on a group frame, resolved by the renderer's anchor solver at the default, smallest and largest party and raid frame sizes.
local G = dofile("Tools/regression/group_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local SCREEN = { width = 2383, height = 1540, uiScale = 768 / 1080 }
local SIZES = {
	{ label = "default", party = { width = 230, height = 46 }, raid = { width = 72, height = 40 } },
	{ label = "smallest", party = { width = 40, height = 16 }, raid = { width = 40, height = 16 } },
	{ label = "largest", party = { width = 400, height = 120 }, raid = { width = 400, height = 120 } },
}
local INDICATORS = { "role", "leader", "marker", "healthText" }

local function saved(kind, size)
	local settings = { enabled = true, [kind] = { width = size.width, height = size.height, healthText = "PERCENT" } }
	return { version = 2, profiles = { Default = { GroupFrames = settings } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

local function content(ns, header, unit)
	local i = 1
	while header._attributes["child" .. i] do
		local button = header._attributes["child" .. i]
		if button._attributes.unit == unit and button._shown then
			return ns.Button.Content(button)
		end
		i = i + 1
	end
end

local function find(scene, object)
	for _, item in ipairs(scene.items) do
		if item.object == object then
			return item
		end
	end
end

local function intersects(a, b)
	return a[1] < b[1] + b[3] and b[1] < a[1] + a[3] and a[2] < b[2] + b[4] and b[2] < a[2] + a[4]
end

local function describe(r)
	return string.format("[x %.1f to %.1f, y %.1f to %.1f]", r[1], r[1] + r[3], r[2], r[2] + r[4])
end

-- One frame of the kind at the size: the leader, a tank, marked with the skull, at 82% health.
local function frame(kind, size)
	local opts = { width = SCREEN.width, height = SCREEN.height, uiScale = SCREEN.uiScale, saved = saved(kind, size) }
	local env, K, ns = G.New(opts)
	local member = { name = "Thaldren", class = "WARRIOR", role = "TANK", leader = true, marker = 8, health = 82, maxHealth = 100 }
	local unit
	if kind == "party" then
		G.SetRoster(env, "party", { member, { name = "Sylaen", class = "DRUID", role = "HEALER" } })
		unit = "party1"
	else
		local members = G.Members(5)
		for k, v in pairs(member) do
			members[1][k] = v
		end
		G.SetRoster(env, "raid", members)
		unit = "raid1"
	end
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local header = kind == "party" and ns.Headers.party or ns.Headers.raid[1]
	local f = content(ns, header, unit)
	assert(f, kind .. " " .. unit .. " has a frame")
	return env, f, ns
end

for _, size in ipairs(SIZES) do
	for _, kind in ipairs({ "party", "raid" }) do
		local env, f = frame(kind, size[kind])
		local what = kind .. " " .. size.label .. " (" .. size[kind].width .. " by " .. size[kind].height .. ")"
		local scene = Scene.Build(env)
		local rects = {}
		for _, name in ipairs(INDICATORS) do
			local region = f[name]
			assert(region:IsShown(), what .. ": the " .. name .. " shows")
			local item = find(scene, region)
			assert(item, what .. ": the renderer draws the " .. name)
			rects[name] = item.rect
		end
		-- Without a portrait and with the name above the bar, the leader crown is a deliberate badge on the role
		-- icon's top-left corner (round 2, to give raid names the row); it stays smaller and inside that corner.
		local badge = f.parts.icons.badge
		if badge then
			local role, leader = rects.role, rects.leader
			assert(leader[3] < role[3] and leader[1] <= role[1] + 0.01 and leader[2] <= role[2] + 0.01, what .. ": the leader badge sits on the role icon's top-left corner")
		end
		for i = 1, #INDICATORS do
			for j = i + 1, #INDICATORS do
				local a, b = INDICATORS[i], INDICATORS[j]
				local pair = (a == "role" and b == "leader") or (a == "leader" and b == "role")
				if not (badge and pair) then
					assert(not intersects(rects[a], rects[b]), what .. ": the " .. a .. " " .. describe(rects[a]) .. " overlaps the " .. b .. " " .. describe(rects[b]))
				end
			end
		end
		local frameRect = { Scene.Rect(env, f) }
		assert(frameRect[1], what .. ": the frame resolves")
		for _, name in ipairs({ "role", "healthText" }) do
			local r = rects[name]
			assert(r[1] >= frameRect[1] - 0.01 and r[1] + r[3] <= frameRect[1] + frameRect[3] + 0.01, what .. ": the " .. name .. " " .. describe(r) .. " stays inside the frame's width " .. describe(frameRect))
		end
	end
end

-- A frame that grows back from the smallest size to the default loses the narrowed health text width the
-- on-the-bar layout gave it, so the text draws at its natural width again above the bar.
do
	local env, f, ns = frame("party", SIZES[2].party)
	local Style = ns.Style
	local narrowed = f.healthText._width
	assert(narrowed and narrowed > 0, "the smallest party frame narrows its health text")
	Style.Apply(f, 230, 46)
	-- Above the bar the percent keeps a fixed reserve for "100%" (so the name's width is known), never the narrowed width.
	assert(f.healthText._width ~= narrowed, "the default party frame frees the health text's narrowed width again, got " .. tostring(f.healthText._width))
	local scene = Scene.Build(env)
	local text = find(scene, f.healthText)
	assert(text and text.rect[3] > 10, "and the renderer draws it at its natural width")
end

print("ok")
