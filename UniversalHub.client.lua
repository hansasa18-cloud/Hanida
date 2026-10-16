--[[
 HANIDA NEXUS v2 | PC + Mobile
 Roblox Studio / your own experience: StarterPlayer > StarterPlayerScripts (LocalScript)
 Built-in local utilities. Admin actions require UniversalHub.server.lua in ServerScriptService.
 No external asset IDs, HTTP, exploit APIs, or anti-cheat bypass.
]]
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer
if not player then return end
local playerGui = player:WaitForChild("PlayerGui")

-- Reload-safe teardown, including RenderStepped connections and effects.
if type(_G.HANIDA_NEXUS_DISPOSE) == "function" then pcall(_G.HANIDA_NEXUS_DISPOSE) end
local previous = playerGui:FindFirstChild("HanidaNexusV2")
if previous then previous:Destroy() end

local T = {
 bg = Color3.fromRGB(10,12,22), panel = Color3.fromRGB(20,23,38),
 raised = Color3.fromRGB(30,34,53), border = Color3.fromRGB(56,61,87),
 purple = Color3.fromRGB(156,114,255), teal = Color3.fromRGB(67,224,207),
 white = Color3.fromRGB(243,244,253), soft = Color3.fromRGB(167,173,197),
 dim = Color3.fromRGB(113,121,151), red = Color3.fromRGB(255,105,128),
}
local settings = {
 speed=false, jump=false, infJump=false, noclip=false, fly=false,
 esp=false, showNames=true, showHealth=true, showDistance=true, teamCheck=true,
 aim=false, aimNPC=true, aimPlayers=false, aimVisible=true, showAimCircle=true, aimHead=true,
 fullbright=false, fovOn=false, lowGraphics=false, follow=false, spectate=false,
 aura=false, fpsCounter=true,
 walkSpeed=28, jumpPower=72, flySpeed=55, cameraFOV=85,
 espRange=350, espRefresh=0.25, espOpacity=.86, aimFOV=145, aimSmoothing=0.20,
 auraRange=12, auraDamage=10, auraInterval=0.6,
 bringDistance=5, flingPower=55, followDistance=3,
}
local defaults = table.clone(settings)
local alive, hidden = true, false
local connections, espItems = {}, {}
local flyVelocity, flyGyro, waypoint, selectedPlayer
local aimHeld, upHeld, downHeld = false, false, false
local lastAura, lastESP, lastFollow, lastFPS, fpsFrames = 0,0,0,0,0
local restoredCollisions = {}
local humanoidOriginals = setmetatable({}, {__mode="k"})
local originalLighting = {
 Ambient=Lighting.Ambient, OutdoorAmbient=Lighting.OutdoorAmbient,
 Brightness=Lighting.Brightness, ClockTime=Lighting.ClockTime,
 FogEnd=Lighting.FogEnd, GlobalShadows=Lighting.GlobalShadows,
}
local originalFOV = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
local mapRows, allRefreshers = {}, {}
local serverRemote = ReplicatedStorage:FindFirstChild("HanidaNexusAction")

local function on(sig, fn)
 local c = sig:Connect(fn); table.insert(connections,c); return c
end
local function make(class, props, parent)
 local o = Instance.new(class)
 for k,v in pairs(props or {}) do o[k]=v end
 o.Parent = parent; return o
end
local function round(o,r) make("UICorner",{CornerRadius=UDim.new(0,r or 12)},o) end
local function stroke(o,color,thick,trans)
 return make("UIStroke",{Color=color or T.border,Thickness=thick or 1,Transparency=trans or 0},o)
end
local function gradient(o,c1,c2,rot)
 make("UIGradient",{Color=ColorSequence.new(c1,c2),Rotation=rot or 0},o)
end
local function txt(parent,value,size,color,bold,props)
 local args={BackgroundTransparency=1,Text=value,TextSize=size or 13,
  TextColor3=color or T.white,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
  TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
  TextTruncate=Enum.TextTruncate.AtEnd}
 for k,v in pairs(props or {}) do args[k]=v end
 return make("TextLabel",args,parent)
end
local function button(parent,label,props)
 local p={Text=label,Font=Enum.Font.GothamSemibold,TextSize=13,
  TextColor3=T.white,BackgroundColor3=T.raised,BorderSizePixel=0,
  AutoButtonColor=true}
 for k,v in pairs(props or {}) do p[k]=v end
 local b=make("TextButton",p,parent); round(b,10); return b
end
local function getChar(plr)
 local c=(plr or player).Character
 if not c then return end
 return c,c:FindFirstChildOfClass("Humanoid"),c:FindFirstChild("HumanoidRootPart")
end
local function getCamera() return workspace.CurrentCamera end
local function notice(message)
 if alive and _G.HANIDA_NEXUS_STATUS then _G.HANIDA_NEXUS_STATUS.Text = tostring(message) end
end
local function selectedName()
 return selectedPlayer and selectedPlayer.Parent==Players and selectedPlayer.DisplayName or "대상 선택"
end
local function requestServer(kind,data)
 serverRemote = ReplicatedStorage:FindFirstChild("HanidaNexusAction")
 if not serverRemote or not serverRemote:IsA("RemoteEvent") then
  notice("서버 기능 미설치 · README의 서버 스크립트를 추가해 주세요")
  return false
 end
 serverRemote:FireServer(kind,data or {}); return true
end

-- Desktop and phone-compatible responsive shell.
local gui=make("ScreenGui",{Name="HanidaNexusV2",ResetOnSpawn=false,
 IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},playerGui)
local shadow=make("Frame",{BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=0.46,
 BorderSizePixel=0,ZIndex=1},gui); round(shadow,21)
local main=make("Frame",{BackgroundColor3=T.bg,BorderSizePixel=0,Active=true,ZIndex=2},gui)
round(main,19); stroke(main,T.border,1,0.1)
gradient(main,Color3.fromRGB(17,18,32),T.bg,90)
local glow=make("Frame",{Position=UDim2.new(0,0,0,0),Size=UDim2.new(1,0,0,4),
 BackgroundColor3=T.purple,BorderSizePixel=0,ZIndex=4},main)
