-- ============================================================
-- YBA Controller v8.0 (Kavo UI + VirtualUser Click)
-- ============================================================
print("[YBA Controller] Загрузка v8.0...")
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()

-- ============================================================
-- 1. НАСТРОЙКИ
-- ============================================================
local TARGET_ITEMS = {
    "Rokakaka", "Lucky Arrow", "Caesar's Headband", "Clackers",
    "Ancient Scroll", "Diamond", "Dio's Diary", "Gold Coin",
    "Lucky Stone Mask", "Mysterious Arrow", "Pure Rokakaka",
    "Quinton's Glove", "Rib Cage of The Saint's Corpse",
    "Steel Ball", "Stone Mask", "Zeppeli's Hat",
}

local LUCKY_ARROW_PRICE = 75000
local PICKUP_COOLDOWN = 0.5
local SELL_COOLDOWN = 5
local FLY_TO_MERCHANT_SPEED = 80

local State = {
    ESP = true, AutoFarm = false, AutoSell = false,
    Noclip = false, Speed = false, AutoBuyLucky = false,
    FlySpeed = 80, PickupRange = 5, WalkSpeed = 30,
    Busy = false,
}

-- ============================================================
-- 2. СЕРВИСЫ
-- ============================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local VirtualInputManager = nil
pcall(function()
    VirtualInputManager = game:GetService("VirtualInputManager")
end)

-- ============================================================
-- 3. ESP
-- ============================================================
local espObjects = {}

local function createESP(part, itemName)
    if not part or espObjects[part] then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "YBA_ItemESP"
    bb.Size = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = part
    bb.Parent = part
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1, 0, 1, 0)
    tl.BackgroundTransparency = 1
    tl.Text = itemName
    tl.TextColor3 = Color3.fromRGB(255, 215, 0)
    tl.TextStrokeTransparency = 0
    tl.TextScaled = true
    tl.Font = Enum.Font.SourceSansBold
    tl.Parent = bb
    espObjects[part] = bb
end

local function clearAllESP()
    for _, gui in pairs(espObjects) do
        if gui and gui.Parent then gui:Destroy() end
    end
    espObjects = {}
end

local function getValidItems()
    local out = {}
    local folder = Workspace:FindFirstChild("Item_Spawns")
    if not folder then return out end
    local items = folder:FindFirstChild("Items")
    if not items then return out end
    for _, model in ipairs(items:GetChildren()) do
        if model:IsA("Model") then
            local prompt = model:FindFirstChildOfClass("ProximityPrompt")
            if prompt and prompt.ActionText == "Pick Up" then
                local mesh = model:FindFirstChildOfClass("MeshPart") or model:FindFirstChildOfClass("BasePart")
                if mesh and mesh.Transparency < 1 then
                    table.insert(out, {model = model, prompt = prompt, mesh = mesh, name = prompt.ObjectText})
                end
            end
        end
    end
    return out
end

local function scanForItems()
    if not State.ESP then return end
    for _, data in ipairs(getValidItems()) do
        for _, name in ipairs(TARGET_ITEMS) do
            if string.find(data.name:lower(), name:lower(), 1, true) then
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
-- 4. AUTOFARM
-- ============================================================
local function findNearestItem()
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local nearest, minDist = nil, math.huge
    for _, data in ipairs(getValidItems()) do
        for _, name in ipairs(TARGET_ITEMS) do
            if string.find(data.name:lower(), name:lower(), 1, true) then
                local dist = (data.mesh.Position - root.Position).Magnitude
                if dist < minDist then nearest, minDist = data, dist end
                break
            end
        end
    end
    return nearest
end

local flyConn = nil
local cachedTarget = nil
local lastScan = 0
local lastPickup = 0

