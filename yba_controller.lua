-- ============================================================
-- ========== 1. ЗАГРУЗКА KAVO UI =============================
-- ============================================================
print("[YBA Controller] Загрузка v4.1 (Fixed Sell & ESP)...")
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()

-- ============================================================
-- ========== 2. НАСТРОЙКИ И СОСТОЯНИЕ ========================
-- ============================================================
local TARGET_ITEMS = {
    "Rokakaka",
    "Lucky Arrow",
    "Caesar's Headband",
    "Clackers",
    "Ancient Scroll",
    "Diamond",
    "Dio's Diary",
    "Gold Coin",
    "Lucky Stone Mask",
    "Mysterious Arrow",
    "Pure Rokakaka",
    "Quinton's Glove",
    "Rib Cage of The Saint's Corpse",
    "Steel Ball",
    "Stone Mask",
    "Zeppeli's Hat",
}

local LUCKY_ARROW_PRICE = 75000

local ITEM_FOLDERS = { "Items", "DroppedItems", "SpawnedItems", "Tools" }

local State = {
    ESP = true,
    AutoSell = false,
    Noclip = false,
    Speed = false,
    AutoFarm = false,
    AutoBuyLucky = false,
    WalkSpeed = 30,
    ScanInterval = 5,
    FlySpeed = 80,
    PickupRange = 5,
}

-- ============================================================
-- ========== 3. СЕРВИСЫ ======================================
-- ============================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local VirtualInputManager = nil
pcall(function()
    VirtualInputManager = game:GetService("VirtualInputManager")
end)

-- ============================================================
-- ========== 4. ФИЛЬТР ПРЕДМЕТОВ (ОСЛАБЛЕН) ==================
-- ============================================================
local function isValidItem(obj)
    if not obj then return false end
    if obj:IsA("Tool") then return true end
    if obj:IsA("BasePart") then
        if obj.Size.Magnitude > 50 then return false end
        return true
    end
    if obj:IsA("Model") then
        if obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart") then
            return true
        end
    end
    return false
end

-- ============================================================
-- ========== 5. ПРОВЕРКА БАЛАНСА =============================
-- ============================================================
local function getPlayerMoney()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local cash = leaderstats:FindFirstChild("Cash") or leaderstats:FindFirstChild("Money")
        if cash and cash:IsA("IntValue") then return cash.Value end
    end
    local attr = LocalPlayer:GetAttribute("Money") or LocalPlayer:GetAttribute("Cash")
    if typeof(attr) == "number" then return attr end
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local currency = playerGui:FindFirstChild("Currency")
        if currency then
            local moneyLabel = currency:FindFirstChild("Money")
            if moneyLabel and moneyLabel:IsA("TextLabel") then
                local num = tonumber(moneyLabel.Text:gsub("[^%d]", ""))
                if num then return num end
            end
            local moneyVal = currency:FindFirstChild("Money")
            if moneyVal and moneyVal:IsA("IntValue") then return moneyVal.Value end
        end
    end
    local char = LocalPlayer.Character
    if char then
        local stats = char:FindFirstChild("Stats")
        if stats then
            local money = stats:FindFirstChild("Money") or stats:FindFirstChild("Cash")
            if money and money:IsA("IntValue") then return money.Value end
        end
    end
    return nil
end

-- ============================================================
-- ========== 6. ОТЛАДКА ======================================
-- ============================================================
local function debugNearbyObjects()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    print("=== Объекты в радиусе 50 studs ===")
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj:IsA("BasePart") or obj:IsA("Model")) and obj ~= char then
            local pos = nil
            if obj:IsA("BasePart") then pos = obj.Position
            elseif obj:IsA("Model") and obj.PrimaryPart then pos = obj.PrimaryPart.Position end
            if pos and (pos - root.Position).Magnitude < 50 then
                local anchored = "N/A"
                if obj:IsA("BasePart") then anchored = tostring(obj.Anchored) end
                print(obj.ClassName, "| Имя:", obj.Name, "| Anchored:", anchored)
            end
        end
    end
    print("===================================")
end