gradient(glow,T.purple,T.teal,0)
local header=make("Frame",{BackgroundTransparency=1,Active=true,ZIndex=5},main)
local logo=make("Frame",{BackgroundColor3=T.purple,BorderSizePixel=0,
 Size=UDim2.fromOffset(41,41),Position=UDim2.fromOffset(15,12),ZIndex=6},header)
round(logo,13); gradient(logo,T.purple,T.teal,50)
txt(logo,"H",24,T.bg,true,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,ZIndex=7})
local brand=txt(header,"HANIDA  /  NEXUS",20,T.white,true,
 {Position=UDim2.fromOffset(67,8),Size=UDim2.new(1,-190,0,30),ZIndex=7})
local sub=txt(header,"UNIVERSAL CONTROL CENTER  •  v2.0",10,T.soft,false,
 {Position=UDim2.fromOffset(69,37),Size=UDim2.new(1,-197,0,19),ZIndex=7})
local close=button(header,"×",{Size=UDim2.fromOffset(37,34),BackgroundColor3=Color3.fromRGB(70,38,59),
 TextColor3=T.red,TextSize=21,ZIndex=7})
local collapse=button(header,"—",{Size=UDim2.fromOffset(37,34),ZIndex=7})
local headerLine=make("Frame",{BackgroundColor3=T.border,BackgroundTransparency=0.55,
 BorderSizePixel=0,Size=UDim2.new(1,-28,0,1),ZIndex=5},main)
local sidebar=make("ScrollingFrame",{BackgroundColor3=T.panel,BackgroundTransparency=0.12,
 BorderSizePixel=0,ScrollBarThickness=0,ZIndex=5},main)
round(sidebar,13)
local navLayout=make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6)},sidebar)
local navPad=make("UIPadding",{PaddingLeft=UDim.new(0,9),PaddingTop=UDim.new(0,10),
 PaddingRight=UDim.new(0,9),PaddingBottom=UDim.new(0,8)},sidebar)
local content=make("Frame",{BackgroundColor3=T.panel,BackgroundTransparency=0.15,
 BorderSizePixel=0,ZIndex=5},main)
round(content,13)
local footer=make("Frame",{BackgroundTransparency=1,ZIndex=5},main)
local status=txt(footer,"READY  •  화면 조작 준비 완료",11,T.soft,false,
 {Position=UDim2.fromOffset(10,0),Size=UDim2.new(1,-115,1,0),ZIndex=6})
_G.HANIDA_NEXUS_STATUS=status
local fpsTxt=txt(footer,"FPS --",11,T.teal,true,
 {Position=UDim2.new(1,-100,0,0),Size=UDim2.fromOffset(91,30),TextXAlignment=Enum.TextXAlignment.Right,ZIndex=6})
local launcher=button(gui,"✦  HUB",{Size=UDim2.fromOffset(99,42),BackgroundColor3=T.purple,
 TextColor3=T.bg,TextSize=14,Visible=false,ZIndex=20})
gradient(launcher,T.purple,T.teal,0)

local pages, navButtons, activePage, mobileMode={}, {}, nil, false
local function applyFilter(query)
 query=string.lower(query or "")
 for pageName,items in pairs(mapRows) do
  for _,entry in ipairs(items) do
   entry.frame.Visible=(query=="" or pageName~=activePage or string.find(string.lower(entry.name),query,1,true)~=nil)
  end
 end
end
local searchBox=make("TextBox",{PlaceholderText="기능 검색...",Text="",ClearTextOnFocus=false,
 TextSize=12,Font=Enum.Font.Gotham,TextColor3=T.white,PlaceholderColor3=T.dim,
 BackgroundColor3=T.raised,BorderSizePixel=0,ZIndex=6},main)
round(searchBox,9); stroke(searchBox,T.border,1,0.5)
local function goPage(name)
 activePage=name
 for key,p in pairs(pages) do p.Visible=(key==name) end
 for key,b in pairs(navButtons) do
  b.BackgroundColor3=(key==name) and Color3.fromRGB(69,54,109) or T.panel
  b.TextColor3=(key==name) and T.white or T.soft
 end
 applyFilter(searchBox.Text)
 notice(name.."  •  설정 선택 완료")
end
local function addPage(name,icon)
 local b=button(sidebar,"  "..icon.."    "..name,{Size=UDim2.fromOffset(155,40),
  BackgroundColor3=T.panel,TextXAlignment=Enum.TextXAlignment.Left,TextSize=13,ZIndex=6})
 on(b.MouseButton1Click,function() goPage(name) end)
 navButtons[name]=b
 local p=make("ScrollingFrame",{Name=name,Position=UDim2.fromOffset(10,10),
  Size=UDim2.new(1,-20,1,-20),BackgroundTransparency=1,BorderSizePixel=0,
  AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.fromOffset(0,0),
  ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarThickness=3,
  ScrollBarImageColor3=T.purple,Visible=false,ZIndex=6},content)
 make("UIListLayout",{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder},p)
 make("UIPadding",{PaddingRight=UDim.new(0,7),PaddingBottom=UDim.new(0,16)},p)
 pages[name]=p;mapRows[name]={};return p
end
local dashboard=addPage("대시보드","◇")
local movement=addPage("이동","↗")
local combat=addPage("조준 / 전투","◎")
local visuals=addPage("ESP / 화면","◈")
local people=addPage("플레이어","♧")
local utility=addPage("편의 기능","✧")
local options=addPage("환경 설정","⚙")
local function track(page,name,frame)
 table.insert(mapRows[page.Name],{name=name,frame=frame})
 return frame
end
local function section(page,name,desc)
 local f=make("Frame",{Size=UDim2.new(1,-4,0,51),BackgroundTransparency=1,ZIndex=7},page)
 txt(f,name,17,T.white,true,{Size=UDim2.new(1,0,0,29),ZIndex=8})
 txt(f,desc or "",11,T.soft,false,{Position=UDim2.fromOffset(0,28),Size=UDim2.new(1,0,0,17),ZIndex=8})
 return track(page,name,f)
