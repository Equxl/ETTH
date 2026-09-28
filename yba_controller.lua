-- ============================================================
-- YBA SIMPLE HOOK v4
-- Ловит все вызовы FireServer и InvokeServer
-- ============================================================
print("[HOOK] Запуск...")

local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    
    -- Ловим только вызовы сервера
    if (method == "FireServer" or method == "InvokeServer") and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
        print("[HOOK] >>> " .. method .. " на: " .. self:GetFullName())
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
        print("[HOOK] ------------------------------")
    end
    
    return oldNamecall(self, ...)
end)

setreadonly(mt, true)
print("[HOOK] Готово. ТЕПЕРЬ продайте предмет торговцу вручную и смотрите логи [HOOK] в консоли (F9).")
