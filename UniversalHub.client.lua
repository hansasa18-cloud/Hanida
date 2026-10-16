--[[
  UNIVERSAL HUB - Personal Roblox Studio testing utility
  Put this LocalScript into StarterPlayer > StarterPlayerScripts.
  Client-side only: it does not grant server permissions or change other players' data.
  Tested by static inspection only; individual experiences may override character controls.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")

local localPlayer = Players.LocalPlayer
if not localPlayer then return end
local playerGui = localPlayer:WaitForChild("PlayerGui")
local mouse = localPlayer:GetMouse()

if type(_G.__UniversalHubDispose) == "function" then
    pcall(_G.__UniversalHubDispose)
end
local old = playerGui:FindFirstChild("UniversalHub_GUI")
if old then old:Destroy() end

local C = {
    background = Color3.fromRGB(14, 18, 29),
    panel = Color3.fromRGB(24, 31, 46),
    panelLight = Color3.fromRGB(32, 41, 59),
    button = Color3.fromRGB(42, 55, 73),
    accent = Color3.fromRGB(81, 216, 194),
    text = Color3.fromRGB(241, 245, 252),
    muted = Color3.fromRGB(151, 166, 186),
    danger = Color3.fromRGB(240, 106, 114),
}

local states = {
    speed = false, jump = false, fly = false, infiniteJump = false,
    noclip = false, clickTP = false, esp = false, nameESP = false,
    fullbright = false, customFOV = false, aimAssist = false,
    follow = false, spectate = false, lowGraphics = false,
}
local values = {walkSpeed = 32, jumpPower = 85, flySpeed = 65, fov = 90}
local saved = {
    lighting = {Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows},
    terrain = {},
    baseFOV = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70,
}
local terrain = workspace:FindFirstChildOfClass("Terrain")
if terrain then
    saved.terrain.WaterWaveSize = terrain.WaterWaveSize
    saved.terrain.WaterWaveSpeed = terrain.WaterWaveSpeed
    saved.terrain.WaterReflectance = terrain.WaterReflectance
end

local connections = {}
local espRecords = {}
local colliding = setmetatable({}, {__mode = "k"})
local selectedPlayer = nil
local originalHumanoid = nil
local originalSpeed = nil
local originalJump = nil
local flyingVelocity = nil
local flyingGyro = nil
local rightMouseDown = false
local disposed = false
local lastESP = 0
local lastFollow = 0
local speedTimer = 0

local function listen(signal, fn)
    local connection = signal:Connect(fn)
    table.insert(connections, connection)
    return connection
end

local function new(class, props, parent)
    local obj = Instance.new(class)
    for name, value in pairs(props or {}) do obj[name] = value end
    obj.Parent = parent
    return obj
end

local function rounded(ui, radius)
    new("UICorner", {CornerRadius = UDim.new(0, radius or 9)}, ui)
end

local function outline(ui, color, thickness)
    new("UIStroke", {Color = color or C.button, Thickness = thickness or 1}, ui)
end

local function label(parent, text, size, color, weight, props)
    local base = {
        Text = text, TextSize = size or 14, TextColor3 = color or C.text,
        Font = weight or Enum.Font.Gotham, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }
    for k,v in pairs(props or {}) do base[k] = v end
    return new("TextLabel", base, parent)
end

local function getCharacter()
    local character = localPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return character, humanoid, root
end

local function getSelected()
    if not selectedPlayer or selectedPlayer.Parent ~= Players then return nil, nil, nil end
    local character = selectedPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return character, humanoid, root
end

local gui = new("ScreenGui", {
    Name = "UniversalHub_GUI", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = false,
}, playerGui)

local main = new("Frame", {
    Name = "Main", Size = UDim2.fromOffset(705, 468),
    Position = UDim2.new(0.5, -352, 0.5, -234),
    BackgroundColor3 = C.background, BorderSizePixel = 0,
    Active = true,
}, gui)
rounded(main, 14)
outline(main, C.panelLight)

local header = new("Frame", {
    Size = UDim2.new(1, 0, 0, 66), BackgroundTransparency = 1,
    Active = true,
}, main)
label(header, "UNIVERSAL  /  HUB", 21, C.text, Enum.Font.GothamBold, {
    Position = UDim2.fromOffset(22, 10), Size = UDim2.fromOffset(440, 29),
})
label(header, "로블록스 개인 테스트용 · 클라이언트 기능", 12, C.muted, Enum.Font.Gotham, {
    Position = UDim2.fromOffset(23, 37), Size = UDim2.fromOffset(500, 20),
})

local function headerButton(textValue, xOffset, color)
    local b = new("TextButton", {
        Position = UDim2.new(1, xOffset, 0, 15), Size = UDim2.fromOffset(35, 35),
        Text = textValue, TextColor3 = C.text, TextSize = 18,
        Font = Enum.Font.GothamBold, AutoButtonColor = true,
        BackgroundColor3 = color, BorderSizePixel = 0,
    }, header)
    rounded(b, 8)
    return b
end

local minimizeButton = headerButton("−", -84, C.button)
local closeButton = headerButton("×", -43, C.danger)

local divider = new("Frame", {Position = UDim2.fromOffset(0, 65),
    Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.panelLight,
    BorderSizePixel = 0}, main)

local sidebar = new("Frame", {
    Position = UDim2.fromOffset(13, 80), Size = UDim2.fromOffset(168, 324),
    BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, main)
rounded(sidebar, 10)
new("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8),
    PaddingRight = UDim.new(0, 8)}, sidebar)
new("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, sidebar)

local content = new("Frame", {
    Position = UDim2.fromOffset(194, 80), Size = UDim2.fromOffset(498, 324),
    BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, main)
rounded(content, 10)

local status = label(main, "준비 완료 · 우측 Shift 키로 창 숨기기/표시", 12,
    C.muted, Enum.Font.Gotham, {Position = UDim2.fromOffset(21, 425),
    Size = UDim2.fromOffset(664, 25)})
local function notice(message)
    if not disposed and status then status.Text = message end
end

local restoreButton = new("TextButton", {
    Text = "☰ HUB", Size = UDim2.fromOffset(97, 39),
    Position = UDim2.fromOffset(15, 112),
    BackgroundColor3 = C.accent, TextColor3 = C.background,
    Font = Enum.Font.GothamBold, TextSize = 14,
    Visible = false, BorderSizePixel = 0,
}, gui)
rounded(restoreButton, 9)

local pages = {}
local navButtons = {}
local currentPage

local function selectPage(name)
    currentPage = name
    for key, page in pairs(pages) do page.Visible = (key == name) end
    for key, button in pairs(navButtons) do
        button.BackgroundColor3 = (key == name) and C.accent or C.panelLight
        button.TextColor3 = (key == name) and C.background or C.text
    end
end

local function addPage(name)
    local nav = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.panelLight,
        TextColor3 = C.text, Text = name, Font = Enum.Font.GothamSemibold,
        TextSize = 13, BorderSizePixel = 0,
    }, sidebar)
    rounded(nav, 8)
    local page = new("ScrollingFrame", {
        Name = name, Position = UDim2.fromOffset(7, 7),
        Size = UDim2.new(1, -14, 1, -14),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 4, ScrollBarImageColor3 = C.accent,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, content)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8)}, page)
    new("UIPadding", {PaddingRight = UDim.new(0, 7),
        PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 10)}, page)
    pages[name] = page
    navButtons[name] = nav
    listen(nav.MouseButton1Click, function() selectPage(name) end)
    return page