end
local function card(page,title,detail,height)
 local f=make("Frame",{Size=UDim2.new(1,-4,0,height or 72),BackgroundColor3=T.raised,
  BackgroundTransparency=0.10,BorderSizePixel=0,ZIndex=7},page)
 round(f,12); stroke(f,T.border,1,0.72)
 txt(f,title,13,T.white,true,{Position=UDim2.fromOffset(13,7),Size=UDim2.new(1,-127,0,26),ZIndex=8})
 txt(f,detail or "",11,T.soft,false,{Position=UDim2.fromOffset(13,32),
  Size=UDim2.new(1,-127,0,32),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,ZIndex=8})
 track(page,title.." "..(detail or ""),f)
 return f
end
local function info(page,title,detail)
 local f=card(page,title,detail,84)
 return f
end
local function toggle(page,title,description,key,callback)
 local f=card(page,title,description,74)
 local b=button(f,"",{Size=UDim2.fromOffset(88,34),Position=UDim2.new(1,-100,0.5,-17),ZIndex=9})
 local function paint()
  b.Text=settings[key] and "●  ON" or "○  OFF"
  b.BackgroundColor3=settings[key] and T.purple or T.panel
  b.TextColor3=settings[key] and T.bg or T.soft
 end
 local function set(v)
  settings[key]=not not v
  if callback then
   local ok,err=pcall(callback,settings[key])
   if not ok then settings[key]=false; notice("실행 실패: "..tostring(err):sub(1,65)) end
  end
  paint()
 end
 on(b.MouseButton1Click,function() set(not settings[key]) end)
 table.insert(allRefreshers,paint)
 paint();return set
end
local function slider(page,title,description,key,minv,maxv,step,callback)
 local f=make("Frame",{Size=UDim2.new(1,-4,0,94),BackgroundColor3=T.raised,
  BackgroundTransparency=.10,BorderSizePixel=0,ZIndex=7},page)
 round(f,12);stroke(f,T.border,1,.72);track(page,title.." "..description,f)
 txt(f,title,13,T.white,true,{Position=UDim2.fromOffset(13,7),Size=UDim2.new(1,-90,0,23),ZIndex=8})
 txt(f,description,10,T.soft,false,{Position=UDim2.fromOffset(13,31),Size=UDim2.new(1,-26,0,18),ZIndex=8})
 local readout=txt(f,"",13,T.teal,true,{Position=UDim2.new(1,-91,0,6),
  Size=UDim2.fromOffset(78,26),TextXAlignment=Enum.TextXAlignment.Right,ZIndex=8})
 local trackBg=make("Frame",{Position=UDim2.new(0,17,1,-27),Size=UDim2.new(1,-34,0,8),
  BackgroundColor3=T.panel,BorderSizePixel=0,Active=true,ZIndex=9},f)
 round(trackBg,7)
 local fill=make("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=T.purple,
  BorderSizePixel=0,ZIndex=10},trackBg);round(fill,7);gradient(fill,T.purple,T.teal,0)
 local knob=make("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(0,0,.5,0),
  Size=UDim2.fromOffset(17,17),BackgroundColor3=T.white,BorderSizePixel=0,ZIndex=11},trackBg)
 round(knob,10);stroke(knob,T.purple,2,.1)
 local function paint()
  local val=math.clamp(tonumber(settings[key]) or minv,minv,maxv)
  local alpha=(val-minv)/(maxv-minv)
  readout.Text=string.format("%g",val)
  fill.Size=UDim2.new(alpha,0,1,0)
  knob.Position=UDim2.new(alpha,0,.5,0)
 end
 local dragging=false
 local function update(x)
  local ratio=math.clamp((x-trackBg.AbsolutePosition.X)/math.max(trackBg.AbsoluteSize.X,1),0,1)
  settings[key]=math.clamp(math.floor((minv+(maxv-minv)*ratio)/step+0.5)*step,minv,maxv)
  paint();if callback then callback(settings[key]) end
 end
 on(trackBg.InputBegan,function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
   dragging=true;update(input.Position.X)
  end
 end)
 on(UIS.InputChanged,function(input)
  if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
   update(input.Position.X)
  end
 end)
 on(UIS.InputEnded,function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
 end)
 table.insert(allRefreshers,paint);paint();return paint
end
local function action(page,title,description,caption,fn)
 local f=card(page,title,description,75)
 local b=button(f,caption or "실행",{Size=UDim2.fromOffset(90,34),
  Position=UDim2.new(1,-102,.5,-17),ZIndex=9})
 on(b.MouseButton1Click,function()
  local ok,err=pcall(fn)
  if not ok then notice("오류: "..tostring(err):sub(1,75)) end
 end)
 return b
end
local function cycle(page,title,description,labels,key)
 local f=card(page,title,description,74)
 local b=button(f,"",{Size=UDim2.fromOffset(96,34),Position=UDim2.new(1,-108,.5,-17),ZIndex=9})
 local function paint() b.Text=settings[key] and labels[2] or labels[1] end
 on(b.MouseButton1Click,function() settings[key]=not settings[key];paint() end)
 table.insert(allRefreshers,paint);paint();return paint
end

-- Persist defaults only for the current script lifetime (no external filesystem).
local function refreshAll() for _,fn in ipairs(allRefreshers) do pcall(fn) end end
local function setOriginalHumanoid(h)
 if h and not humanoidOriginals[h] then
  humanoidOriginals[h]={WalkSpeed=h.WalkSpeed,JumpPower=h.JumpPower,JumpHeight=h.JumpHeight}
 end
end
local function stopFly()
 if flyVelocity then flyVelocity:Destroy();flyVelocity=nil end
 if flyGyro then flyGyro:Destroy();flyGyro=nil end
 upHeld=false;downHeld=false
