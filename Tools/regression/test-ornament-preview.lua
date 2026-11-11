-- test-ornament-preview.lua: in the Options preview, ornaments that fit inside the preview's clip do not refit its content, and ornaments that would cross the clip shrink the content just enough to draw whole inside it.
local O = dofile("Tools/regression/options_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local function Scale(shown, inside)
	local handle
	local env, K, ns = O.New({ before = function(e, core)
		core.Layout = nil
		core.Modules.Register(O.W.CoreEnv.Module("UnitFrames", { defaults = {} }))
		local schema = { { type = "header", label = "Frames" } }
		schema.preview = function(parent)
			local frame = e.CreateFrame("Frame", nil, parent)
			frame:SetAllPoints(parent)
			local content = frame:CreateTexture(nil, "ARTWORK")
			content:SetSize(180, 80)
			content:SetPoint("CENTER", frame, "CENTER")
			content:SetTexture(core.Tokens.Texture("barFlat"))
			local portrait = e.CreateFrame("Frame", nil, frame)
			local pixel = core.Scale.Pixel(1) / core.Widgets.ScaleFactor(portrait)
			if inside then
				portrait:SetPoint("CENTER", content, "CENTER")
			else
				portrait:SetPoint("RIGHT", content, "LEFT", 20 * pixel, 0)
			end
			portrait:SetSize(39 * pixel, 39 * pixel)
			handle = core.Widgets.Ornament(portrait, "ring")
			handle.elite = true
			return frame
		end
		core.Options.Register("UnitFrames", schema)
	end })
	K.Store.Module("Widgets").cardMaterial = "ForgedBrackets"
	K.Store.Module("Widgets").ornaments = shown and "Full" or "Off"
	K.Options.Open("UnitFrames")
	env.RunTimers()
	for _ = 1, 60 do O.W.Tick(env, 1 / 60) end
	env.RunTimers()
	local pixel = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(handle.target)
	handle.target:SetSize(39 * pixel, 39 * pixel)
	handle:Restyle()
	local scene = Scene.Build(env)
	local solver = Scene.RectSolver(env)
	local hx, hy, hw, hh = Scene.RectIn(solver, ns.Window.Parts().preview.holder)
	local painted = 0
	for _, item in ipairs(scene.items) do
		for i = 1, handle.used do
			if item.object == handle.textures[i] then
				painted = painted + 1
				local x, y, w, h = Scene.RectIn(solver, item.object)
				assert(x >= hx - 0.01 and y >= hy - 0.01 and x + w <= hx + hw + 0.01 and y + h <= hy + hh + 0.01, "an ornament piece lies wholly inside the preview's clip")
			end
		end
	end
	assert(painted == (shown and 2 or 0), "the preview collects the actual Full ring and elite pendant, got " .. painted .. " used " .. handle.used)
	return ns.Window.Parts().preview.current:GetScale()
end

local off, full = Scale(false, true), Scale(true, true)
assert(off == full, "ornaments that fit inside the clip must not change the preview content scale: " .. tostring(off) .. " versus " .. tostring(full))
local edgeOff, edgeFull = Scale(false), Scale(true)
assert(edgeFull < edgeOff, "ornaments that would cross the clip shrink the preview: " .. tostring(edgeOff) .. " versus " .. tostring(edgeFull))
print(string.format("ok ornaments that fit leave the preview at %.2f; a ring that would cross the clip shrinks it from %.2f to %.2f and draws whole inside", off, edgeOff, edgeFull))
