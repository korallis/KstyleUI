-- test-unitframes-preview-fit.lua: the unit frames live preview fits its pane: every frame kind, its cast line and its sample auras lie inside the pane at the options pane's width, and a resize fits it again (round 4: Opus #1, Astra #2; "ing Frostbolt" cut at the pane's edge).
local U = dofile("Tools/regression/unitframes_env.lua")
local D = dofile("Tools/regression/databars_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local PANE_W, PANE_H = 280, 560

local function inside(a, b)
	return a[1] >= b[1] - 0.5 and a[2] >= b[2] - 0.5 and a[1] + a[3] <= b[1] + b[3] + 0.5 and a[2] + a[4] <= b[2] + b[4] + 0.5
end

local function fmt(r)
	return string.format("(%.1f,%.1f %.1fx%.1f)", r[1], r[2], r[3], r[4])
end

local env, K = U.New()
env._textWidth = D.TextWidth
local pane = env.CreateFrame("Frame", nil, K.Scale.Root())
pane:SetSize(PANE_W, PANE_H)
pane:SetPoint("CENTER")
local preview = K.Options.Preview("UnitFrames")(pane)

local function regions(kind)
	local out = { holder = preview.holders[kind] }
	local view = preview.views[kind]
	for _, key in ipairs({ "name", "caption", "health", "power", "marker", "healthText" }) do
		out[key] = view[key]
	end
	local cb = preview.casts[kind]
	if cb and cb.frame:IsShown() then
		for _, key in ipairs({ "frame", "label", "text", "timer", "bar" }) do
			out["cast." .. key] = cb[key]
		end
	end
	for i, icon in ipairs(preview.auraIcons[kind] or {}) do
		out["aura" .. i] = icon
	end
	return out
end

local function Check(where)
	local box = { Scene.Rect(env, pane) }
	for _, kind in ipairs(U.KINDS) do
		K.Options.Write("UnitFrames", "edit", kind)
		preview:Refresh()
		assert(preview.kind == kind, "the preview draws " .. kind)
		for key, region in pairs(regions(kind)) do
			if region:IsVisible() then
				local r = { Scene.Rect(env, region) }
				if r[1] and r[3] > 0 then
					local w = key:find("text") or key:find("label") or key:find("name") or key:find("caption")
					if w and region.GetUnboundedStringWidth then
						local text = region:GetUnboundedStringWidth()
						if type(text) == "number" and text > r[3] + 0.5 and region:GetWidth() == 0 then
							r[3] = text
						end
					end
					assert(inside(r, box), string.format("%s: the %s preview's %s %s leaves the pane %s", where, kind, key, fmt(r), fmt(box)))
				end
			end
		end
	end
end

Check("at " .. PANE_W .. " units")
pane:SetSize(220, PANE_H)
Check("after a resize to 220 units")
pane:SetSize(PANE_W, PANE_H)

-- The target sigil, wider than the pane, is laid out no narrower than the pane holds at three quarters scale, then
-- scaled to fit: its text stays legible instead of shrinking with a 490-unit frame.
K.Options.Write("UnitFrames", "edit", "target")
preview:Refresh()
local holder = preview.holders.target
local element = K.Setup.Layouts.Element("unitframes.target")
local w, scale = holder:GetWidth(), holder:GetScale()
assert(w < element.width and w > PANE_W, "the sample sigil is laid out between the pane and its real width " .. element.width .. ": " .. w)
assert(scale < 1 and scale >= 0.75 - 1e-6, "and scaled down to the pane, no smaller than three quarters: " .. scale)

assert(#env._errors == 0, tostring(env._errors[1]))
assert(K.ErrorCount() == 0, "KstyleUI caught no errors")
print("unitframes preview fit ok")
