-- test-perf-slices.lua: unchanged owned slices skip mutations; bevel corners stay correct and public slices repaint after engine recolouring; an unchanged font and an unchanged chrome visibility write nothing.
local W = dofile("Tools/regression/widget_env.lua")
local env, K = W.New()
local owner = env.CreateFrame("Frame", nil, K.Scale.Root())
owner:SetSize(160.25, 80.5)
local chrome = K.Widgets.Chrome(owner, { shape = "tile" })
env.RunTimers()
local counts = {}
for _, slice in ipairs({ chrome.fill, chrome.rim, chrome.line }) do
	for _, piece in ipairs(slice) do
		for _, method in ipairs({ "ClearAllPoints", "SetPoint", "SetSize", "SetVertexColor" }) do
			local real = piece[method]
			piece[method] = function(self, ...)
				counts[method] = (counts[method] or 0) + 1
				return real(self, ...)
			end
		end
	end
end
chrome:Restyle()
assert(not next(counts), "P7: cache numeric slice layout inputs and unchanged colours; repeated chrome restyle must not mutate its slices")
chrome:SetFillRGBA(0.2, 0.3, 0.4, 0.8)
assert(counts.SetVertexColor == 9, "P7: repaint all nine pieces when a slice colour changes")
local slice = K.Widgets.NineSlice(owner, "chamferTile")
K.Widgets.ColorSlice(slice, 0.2, 0.3, 0.4, 0.8)
slice[1]:SetVertexColor(1, 1, 1, 1)
K.Widgets.ColorSlice(slice, 0.2, 0.3, 0.4, 0.8)
assert(W.SameColor(slice[1], 0.2, 0.3, 0.4, 0.8), "P7: engine-owned slices must remain writable after the engine recolours a piece")
owner:SetSize(160.5, 80.25)
assert(counts.SetPoint and counts.SetPoint > 0, "P7: changed fractional edges must invalidate the slice layout")
local panel = K.Widgets.Chrome(owner)
panel:Restyle()
local r, g, b, a = K.Widgets.Rgba("medRimLit")
assert(W.SameColor(panel.rim[1], r, g, b, a), "P7: retain bevel corner colours when the base rim colour was unchanged")
local function Writes(run)
	local writes = {}
	env._onCall = function(_, method)
		writes[#writes + 1] = method
	end
	run()
	env._onCall = nil
	return table.concat(writes, ", ")
end
local text = K.Widgets.FontString(owner, "OVERLAY")
K.Widgets.StyleText(text, "body")
local wrote = Writes(function() K.Widgets.StyleText(text, "body") end)
assert(wrote == "", "fights audit: Widgets.ApplyFont must not set an unchanged font or shadow again (it wrote " .. wrote .. "); compare GetFont, GetShadowColor and GetShadowOffset first, so a hook answering another addon's SetFont settles")
chrome:SetShown(true)
wrote = Writes(function() chrome:SetShown(true) end)
assert(wrote == "", "fights audit: Chrome:SetShown with an unchanged visibility must write nothing (it wrote " .. wrote .. "); the minimap's coordinate ticker shows its plaques five times a second")
chrome:SetShown(false)
assert(not chrome.fill[1]:IsShown(), "a hidden chrome hides its slices")
chrome:SetShown(true)
assert(chrome.fill[1]:IsShown(), "and shows them again")
assert(#env._errors == 0, table.concat(env._errors, "\n"))
print("perf slices ok")
