-- The visual audit calls for whole physical edges around open popups, even beside a fractional owner.
local W = dofile("Tools/regression/widget_env.lua")
for _, screen in ipairs({ { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
    local _, K = W.New({ width = screen[1], height = screen[2], size = "auto" })
    local root = K.Scale.Root()
    local dropdown = K.Widgets.Dropdown(root, { options = { { label = "Full", value = "full" } } })
    dropdown:SetPoint("CENTER", root, "CENTER", 0.37, -0.29)
    dropdown:Open()
    local function whole(frame)
        local unit = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(frame)
        for _, edge in ipairs({ frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom() }) do
            local px = edge / unit
            assert(math.abs(px - math.floor(px + 0.5)) < 0.001, screen[2] .. "p popup edge: " .. px)
        end
    end
    whole(K.Widgets.DropdownMenu())
    local tip = K.Widgets.Tooltip()
    for _, side in ipairs({ "RIGHT", "BOTTOM", "LEFT", "TOP" }) do
        tip:SetOwner(dropdown, side)
        tip:AddTitle("Motion")
        tip:AddLine("Full")
        tip:AddDivider()
        tip:Show()
        whole(tip)
        whole(tip.used[3].divider)
    end
end
print("popup edges align at 1440p and 2160p")