end

local home = addPage("홈")
local movement = addPage("이동")
local visuals = addPage("ESP / 화면")
local combat = addPage("조준 보조")
local people = addPage("플레이어")
local misc = addPage("기타 / 설정")

local function section(page, heading, details)
    local f = new("Frame", {Size = UDim2.new(1, -4, 0, details and 48 or 28),
        BackgroundTransparency = 1}, page)
    label(f, heading, 17, C.text, Enum.Font.GothamBold,
        {Position = UDim2.fromOffset(3, 0), Size = UDim2.new(1, -5, 0, 26)})
    if details then
        label(f, details, 12, C.muted, Enum.Font.Gotham,
            {Position = UDim2.fromOffset(3, 26), Size = UDim2.new(1, -7, 0, 20)})
    end
end

local function info(page, title, description)
    local f = new("Frame", {Size = UDim2.new(1, -4, 0, 67),
        BackgroundColor3 = C.panelLight, BorderSizePixel = 0}, page)
    rounded(f, 8)
    label(f, title, 14, C.text, Enum.Font.GothamSemibold,
        {Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 24)})
    label(f, description, 11, C.muted, Enum.Font.Gotham,
        {Position = UDim2.fromOffset(12, 33), Size = UDim2.new(1, -24, 0, 25),
        TextWrapped = true})
