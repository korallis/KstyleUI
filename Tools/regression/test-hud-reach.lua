-- test-hud-reach.lua: the complete live HUD keeps its visible parts and mouse targets apart and inside the screen margin.
local Suite = dofile("Tools/regression/suite_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local Meters = dofile("Tools/regression/meters_env.lua")
local Minimap = dofile("Tools/regression/minimap_env.lua")
local Cooldowns = dofile("Tools/regression/cooldowns_env.lua")
local DataBars = dofile("Tools/regression/databars_env.lua")
local Chat = dofile("Tools/regression/chat_env.lua")

local screens = { {1920,1080}, {2560,1440}, {5120,1440}, {3840,2160}, {3456,2234}, {2383,1540}, {2560,1600}, {3440,1440}, {3840,1080} }
local allowed = {
	-- The secure party and raid headers are mutually exclusive in the game.
	["groupframes.party/groupframes.raid"] = true,
	-- Bar 1 owns the common tray behind both action rows; its art cannot intercept clicks.
	["actionbars.bar1/actionbars.bar2"] = true,
}
local failures, checked = {}, 0
local function fail(label, key, why)
	local line = label .. ": " .. key .. ": " .. why
	if not failures[line] then failures[line] = true; print(line) end
end
local function overlap(a, b, slack)
	return math.min(a[1]+a[3], b[1]+b[3])-math.max(a[1], b[1]) > slack
		and math.min(a[2]+a[4], b[2]+b[4])-math.max(a[2], b[2]) > slack
end
local function pair(a, b)
	return a < b and a .. "/" .. b or b .. "/" .. a
end

local env, K = Suite.New(nil, 1920, 1080, function(e)
	e._textWidth = function(text, path, size) return Scene.TextWidth(text, size, path) end
	Meters.Game(e)
	e.UnitReaction = function() return 2 end
	Minimap.Blizzard(e, {})
	Cooldowns.Install(e)
	Cooldowns.Viewers(e)
	DataBars.Game(e)
	DataBars.Blizzard(e)
	Chat.Install(e, {})
	for _, unit in ipairs({"target", "focus", "focustarget", "targettarget", "pet", "boss1", "boss2", "boss3", "boss4", "boss5"}) do
		e._units[unit] = {name=unit, class="WARRIOR", reaction=2, hostile=true, exists=true}
	end
end)
env.SetQuiet(true)
local choice = K.Setup.NewChoice()
for _, style in ipairs({"frames", "orbs", "medallions"}) do
	if not arg[1] or arg[1] == style then
		for _, layout in ipairs({"DPS", "Tank", "Healer"}) do
			choice.hudStyle, choice.layout = style, layout
			assert(K.Setup.Apply(choice), "full HUD setup must apply")
			K.Options.Write("Meters", "threat.shown", true)
			env.RunTimers()
			for _, arrangement in ipairs({"centred", "spread"}) do
				K.Options.Write("Layout", "arrangement", arrangement)
				for index, screen in ipairs(screens) do
					if not arg[2] or tonumber(arg[2]) == index then
						local w,h = screen[1],screen[2]
						env.GetPhysicalScreenSize = function() return w,h end
						env.UIParent._width = 768*w/h/env.UIParent._scale
						env.FireEvent("DISPLAY_SIZE_CHANGED")
						env.RunTimers()
						local label = string.format("%s %s %s %dx%d", style,layout,arrangement,w,h)
						assert(#env._errors == 0 and K.ErrorCount() == 0, label .. ": fixture errors: " .. tostring(env._errors[1]))
						local owners, groups = {}, {}
						for _, element in ipairs(K.Layout.Elements()) do
							if K.Setup.Layouts.Element(element.key) then
								owners[K.Layout.Element(element.key).frame] = element.key
							end
						end
						local function owner(object)
							while object and not owners[object] do object=object._parent end
							return object and owners[object]
						end
						local scene = Scene.Build(env, {paths=function(path) return type(path)=="string" and path or nil end})
						local pixel = 1080/h
						local margin = K.Tokens.Size("screenMargin")*K.Scale.AppliedUserScale()
						local width = w*1080/h
						local function add(key, item)
								local r=item.rect
								if r[1]<margin-pixel or r[2]<margin-pixel or r[1]+r[3]>width-margin+pixel or r[2]+r[4]>1080-margin+pixel then
									fail(label,key,"outside screen margin; move the default inward and reserve its full ornament/label bounds (" .. (item.text or item.file or item.kind) .. " " .. table.concat(r,",") .. ")")
								end
								groups[key]=groups[key] or {}
								local group=groups[key]
								group[#group+1]=item
								local box=group.bounds
								if box then
									local right,bottom=math.max(box[1]+box[3],r[1]+r[3]),math.max(box[2]+box[4],r[2]+r[4])
									box[1],box[2]=math.min(box[1],r[1]),math.min(box[2],r[2])
									box[3],box[4]=right-box[1],bottom-box[2]
								else group.bounds={unpack(r)} end
						end
						for _, item in ipairs(scene.items) do
							local key = owner(item.object)
							local file = item.file or item.path or ""
							-- Soft shadows/glows have transparent padding and deliberately bleed; solid ornaments stay checked.
							if key and not file:find("Shadow",1,true) and not file:find("Glow.png",1,true) then add(key,item) end
						end
						local solver, clicks = Scene.RectSolver(env), {}
						for _, frame in ipairs(env._frames) do
							local key=owner(frame)
							if key and frame:IsVisible() and frame:IsMouseEnabled() and env.Look(frame:GetAlpha())>0 then
								local rect={Scene.RectIn(solver,frame)}
								assert(#rect==4,label .. ": " .. key .. ": clickable bounds must resolve")
								local click={kind="click",rect=rect,key=key}
								clicks[#clicks+1]=click
								add(key,click)
							end
						end
						-- Disabled/empty slots keep a reservation too, so enabling a spare never hides another control.
						local L=K.Setup.Layouts
						local state=L.PrepareFits(layout,w,h,{},nil,style)
						local rx,ry,_,rh=Scene.RectIn(solver,K.Scale.Root())
						local scale=K.Scale.AppliedUserScale()
						local rw,rootHeight=K.Layout.RootSize()
						for i,element in ipairs(L.ELEMENTS) do
							local key=element.key
							if not groups[key] and not (style=="orbs" and key=="unitframes.player") then
								local size=state.sizes[i]
								local p=L.Place(layout,style,K.Scale.Aspect(),key,K.Scale.Band())
								local l,b,r,t=L.Rect({width=size[1],height=size[2],offsetX=size[3],offsetY=size[4]},p,rw,rootHeight)
								add(key,{kind="reserve",rect={rx+l*scale,ry+rh-t*scale,(r-l)*scale,(t-b)*scale}})
							end
						end
						for i,a in ipairs(clicks) do
							for j=i+1,#clicks do
								local b=clicks[j]
								if a.key~=b.key and pair(a.key,b.key)~="groupframes.party/groupframes.raid" and overlap(a.rect,b.rect,pixel) then
									fail(label,pair(a.key,b.key),"mouse targets cover one another; move the defaults apart")
								end
							end
						end
						for a, first in pairs(groups) do
							for b, second in pairs(groups) do
								if a<b and not allowed[pair(a,b)] and overlap(first.bounds,second.bounds,pixel) then
									local hit=false
									for _,r in ipairs(first) do
										for _,s in ipairs(second) do
											if overlap(r.rect,s.rect,pixel) then hit=true; break end
										end
										if hit then break end
									end
									if hit then fail(label,pair(a,b),"overlap; separate the defaults using their full placed bounds") end
								end
							end
						end
						checked=checked+1
						collectgarbage("collect")
					end
				end
			end
		end
	end
end
K.Options.Write("HudStyle","style","frames")
assert(K.Layout.Update("chat.main",{anchor="BOTTOMLEFT",x=-5000,y=-5000},true))
env.RunTimers()
local left,bottom=K.Layout.Rect("chat.main")
if left<K.Tokens.Size("screenMargin") or bottom<K.Tokens.Size("screenMargin") then
	fail("saved","chat.main","off-screen saved position must display inside the margin; clamp display geometry without rewriting Store.Layout")
end
assert(K.Store.Layout()["chat.main"].x==-5000 and K.Store.Layout()["chat.main"].y==-5000,"display clamp must preserve the saved position")
local x,y=400*K.Scale.Pixel(1),400*K.Scale.Pixel(1)
assert(K.Layout.Update("chat.main",{anchor="BOTTOMLEFT",x=x,y=y},true))
env.RunTimers()
left,bottom=K.Layout.Rect("chat.main")
assert(math.abs(left-x)<1e-8 and math.abs(bottom-y)<1e-8,"on-screen custom position must move zero pixels")
assert(next(failures)==nil, "HUD reach failed; move the named defaults, preserve custom positions, and rerun test-hud-reach.lua")
print("HUD reach ok: " .. checked .. " style/layout/arrangement/screen combinations")