end
local function startFly()
 stopFly()
 local c,h,root=getChar()
 if not root or not h then notice("캐릭터 준비 중");settings.fly=false;refreshAll();return end
 flyVelocity=make("BodyVelocity",{MaxForce=Vector3.new(1e6,1e6,1e6),Velocity=Vector3.zero,P=8000},root)
 flyGyro=make("BodyGyro",{MaxTorque=Vector3.new(1e6,1e6,1e6),P=7000,D=300,CFrame=root.CFrame},root)
end
local function restoreNoclip()
 for part,value in pairs(restoredCollisions) do
  if part and part.Parent then pcall(function() part.CanCollide=value end) end
  restoredCollisions[part]=nil
 end
end
local espFolder=make("Folder",{Name="HanidaNexus_ESP"},gui)
local function removeESP(plr)
 local o=espItems[plr]
 if o then
  if o.mark then o.mark:Destroy() end
  if o.tag then o.tag:Destroy() end
 end
 espItems[plr]=nil
end
local function clearESP()
 for plr in pairs(espItems) do removeESP(plr) end
end
local function updateESP()
 local _,_,myRoot=getChar()
 for _,plr in ipairs(Players:GetPlayers()) do
  if plr~=player then
   local c,h,root=getChar(plr)
   local visible=settings.esp and c and root and h and h.Health>0 and myRoot
    and (root.Position-myRoot.Position).Magnitude<=settings.espRange
    and (not settings.teamCheck or plr.Team==nil or player.Team~=plr.Team)
   if not visible then removeESP(plr)
   else
    local r=espItems[plr]
    if not r or r.character~=c then
     removeESP(plr)
     local mark=make("Highlight",{Adornee=c,FillColor=T.purple,
      OutlineColor=T.teal,FillTransparency=settings.espOpacity,OutlineTransparency=.15,
      DepthMode=Enum.HighlightDepthMode.AlwaysOnTop},espFolder)
     local tag=make("BillboardGui",{Adornee=root,AlwaysOnTop=true,
      Size=UDim2.fromOffset(180,47),StudsOffsetWorldSpace=Vector3.new(0,3.6,0)},espFolder)
     local title=txt(tag,"",12,T.white,true,{Size=UDim2.new(1,0,0,23),
      TextXAlignment=Enum.TextXAlignment.Center,TextStrokeTransparency=.45})
     local subtitle=txt(tag,"",11,T.teal,false,{Position=UDim2.fromOffset(0,23),
      Size=UDim2.new(1,0,0,18),TextXAlignment=Enum.TextXAlignment.Center,TextStrokeTransparency=.45})
     r={character=c,mark=mark,tag=tag,title=title,subtitle=subtitle}
     espItems[plr]=r
    end
    r.mark.FillTransparency=settings.espOpacity
    r.title.Text=settings.showNames and plr.DisplayName or ""
    local infoParts={}
    if settings.showHealth then table.insert(infoParts,math.floor(h.Health).." HP") end
    if settings.showDistance then table.insert(infoParts,math.floor((root.Position-myRoot.Position).Magnitude).." studs") end
    r.subtitle.Text=table.concat(infoParts,"  ·  ")
    r.tag.Enabled=settings.showNames or settings.showHealth or settings.showDistance
   end
  end
 end
end
local function lineOfSight(position,targetChar)
 local cam=getCamera();if not cam then return false end
 local params=RaycastParams.new()
 local character=getChar();params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances=character and {character} or {}
 local hit=workspace:Raycast(cam.CFrame.Position,position-cam.CFrame.Position,params)
 return not hit or (targetChar and hit.Instance:IsDescendantOf(targetChar))
end
local function aimTarget()
 local cam=getCamera();if not cam then return end
 local width=cam.ViewportSize.X;local height=cam.ViewportSize.Y
 local middle=Vector2.new(width/2,height/2)
 local best,bestDist=nil,settings.aimFOV
 local function candidate(c,allow)
  if not allow or not c then return end
  local h=c:FindFirstChildOfClass("Humanoid")
  if not h or h.Health<=0 then return end
  local root=(settings.aimHead and c:FindFirstChild("Head")) or c:FindFirstChild("HumanoidRootPart")
  if not root then return end
  local pos,visible=cam:WorldToViewportPoint(root.Position)
  if not visible or pos.Z<=0 then return end
  local distance=(Vector2.new(pos.X,pos.Y)-middle).Magnitude
  if distance>=bestDist then return end
  if settings.aimVisible and not lineOfSight(root.Position,c) then return end
  bestDist=distance;best=root
 end
 if settings.aimPlayers then
  for _,plr in ipairs(Players:GetPlayers()) do
   if plr~=player and (not settings.teamCheck or not plr.Team or plr.Team~=player.Team) then
    candidate(plr.Character,true)
   end
  end
 end
 if settings.aimNPC then
  for _,model in ipairs(CollectionService:GetTagged("HubNPC")) do
   if model:IsA("Model") and model:IsDescendantOf(workspace) then candidate(model,true) end
  end
 end
 return best
end
local function restoreLighting()
 for key,val in pairs(originalLighting) do pcall(function() Lighting[key]=val end) end
end
local function bright(enable)
 if enable then
  Lighting.Ambient=Color3.fromRGB(240,240,255)
  Lighting.OutdoorAmbient=Color3.fromRGB(215,215,255)
  Lighting.Brightness=3;Lighting.ClockTime=14;Lighting.FogEnd=100000
  Lighting.GlobalShadows=false
 else restoreLighting() end
end
local hiddenDecor={}
local function lowGraphics(enable)
 if enable then
  for _,inst in ipairs(workspace:GetDescendants()) do
   if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") then
    if hiddenDecor[inst]==nil then hiddenDecor[inst]=inst.Enabled end
    inst.Enabled=false
   end
  end
 else
  for inst,prev in pairs(hiddenDecor) do
   if inst and inst.Parent then pcall(function() inst.Enabled=prev end) end
   hiddenDecor[inst]=nil
  end
 end