end

local function addToggle(page, title, description, stateKey, change)
    local f = new("Frame", {Size = UDim2.new(1, -4, 0, 65),
        BackgroundColor3 = C.panelLight, BorderSizePixel = 0}, page)
    rounded(f, 8)
    label(f, title, 14, C.text, Enum.Font.GothamSemibold,
        {Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -112, 0, 24)})
    label(f, description, 11, C.muted, Enum.Font.Gotham,
        {Position = UDim2.fromOffset(12, 33), Size = UDim2.new(1, -112, 0, 23),
        TextWrapped = true})
    local b = new("TextButton", {
        Position = UDim2.new(1, -92, 0.5, -16), Size = UDim2.fromOffset(80, 32),
        Font = Enum.Font.GothamBold, TextSize = 12,
        BorderSizePixel = 0, AutoButtonColor = true,
    }, f)
    rounded(b, 7)
    local function redraw()
        b.Text = states[stateKey] and "켜짐" or "꺼짐"
        b.BackgroundColor3 = states[stateKey] and C.accent or C.button
        b.TextColor3 = states[stateKey] and C.background or C.text
    end
    redraw()
    listen(b.MouseButton1Click, function()
        states[stateKey] = not states[stateKey]
        if change then
            local ok, err = pcall(change, states[stateKey])
            if not ok then
                states[stateKey] = not states[stateKey]
                notice("오류: " .. tostring(err):sub(1, 70))
            end
        end
        redraw()
    end)
    return redraw
end

local function addAction(page, textValue, description, callback)
    local f = new("Frame", {Size = UDim2.new(1, -4, 0, 59),
        BackgroundColor3 = C.panelLight, BorderSizePixel = 0}, page)
    rounded(f, 8)
    local b = new("TextButton", {Text = textValue,
        Position = UDim2.fromOffset(11, 10), Size = UDim2.fromOffset(144, 37),
        BackgroundColor3 = C.button, TextColor3 = C.text,
        Font = Enum.Font.GothamSemibold, TextSize = 12,
        BorderSizePixel = 0}, f)
    rounded(b, 7)
    label(f, description, 11, C.muted, Enum.Font.Gotham,
        {Position = UDim2.fromOffset(167, 7), Size = UDim2.new(1, -181, 1, -13),
        TextWrapped = true})
    listen(b.MouseButton1Click, function()
        local ok, err = pcall(callback)
        if not ok then notice("오류: " .. tostring(err):sub(1, 70)) end
    end)
    return b
end