-- ============================================================
-- ========== 7. ПОИСК ПАПКИ С ПРЕДМЕТАМИ =====================
-- ============================================================
local function getItemContainer()
    for _, name in ipairs(ITEM_FOLDERS) do
        local folder = Workspace:FindFirstChild(name)
        if folder then return folder end
    end
    return nil
end

-- ============================================================
-- ========== 8. ESP ==========================================
-- ============================================================
local espObjects = {}

local function createESP(part)
    if not part or not part:IsA("BasePart") then return end
    if espObjects[part] then return end

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
    textLabel.Text = part.Name
    textLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    textLabel.TextStrokeTransparency = 0
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.Parent = billboard

    espObjects[part] = billboard
end

local function removeESP(part)
    if espObjects[part] then
        espObjects[part]:Destroy()
        espObjects[part] = nil
    end
end

local function clearAllESP()
    for _, gui in pairs(espObjects) do
        if gui and gui.Parent then gui:Destroy() end
    end
    espObjects = {}
end

local function scanForItems()
    if not State.ESP then return end
    local container = getItemContainer() or Workspace

    for _, obj in ipairs(container:GetDescendants()) do
        if isValidItem(obj) then
            for _, itemName in ipairs(TARGET_ITEMS) do
                if obj.Name:lower() == itemName:lower() then
                    if obj:IsA("BasePart") then
                        createESP(obj)
                    elseif obj:IsA("Model") and obj.PrimaryPart then
                        createESP(obj.PrimaryPart)
                    end
                    break
                end
            end
        end
    end
end

local function cleanupESP()
    for part, gui in pairs(espObjects) do
        if not part or not part.Parent then
            removeESP(part)
        end
    end
end

-- ============================================================
-- ========== 9. NOCLIP =======================================
-- ============================================================
local noclipConnection = nil

local function applyNoclip()
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            part.CanCollide = false
        end
    end
end

local function startNoclip()
    if noclipConnection then return end
    noclipConnection = RunService.Stepped:Connect(function()
        if State.Noclip then pcall(applyNoclip) end
    end)
end

local function stopNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
end

-- ============================================================
-- ========== 10. SPEED =======================================
-- ============================================================
local function applySpeed()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = State.Speed and State.WalkSpeed or 16
    end
end

-- ============================================================
-- ========== 11. ПРОДАЖА (ИСПРАВЛЕНО) ========================
-- ============================================================
local function findSellRemote()
    local plr = LocalPlayer
    if plr and plr.Character then
        for _, obj in pairs(plr.Character:GetChildren()) do
            if obj:IsA("RemoteEvent") then return obj end
        end
    end
    local places = { Workspace, game:GetService("ReplicatedStorage"), Players }
    for _, place in pairs(places) do
        if place then
            for _, obj in pairs(place:GetDescendants()) do
                if obj:IsA("RemoteEvent") then
                    local n = obj.Name:lower()
                    if n:find("remote") or n:find("sell") or n:find("server") then
                        return obj
                    end
                end
            end
        end
    end
    return nil
end

local function sellItem(itemInstance)
    if not itemInstance or not itemInstance.Parent then return false end
    local plr = LocalPlayer
    local living = Workspace:FindFirstChild("Living") or Workspace
    local target = living:FindFirstChild(plr.Name) or living
    pcall(function() itemInstance.Parent = target end)

    local args = {
        [1] = "EndDialogue",
        [2] = {
            ["NPC"] = "Merchant",
            ["Option"] = "Option2",
            ["Dialogue"] = "Dialogue5"
        }
    }
    local remote = findSellRemote()
    if remote then
        pcall(function() remote:FireServer(unpack(args)) end)
        task.wait(0.2) -- Увеличена задержка для безопасности
        return true
    end
    return false
end

-- ИСПРАВЛЕНО: Теперь проверяет и Backpack, и Character (руки)
local function autoSellItems()
    if not State.AutoSell then return end
    local containers = {
        LocalPlayer:FindFirstChild("Backpack"),
        LocalPlayer.Character
    }
    for _, container in ipairs(containers) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                for _, targetName in ipairs(TARGET_ITEMS) do
                    if item.Name:lower() == targetName:lower() then
                        sellItem(item)
                        break
                    end
                end
            end
        end
    end
end

