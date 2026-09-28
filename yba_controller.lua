-- ============================================================
-- YBA Controller v6.1 (ESP + AutoFarm + AutoSell)
-- ============================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local TARGET_ITEMS = {
    "Rokakaka", "Lucky Arrow", "Caesar's Headband", "Clackers",
    "Ancient Scroll", "Diamond", "Dio's Diary", "Gold Coin",
    "Lucky Stone Mask", "Mysterious Arrow", "Pure Rokakaka",
    "Quinton's Glove", "Rib Cage of The Saint's Corpse",
    "Steel Ball", "Stone Mask", "Zeppeli's Hat",
}

local State = {
    ESP = true,
    AutoFarm = false,
    AutoSell = false,
    Noclip = false,
    Speed = false,
    FlySpeed = 80,
    PickupRange = 5,
    WalkSpeed = 30,
}

-- ============================================================
-- ESP
-- ============================================================
local espObjects = {}

local function createESP(part, itemName)
    if not part or espObjects[part] then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "YBA_ItemESP"
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = part
    billboard.Parent = part

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = itemName
    textLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    textLabel.TextStrokeTransparency = 0
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.Parent = billboard
    espObjects[part] = billboard
end

local function clearAllESP()
    for _, gui in pairs(espObjects) do
        if gui and gui.Parent then gui:Destroy() end
    end
    espObjects = {}
end

-- Функция поиска валидных предметов (игнорируем фантомы в Workspace)
local function getValidItems()
    local validItems = {}
    local itemsFolder = Workspace:FindFirstChild("Item_Spawns")
    if not itemsFolder then return validItems end
    local items = itemsFolder:FindFirstChild("Items")
    if not items then return validItems end

    for _, model in ipairs(items:GetChildren()) do
        if model:IsA("Model") then
            local prompt = model:FindFirstChildOfClass("ProximityPrompt")
            if prompt and prompt.ActionText == "Pick Up" then
                local itemName = prompt.ObjectText
                local mesh = model:FindFirstChildOfClass("MeshPart") or model:FindFirstChildOfClass("BasePart")
                -- Проверяем, что предмет не прозрачный (не фантом)
                if mesh and mesh.Transparency < 1 then
                    table.insert(validItems, {model = model, prompt = prompt, mesh = mesh, name = itemName})
                end
            end
        end
    end
    return validItems
end

local function scanForItems()
    if not State.ESP then return end
    local items = getValidItems()
    for _, data in ipairs(items) do
        for _, targetName in ipairs(TARGET_ITEMS) do
            if string.find(data.name:lower(), targetName:lower(), 1, true) then
                createESP(data.mesh, data.name)
                break
            end
        end
    end
end

local function cleanupESP()
    for part, gui in pairs(espObjects) do
        if not part or not part.Parent or part.Transparency >= 1 then
            gui:Destroy()
            espObjects[part] = nil
        end
    end
end

-- ============================================================
-- AUTOFARM
-- ============================================================
local function findNearestItem()
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local nearest, minDist = nil, math.huge
    local items = getValidItems()
    for _, data in ipairs(items) do
        for _, targetName in ipairs(TARGET_ITEMS) do
            if string.find(data.name:lower(), targetName:lower(), 1, true) then
                local dist = (data.mesh.Position - root.Position).Magnitude
                if dist < minDist then
                    nearest, minDist = data, dist
                end
                break
            end
        end
    end
    return nearest
end

local flyConnection = nil
local cachedTarget = nil
local lastScanTime = 0

local function startAutoFarm()
    if flyConnection then return end
    flyConnection = RunService.Heartbeat:Connect(function(dt)
        if not State.AutoFarm then return end
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local now = tick()
        if now - lastScanTime > 0.5 or not cachedTarget or not cachedTarget.mesh.Parent then
            cachedTarget = findNearestItem()
            lastScanTime = now
        end

        local target = cachedTarget
        if not target then return end

        local targetPos = target.mesh.Position
        local dist = (targetPos - root.Position).Magnitude

        if dist <= State.PickupRange then
            root.AssemblyLinearVelocity = Vector3.zero
            if fireproximityprompt then
                pcall(function() fireproximityprompt(target.prompt) end)
                print("[AutoFarm] Подобрал: " .. target.name)
            end
            cachedTarget = nil
            lastScanTime = 0
            return
        end

        local dir = targetPos - root.Position
        local step = math.min(State.FlySpeed * dt, dist - (State.PickupRange - 0.5))
        if step > 0 then
            local newPos = root.Position + dir.Unit * step
            root.CFrame = CFrame.new(newPos, newPos + dir.Unit)
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end)
end

