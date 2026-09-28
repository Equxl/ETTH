-- ============================================================
-- YBA HARD HOOK
-- Перехватывает FireServer у всех RemoteEvent напрямую
-- ============================================================
print("[HOOK] Запуск жесткого хука...")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function hookRemote(remote)
    if not remote or not remote:IsA("RemoteEvent") then return end
    local oldFireServer = remote.FireServer
    if not oldFireServer then return end
    
    hookfunction(oldFireServer, function(self, ...)
        print("[HOOK] >>> FireServer: " .. self:GetFullName())
        local args = {...}
        for i, v in ipairs(args) do
            if type(v) == "table" then
                print("[HOOK]    Аргумент " .. i .. " (таблица):")
                for k, val in pairs(v) do
                    print("[HOOK]       " .. tostring(k) .. " = " .. tostring(val))
                end
            else
                print("[HOOK]    Аргумент " .. i .. ": " .. tostring(v))
            end
        end
        print("[HOOK] ------------------------")
        return oldFireServer(self, ...)
    end)
end

-- Проходим по всем объектам в игре
local count = 0
for _, obj in ipairs(game:GetDescendants()) do
    if obj:IsA("RemoteEvent") then
        hookRemote(obj)
        count = count + 1
    end
end

print("[HOOK] Установлено хуков на RemoteEvent: " .. count)
print("[HOOK] ТЕПЕРЬ продайте предмет торговцу вручную!")
