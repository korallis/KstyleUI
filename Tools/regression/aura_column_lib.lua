-- aura_column_lib.lua: Run(uiScale) checks that the column target's debuff row of four, its timers and its bars stay inside the reserve every preset keeps for the target (KSTY-12), at every screen and interface size; the reserve starts at the element's left edge and the whole-pixel row has to fit it down to 720p at the smallest size.
local U = dofile("Tools/regression/unitframes_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local EPS = 1e-3

local function overlap(r, s)
	return r.left < s.right - EPS and s.left < r.right - EPS and r.bottom < s.top - EPS and s.bottom < r.top - EPS
end

local function inside(r, s)
	return r.left >= s.left - EPS and r.right <= s.right + EPS and r.bottom >= s.bottom - EPS and r.top <= s.top + EPS
end

local function fmt(r)
	return string.format("(%.1f,%.1f-%.1f,%.1f)", r.left, r.bottom, r.right, r.top)
end

local SCREENS = { { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3456, 2234 }, { 3840, 2160 }, { 5120, 1440 } }

local M = {}

function M.Run(uiScale)
	local env, K = U.New({ lumen = true })
	local cenv, cK, cns = U.New({ fit = true, size = "default", uiScale = uiScale })
	local croot = cK.Scale.Root()
	U.SetUnit(cenv, "target", { name = "Shadowgale Poacher", level = 12, health = 50, healthMax = 100, reaction = 2, canAttack = true })
	cenv.FireEvent("PLAYER_TARGET_CHANGED")
	cenv.RunTimers()
	local view = cns.Frames.Get("target").views[1]
	assert(view.geometry.form == "column", "the fresh fixture's target is the column")
	local debuffs = view.auras.container._groups.debuffs
	assert(debuffs.max == 4 and cns.Settings.Value("target", "auraRows") == 1 and cns.Settings.Value("target", "auraColumns") == 4, "the column target holds one row of four")
	local Layouts = cK.Setup.Layouts
	local element = Layouts.Element("unitframes.target")
	local function crect(frame, where)
		local r, why = Geometry.Rect(frame, croot)
		assert(r, where .. ": no rect: " .. tostring(why))
		return r
	end
	for _, screen in ipairs(SCREENS) do
		cenv.GetPhysicalScreenSize = function() return screen[1], screen[2] end
		cenv.UIParent:SetSize(768 * screen[1] / screen[2] / uiScale, 768 / uiScale)
		cenv.FireEvent("DISPLAY_SIZE_CHANGED")
		for _, size in ipairs({ 0.6, 16 / 19, 1.5 }) do
			cK.Scale.SetUserScale(size)
			cenv.RunTimers()
			local at = string.format("%dx%d UI %.4f requested %.4f applied %.4f", screen[1], screen[2], uiScale, size, cK.Scale.AppliedUserScale())
			view.auras.container:_Acquire("debuffs", 4)
			assert(view.auras.host:IsShown(), at .. ": the debuff row shows")
			local mine = {}
			local pitch = K.Widgets.Snap(view.auras.host, 27.6) + K.Widgets.Snap(view.auras.host, 4)
			for i, tile in ipairs(debuffs.buttons) do
				mine[tile] = i
				tile:ClearAllPoints()
				tile:SetPoint("TOPLEFT", view.auras.container, "TOPLEFT", (i - 1) * pitch, 0)
			end
			for _, entry in ipairs(view.auras.buttons) do
				cns.Auras.LayoutTile(entry)
			end
			local button, host, portrait = crect(view.button, at), crect(view.auras.host, at), crect(view.portraitFrame, at)
			local px = croot:GetEffectiveScale() * screen[2] / 768
			local snap = 1 / px
			local expect = 4 * 27.6 + 3 * 4
			assert(math.abs((host.right - host.left) - expect) <= 4 * snap, at .. ": the row is four icons wide: " .. (host.right - host.left))
			assert(host.left >= portrait.right - EPS and math.abs(host.left - portrait.right - 16.5) <= 2 * snap, at .. ": the row starts 16.5 right of the portrait")
			assert(not overlap(host, portrait) and not overlap(host, button), at .. ": the row clears the portrait and the bars")
			local rw, rh = croot:GetWidth(), croot:GetHeight()
			local room = cns.Auras.TimerRoom("target")
			local timers = {}
			for _, entry in ipairs(view.auras.buttons) do
				if mine[entry.button] then
					local tile = crect(entry.button, at)
					timers[#timers + 1] = { left = tile.left - button.left, right = tile.right - button.left, bottom = tile.bottom - room - button.bottom, top = tile.bottom - button.bottom }
				end
			end
			assert(#timers >= 4, at .. ": four timers are laid out")
			for _, name in ipairs(Layouts.Names()) do
				local layout = Layouts.Get(name, rh)
				local pos = layout["unitframes.target"]
				local w, h, offset = Layouts.Footprint(name, "unitframes.target")
				local l, bo = Layouts.Rect({ width = element.width, height = element.height }, pos, rw, rh)
				local move = { l - button.left, bo - button.bottom }
				local function moved(r)
					return { left = r.left + move[1], right = r.right + move[1], bottom = r.bottom + move[2], top = r.top + move[2] }
				end
				local rl, rb, rr, rt = Layouts.Rect({ width = w, height = h, offsetX = offset }, pos, rw, rh)
				local reserve = { left = rl - snap, bottom = rb - snap, right = rr + snap, top = rt + snap }
				assert(math.abs(rl - l) < 0.6, at .. " " .. name .. ": the reserve starts at the element's left edge")
				for what, part in pairs({ bars = button, portrait = portrait, row = host }) do
					assert(inside(moved(part), reserve), at .. " " .. name .. ": the target's " .. what .. " " .. fmt(moved(part)) .. " stays inside its reserve " .. fmt(reserve))
				end
				for i, t in ipairs(timers) do
					local box = { left = t.left + l, right = t.right + l, bottom = t.bottom + bo, top = t.top + bo }
					assert(inside(box, reserve), at .. " " .. name .. ": timer " .. i .. " " .. fmt(box) .. " stays inside the reserve " .. fmt(reserve))
				end
			end
		end
	end
	assert(#cenv._errors == 0 and cK.ErrorCount() == 0, "no errors in the column fixture")
	assert(#env._errors == 0 and K.ErrorCount() == 0, "column bounds: " .. tostring(env._errors[1]))
end

return M
