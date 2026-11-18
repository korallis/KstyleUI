-- test-dialog-button-fit.lua: real translated action buttons fit their dialog, while ordinary two-button dialogs retain their geometry.
local W = dofile("Tools/regression/widget_env.lua")
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")

for _, locale in ipairs({ "frFR", "deDE" }) do
	local env, K = W.New({ saved = Gallery.Saved(), setup = function(e)
		Common.ForceScreen(e)
		e.GetLocale = function() return locale end
	end })
	local small = K.Widgets.Confirm({ title = "Existing dialog", text = "An ordinary confirmation." })
	local host = K.Widgets.DialogHost()
	local width, height = host:GetSize()
	assert(W.Near(width, K.Widgets.Snap(host, 360)), "ordinary dialogs must keep their original 360-unit width")
	small:Close()
	local L = K.L
	K.Widgets.Popup({ title = L["New spells"], text = L["New spells:"] .. "\nCharge", buttons = {
		{ label = L["Not now"] }, { label = L["Update bars"] }, { label = L["Add new to bars"] },
	} })
	W.Settle(env)
	assert(host:GetWidth() > width, locale .. ": the translated three-button row needs a wider dialog")
	local solver = Common.Scene.RectSolver(env)
	local cardX, _, cardWidth = Common.Scene.RectIn(solver, host)
	for _, button in ipairs(host.visibleButtons) do
		local x, _, w = Common.Scene.RectIn(solver, button)
		assert(x >= cardX and x + w <= cardX + cardWidth + 0.01, locale .. ": each button must stay inside its dialog; size the dialog to the button row")
		assert(not button.label:IsTruncated(), locale .. ": translated action labels must remain readable")
	end
	W.Click(host.visibleButtons[1])
	K.Widgets.Confirm({ title = "Existing dialog", text = "An ordinary confirmation." })
	assert(W.Near(host:GetWidth(), width) and W.Near(host:GetHeight(), height), "a normal dialog after a wide one must recover its original geometry")
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
end

print("test-dialog-button-fit: ok")