-- ============================================================
-- ========== 12. АВТОПОКУПКА LUCKY ARROW =====================
-- ============================================================
local function buyLuckyArrow()
    local char = LocalPlayer.Character
    if not char then return false end
    local money = getPlayerMoney()
    if money == nil then return false end
    if money < LUCKY_ARROW_PRICE then return false end
    local remote = char:FindFirstChild("RemoteEvent") or findSellRemote()
    if not remote then return false end

    local args = {
        "PurchaseShopItem",
        {["ItemName"] = "Lucky Arrow"},
        1,
        2
    }
    local success = pcall(function() remote:FireServer(unpack(args)) end)
    if success then
        print(string.format("[YBA AutoBuy] Куплен Lucky Arrow. Баланс: $%d", money))
    end
    return success
end

-- ============================================================
-- ========== 13. AUTOFARM ====================================
-- ============================================================
local function findNearestTargetItem()
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local container = getItemContainer() or Workspace
    local nearest, minDist = nil, math.huge
    for _, obj in ipairs(container:GetDescendants()) do
        if isValidItem(obj) then
            for _, name in ipairs(TARGET_ITEMS) do
                if obj.Name:lower() == name:lower() then
                    local pos = nil
                    if obj:IsA("BasePart") then pos = obj.Position
                    elseif obj:IsA("Model") and obj.PrimaryPart then pos = obj.PrimaryPart.Position end
                    if pos then
                        local dist = (pos - root.Position).Magnitude
                        if dist < minDist then
                            nearest, minDist = obj, dist
                        end
                    end
                    break
                end
            end
        end
    end
    return nearest
end

local function pressE()
    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
        return
    end
    if fireproximityprompt then
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        for _, prompt in ipairs(Workspace:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                local p = prompt.Parent
                if p and p:IsA("BasePart") then
                    if (p.Position - root.Position).Magnitude < (prompt.MaxActivationDistance or 10) then
                        pcall(function() fireproximityprompt(prompt) end)
                    end
                end
            end
        end
    end
end

local flyConnection = nil
local lastTargetName = nil
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
        if now - lastScanTime > 0.5 or not cachedTarget or not cachedTarget.Parent then
            cachedTarget = findNearestTargetItem()
            lastScanTime = now
        end

        local target = cachedTarget
        if not target then lastTargetName = nil; return end

        local targetPos = nil
        if target:IsA("BasePart") then targetPos = target.Position
        elseif target:IsA("Model") and target.PrimaryPart then targetPos = target.PrimaryPart.Position end
        if not targetPos then return end
        local dist = (targetPos - root.Position).Magnitude

        if target.Name ~= lastTargetName then
            lastTargetName = target.Name
            print("[YBA AutoFarm] Цель: " .. target.Name)
        end

        if dist <= State.PickupRange then
            root.AssemblyLinearVelocity = Vector3.zero
            pressE()
            cachedTarget = nil
            lastScanTime = 0
            return
        end

        local dir = targetPos - root.Position
        local speed = State.FlySpeed
        local step = math.min(speed * dt, dist - (State.PickupRange - 0.5))
        if step > 0 then
            local newPos = root.Position + dir.Unit * step
            root.CFrame = CFrame.new(newPos, newPos + dir.Unit)
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end)
end

local function stopAutoFarm()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    lastTargetName = nil
    cachedTarget = nil
    lastScanTime = 0
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then root.AssemblyLinearVelocity = Vector3.zero end
    end
end

-- ============================================================
-- ========== 14. РЕСПАВН =====================================
-- ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if State.Noclip then applyNoclip() end
    if State.Speed then applySpeed() end
end)

-- ============================================================
-- ========== 15. ЦИКЛЫ =======================================
-- ============================================================
task.spawn(function()
    while task.wait(State.ScanInterval) do
        if State.ESP then
            pcall(scanForItems)
            pcall(cleanupESP)
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        pcall(autoSellItems) -- Вызов обновленной функции
    end
end)

task.spawn(function()
    while task.wait(5) do
        if State.AutoBuyLucky then
            pcall(buyLuckyArrow)
        end
    end
end)

-- ============================================================
-- ========== 16. GUI С KAVO UI ===============================
-- ============================================================
local Window = Library.CreateLib("YBA Controller | v4.1", "BloodTheme")