end
local function resetFeatureStates()
 for k,v in pairs(defaults) do settings[k]=v end
 settings.speed=false;settings.jump=false;settings.fly=false;settings.esp=false
 settings.noclip=false;settings.aim=false;settings.aura=false
 settings.fullbright=false;settings.fovOn=false;settings.lowGraphics=false
 settings.follow=false;settings.spectate=false
 stopFly();restoreNoclip();clearESP();restoreLighting();lowGraphics(false)
 local cam=getCamera();if cam then
  cam.FieldOfView=originalFOV;cam.CameraType=Enum.CameraType.Custom
  local _,h=getChar();if h then cam.CameraSubject=h end
 end
 for h,data in pairs(humanoidOriginals) do
  if h and h.Parent then
   pcall(function() h.WalkSpeed=data.WalkSpeed;h.JumpPower=data.JumpPower;h.JumpHeight=data.JumpHeight end)
  end
 end
 refreshAll();notice("모든 기능 초기화 완료")
end

section(dashboard,"CONTROL CENTER","Hanida Nexus · 원터치 제어 + 상세 커스터마이징")
info(dashboard,"시작하기","메뉴 왼쪽/위쪽에서 기능 선택 · 모든 값은 슬라이더로 조절 가능")
info(dashboard,"멀티 플랫폼","PC: RightShift 메뉴 숨김 / 모바일: HUB 버튼과 터치 UI")
info(dashboard,"서버 기능 안내","Bring / Fling / PvE Kill Aura는 서버 스크립트와 관리자 권한이 필요해요")
action(dashboard,"안전하게 전체 초기화","효과, 속도, 카메라, UI 상태를 기본값으로", "초기화",resetFeatureStates)
action(dashboard,"현재 자리 기억","현재 캐릭터 위치를 임시 웨이포인트에 저장", "저장",function()
 local _,_,root=getChar();if root then waypoint=root.CFrame;notice("웨이포인트 저장 완료") end
end)
action(dashboard,"저장 위치로 이동","이번 실행에서 저장한 위치로 되돌아가기", "이동",function()
 local c,_,root=getChar();if c and root and waypoint then c:PivotTo(waypoint);notice("위치 이동 완료")
 else notice("저장한 위치가 없어요") end
end)

section(movement,"MOVEMENT","실시간 수치 조절 · 키보드와 모바일 조이스틱 지원")
toggle(movement,"Speed · 이동 속도","켜면 원하는 이동 속도가 적용됩니다","speed")
slider(movement,"이동 속도","기본 16 · 최대 100","walkSpeed",16,100,1)
toggle(movement,"Jump · 점프력","휴머노이드의 점프 강도를 바꿔요","jump")
slider(movement,"점프력","기본 보통 50 · 최대 150","jumpPower",40,150,1)
toggle(movement,"Infinite Jump","공중에서 다시 점프 가능","infJump")
toggle(movement,"Noclip","자신 캐릭터의 충돌을 로컬에서 비활성화","noclip",function(v)
 if not v then restoreNoclip() end
end)
toggle(movement,"Fly · 자유 비행","PC: E 상승 / Q 하강 · 모바일: ▲ ▼ 버튼","fly",function(v)
 if v then startFly() else stopFly() end
end)
slider(movement,"비행 속도","비행 중에도 실시간 변경","flySpeed",10,160,5)

section(combat,"AIM / COMBAT","내 경험의 연습용 조준 보조 · 관리자 PvE 설정")
toggle(combat,"Aim Assist","PC: 오른쪽 버튼 누르는 동안 / 모바일: 토글","aim")
slider(combat,"Aim FOV","화면 중앙에서 인식할 범위 (픽셀)","aimFOV",35,320,5)
slider(combat,"Aim Smooth","0.05 부드럽게 · 1 즉시 회전","aimSmoothing",.05,1,.05)
cycle(combat,"NPC 타겟","HubNPC 태그가 지정된 NPC를 조준",{"OFF","ON"},"aimNPC")
cycle(combat,"플레이어 타겟","설정한 연습 환경에서 플레이어 조준",{"OFF","ON"},"aimPlayers")
cycle(combat,"가림 판정","가려진 대상은 조준 대상에서 제외",{"OFF","ON"},"aimVisible")
cycle(combat,"FOV 원 표시","조준 탐지 범위를 화면 중앙에 표시",{"OFF","ON"},"showAimCircle")
cycle(combat,"헤드 우선 조준","ON: Head / OFF: HumanoidRootPart",{"BODY","HEAD"},"aimHead")
toggle(combat,"PvE Kill Aura","태그된 NPC 대상으로만 서버 검증 후 피해","aura",function(v)
 if v and not ReplicatedStorage:FindFirstChild("HanidaNexusAction") then
  settings.aura=false;notice("PvE Aura 사용에는 서버 스크립트가 필요합니다")
 end
end)
slider(combat,"오라 범위","서버에서 최대 20 studs로 제한","auraRange",4,20,1)
slider(combat,"오라 피해","서버에서 최대 25로 제한","auraDamage",1,25,1)
slider(combat,"오라 간격","서버에서 최소 0.35초로 제한","auraInterval",.35,1.5,.05)

section(visuals,"VISUALS","시야 표시와 분위기 설정")
toggle(visuals,"Player ESP","플레이어 강조 표시 / 거리 조건 적용","esp",function(v)
 if not v then clearESP() end
end)
cycle(visuals,"이름 표시","플레이어 표시 이름",{"OFF","ON"},"showNames")
cycle(visuals,"체력 표시","체력을 숫자로 표시",{"OFF","ON"},"showHealth")
cycle(visuals,"거리 표시","대상과의 거리를 표시",{"OFF","ON"},"showDistance")
cycle(visuals,"팀 필터","같은 팀 플레이어는 표시/조준에서 제외",{"OFF","ON"},"teamCheck")
slider(visuals,"ESP 범위","멀리 떨어진 대상은 표시하지 않음","espRange",50,1000,25)
slider(visuals,"ESP 채우기 투명도","0.95 연하게 · 0.2 진하게","espOpacity",.2,.95,.05)
slider(visuals,"ESP 갱신 간격","작을수록 부드럽지만 리소스를 사용함","espRefresh",.1,1,.05)
toggle(visuals,"Fullbright","조명 효과 밝게 표시 (로컬)","fullbright",bright)
toggle(visuals,"사용자 FOV","카메라 시야각 변경","fovOn",function(v)
 local c=getCamera();if c then c.FieldOfView=v and settings.cameraFOV or originalFOV end
end)
slider(visuals,"카메라 FOV","카메라 렌즈 화각","cameraFOV",55,120,1,function(v)
 local c=getCamera();if c and settings.fovOn then c.FieldOfView=v end
end)

