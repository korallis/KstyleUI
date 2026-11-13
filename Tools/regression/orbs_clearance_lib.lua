-- orbs_clearance_lib.lua: under the Orbs HUD style, nothing another surface draws (the bars beside the orbs, the tracked buff icons, the buff and debuff rows, the reputation and honour bars, the cast bar, the cooldowns) reaches into either orb, on four screens.
local Hud = dofile("Tools/render/scenes/hud.lua")

local M = {}
M.SCREENS = { { 1280, 720 }, { 1920, 1080 }, { 3440, 1440 }, { 5120, 1440 } }
local MODULES = { "actionbars", "databars", "cooldowns", "auras", "unitframes" }

local function Options(layout, class)
	return {
		class = class, layout = layout, applyPreset = true, settings = Hud.PresetSettings(layout),
		target = { name = "Shadowgale Poacher", creature = "Humanoid", power = 240, powerMax = 345 },
		game = {
			faction = { factionID = 72, name = "Stormwind", reaction = 5, currentReactionThreshold = 3000, nextReactionThreshold = 9000, currentStanding = 4500 },
			honor = 300, honorMax = 1000, honorLevel = 2, battlefield = true,
		},
	}
end

local function Under(object, roots)
	while object do
		if roots[object] then
			return roots[object]
		end
		object = object._parent
	end
end

-- Box(items, roots, name) -> the union of the drawn items under roots that resolve to name, in screen units.
local function Box(items, roots, name)
	local l, t, r, b = math.huge, math.huge, -math.huge, -math.huge
	for _, item in ipairs(items) do
		local rect = item.rect
		if rect[3] > 0 and rect[4] > 0 and Under(item.object, roots) == name then
			l, t = math.min(l, rect[1]), math.min(t, rect[2])
			r, b = math.max(r, rect[1] + rect[3]), math.max(b, rect[2] + rect[4])
		end
	end
	return l < r and { l, t, r, b } or nil
end

local function Hits(rect, box)
	return rect[1] < box[3] - 0.001 and box[1] < rect[1] + rect[3] - 0.001 and rect[2] < box[4] - 0.001 and box[2] < rect[2] + rect[4] - 0.001
end

local function Case(layout, class, screen, required)
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2] })
	local label = string.format("%s %s %dx%d", layout, class, screen[1], screen[2])
	local opts = Options(layout, class)
	local scenes, spaces = {}, {}
	for _, name in ipairs(MODULES) do
		local scene, ns = Hud.Module(name, opts)
		local K = Hud.envs[scene].KstyleUI
		assert(K.HudStyle.Current() == "orbs", label .. ": " .. name .. " runs the Orbs style")
		assert(Hud.envs[scene]._renderPreset == layout, label .. ": " .. name .. " ran Setup.Apply")
		for _, line in ipairs(scene.log) do
			assert(not line:find("error:", 1, true), label .. ": " .. name .. ": " .. line)
		end
		scenes[name], spaces[name] = scene, ns
	end
	local U = spaces.unitframes
	local orbs, roots = {}, {}
	for _, kind in ipairs({ "health", "power" }) do
		local orb = assert(U.Orbs.Get(kind), label .. ": the " .. kind .. " orb is built")
		assert(orb:IsShown(), label .. ": the " .. kind .. " orb shows")
		roots[orb] = kind
	end
	for _, kind in ipairs({ "health", "power" }) do
		orbs[kind] = assert(Box(scenes.unitframes.items, roots, kind), label .. ": the " .. kind .. " orb draws")
		local box = orbs[kind]
		assert(box[1] >= 0 and box[2] >= 0 and box[3] <= screen[1] / screen[2] * 1080 + 0.001 and box[4] <= 1080.001,
			label .. ": the " .. kind .. " orb stays on the screen")
	end
	local AB = spaces.actionbars
	local wanted = {
		{ "actionbars", AB.bars.bar2.holder, "bar 2" },
		{ "actionbars", AB.bars.pet.holder, "the pet bar", required.pet },
		{ "actionbars", AB.bars.stance.holder, "the stance bar", required.stance },
		{ "databars", spaces.databars.Bars.views.rep and spaces.databars.Bars.views.rep.track, "the reputation bar" },
		{ "databars", spaces.databars.Bars.views.honor and spaces.databars.Bars.views.honor.track, "the honour bar" },
		{ "auras", nil, "the buff tiles" },
		{ "cooldowns", Hud.envs[scenes.cooldowns].BuffIconCooldownViewer, "the tracked buff icons" },
	}
	for _, want in ipairs(wanted) do
		if want[4] ~= false then
			local frame = assert(want[2] or want[1] == "auras", label .. ": " .. want[3] .. " exists")
			if want[1] ~= "auras" then
				assert(Box(scenes[want[1]].items, { [frame] = true }, true), label .. ": draws " .. want[3])
			end
		end
	end
	local own = {}
	for _, orb in pairs(roots) do
		own[orb] = true
	end
	for name, scene in pairs(scenes) do
		local count = 0
		for _, item in ipairs(scene.items) do
			local rect = item.rect
			if rect[3] > 0 and rect[4] > 0 and not (name == "unitframes" and Under(item.object, roots)) then
				count = count + 1
				for kind, box in pairs(orbs) do
					assert(not Hits(rect, box), string.format("%s: %s draws into the %s orb: %s at %.1f %.1f %.1f %.1f", label, name, kind,
						tostring(item.text or item.file or item.kind), rect[1], rect[2], rect[3], rect[4]))
				end
			end
		end
		assert(count > 0, label .. ": " .. name .. " draws")
	end
end

function M.Run(layout, class, required)
	local previousScreen, previousStyle = rawget(_G, "RENDER_SCREEN"), rawget(_G, "RENDER_HUD_STYLE")
	rawset(_G, "RENDER_HUD_STYLE", "Orbs")
	for _, screen in ipairs(M.SCREENS) do
		Case(layout, class, screen, required or {})
		collectgarbage("collect")
	end
	rawset(_G, "RENDER_SCREEN", previousScreen)
	rawset(_G, "RENDER_HUD_STYLE", previousStyle)
	print("ok orbs clearance " .. layout .. " " .. class .. ": four screens")
end

return M