local FarmTab = Window:NewTab("AutoFarm")
local FarmSection = FarmTab:NewSection("Автоматизация")

FarmSection:NewToggle("★ AutoFarm", "Автоматический поиск и подбор предметов", function(state)
    State.AutoFarm = state
    if state then
        if not State.Noclip then State.Noclip = true; startNoclip() end
        startAutoFarm()
    else
        stopAutoFarm()
    end
end)

FarmSection:NewToggle("Авто-продажа", "Продавать предметы из Backpack и рук", function(state)
    State.AutoSell = state
end)

FarmSection:NewToggle("Авто-покупка Lucky Arrow", "Покупать Lucky Arrow при балансе $" .. LUCKY_ARROW_PRICE .. "+", function(state)
    State.AutoBuyLucky = state
end)

FarmSection:NewSlider("Скорость полёта", "Скорость перемещения в AutoFarm", 200, 30, function(value) State.FlySpeed = value end)
FarmSection:NewSlider("Дистанция подбора", "На каком расстоянии жать E", 10, 1, function(value) State.PickupRange = value end)

local VisualTab = Window:NewTab("Visuals")
local VisualSection = VisualTab:NewSection("ESP")
VisualSection:NewToggle("ESP предметов", "Подсвечивать предметы из списка", function(state)
    State.ESP = state
    if not state then clearAllESP() end
end)
VisualSection:NewSlider("Интервал сканирования", "Как часто сканировать мир (сек)", 10, 1, function(value) State.ScanInterval = value end)

local MoveTab = Window:NewTab("Movement")
local MoveSection = MoveTab:NewSection("Скорость и коллизии")
MoveSection:NewToggle("Noclip", "Проход сквозь стены", function(state)
    State.Noclip = state
    if state then startNoclip() else stopNoclip() end
end)
MoveSection:NewToggle("Ускорение", "Увеличить скорость ходьбы", function(state)
    State.Speed = state
    applySpeed()
end)
MoveSection:NewSlider("Скорость ходьбы", "Значение WalkSpeed", 150, 16, function(value)
    State.WalkSpeed = value
    if State.Speed then applySpeed() end
end)

local ItemsTab = Window:NewTab("Items")
local ItemsSection = ItemsTab:NewSection("Выбор предметов для поиска")
local allItems = {
    "Rokakaka", "Lucky Arrow", "Caesar's Headband", "Clackers",
    "Ancient Scroll", "Diamond", "Dio's Diary", "Gold Coin",
    "Lucky Stone Mask", "Mysterious Arrow", "Pure Rokakaka",
    "Quinton's Glove", "Rib Cage of The Saint's Corpse",
    "Steel Ball", "Stone Mask", "Zeppeli's Hat",
}
ItemsSection:NewDropdown("Добавить предмет в поиск", "Выберите предмет из списка", allItems, function(selected)
    local alreadyExists = false
    for _, item in ipairs(TARGET_ITEMS) do
        if item:lower() == selected:lower() then alreadyExists = true; break end
    end
    if not alreadyExists then
        table.insert(TARGET_ITEMS, selected)
        print("[YBA] Добавлен предмет: " .. selected)
    else
        print("[YBA] Предмет уже в списке: " .. selected)
    end
end)
ItemsSection:NewButton("Очистить список предметов", "Удалить все предметы из TARGET_ITEMS", function()
    table.clear(TARGET_ITEMS)
    clearAllESP()
    print("[YBA] Список TARGET_ITEMS очищен")
end)
ItemsSection:NewButton("🔍 Показать объекты рядом (Debug)", "Выводит в консоль имена объектов в радиусе 50 studs", function()
    debugNearbyObjects()
end)

local InfoTab = Window:NewTab("Info")
local InfoSection = InfoTab:NewSection("О скрипте")
InfoSection:NewLabel("YBA Controller v4.1")
InfoSection:NewLabel("Исправлена автопродажа (руки + Backpack)")
InfoSection:NewLabel("Ослаблен фильтр ESP")
InfoSection:NewLabel("Внимание: читы могут привести к бану!")

print("[YBA Controller] v4.1 загружена. Автопродажа исправлена.")