local function startAutoFarm()
    if flyConn then return end
    flyConn = RunService.Heartbeat:Connect(function(dt)
        if not State.AutoFarm or State.Busy then return end
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        if tick() - lastPickup < PICKUP_COOLDOWN then
            root.AssemblyLinearVelocity = Vector3.zero
            return
        end

        local now = tick()
        if now - lastScan > 0.5 or not cachedTarget or not cachedTarget.mesh.Parent then
            cachedTarget = findNearestItem()
            lastScan = now
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
                lastPickup = tick()
            end
            cachedTarget = nil
            lastScan = 0
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
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    cachedTarget = nil; lastScan = 0
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then root.AssemblyLinearVelocity = Vector3.zero end
    end
end

-- ============================================================
-- 5. AUTOSELL
-- ============================================================

local function hasItemsInBackpack()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return false end
    for _, item in ipairs(bp:GetChildren()) do
        if item:IsA("Tool") then return true end
    end
    return false
end

local function findMerchant()
    local d = Workspace:FindFirstChild("Dialogues")
    if not d then return nil, nil end
    for _, obj in ipairs(d:GetChildren()) do
        if obj:IsA("Model") and obj.Name:lower():find("merchant") then
            local prompt = obj:FindFirstChildOfClass("ProximityPrompt")
            if prompt and prompt.ActionText == "Interact" then
                return obj, prompt
            end
        end
    end
    return nil, nil
end

local function flyToMerchant(merchant)
    if not merchant then return false end
    local targetPos = nil
    if merchant.PrimaryPart then
        targetPos = merchant.PrimaryPart.Position
    else
        local part = merchant:FindFirstChildWhichIsA("BasePart")
        if part then targetPos = part.Position end
    end
    if not targetPos then return false end

    local startTime = tick()
    while tick() - startTime < 15 do
        local char = LocalPlayer.Character
        if not char then return false end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return false end
        local dist = (targetPos - root.Position).Magnitude
        if dist < 7 then
            root.AssemblyLinearVelocity = Vector3.zero
            return true
        end
        local dir = (targetPos - root.Position).Unit
        local step = math.min(FLY_TO_MERCHANT_SPEED * 0.03, dist - 6)
        local newPos = root.Position + dir * step
        root.CFrame = CFrame.new(newPos, newPos + dir)
        root.AssemblyLinearVelocity = Vector3.zero
        RunService.Heartbeat:Wait()
    end
    return false
end

-- НОВОЕ: клик через VirtualUser (главный способ)
local function clickButton(btn)
    if not btn then return false end
    
    local absPos = btn.AbsolutePosition
    local absSize = btn.AbsoluteSize
    local centerX = absPos.X + absSize.X / 2
    local centerY = absPos.Y + absSize.Y / 2
    
    -- Способ 1: VirtualUser (встроенный сервис Roblox)
    local ok1 = pcall(function()
        local VirtualUser = game:GetService("VirtualUser")
        VirtualUser:CaptureController()
        VirtualUser:ClickButton1(Vector2.new(centerX, centerY))
    end)
    
    -- Способ 2: mousemoverel + mouse1click (функции Xeno)
    pcall(function()
        local mouse = LocalPlayer:GetMouse()
        mousemoverel(centerX - mouse.X, centerY - mouse.Y)
        task.wait(0.1)
        mouse1click()
    end)
    
    -- Способ 3: VirtualInputManager
    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 0)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0)
        end)
    end
    
    -- Способ 4: Activate
    pcall(function() btn:Activate() end)
    
    return true
end

local function pressNumberKey(num)
    if not VirtualInputManager then return end
    local keyName = "One"
    if num == 2 then keyName = "Two"
    elseif num == 3 then keyName = "Three"
    elseif num == 4 then keyName = "Four"
    elseif num == 5 then keyName = "Five"
    elseif num == 6 then keyName = "Six"
    elseif num == 7 then keyName = "Seven"
    elseif num == 8 then keyName = "Eight"
    elseif num == 9 then keyName = "Nine"
    end
    local keyCode = Enum.KeyCode[keyName]
    if not keyCode then return end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

local function findButtonByText(searchText)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    searchText = searchText:lower()
    for _, gui in ipairs(pg:GetChildren()) do
        for _, obj in ipairs(gui:GetDescendants()) do
            if obj:IsA("TextButton") and obj.Visible and obj.AbsoluteSize.X > 0 then
                local txt = (obj.Text or ""):lower()
                txt = txt:gsub("<[^>]+>", "")
                if txt:find(searchText, 1, true) then
                    return obj
                end
            end
        end
    end
    return nil
end

local lastSell = 0
local isSelling = false