local function addStepper(page, title, description, key, step, minimum, maximum)
    local f = new("Frame", {Size = UDim2.new(1, -4, 0, 64),
        BackgroundColor3 = C.panelLight, BorderSizePixel = 0}, page)
    rounded(f, 8)
    label(f, title, 13, C.text, Enum.Font.GothamSemibold,
        {Position = UDim2.fromOffset(11, 6), Size = UDim2.new(1, -180, 0, 26)})
    label(f, description, 11, C.muted, Enum.Font.Gotham,
        {Position = UDim2.fromOffset(11, 32), Size = UDim2.new(1, -180, 0, 22)})
    local less = new("TextButton", {Text = "−", TextSize = 18,
        Font = Enum.Font.GothamBold, TextColor3 = C.text,
        Position = UDim2.new(1, -155, 0.5, -16), Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = C.button, BorderSizePixel = 0}, f)
    local valueText = label(f, tostring(values[key]), 14, C.accent, Enum.Font.GothamBold,
        {Position = UDim2.new(1, -116, 0.5, -17), Size = UDim2.fromOffset(70, 34),
        TextXAlignment = Enum.TextXAlignment.Center})
    local more = new("TextButton", {Text = "+", TextSize = 18,
        Font = Enum.Font.GothamBold, TextColor3 = C.text,
        Position = UDim2.new(1, -41, 0.5, -16), Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = C.button, BorderSizePixel = 0}, f)
    rounded(less, 6)
    rounded(more, 6)
    listen(less.MouseButton1Click, function()
        values[key] = math.max(minimum, values[key] - step)
        valueText.Text = tostring(values[key])
    end)
    listen(more.MouseButton1Click, function()
        values[key] = math.min(maximum, values[key] + step)
        valueText.Text = tostring(values[key])
    end)
end

-- Character modifiers -------------------------------------------------------
local function trackHumanoid()
    local _, hum = getCharacter()
    if hum and hum ~= originalHumanoid then
        originalHumanoid = hum
        originalSpeed = hum.WalkSpeed
        originalJump = hum.JumpPower
    end
    return hum
end

local function stopFly()
    if flyingVelocity then flyingVelocity:Destroy(); flyingVelocity = nil end
    if flyingGyro then flyingGyro:Destroy(); flyingGyro = nil end
    local _, hum = getCharacter()
    if hum then hum.PlatformStand = false end
end

local function startFly()
    stopFly()
    local _, hum, root = getCharacter()
    if not hum or not root then
        states.fly = false
        notice("캐릭터를 찾을 수 없습니다")
        return
    end
    flyingVelocity = new("BodyVelocity", {
        Name = "UniversalHub_FlyVelocity", MaxForce = Vector3.new(1e8, 1e8, 1e8),
        P = 10000, Velocity = Vector3.zero,
    }, root)
    flyingGyro = new("BodyGyro", {
        Name = "UniversalHub_FlyGyro", MaxTorque = Vector3.new(1e8, 1e8, 1e8),
        P = 10000, CFrame = root.CFrame,
    }, root)
    hum.PlatformStand = true
    notice("비행: WASD 이동 / Space 상승 / 왼쪽 Ctrl 하강")
end

local function restoreCollisions()
    for part, oldCollision in pairs(colliding) do
        if part and part.Parent then
            pcall(function() part.CanCollide = oldCollision end)
        end
        colliding[part] = nil
    end
end

-- Visual modifiers ---------------------------------------------------------
local function setFullbright(on)
    if on then
        Lighting.Ambient = Color3.fromRGB(220, 220, 220)
        Lighting.OutdoorAmbient = Color3.fromRGB(220, 220, 220)
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
    else
        for property, value in pairs(saved.lighting) do
            if property ~= "GlobalShadows" then
                pcall(function() Lighting[property] = value end)
            end
        end
        if states.lowGraphics then Lighting.GlobalShadows = false end
    end
end

local function setLowGraphics(on)
    if on then
        Lighting.GlobalShadows = false
        if terrain then
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
        end
    else
        Lighting.GlobalShadows = saved.lighting.GlobalShadows
        if terrain then
            for property, value in pairs(saved.terrain) do
                pcall(function() terrain[property] = value end)
            end
        end
    end
end

local function clearESP(player)
    local record = espRecords[player]
    if not record then return end
    if record.highlight then record.highlight:Destroy() end
    if record.nameTag then record.nameTag:Destroy() end
    espRecords[player] = nil
end

