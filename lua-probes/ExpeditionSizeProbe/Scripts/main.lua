-- Sonda: mede o tamanho FISICO do escritorio de expedicao instalado.
-- Casca fixa (keybind). A logica recarrega a cada F7 via dofile, sem reiniciar.
-- Regra de ouro: callback de keybind roda na thread do UE4SS -> tocar UObject
-- exige game thread (por isso o ExecuteInGameThread).
-- F7 (F8 e do EggPicker; F3 do LineTrace; F9 ocupado).

local LOGIC = "C:/Program Files (x86)/Steam/steamapps/common/Palworld/Pal/Binaries/Win64/ue4ss/Mods/ExpeditionSizeProbe/Scripts/logic.lua"

RegisterKeyBind(Key.F7, function()
    ExecuteInGameThread(function()
        local ok, err = pcall(dofile, LOGIC)
        if not ok then
            print("[ExpSize] erro na logica: " .. tostring(err) .. "\n")
        end
    end)
end)

print("[ExpSize] pronto. Entre numa base com o escritorio de expedicao e aperte F7.\n")
