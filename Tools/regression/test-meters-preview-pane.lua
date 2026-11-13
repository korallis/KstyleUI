-- test-meters-preview-pane.lua: the Meters page's sample in the settings window's real preview pane draws every text whole at the 11 px floor, cutting rows or columns rather than truncating one.
local O = dofile("Tools/regression/options_env.lua")
local M = dofile("Tools/regression/meters_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Scene = dofile("Tools/render/scene.lua")
local Guard = dofile("Tools/render/guard.lua")

local function under(object, root)
	local node = object
	while node do
		if node == root then
			return true
		end
		node = node:GetParent()
	end
	return false
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 3840, 2160 } }) do
	local env, K = O.New({
		width = screen[1],
		height = screen[2],
		setup = function(env)
			M.Game(env)
		end,
		before = function(env)
			Load(M.Files(), env)
		end,
	})
	assert(K.Options.Open("Meters") ~= false, "the settings window opens on the Meters page")
	env.RunTimers()
	O.W.Settle(env)
	local frame
	for _, f in ipairs(env._frames) do
		if f.damage and f.threat and f.swing and f.Refresh and f:IsVisible() then
			frame = f
		end
	end
	assert(frame, "the Meters page shows its sample")
	local where = screen[1] .. "x" .. screen[2]
	assert(frame.damage.count > 0 and frame.threat.count > 0, where .. ": both sample meters keep rows")
	local scene = Scene.Build(env)
	local cut = {}
	for _, finding in ipairs(Guard.Check(scene)) do
		if finding.kind == "ellipsis" and finding.object and under(finding.object, frame) then
			cut[#cut + 1] = finding.subject .. " (" .. finding.detail .. ")"
		end
	end
	assert(#cut == 0, where .. ": the sample truncates " .. table.concat(cut, "; "))
	assert(#env._errors == 0, "no Lua error: " .. tostring(env._errors[1]))
end

print("meters preview pane ok")