local function stopAutoFarm()
    if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
    cachedTarget = nil
    lastScanTime = 0
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then root.AssemblyLinearVelocity = Vector3.zero end
    end
end

-- ============================================================
-- AUTOSELL (НОВОЕ!)
-- ============================================================
local function autoSellItems()
    if not State.AutoSell then return end

    -- 1. Проверяем, есть ли предметы в инвентаре (Backpack)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local hasItems = false
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then -- В YBA предметы в инвентаре - это Tool
                hasItems = true
                break
            end
        end
    end
    if not hasItems then return end -- Если нечего продавать, выходим

    -- 2. Ищем кнопку "I'll sell ALL of these." в интерфейсе
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    for _, gui in ipairs(playerGui:GetChildren()) do
        for _, obj in ipairs(gui:GetDescendants()) do
            if obj:IsA("TextButton") and obj.Text then
                local btnText = obj.Text:lower()
                -- Ищем кнопку, где есть слова "sell" и "all"
                if btnText:find("sell") and btnText:find("all") then
                    -- Нажимаем на кнопку
                    obj:Fire("MouseButton1Click")
                    print("[AutoSell] Нажал кнопку продажи: " .. obj.Text)
                    task.wait(1) -- Задержка, чтобы сервер успел обработать
                    return
                end
            end
        end
    end
end

-- ============================================================
-- NOCLIP & SPEED
-- ============================================================
local noclipConnection = nil
local function applyNoclip()
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
    end
end

local function startNoclip()
    if noclipConnection then return end
    noclipConnection = RunService.Stepped:Connect(function()
        if State.Noclip then pcall(applyNoclip) end
    end)
end

local function stopNoclip()
    if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
end

local function applySpeed()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = State.Speed and State.WalkSpeed or 16 end
end

-- ============================================================
-- ЦИКЛЫ
-- ============================================================
task.spawn(function()
    while task.wait(3) do
        if State.ESP then pcall(scanForItems); pcall(cleanupESP) end
    end
end)

task.spawn(function()
    while task.wait(2) do -- Проверка автопродажи каждые 2 секунды
        pcall(autoSellItems)
    end
end)

-- ============================================================
-- ПРОСТОЙ GUI
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local function createBtn(text, y, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 180, 0, 36)
    btn.Position = UDim2.new(0, 20, 0, y)
    btn.BackgroundColor3 = color
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 14
    btn.Parent = ScreenGui
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local btnESP = createBtn("ESP: ВКЛ", 100, Color3.fromRGB(40, 40, 55), function()
    State.ESP = not State.ESP
    btnESP.Text = "ESP: " .. (State.ESP and "ВКЛ" or "ВЫКЛ")
    if not State.ESP then clearAllESP() end
end)

local btnFarm = createBtn("AutoFarm: ВЫКЛ", 140, Color3.fromRGB(60, 40, 40), function()
    State.AutoFarm = not State.AutoFarm
    btnFarm.Text = "AutoFarm: " .. (State.AutoFarm and "ВКЛ" or "ВЫКЛ")
    if State.AutoFarm then
        if not State.Noclip then State.Noclip = true; startNoclip() end
        startAutoFarm()
    else
        stopAutoFarm()
    end
end)

local btnSell = createBtn("AutoSell: ВЫКЛ", 180, Color3.fromRGB(40, 60, 40), function()
    State.AutoSell = not State.AutoSell
    btnSell.Text = "AutoSell: " .. (State.AutoSell and "ВКЛ" or "ВЫКЛ")
end)

local btnNoclip = createBtn("Noclip: ВЫКЛ", 220, Color3.fromRGB(40, 40, 60), function()
    State.Noclip = not State.Noclip
    btnNoclip.Text = "Noclip: " .. (State.Noclip and "ВКЛ" or "ВЫКЛ")
    if State.Noclip then startNoclip() else stopNoclip() end
end)

local btnSpeed = createBtn("Speed: ВЫКЛ", 260, Color3.fromRGB(60, 40, 60), function()
    State.Speed = not State.Speed
    btnSpeed.Text = "Speed: " .. (State.Speed and "ВКЛ" or "ВЫКЛ")
    applySpeed()
end)

print("[YBA v6.1] Запущен. ESP, AutoFarm и AutoSell готовы.")