local function updateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local character = player.Character
            local hum = character and character:FindFirstChildOfClass("Humanoid")
            local head = character and character:FindFirstChild("Head")
            local active = character and hum and hum.Health > 0 and head
            local record = espRecords[player]
            if record and record.character ~= character then
                clearESP(player)
                record = nil
            end
            if active and (states.esp or states.nameESP) then
                if not record then
                    record = {character = character}
                    espRecords[player] = record
                end
                if states.esp and not record.highlight then
                    record.highlight = new("Highlight", {
                        Name = "UniversalHub_LocalESP", Adornee = character,
                        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                        FillColor = C.accent, FillTransparency = 0.7,
                        OutlineColor = C.accent, OutlineTransparency = 0,
                    }, character)
                elseif not states.esp and record.highlight then
                    record.highlight:Destroy()
                    record.highlight = nil
                end
                if states.nameESP and not record.nameTag then
                    local billboard = new("BillboardGui", {
                        Name = "UniversalHub_NameESP", Adornee = head,
                        Size = UDim2.fromOffset(220, 46),
                        StudsOffset = Vector3.new(0, 2.3, 0),
                        AlwaysOnTop = true, MaxDistance = 10000,
                    }, playerGui)
                    record.nameTag = billboard
                    record.text = label(billboard, "", 13, C.text,
                        Enum.Font.GothamBold, {Size = UDim2.fromScale(1, 1),
                        TextXAlignment = Enum.TextXAlignment.Center,
                        TextStrokeTransparency = 0.15})
                elseif not states.nameESP and record.nameTag then
                    record.nameTag:Destroy()
                    record.nameTag = nil
                    record.text = nil
                end
                if record.text then
                    local _, _, myRoot = getCharacter()
                    local theirRoot = character:FindFirstChild("HumanoidRootPart")
                    local distance = myRoot and theirRoot and
                        math.floor((myRoot.Position - theirRoot.Position).Magnitude) or 0
                    record.text.Text = string.format("%s · %d HP · %d studs",
                        player.DisplayName, math.floor(hum.Health), distance)
                end
            else
                clearESP(player)
            end
        end
    end
end

-- Page controls ------------------------------------------------------------
section(home, "종합 유틸리티 허브", "현재 게임의 내 캐릭터와 화면에 적용되는 테스트 기능")
info(home, "핵심 기능", "Speed · Fly · Noclip · 무한 점프 · ESP · Fullbright · 시점/카메라 설정")
info(home, "조작", "좌측 탭에서 기능을 켜거나 끄세요. 오른쪽 Shift 키로 UI를 표시/숨깁니다.")
info(home, "제한 사항", "게임 서버에서 검증하는 체력·아이템·타 플레이어 위치는 이 스크립트로 변경할 수 없습니다.")

section(movement, "이동 기능")
addToggle(movement, "Speed", "내 캐릭터의 걷기 속도 변경", "speed", function(on)
    local hum = trackHumanoid()
    if hum then hum.WalkSpeed = on and values.walkSpeed or (originalSpeed or 16) end
end)
addStepper(movement, "걷기 속도", "Speed 활성화 시 적용", "walkSpeed", 4, 8, 100)
addToggle(movement, "Jump Power", "점프 높이 조절", "jump", function(on)
    local hum = trackHumanoid()
    if hum then
        hum.UseJumpPower = true
        hum.JumpPower = on and values.jumpPower or (originalJump or 50)
    end
end)
addStepper(movement, "점프 파워", "Jump Power 활성화 시 적용", "jumpPower", 5, 30, 160)
addToggle(movement, "Fly", "WASD + Space / 왼쪽 Ctrl", "fly", function(on)
    if on then startFly() else stopFly() end
end)
addStepper(movement, "비행 속도", "Fly 활성화 시 적용", "flySpeed", 10, 15, 165)
addToggle(movement, "Infinite Jump", "공중에서 점프 키를 다시 눌러 점프", "infiniteJump")
addToggle(movement, "Noclip", "내 캐릭터의 충돌 비활성화", "noclip", function(on)
    if not on then restoreCollisions() end
end)
addToggle(movement, "Alt + 클릭 순간이동", "Alt를 누른 채 바닥을 마우스로 클릭", "clickTP")