local function autoSellItems(force)
    force = force or false
    if not force and not State.AutoSell then return end
    if isSelling then return end
    if not hasItemsInBackpack() then return end
    if not force and tick() - lastSell < SELL_COOLDOWN then return end
    
    lastSell = tick()
    isSelling = true
    State.Busy = true

    print("[AutoSell] === НАЧАЛО ===")
    local merchant, prompt = findMerchant()
    if not merchant then
        print("[AutoSell] Торговец не найден.")
        State.Busy = false; isSelling = false; return
    end
    print("[AutoSell] Торговец: " .. merchant.Name)

    if not flyToMerchant(merchant) then
        print("[AutoSell] Не долетел.")
        State.Busy = false; isSelling = false; return
    end
    task.wait(0.5)

    print("[AutoSell] Открываю диалог...")
    pcall(function() fireproximityprompt(prompt) end)
    task.wait(2.5)

    print("[AutoSell] ЭТАП 1: Ищу кнопку 'I'd like to sell...'")
    local stage1Done = false
    for attempt = 1, 5 do
        local btn = findButtonByText("i'd like to sell")
        if not btn then btn = findButtonByText("like to sell") end
        if not btn then btn = findButtonByText("sell this") end
        
        if btn then
            print("[AutoSell] Попытка " .. attempt .. ": кликаю по '" .. btn.Text .. "'")
            clickButton(btn)
            pressNumberKey(1)
            task.wait(1.5)
            
            if not findButtonByText("i'd like to sell") and not findButtonByText("like to sell") then
                stage1Done = true
                print("[AutoSell] Этап 1 пройден (кнопка исчезла)")
                break
            end
        else
            stage1Done = true
            print("[AutoSell] Кнопка этапа 1 не найдена")
            break
        end
    end

    if not stage1Done then
        print("[AutoSell] Этап 1 не удался.")
        State.Busy = false; isSelling = false; return
    end

    task.wait(2.0)

    print("[AutoSell] ЭТАП 2: Ищу кнопку 'Sell ALL'")
    local stage2Done = false
    for attempt = 1, 5 do
        local btn = findButtonByText("sell all")
        if not btn then btn = findButtonByText("all of these") end
        if not btn then btn = findButtonByText("i'll sell") end
        
        if btn then
            print("[AutoSell] Попытка " .. attempt .. ": кликаю по '" .. btn.Text .. "'")
            clickButton(btn)
            pressNumberKey(6)
            pressNumberKey(5)
            task.wait(1.5)
            
            if not findButtonByText("sell all") and not findButtonByText("all of these") then
                stage2Done = true
                print("[AutoSell] Этап 2 пройден!")
                break
            end
        else
            stage2Done = true
            print("[AutoSell] Кнопка этапа 2 не найдена")
            break
        end
    end

    if stage2Done then
        print("[AutoSell] === ПРОДАЖА ЗАВЕРШЕНА ===")
    else
        print("[AutoSell] === ПРОДАЖА НЕ УДАЛАСЬ ===")
    end

    State.Busy = false
    isSelling = false
end

-- ============================================================
-- 6. АВТОПОКУПКА LUCKY ARROW
-- ============================================================
local function getPlayerMoney()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        local c = ls:FindFirstChild("Cash") or ls:FindFirstChild("Money")
        if c and c:IsA("IntValue") then return c.Value end
    end
    local a = LocalPlayer:GetAttribute("Money") or LocalPlayer:GetAttribute("Cash")
    if typeof(a) == "number" then return a end
    return nil
end

local function findSellRemote()
    local c = LocalPlayer.Character
    if c then
        for _, o in pairs(c:GetChildren()) do
            if o:IsA("RemoteEvent") then return o end
        end
    end
    for _, p in pairs({Workspace, game:GetService("ReplicatedStorage")}) do
        for _, o in pairs(p:GetDescendants()) do
            if o:IsA("RemoteEvent") then
                local n = o.Name:lower()
                if n:find("remote") or n:find("sell") or n:find("server") then return o end
            end
        end
    end
    return nil
end

local function buyLuckyArrow()
    local c = LocalPlayer.Character
    if not c then return false end
    local m = getPlayerMoney()
    if m == nil or m < LUCKY_ARROW_PRICE then return false end
    local r = c:FindFirstChild("RemoteEvent") or findSellRemote()
    if not r then return false end
    local ok = pcall(function() r:FireServer("PurchaseShopItem", {["ItemName"] = "Lucky Arrow"}, 1, 2) end)
    if ok then print(string.format("[AutoBuy] Куплен Lucky Arrow. $%d", m)) end
    return ok
end

-- ============================================================
-- 7. NOCLIP & SPEED
-- ============================================================
local noclipConn = nil
local function applyNoclip()
    local c = LocalPlayer.Character
    if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
    end
end

local function startNoclip()
    if noclipConn then return end
    noclipConn = RunService.Stepped:Connect(function()
        if State.Noclip then pcall(applyNoclip) end
    end)
end

local function stopNoclip()
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    local c = LocalPlayer.Character
    if c then
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
end

local function applySpeed()
    local c = LocalPlayer.Character
    if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid")
    if h then h.WalkSpeed = State.Speed and State.WalkSpeed or 16 end
end

-- ============================================================
-- 8. ЦИКЛЫ
-- ============================================================
task.spawn(function()
    while task.wait(3) do
        if State.ESP then pcall(scanForItems); pcall(cleanupESP) end
    end
end)

task.spawn(function()
    while task.wait(2) do pcall(autoSellItems) end
end)

task.spawn(function()
    while task.wait(5) do
        if State.AutoBuyLucky then pcall(buyLuckyArrow) end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if State.Noclip then applyNoclip() end
    if State.Speed then applySpeed() end
end)

