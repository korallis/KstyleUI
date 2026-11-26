-- The visual audit requires the minimap menu to fit translated labels at the largest text size.
local M = dofile("Tools/regression/minimap_env.lua")
local Common = dofile("Tools/render/scenes/_common.lua")
local env, K, ns = M.New({ enabled = true, setup = function(e)
    Common.ForceScreen(e)
    e.GetLocale = function() return "esES" end
    for _, name in ipairs({ "Character", "Guild", "QuestLog", "Spellbook", "MainMenu" }) do
        e.CreateFrame("Button", name .. "MicroButton", e.UIParent)
    end
end })
M.Settle(env)
K.Options.Write("Appearance", "fontScale", 1.3)
K.Options.Write("Minimap", "microMenu", true)
env.Minimap:GetScript("OnMouseUp")(env.Minimap, "MiddleButton")
local panel = ns.Micro.panel
assert(panel:IsShown() and panel.rows[10]:GetText() == "Hermandad y comunidades")
for _, row in ipairs(panel.rows) do
    if row:IsShown() then
        assert(row.label:GetStringWidth() < row:GetWidth(), row:GetText() .. " must fit inside its button")
        assert(row:GetWidth() == panel.rows[10]:GetWidth(), "menu rows keep common edges")
    end
end
print("large Spanish minimap labels fit")