section(visuals, "ESP / 화면 변경")
addToggle(visuals, "Player Highlight ESP", "다른 플레이어 캐릭터 윤곽선 표시", "esp", function()
    updateESP()
end)
addToggle(visuals, "Name · HP · Distance ESP", "머리 위 이름, 체력, 거리 표시", "nameESP", function()
    updateESP()
end)
addToggle(visuals, "Fullbright", "밝기와 안개 변경", "fullbright", setFullbright)
addToggle(visuals, "Custom FOV", "카메라 시야각 직접 설정", "customFOV", function(on)
    local cam = workspace.CurrentCamera
    if cam then cam.FieldOfView = on and values.fov or saved.baseFOV end
end)
addStepper(visuals, "시야각 FOV", "Custom FOV 활성화 시 적용", "fov", 5, 45, 120)

section(combat, "카메라 조준 보조", "개인 테스트용 카메라 조작 · 게임의 발사/피격 판정은 변경하지 않음")
addToggle(combat, "Aim Assist", "우클릭 중 화면 중앙의 가까운 상대를 향해 카메라 회전", "aimAssist")
info(combat, "적용 범위", "타 플레이어가 화면에 보이고 시야가 가려지지 않았을 때만 동작합니다. 무기 자동 발사, 탄환 판정 조작, 서버 권한 변경은 포함되지 않습니다.")

section(people, "플레이어 선택", "아래 목록에서 원하는 플레이어를 선택하세요")
local chosenText = nil
chosenText = label(people, "선택된 플레이어: 없음", 13, C.accent, Enum.Font.GothamSemibold,
    {Size = UDim2.new(1, -4, 0, 28)})
local playerPicker = new("ScrollingFrame", {
    Size = UDim2.new(1, -4, 0, 120), BackgroundColor3 = C.panelLight,
    BorderSizePixel = 0, ScrollBarThickness = 4,
    CanvasSize = UDim2.fromOffset(0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, people)
rounded(playerPicker, 8)
new("UIPadding", {PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7),
    PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7)}, playerPicker)
new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 5)}, playerPicker)

local function refreshPlayers()
    for _, child in ipairs(playerPicker:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local count = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            count = count + 1
            local name = player.DisplayName .. "  (@" .. player.Name .. ")"
            local b = new("TextButton", {
                Size = UDim2.new(1, 0, 0, 27), Text = name,
                BackgroundColor3 = C.button, BorderSizePixel = 0,
                TextColor3 = C.text, TextSize = 12, Font = Enum.Font.Gotham,
            }, playerPicker)
            rounded(b, 5)
            listen(b.MouseButton1Click, function()
                selectedPlayer = player
                chosenText.Text = "선택된 플레이어: " .. player.Name
                notice("선택: " .. player.Name)
            end)
        end
    end
    if count == 0 then
        local message = label(playerPicker, "다른 플레이어가 없습니다.", 12, C.muted,
            Enum.Font.Gotham, {Size = UDim2.new(1, 0, 0, 29),
            TextXAlignment = Enum.TextXAlignment.Center})
        -- Remove message during the next refresh.
        message.Name = "EmptyPlayers"
    end
end
addAction(people, "플레이어 새로고침", "현재 서버의 플레이어 목록 갱신", function()
    local empty = playerPicker:FindFirstChild("EmptyPlayers")
    if empty then empty:Destroy() end
    refreshPlayers()
end)
addAction(people, "선택 유저로 이동", "내 캐릭터를 선택한 플레이어 근처로 이동", function()
    local _, _, targetRoot = getSelected()
    local _, _, ownRoot = getCharacter()
    if not targetRoot or not ownRoot then notice("플레이어를 먼저 선택하세요") return end
    ownRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 5)
end)
addToggle(people, "Spectate", "선택한 플레이어 시점 관전", "spectate", function(on)
    local camera = workspace.CurrentCamera
    if not camera then return end
    if on then
        local _, humanoid = getSelected()
        if not humanoid then error("플레이어를 먼저 선택하세요") end
        camera.CameraSubject = humanoid
    else
        local _, humanoid = getCharacter()
        if humanoid then camera.CameraSubject = humanoid end
    end
end)
addToggle(people, "Follow Player", "선택한 플레이어를 내 캐릭터가 따라가기", "follow", function(on)
    if on and not getSelected() then
        error("플레이어를 먼저 선택하세요")
    end
end)

