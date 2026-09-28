-- ============================================================
-- YBA DEBUG v2. Логи помечены [DEBUG_YBA]
-- ============================================================
print("[DEBUG_YBA] Запуск отладки v2...")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- 1. Функция поиска предметов рядом
local function showNearby()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    print("[DEBUG_YBA] --- Объекты в радиусе 30 studs ---")
    local count = 0
    for _, obj in ipairs(game:GetService("Workspace"):GetDescendants()) do
        if obj ~= char and (obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("Tool")) then
            local pos = nil
            if obj:IsA("BasePart") then pos = obj.Position
            elseif obj:IsA("Model") and obj.PrimaryPart then pos = obj.PrimaryPart.Position
            elseif obj:IsA("Tool") and obj:FindFirstChildWhichIsA("BasePart") then
                pos = obj:FindFirstChildWhichIsA("BasePart").Position
            end
            
            if pos and (pos - root.Position).Magnitude < 30 then
                local parentName = obj.Parent and obj.Parent.Name or "nil"
                print("[DEBUG_YBA] " .. obj.ClassName .. " | Имя: " .. obj.Name .. " | Родитель: " .. parentName)
                count = count + 1
            end
        end
    end
    print("[DEBUG_YBA] Найдено объектов рядом: " .. count)
end

-- 2. Функция поиска RemoteEvent и RemoteFunction
local function findRemotes()
    print("[DEBUG_YBA] --- Поиск RemoteEvent и RemoteFunction ---")
    local foundEvents = {}
    local foundFuncs = {}
    
    local function scan(container, path)
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                table.insert(foundEvents, obj)
            elseif obj:IsA("RemoteFunction") then
                table.insert(foundFuncs, obj)
            end
        end
    end
    
    scan(game:GetService("ReplicatedStorage"), "ReplicatedStorage")
    scan(game:GetService("Workspace"), "Workspace")
    
    local char = LocalPlayer.Character
    if char then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("RemoteEvent") then table.insert(foundEvents, obj) end
            if obj:IsA("RemoteFunction") then table.insert(foundFuncs, obj) end
        end
    end
    
    print("[DEBUG_YBA] Найдено RemoteEvent: " .. #foundEvents)
    print("[DEBUG_YBA] Найдено RemoteFunction: " .. #foundFuncs)
    return foundEvents, foundFuncs
end

-- 3. Хук на вызовы сервера
local function hookCalls()
    print("[DEBUG_YBA] --- Хук FireServer и InvokeServer ---")
    print("[DEBUG_YBA] Теперь ВРУЧНУЮ продайте предмет торговцу!")
    
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)
    
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "InvokeServer") and 
           (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
            local args = {...}
            print("[DEBUG_YBA] >>> " .. method .. ": " .. self:GetFullName())
            for i, v in ipairs(args) do
                if type(v) == "table" then
                    print("[DEBUG_YBA]    [" .. i .. "] table:")
                    for k, val in pairs(v) do
                        print("[DEBUG_YBA]       " .. tostring(k) .. " = " .. tostring(val))
                    end
                else
                    print("[DEBUG_YBA]    [" .. i .. "] " .. tostring(v))
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    
    setreadonly(mt, true)
end

-- Запуск
findRemotes()
hookCalls()
task.wait(1)
showNearby()

-- Автоматический показ предметов каждые 3 секунды
task.spawn(function()
    while task.wait(3) do
        pcall(showNearby)
    end
end)

print("[DEBUG_YBA] Готово. Ждите логов [DEBUG_YBA] в консоли.")