-- ============================================================
-- 9. KAVO UI
-- ============================================================
local Window = Library.CreateLib("YBA Controller | v8.0", "BloodTheme")

local FarmTab = Window:NewTab("AutoFarm")
local FarmSec = FarmTab:NewSection("Автоматизация")

FarmSec:NewToggle("★ AutoFarm", "Автоматический поиск и подбор предметов", function(v)
    State.AutoFarm = v
    if v then
        if not State.Noclip then State.Noclip = true; startNoclip() end
        startAutoFarm()
    else
        stopAutoFarm()
    end
end)

FarmSec:NewToggle("Авто-продажа", "Плавно летит к торговцу и продаёт всё", function(v)
    State.AutoSell = v
end)

FarmSec:NewToggle("Авто-покупка Lucky Arrow", "Покупать при балансе $" .. LUCKY_ARROW_PRICE .. "+", function(v)
    State.AutoBuyLucky = v
end)

FarmSec:NewSlider("Скорость полёта", "AutoFarm", 200, 30, function(v) State.FlySpeed = v end)
FarmSec:NewSlider("Дистанция подбора", "Радиус подбора", 10, 1, function(v) State.PickupRange = v end)

local VisualTab = Window:NewTab("Visuals")
local VisualSec = VisualTab:NewSection("ESP")
VisualSec:NewToggle("ESP предметов", "Подсвечивать предметы", function(v)
    State.ESP = v
    if not v then clearAllESP() end
end)

local MoveTab = Window:NewTab("Movement")
local MoveSec = MoveTab:NewSection("Скорость и коллизии")
MoveSec:NewToggle("Noclip", "Проход сквозь стены", function(v)
    State.Noclip = v
    if v then startNoclip() else stopNoclip() end
end)
MoveSec:NewToggle("Ускорение", "Увеличить WalkSpeed", function(v)
    State.Speed = v
    applySpeed()
end)
MoveSec:NewSlider("Скорость ходьбы", "WalkSpeed", 150, 16, function(v)
    State.WalkSpeed = v
    if State.Speed then applySpeed() end
end)

local ItemsTab = Window:NewTab("Items")
local ItemsSec = ItemsTab:NewSection("Выбор предметов")
local allItems = {
    "Rokakaka", "Lucky Arrow", "Caesar's Headband", "Clackers",
    "Ancient Scroll", "Diamond", "Dio's Diary", "Gold Coin",
    "Lucky Stone Mask", "Mysterious Arrow", "Pure Rokakaka",
    "Quinton's Glove", "Rib Cage of The Saint's Corpse",
    "Steel Ball", "Stone Mask", "Zeppeli's Hat",
}
ItemsSec:NewDropdown("Добавить предмет", "В TARGET_ITEMS", allItems, function(sel)
    for _, item in ipairs(TARGET_ITEMS) do
        if item:lower() == sel:lower() then return end
    end
    table.insert(TARGET_ITEMS, sel)
    print("[YBA] Добавлен: " .. sel)
end)

ItemsSec:NewButton("🧪 Тест: продать сейчас", "Принудительно запустить продажу", function()
    lastSell = 0; isSelling = false; State.Busy = false; State.AutoSell = true
    print("[Test] Ручной запуск AutoSell (force mode)...")
    task.spawn(function() autoSellItems(true) end)
end)

ItemsSec:NewButton("🔍 Debug: что в Backpack?", "Показать все предметы в инвентаре", function()
    print("=== Содержимое Backpack ===")
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then print("Backpack не найден!") return end
    for _, item in ipairs(bp:GetChildren()) do
        print("  [" .. item.ClassName .. "] " .. item.Name)
    end
    print("===========================")
end)

ItemsSec:NewButton("Debug: Показать ВИДИМЫЕ кнопки", "Откройте диалог и нажмите", function()
    print("=== ВИДИМЫЕ КНОПКИ ===")
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    for _, gui in ipairs(pg:GetChildren()) do
        if gui.Enabled then
            for _, obj in ipairs(gui:GetDescendants()) do
                if obj:IsA("TextButton") and obj.Visible and obj.Text and obj.Text ~= "" then
                    print("  [" .. obj.Text .. "] | " .. obj:GetFullName())
                end
            end
        end
    end
    print("======================")
end)

local InfoTab = Window:NewTab("Info")
local InfoSec = InfoTab:NewSection("О скрипте")
InfoSec:NewLabel("YBA Controller v8.0")
InfoSec:NewLabel("AutoSell: 4 способа клика")
InfoSec:NewLabel("Главный способ: VirtualUser (Roblox)")
InfoSec:NewLabel("Если не работает — используйте Debug")

print("[YBA Controller] v8.0 загружена. VirtualUser клик активен.")