section(people,"PLAYERS","대상 선택 후 관전 / 이동 / 관리자 액션")
local playerSelect=action(people,"선택된 플레이어","목록을 한 명씩 전환 · 새로 들어온 유저도 반영","다음 ▶",function()
 local others={}
 for _,p in ipairs(Players:GetPlayers()) do if p~=player then table.insert(others,p) end end
 table.sort(others,function(a,b) return a.Name<b.Name end)
 if #others==0 then selectedPlayer=nil;notice("다른 플레이어가 없어요");return end
 local index=0
 for i,p in ipairs(others) do if p==selectedPlayer then index=i break end end
 selectedPlayer=others[(index % #others)+1]
 notice("대상 선택: "..selectedName().." (@"..selectedPlayer.Name..")")
end)
action(people,"대상에게 이동","내 캐릭터가 선택한 플레이어 옆으로 이동", "이동",function()
 local c,_,r=getChar();local _,_,target=selectedPlayer and getChar(selectedPlayer)
 if c and r and target then c:PivotTo(target.CFrame*CFrame.new(3,0,0));notice("이동: "..selectedName())
 else notice("먼저 대상을 선택해 주세요") end
end)
toggle(people,"관전","선택한 플레이어 시점을 관전","spectate",function(v)
 local cam=getCamera();if not cam then return end
 if v and (not selectedPlayer or selectedPlayer.Parent~=Players) then
  settings.spectate=false;notice("관전할 대상을 선택해 주세요");return
 end
 local _,h=getChar(v and selectedPlayer or player)
 if h then cam.CameraType=Enum.CameraType.Custom;cam.CameraSubject=h
 else settings.spectate=false;notice("관전할 대상이 준비되지 않았어요") end
end)
toggle(people,"자동 따라가기","대상 가까이 MoveTo로 따라가기","follow")
slider(people,"따라가기 거리","대상과 유지할 거리","followDistance",2,12,1)
slider(people,"Bring 간격","이동시 자신과 대상 사이 거리","bringDistance",3,12,1)
action(people,"Bring · 관리자","대상을 내 위치 근처로 이동 (서버 권한 필요)","BRING",function()
 if not selectedPlayer then notice("대상을 먼저 선택해 주세요");return end
 requestServer("Bring",{targetUserId=selectedPlayer.UserId,distance=settings.bringDistance})
end)
slider(people,"Fling 강도","서버에서 지정 범위 내로 강도 제한","flingPower",15,85,5)
action(people,"Fling · 관리자","서버에서 대상에게 게임 내 밀침 적용","FLING",function()
 if not selectedPlayer then notice("대상을 먼저 선택해 주세요");return end
 requestServer("Fling",{targetUserId=selectedPlayer.UserId,power=settings.flingPower})
end)

section(utility,"UTILITY","일상적 테스트와 최적화 기능")
toggle(utility,"Low Graphics","파티클 / 빔 / 트레일 표시를 줄여요","lowGraphics",lowGraphics)
toggle(utility,"FPS 카운터","우측 아래 대략적인 FPS 표시","fpsCounter")
action(utility,"카메라 복구","관전 종료 및 기본 카메라 복구","복구",function()
 settings.spectate=false
 local cam=getCamera();local _,h=getChar()
 if cam and h then cam.CameraType=Enum.CameraType.Custom;cam.CameraSubject=h end
 refreshAll();notice("카메라 복구 완료")
end)
action(utility,"캐릭터 재설정","내 캐릭터를 다시 생성 (테스트 서버 전용)","리스폰",function()
 local _,h=getChar();if h then h.Health=0 end
end)

section(options,"PREFERENCES","원하는 방식으로 쓰는 멀티 플랫폼 컨트롤")
info(options,"사용 방법","PC: RightShift 메뉴 표시 · 비행 E/Q · Aim 우클릭 · 모바일은 터치 버튼")
info(options,"서버 액션 보호","Bring / Fling / NPC Aura는 서버에서 권한·거리·빈도 검증")
info(options,"프리셋","프리셋은 현재 세션의 설정값만 바꿔요. 자동 저장 기능은 없어요.")
action(options,"SMOOTH 프리셋","느린 비행과 부드러운 조준값 적용","적용",function()
 settings.flySpeed=35;settings.aimSmoothing=.12;settings.aimFOV=100
 settings.espRefresh=.4;settings.espOpacity=.9;refreshAll();notice("SMOOTH 프리셋 적용")
end)
action(options,"FAST 프리셋","빠른 이동과 넓은 조준 범위","적용",function()
 settings.flySpeed=120;settings.walkSpeed=70;settings.aimSmoothing=.5
 settings.aimFOV=225;settings.espOpacity=.72;refreshAll();notice("FAST 프리셋 적용")
end)
action(options,"기본값 복원","모든 기능 OFF + 설정값 초기화","초기화",resetFeatureStates)

-- Responsive layout; horizontal navigation and accessible buttons on narrow viewports.
local flyButtons=make("Frame",{BackgroundTransparency=1,Visible=false,ZIndex=18},gui)
local flyUp=button(flyButtons,"▲",{Size=UDim2.fromOffset(57,48),
 BackgroundColor3=T.purple,TextColor3=T.bg,TextSize=23,ZIndex=19})
local flyDown=button(flyButtons,"▼",{Size=UDim2.fromOffset(57,48),
 BackgroundColor3=T.teal,TextColor3=T.bg,TextSize=23,ZIndex=19})
flyDown.Position=UDim2.fromOffset(0,55)
local aimCircle=make("Frame",{BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3,Visible=false},gui)
round(aimCircle,999)
stroke(aimCircle,T.purple,1.5,.32)
local aimTouch=button(gui,"◎  AIM",{Size=UDim2.fromOffset(92,42),
 BackgroundColor3=T.purple,TextColor3=T.bg,ZIndex=18,Visible=false})
local aimTouchActive=false
on(aimTouch.MouseButton1Click,function()
 aimTouchActive=not aimTouchActive
 aimTouch.Text=aimTouchActive and "◎  LOCK" or "◎  AIM"
 aimTouch.BackgroundColor3=aimTouchActive and T.teal or T.purple
end)
local function bindHeld(b,setFn)
 on(b.InputBegan,function(input)
  if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then setFn(true) end
 end)
 on(b.InputEnded,function(input)
  if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then setFn(false) end
 end)
end
bindHeld(flyUp,function(v) upHeld=v end)
bindHeld(flyDown,function(v) downHeld=v end)
local function layout()
 local cam=getCamera();if not cam then return end
 local s=cam.ViewportSize
 mobileMode = UIS.TouchEnabled and (s.X<850 or not UIS.KeyboardEnabled)
 local compact=s.X<750
 local width=math.clamp(s.X-20,300,860)
 local height=math.clamp(s.Y-26,250,580)
 if not compact then height=math.min(height,570) end
 local x=math.floor((s.X-width)/2);local y=math.floor((s.Y-height)/2)
 main.Position=UDim2.fromOffset(x,y);main.Size=UDim2.fromOffset(width,height)
 shadow.Position=UDim2.fromOffset(x+7,y+10);shadow.Size=UDim2.fromOffset(width,height)
 header.Size=UDim2.new(1,0,0,66)
 collapse.Position=UDim2.new(1,-91,0,15)
 close.Position=UDim2.new(1,-48,0,15)
 headerLine.Position=UDim2.fromOffset(14,66)
 if compact then
  brand.TextSize=17;sub.TextSize=9
  sidebar.Position=UDim2.fromOffset(12,75);sidebar.Size=UDim2.new(1,-24,0,52)
  navLayout.FillDirection=Enum.FillDirection.Horizontal
  for _,b in pairs(navButtons) do b.Size=UDim2.fromOffset(123,34) end
  navPad.PaddingTop=UDim.new(0,8);navPad.PaddingLeft=UDim.new(0,8)
  sidebar.AutomaticCanvasSize=Enum.AutomaticSize.X
  sidebar.ScrollingDirection=Enum.ScrollingDirection.X
  searchBox.Position=UDim2.fromOffset(12,132);searchBox.Size=UDim2.new(1,-24,0,31)
  content.Position=UDim2.fromOffset(12,170)
  content.Size=UDim2.new(1,-24,1,-207)
  footer.Position=UDim2.new(0,8,1,-36);footer.Size=UDim2.new(1,-16,0,31)
 else
  brand.TextSize=20;sub.TextSize=10
  sidebar.Position=UDim2.fromOffset(14,83);sidebar.Size=UDim2.new(0,183,1,-133)
  navLayout.FillDirection=Enum.FillDirection.Vertical
  for _,b in pairs(navButtons) do b.Size=UDim2.new(1,-3,0,41) end
  sidebar.AutomaticCanvasSize=Enum.AutomaticSize.Y
  sidebar.ScrollingDirection=Enum.ScrollingDirection.Y
  navPad.PaddingTop=UDim.new(0,10)
  searchBox.Position=UDim2.fromOffset(209,83);searchBox.Size=UDim2.new(1,-223,0,34)
  content.Position=UDim2.fromOffset(209,126)
  content.Size=UDim2.new(1,-223,1,-176)
  footer.Position=UDim2.new(0,14,1,-39);footer.Size=UDim2.new(1,-28,0,31)
 end
 launcher.Position=UDim2.fromOffset(math.max(8,s.X-112),math.max(8,s.Y-62))
 flyButtons.Position=UDim2.fromOffset(math.max(8,s.X-75),math.max(70,s.Y-220))
 flyButtons.Size=UDim2.fromOffset(60,110)
 aimTouch.Position=UDim2.fromOffset(math.max(8,s.X-112),math.max(8,s.Y-277))
end

local dragging=false;local dragStart,startPos
on(header.InputBegan,function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
  dragging=true;dragStart=input.Position;startPos=main.Position
 end
end)
on(UIS.InputChanged,function(input)
 if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
  local delta=input.Position-dragStart
  local cam=getCamera();local vp=cam and cam.ViewportSize or Vector2.new(1200,700)
  local nx=math.clamp(startPos.X.Offset+delta.X,0,math.max(0,vp.X-main.AbsoluteSize.X))
  local ny=math.clamp(startPos.Y.Offset+delta.Y,0,math.max(0,vp.Y-main.AbsoluteSize.Y))
  main.Position=UDim2.fromOffset(nx,ny)
  shadow.Position=UDim2.fromOffset(nx+7,ny+10)
 end
end)
on(UIS.InputEnded,function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)
local function setHidden(v)
 hidden=v;main.Visible=not v;shadow.Visible=not v;launcher.Visible=v
end
on(collapse.MouseButton1Click,function() setHidden(true) end)
on(launcher.MouseButton1Click,function() setHidden(false) end)
on(close.MouseButton1Click,function()
 if type(_G.HANIDA_NEXUS_DISPOSE)=="function" then _G.HANIDA_NEXUS_DISPOSE() end
end)
on(searchBox:GetPropertyChangedSignal("Text"),function()applyFilter(searchBox.Text)end)
on(UIS.InputBegan,function(input,gameProcessed)
 if input.KeyCode==Enum.KeyCode.RightShift then setHidden(not hidden) end
 if gameProcessed then return end
 if input.UserInputType==Enum.UserInputType.MouseButton2 then aimHeld=true end
 if input.KeyCode==Enum.KeyCode.E then upHeld=true end
 if input.KeyCode==Enum.KeyCode.Q then downHeld=true end
end)
on(UIS.InputEnded,function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton2 then aimHeld=false end
 if input.KeyCode==Enum.KeyCode.E then upHeld=false end
 if input.KeyCode==Enum.KeyCode.Q then downHeld=false end
end)
on(UIS.JumpRequest,function()
 if settings.infJump then
  local _,h=getChar();if h and h.Health>0 then h:ChangeState(Enum.HumanoidStateType.Jumping) end
 end
end)
on(Players.PlayerRemoving,function(plr)
 removeESP(plr)
 if selectedPlayer==plr then selectedPlayer=nil end
end)
on(player.CharacterAdded,function()
 stopFly();restoreNoclip()
 task.spawn(function()
  local c=player.Character
  if not c then return end
  c:WaitForChild("HumanoidRootPart",10)
  c:WaitForChild("Humanoid",10)
  if not alive or player.Character~=c then return end
  local _,h=getChar();if h then setOriginalHumanoid(h) end
  if settings.fly then startFly() end
  if settings.spectate then settings.spectate=false;refreshAll() end
 end)
end)
if serverRemote and serverRemote:IsA("RemoteEvent") then
 on(serverRemote.OnClientEvent,function(message)
  if type(message)=="string" then notice(message) end
 end)
end
on(ReplicatedStorage.ChildAdded,function(c)
 if c.Name=="HanidaNexusAction" and c:IsA("RemoteEvent") then
  serverRemote=c
  on(c.OnClientEvent,function(message)if type(message)=="string" then notice(message) end end)
 end
end)

-- Gameplay loops: one shared heartbeat and one render callback, no per-card loops.
on(RS.Stepped,function()
 if not alive then return end
 local c=getChar()
 if c and settings.noclip then
  for _,p in ipairs(c:GetDescendants()) do
   if p:IsA("BasePart") then
    if restoredCollisions[p]==nil then restoredCollisions[p]=p.CanCollide end
    p.CanCollide=false
   end
  end
 end
end)
on(RS.Heartbeat,function(dt)
 if not alive then return end
 local c,h,root=getChar()
 if h and h.Health>0 then
  setOriginalHumanoid(h)
  local orig=humanoidOriginals[h]
  h.WalkSpeed=settings.speed and settings.walkSpeed or orig.WalkSpeed
  if h.UseJumpPower then
   h.JumpPower=settings.jump and settings.jumpPower or orig.JumpPower
  else
   h.JumpHeight=settings.jump and (settings.jumpPower/50)*orig.JumpHeight or orig.JumpHeight
  end
 end
 if settings.fly and h and root then
  if not flyVelocity or not flyVelocity.Parent then startFly() end
  local cam=getCamera()
  if cam and flyVelocity and flyGyro then
   local dir=h.MoveDirection
   local y=(upHeld and 1 or 0)-(downHeld and 1 or 0)
   local velocity=dir*settings.flySpeed+Vector3.new(0,y*settings.flySpeed,0)
   flyVelocity.Velocity=velocity
   local flat=cam.CFrame.LookVector
   local flatLook=Vector3.new(flat.X,0,flat.Z)
   if flatLook.Magnitude>0.001 then
    flyGyro.CFrame=CFrame.lookAt(root.Position,root.Position+flatLook.Unit)
   end
  end
 end
 local now=os.clock()
 if settings.esp and now-lastESP>=settings.espRefresh then lastESP=now;updateESP() end
 if settings.follow and selectedPlayer and now-lastFollow>.28 then
  lastFollow=now
  local _,_,targetRoot=getChar(selectedPlayer)
  if h and targetRoot then h:MoveTo((targetRoot.CFrame*CFrame.new(2,0,settings.followDistance)).Position) end
 end
 if settings.aura and now-lastAura>=settings.auraInterval then
  lastAura=now
  requestServer("AuraTick",{radius=settings.auraRange,damage=settings.auraDamage})
 end
end)
on(RS.RenderStepped,function(dt)
 if not alive then return end
 fpsFrames=fpsFrames+1
 if os.clock()-lastFPS>=1 then
  fpsTxt.Text=settings.fpsCounter and ("FPS  "..fpsFrames) or ""
  playerSelect.Text=selectedPlayer and (selectedName():sub(1,10).." ▶") or "다음 ▶"
  fpsFrames=0;lastFPS=os.clock()
 end
 flyButtons.Visible=UIS.TouchEnabled and settings.fly
 aimTouch.Visible=UIS.TouchEnabled and settings.aim
 local camera=getCamera()
 aimCircle.Visible=settings.aim and settings.showAimCircle and camera~=nil
 if aimCircle.Visible and camera then
  local diameter=settings.aimFOV*2
  local view=camera.ViewportSize
  aimCircle.Size=UDim2.fromOffset(diameter,diameter)
  aimCircle.Position=UDim2.fromOffset((view.X-diameter)/2,(view.Y-diameter)/2)
 end
 if settings.aim and (aimHeld or (UIS.TouchEnabled and aimTouchActive)) then
  local target=aimTarget();local cam=getCamera()
  if target and cam then
   local desired=CFrame.lookAt(cam.CFrame.Position,target.Position)
   cam.CFrame=cam.CFrame:Lerp(desired,settings.aimSmoothing)
  end
 end
end)

local function dispose()
 if not alive then return end
 resetFeatureStates()
 alive=false
 for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
 connections={}
 if gui then gui:Destroy() end
 if _G.HANIDA_NEXUS_STATUS==status then _G.HANIDA_NEXUS_STATUS=nil end
 if _G.HANIDA_NEXUS_DISPOSE==dispose then _G.HANIDA_NEXUS_DISPOSE=nil end
end
_G.HANIDA_NEXUS_DISPOSE=dispose

local c,h=getChar();if h then setOriginalHumanoid(h) end
local function connectViewport()
 local cam=getCamera()
 if cam then on(cam:GetPropertyChangedSignal("ViewportSize"),layout) end
end
connectViewport()
on(workspace:GetPropertyChangedSignal("CurrentCamera"),function()
 connectViewport();layout()
end)
goPage("대시보드")
layout()
notice("HANIDA NEXUS 2.0  •  로드 완료")