section(misc, "성능 / 관리")
addToggle(misc, "Low Graphics", "그림자 및 물 효과 감소", "lowGraphics", setLowGraphics)
addAction(misc, "카메라 초기화", "관전 종료 및 기본 시점으로 복귀", function()
    states.spectate = false
    local _, hum = getCharacter()
    if hum and workspace.CurrentCamera then
        workspace.CurrentCamera.CameraSubject = hum
        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    end
    notice("카메라를 초기화했습니다")
end)
addAction(misc, "서버 재접속", "현재 게임 재접속 (Studio에서는 작동하지 않을 수 있음)", function()
    TeleportService:Teleport(game.PlaceId, localPlayer)
end)
addAction(misc, "캐릭터 리셋", "내 캐릭터만 리스폰", function()
    local _, hum = getCharacter()
    if hum then hum.Health = 0 end
end)
addAction(misc, "UI 숨기기", "오른쪽 Shift로 다시 열 수 있음", function()
    main.Visible = false
    restoreButton.Visible = true
end)

selectPage("홈")
refreshPlayers()

-- Live updates -------------------------------------------------------------
listen(UserInputService.InputBegan, function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        rightMouseDown = true
    end
    if input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
        restoreButton.Visible = not main.Visible
    end
    if gameProcessed then return end
    if states.clickTP and (input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt) then
        -- Alt state is checked when the mouse is clicked.
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and states.clickTP then
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or
            UserInputService:IsKeyDown(Enum.KeyCode.RightAlt) then
            local _, _, root = getCharacter()
            if root and mouse.Target then
                root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 4, 0))
            end
        end
    end
end)
listen(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        rightMouseDown = false
    end
end)
listen(UserInputService.JumpRequest, function()
    if states.infiniteJump then
        local _, hum = getCharacter()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)
listen(RunService.Stepped, function()
    if states.noclip then
        local char = localPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    if colliding[part] == nil then colliding[part] = part.CanCollide end
                    part.CanCollide = false
                end
            end
        end
    end
end)
listen(RunService.Heartbeat, function(dt)
    speedTimer = speedTimer + dt
    if speedTimer >= 0.12 then
        speedTimer = 0
        local hum = trackHumanoid()
        if hum then
            if states.speed then hum.WalkSpeed = values.walkSpeed end
            if states.jump then
                hum.UseJumpPower = true
                hum.JumpPower = values.jumpPower
            end
        end
    end
    lastESP = lastESP + dt
    if lastESP >= 0.27 then
        lastESP = 0
        if states.esp or states.nameESP then updateESP() end
    end
    lastFollow = lastFollow + dt
    if lastFollow >= 0.2 and states.follow then
        lastFollow = 0
        local _, hum = getCharacter()
        local _, _, root = getSelected()
        if hum and root then
            hum:MoveTo(root.Position - root.CFrame.LookVector * 4)
        end
    end
end)
listen(RunService.RenderStepped, function()
    local camera = workspace.CurrentCamera
    if not camera then return end
    if states.customFOV then camera.FieldOfView = values.fov end
    if flyingVelocity and flyingGyro and states.fly then
        local _, hum, root = getCharacter()
        if not hum or not root then
            states.fly = false
            stopFly()
            return
        end
        hum.PlatformStand = true
        local x, y, z = 0, 0, 0
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then z = z + 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then z = z - 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then x = x - 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then x = x + 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then y = y + 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then y = y - 1 end
        local look = camera.CFrame.LookVector
        local right = camera.CFrame.RightVector
        local flatLook = Vector3.new(look.X, 0, look.Z)
        local flatRight = Vector3.new(right.X, 0, right.Z)
        if flatLook.Magnitude > 0 then flatLook = flatLook.Unit end
        if flatRight.Magnitude > 0 then flatRight = flatRight.Unit end
        local dir = flatLook * z + flatRight * x + Vector3.new(0, y, 0)
        flyingVelocity.Velocity = dir.Magnitude > 0 and dir.Unit * values.flySpeed or Vector3.zero
        flyingGyro.CFrame = CFrame.lookAt(root.Position, root.Position + camera.CFrame.LookVector)
    end
end)

