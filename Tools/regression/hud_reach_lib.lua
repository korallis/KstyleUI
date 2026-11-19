-- hud_reach_lib.lua: the complete live HUD keeps its visible parts and mouse targets apart and inside the screen margin.
local Suite = dofile("Tools/regression/suite_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local Guard = dofile("Tools/render/guard.lua")
local Meters = dofile("Tools/regression/meters_env.lua")
local Minimap = dofile("Tools/regression/minimap_env.lua")
local Cooldowns = dofile("Tools/regression/cooldowns_env.lua")
local DataBars = dofile("Tools/regression/databars_env.lua")
local Chat = dofile("Tools/regression/chat_env.lua")
local Group = dofile("Tools/regression/group_env.lua")
local EditMode = dofile("Tools/regression/editmode_fake.lua")
local Auras = dofile("Tools/regression/auras_env.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

local Reach = {}
Reach.screens = {
    {1920,1080}, {2560,1440}, {5120,1440}, {3840,2160}, {3456,2234}, {2383,1540}, {2560,1600}, {3440,1440}, {3840,1080},
    {1280,720}, {1366,768}, {2560,1080}, {1452,1089}, {1685,1123}, {2642,1651}, {1280,1024},
    {1920,1200}, {2043,855}, {4236,1495}, {2266,1000}, {3247,1359},
}

function Reach.New(width, height, style, layout)
	return Suite.New(nil, width or 1920, height or 1080, function(e)
		e._textWidth = function(text, path, size) return Scene.TextWidth(text, size, path) end
		Meters.Game(e)
		Group.Install(e)
		e.UnitReaction = function() return 2 end
		Minimap.Blizzard(e, {})
		Cooldowns.Install(e)
		Cooldowns.Viewers(e)
		DataBars.Game(e)
		DataBars.Blizzard(e)
		Chat.Install(e, {})
		e._reachEdit={saved={},active=1}
		EditMode.Install(e,e._reachEdit)
		for _, unit in ipairs({"target", "focus", "focustarget", "targettarget", "pet", "boss1", "boss2", "boss3", "boss4", "boss5"}) do
			e._units[unit] = {name=unit, class="WARRIOR", reaction=2, hostile=true, exists=true, health=3000, maxHealth=4000, power=60, maxPower=100, level=60}
		end
		Group.SetRoster(e,"raid",Group.Members(40),{name="Tester",class="HUNTER",health=3000,maxHealth=4000,power=60,maxPower=100,level=60},true)
		e._target = true
	end, function(_, K)
		K.Setup.EditMode.CountTracked(function(group) return group=="buffs" and 6 or group=="bars" and 2 or 12 end)
		local choice=K.Setup.NewChoice()
		choice.hudStyle,choice.layout=style or "frames",layout or "DPS"
		assert(K.Setup.Apply(choice),"full HUD setup must apply before login")
		K.Options.Write("Meters","threat.shown",true)
	end)
end

function Reach.Populate(env)
	for _, group in ipairs({"essential","utility"}) do
		env._addons.KstyleUI_Cooldowns.Mirror.Row(group):SetCount(12)
	end
	local K=env.KstyleUI
	local layout=K.Layout.Setting("preset")
	K.Setup.EditMode.Restyle(layout,K.Setup.Story(layout,false))
	local written=assert(EditMode.Named(env._reachEdit,"KstyleUI " .. layout))
	for _,view in ipairs({{"BuffIconCooldownViewer",EditMode.BUFF_ICON,6},{"BuffBarCooldownViewer",EditMode.BUFF_BAR,2}}) do
		local items={}
		for i=1,view[3] do items[i]={id=i,icon=135813,name="Tracked buff " .. i,left=12,total=30} end
		Cooldowns.Native(env,view[1],assert(EditMode.Find(written,EditMode.VIEWER,view[2])),items,tostring)
	end
	local ns=env._addons.KstyleUI_Auras
	for _,name in ipairs({"buffs","debuffs"}) do
		local desc=ns.Panel.Group(name)
		Auras.Assign(env,desc.container,name,10)
		local group=desc.container._groups[name]
		Hud.PlaceAuras(desc.container,group,group.active,desc.ctx.group.columns)
		for _,button in ipairs(group.active) do button._aura.icon:SetTexture(env.Secret(135813)); button._aura.timer:SetText("30s") end
	end
end

function Reach.Run(wantedStyle, wantedLayout, wantedScreen)
	local screens = Reach.screens
	local first,last = wantedScreen=="small" and 10 or wantedScreen=="cases" and 17 or 1, wantedScreen=="small" and 16 or wantedScreen=="cases" and #screens or 9
	local allowed = {
		-- The secure party and raid headers are mutually exclusive in the game.
		["groupframes.party/groupframes.raid"] = true,
		-- Bar 1 owns the common tray behind both action rows; its art cannot intercept clicks.
		["actionbars.bar1/actionbars.bar2"] = true,
		-- The Orbs tray's arms sit behind the two health/resource rings in the same assembly.
		["actionbars.bar1/unitframes.player"] = wantedStyle=="orbs" or nil,
		-- The Medallions crest and XP track sit on the common slab, and XP continues behind the crest.
		["actionbars.bar1/actionbars.hub"] = wantedStyle=="medallions" or nil,
		["actionbars.bar1/databars.xp"] = wantedStyle=="medallions" or nil,
		["actionbars.hub/databars.xp"] = wantedStyle=="medallions" or nil,
	}
	local failures, checked = {}, 0
	local function fail(label, key, why)
		local line = label .. ": " .. key .. ": " .. why
		if not failures[line] then failures[line] = true; print(line) end
	end
	local function overlap(a, b, slack)
		if a.circle then a,b=b,a end
		if b.circle then
			local radius=b[3]/2
			local cx,cy=b[1]+radius,b[2]+b[4]/2
			local dx,dy=math.max(a[1]-cx,0,cx-a[1]-a[3]),math.max(a[2]-cy,0,cy-a[2]-a[4])
			return dx*dx+dy*dy<(radius-slack)*(radius-slack)
		end
		return math.min(a[1]+a[3], b[1]+b[3])-math.max(a[1], b[1]) > slack
			and math.min(a[2]+a[4], b[2]+b[4])-math.max(a[2], b[2]) > slack
	end
	local function pair(a, b)
		return a < b and a .. "/" .. b or b .. "/" .. a
	end

	local env, K = Reach.New(nil,nil,wantedStyle,wantedLayout)
	env.SetQuiet(true)
	local choice = K.Setup.NewChoice()
	for _, style in ipairs({"frames", "orbs", "medallions"}) do
		if not wantedStyle or wantedStyle == style then
			allowed["actionbars.bar1/unitframes.player"]=style=="orbs"
			allowed["actionbars.bar1/actionbars.hub"],allowed["actionbars.bar1/databars.xp"],allowed["actionbars.hub/databars.xp"]=style=="medallions",style=="medallions",style=="medallions"
			for _, layout in ipairs(wantedLayout and {wantedLayout} or {"DPS", "Tank", "Healer"}) do
				choice.hudStyle, choice.layout = style, layout
				if K.HudStyle.Current()~=style or K.Layout.Setting("preset")~=layout then assert(K.Setup.Apply(choice), "full HUD setup must apply") end
				K.Options.Write("Meters", "threat.shown", true)
				env.RunTimers()
				for _, arrangement in ipairs({"centred", "spread"}) do
					K.Options.Write("Layout", "arrangement", arrangement)
					for index, screen in ipairs(screens) do
						if type(wantedScreen)=="number" and wantedScreen==index or type(wantedScreen)~="number" and index>=first and index<=last then
							local w,h = screen[1],screen[2]
							env.GetPhysicalScreenSize = function() return w,h end
							env.UIParent._width = 768*w/h/env.UIParent._scale
							env.FireEvent("DISPLAY_SIZE_CHANGED")
							env.RunTimers()
							Reach.Populate(env)
							local label = string.format("%s %s %s %dx%d", style,layout,arrangement,w,h)
							assert(#env._errors == 0 and K.ErrorCount() == 0, label .. ": fixture errors: " .. tostring(env._errors[1]))
							local owners, groups = {}, {}
							for _, element in ipairs(K.Layout.Elements()) do
								if K.Setup.Layouts.Element(element.key) or element.key=="skins.guide" or element.key=="skins.quests" then
									owners[K.Layout.Element(element.key).frame] = element.key
								end
							end
							owners[env.BuffIconCooldownViewer]="cooldowns.buffs"
							owners[env.BuffBarCooldownViewer]="cooldowns.bars"
							for _,name in ipairs({"buffs","debuffs"}) do owners[env._addons.KstyleUI_Auras.Panel.Group(name).host]="auras." .. name end
							if style=="orbs" then
								for _,kind in ipairs({"health","power"}) do owners[assert(env._addons.KstyleUI_UnitFrames.Orbs.Get(kind))]="unitframes.player" end
								owners[assert(env._addons.KstyleUI_UnitFrames.Orbs.Tray())]="actionbars.bar1"
							end
							if style=="medallions" then
								local slab=env._addons.KstyleUI_ActionBars.Slab
								owners[assert(slab.frame)]="actionbars.bar1"
								owners[assert(slab.hub)]="actionbars.hub"
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
								if key and not (style=="orbs" and key=="unitframes.player") and not file:find("Shadow",1,true) and not file:find("Glow.png",1,true) then add(key,item) end
							end
							local solver, clicks = Scene.RectSolver(env), {}
							if style=="orbs" then
								for _,kind in ipairs({"health","power"}) do
									local rect={Scene.RectIn(solver,env._addons.KstyleUI_UnitFrames.Orbs.Get(kind))}
									rect.circle=true
									add("unitframes.player",{kind="circle",rect=rect})
								end
							end
							for _, frame in ipairs(env._frames) do
								local key=owner(frame)
								if key and frame:IsVisible() and frame:IsMouseEnabled() and env.Look(frame:GetAlpha())>0 then
									local rect={Scene.RectIn(solver,frame)}
									assert(#rect==4,label .. ": " .. key .. ": clickable bounds must resolve")
									local click={kind="click",rect=rect,key=key,object=frame}
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
							local story=L.Story(layout,rootHeight,true,style,rw)
							for _,card in pairs(story) do
								if type(card)=="table" and card.key and not groups[card.key] then
									local l,b,r,t=L.Rect(card,card,rw,rootHeight)
									add(card.key,{kind="reserve",rect={rx+l*scale,ry+rh-t*scale,(r-l)*scale,(t-b)*scale}})
								end
							end
							for _,element in ipairs(L.ELEMENTS) do
								assert(groups[element.key] or style=="orbs" and element.key=="unitframes.player",label .. ": missing HUD bounds for " .. element.key)
							end
							for i,a in ipairs(clicks) do
								for j=i+1,#clicks do
									local b=clicks[j]
									if a.key~=b.key and pair(a.key,b.key)~="groupframes.party/groupframes.raid" and overlap(a.rect,b.rect,pixel*0.01) then
										fail(label,pair(a.key,b.key),"mouse targets cover one another; move the defaults apart")
									end
								end
								for key,items in pairs(groups) do
									if key~=a.key and allowed[pair(a.key,key)] and pair(a.key,key)~="groupframes.party/groupframes.raid" then
										for _,item in ipairs(items) do
											if item.object and Guard.Hides(item) and item.object._parent:GetFrameLevel()>a.object:GetFrameLevel() and overlap(a.rect,item.rect,pixel*0.01) then
												fail(label,pair(a.key,key),"opaque art covers a mouse target; keep the shared tray below its buttons")
											end
										end
									end
								end
							end
							for a, first in pairs(groups) do
								for b, second in pairs(groups) do
									if a<b and not allowed[pair(a,b)] and overlap(first.bounds,second.bounds,pixel*0.01) then
										local hit=false
										for _,r in ipairs(first) do
											for _,s in ipairs(second) do
									if overlap(r.rect,s.rect,pixel*0.01) then hit=(r.text or r.file or r.kind) .. " " .. table.concat(r.rect,",") .. " / " .. (s.text or s.file or s.kind) .. " " .. table.concat(s.rect,","); break end
											end
											if hit then break end
										end
									if hit then fail(label,pair(a,b),"overlap; separate the defaults using their full placed bounds (" .. hit .. ")") end
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
	local shown={Scene.Rect(env,K.Layout.Element("chat.main").frame)}
	local margin=K.Tokens.Size("screenMargin")*K.Scale.AppliedUserScale()
	assert(shown[1]>=margin and shown[2]+shown[4]<=1080-margin+1e-8,"the actual frame must display on screen, not just Layout.Rect")
	local x,y=400*K.Scale.Pixel(1),400*K.Scale.Pixel(1)
	assert(K.Layout.Update("chat.main",{anchor="BOTTOMLEFT",x=x,y=y},true))
	env.RunTimers()
	left,bottom=K.Layout.Rect("chat.main")
	assert(math.abs(left-x)<1e-8 and math.abs(bottom-y)<1e-8,"on-screen custom position must move zero pixels")
	shown={Scene.Rect(env,K.Layout.Element("chat.main").frame)}
	local rootX=Scene.Rect(env,K.Scale.Root())
	assert(math.abs(shown[1]-rootX-x*K.Scale.AppliedUserScale())<1e-8 and math.abs(1080-shown[2]-shown[4]-y*K.Scale.AppliedUserScale())<1e-8,"the actual on-screen frame must move zero pixels")
	assert(next(failures)==nil, "HUD reach failed; move the named defaults, preserve custom positions, and rerun test-hud-reach.lua")
	print("HUD reach ok: " .. checked .. " style/layout/arrangement/screen combinations")
end

return Reach
