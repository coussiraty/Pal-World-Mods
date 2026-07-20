-- Roda JA na game thread (chamado dentro de ExecuteInGameThread pelo main.lua).
-- Le a escala aplicada e o tamanho de mundo (ja com escala) da malha do predio.

local list = FindAllOf("BP_BuildObject_Expedition_C")
if not list or #list == 0 then
    print("[ExpSize] nenhuma instancia de BP_BuildObject_Expedition_C. Precisa estar carregada numa base.\n")
    return
end

for i = 1, #list do
    local a = list[i]
    if a and a:IsValid() then
        -- 1) prova direta de que o patch pegou: escala do Root (a alavanca)
        local root = a.Root
        if root and root:IsValid() then
            local s = root.RelativeScale3D
            print(string.format("[ExpSize] #%d Root.RelativeScale3D = (%.3f, %.3f, %.3f)   [esperado 0.650]\n",
                i, s.X, s.Y, s.Z))
        else
            print(string.format("[ExpSize] #%d Root invalido\n", i))
        end

        -- 2) tamanho fisico real: BoxExtent de mundo da malha (ja inclui a escala herdada)
        local mesh = a.SM_PalExpeditionFacilities
        if mesh and mesh:IsValid() then
            local b = mesh.Bounds
            local e = b.BoxExtent
            print(string.format("[ExpSize] #%d malha BoxExtent(mundo) = (%.1f, %.1f, %.1f)  half-size cm\n",
                i, e.X, e.Y, e.Z))
        end
    end
end