local function aiming()
    if not states.aimAssist or not rightMouseDown then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local view = camera.ViewportSize
    local center = Vector2.new(view.X / 2, view.Y / 2)
    local _, _, myRoot = getCharacter()
    if not myRoot then return end
    local chosenPart = nil
    local smallest = 220
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and
            (not localPlayer.Team or not player.Team or localPlayer.Team ~= player.Team) then
            local character = player.Character
            local hum = character and character:FindFirstChildOfClass("Humanoid")
            local head = character and character:FindFirstChild("Head")
            if hum and hum.Health > 0 and head then
                local point, visible = camera:WorldToViewportPoint(head.Position)
                if visible and point.Z > 0 then
                    local delta = (Vector2.new(point.X, point.Y) - center).Magnitude
                    if delta < smallest then
                        local rayParams = RaycastParams.new()
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                        rayParams.FilterDescendantsInstances = {localPlayer.Character}
                        local origin = camera.CFrame.Position
                        local result = workspace:Raycast(origin, head.Position - origin, rayParams)
                        if result and result.Instance:IsDescendantOf(character) then
                            chosenPart = head
                            smallest = delta
                        end
                    end
                end
            end
        end
    end
    if chosenPart then
        camera.CFrame = camera.CFrame:Lerp(
            CFrame.lookAt(camera.CFrame.Position, chosenPart.Position), 0.20)
    end
end
RunService:BindToRenderStep("UniversalHub_LocalAimAssist", Enum.RenderPriority.Camera.Value + 2, aiming)

listen(localPlayer.CharacterAdded, function()
    stopFly()
    restoreCollisions()
    originalHumanoid = nil
    task.delay(0.75, function()
        if disposed then return end
        trackHumanoid()
        if states.fly then startFly() end
        if states.spectate then
            local _, hum = getSelected()
            if hum and workspace.CurrentCamera then
                workspace.CurrentCamera.CameraSubject = hum
            end
        end
    end)
end)
listen(Players.PlayerRemoving, function(player)
    clearESP(player)
    if selectedPlayer == player then
        selectedPlayer = nil
        chosenText.Text = "선택된 플레이어: 없음"
        states.follow = false
        states.spectate = false
        local _, hum = getCharacter()
        if hum and workspace.CurrentCamera then
            workspace.CurrentCamera.CameraSubject = hum
        end
    end
end)

-- Draggable window ---------------------------------------------------------
local dragging = false
local dragStart = Vector2.zero
local startPosition = main.Position
listen(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
        input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = main.Position
    end
end)
listen(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
        input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
listen(UserInputService.InputChanged, function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
        input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end
end)

local function dispose()
    if disposed then return end
    states.fly = false
    states.follow = false
    states.aimAssist = false
    stopFly()
    restoreCollisions()
    for player in pairs(espRecords) do clearESP(player) end
    if originalHumanoid and originalHumanoid.Parent then
        pcall(function()
            if originalSpeed then originalHumanoid.WalkSpeed = originalSpeed end
            if originalJump then originalHumanoid.JumpPower = originalJump end
        end)
    end
    states.lowGraphics = false
    states.fullbright = false
    setLowGraphics(false)
    setFullbright(false)
    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = saved.baseFOV
        local _, hum = getCharacter()
        if hum then workspace.CurrentCamera.CameraSubject = hum end
    end
    RunService:UnbindFromRenderStep("UniversalHub_LocalAimAssist")
    disposed = true
    for _, connection in ipairs(connections) do connection:Disconnect() end
    if gui and gui.Parent then gui:Destroy() end
    if _G.__UniversalHubDispose == dispose then _G.__UniversalHubDispose = nil end
end
_G.__UniversalHubDispose = dispose
listen(minimizeButton.MouseButton1Click, function()
    main.Visible = false
    restoreButton.Visible = true
end)
listen(restoreButton.MouseButton1Click, function()
    main.Visible = true
    restoreButton.Visible = false
end)
listen(closeButton.MouseButton1Click, dispose)

notice("준비 완료 · 우측 Shift로 UI 숨기기/표시 · X로 종료 및 복원")
