-- =====================================================================
--  Rainbow Star  --  Plantacao Prismatica: uma colheita, as 7 culturas
--
--  Duas metades:
--   1. COLHEITA: ao colher a RainbowStar_Plantation, larga no canteiro as 7
--      culturas do jeito nativo (recolhe andando por cima, pals levam pro bau).
--   2. VISUAL PRISMATICO: o canteiro cresce so com framboesa (o jogo enche um
--      unico ISM por estagio); aqui as mudas sao repartidas entre 7 ISMs, um
--      por cultura, pra o canteiro mostrar as 7 plantas de verdade.
--
--  O resto do mod NAO esta aqui:
--    construcao/icone/aba/custo ..... PalSchema  buildings/rainbowstar.json
--    row da cultura ................. PalSchema  raw/farmcrop.json
--    item colhido + nome ............ PalSchema  items/ e translations/
--    blueprints da planta/canteiro .. LogicMods/RainbowStar.pak
--
--  REGRAS DO UE4SS QUE ESTE ARQUIVO RESPEITA (aprendidas na marra):
--   1. Callback de RegisterHook JA roda na game thread. Nunca LoopAsync com
--      UObject -- foi o que derrubava outros mods (minidumps).
--   2. Ponteiro nulo NAO vira nil: vira userdata truthy. So :IsValid() prova.
--   3. "chamou sem erro" != "funcionou": pcall nao pega access violation.
--   4. '#' num TArray do UE4SS nao funciona -- use :GetArrayNum().
-- =====================================================================

local CONFIG = {
    AnchorMapObjectId = "RainbowStar_Plantation",
    Culturas = {
        { id = "Berries", num = 10 },
        { id = "Wheat",   num = 10 },
        { id = "Tomato",  num = 10 },
        { id = "Lettuce", num = 10 },
        { id = "Carrot",  num = 10 },
        { id = "Onion",   num = 10 },
        { id = "Potato",  num = 10 },
    },
    AlturaDrop = 100.0,   -- cm acima do canteiro
    Log = true,
}

local function log(m) print("[RainbowStar] " .. tostring(m) .. "\n") end

local function alive(o)
    if o == nil then return false end
    local ok, v = pcall(function() return o:IsValid() end)
    return ok and v == true
end


-- =====================================================================
--  1. COLHEITA -- larga as 7 culturas no canteiro
-- =====================================================================

-- ROTA 1 (a boa): inventario -> RequestDrop_ToServer com autopickup. Mesmo
-- pipeline do botao "largar", entao o item nasce identico ao drop de colheita.
-- ATENCAO: GetInventoryData() vive no APalPlayerState, NAO no Controller.
local function inventario()
    local ps = FindFirstOf("PalPlayerState")
    if alive(ps) then
        local inv = nil
        pcall(function() inv = ps:GetInventoryData() end)
        if alive(inv) then return inv end
        pcall(function() inv = ps.InventoryData end)
        if alive(inv) then return inv end
    end
    local l = FindAllOf("PalPlayerInventoryData")
    if l then
        for _, x in ipairs(l) do
            local n = ""
            pcall(function() n = x:GetFullName() end)
            if alive(x) and not string.find(n, "Default__") then return x end
        end
    end
    return nil
end

local function redeItem()
    local l = FindAllOf("PalNetworkItemComponent")
    if l then for _, n in ipairs(l) do if alive(n) then return n end end end
    return nil
end

local function slotsDe(inv, procurados)
    local achados = {}
    pcall(function()
        local mh = inv.InventoryMultiHelper
        local conts = mh and mh.Containers
        if not conts then return end
        for ci = 1, conts:GetArrayNum() do
            local cont = conts[ci]
            if alive(cont) then
                local cid = cont:GetId()
                local slots = cont.ItemSlotArray
                if slots then
                    for i = 1, slots:GetArrayNum() do    -- rele Num a cada volta
                        local s = slots[i]
                        if alive(s) then
                            local id = s.ItemId.StaticId:ToString()
                            local n = s.StackCount
                            if procurados[id] and n and n > 0 then
                                achados[#achados + 1] =
                                    { SlotId = { ContainerId = cid, SlotIndex = s.SlotIndex }, Num = n }
                                procurados[id] = nil
                            end
                        end
                    end
                end
            end
        end
    end)
    return achados
end

local function dropNativo(loc)
    local inv = inventario()
    if not inv then return false, "sem inventario" end
    local nic = redeItem()
    if not nic then return false, "sem PalNetworkItemComponent" end

    local procurados, entregues = {}, {}
    for _, c in ipairs(CONFIG.Culturas) do
        local res = nil
        local ok = pcall(function()
            res = inv:AddItem_ServerInternal(FName(c.id), c.num, false, 0.0, false)
        end)
        if ok and res ~= nil then
            procurados[c.id] = true
            entregues[#entregues + 1] = c.id
        end
    end
    if #entregues == 0 then return false, "AddItem nao entregou nada (mochila cheia?)" end

    local froms = slotsDe(inv, procurados)
    if #froms == 0 then return false, "itens entraram mas nao achei os slots" end

    local ok = pcall(function()
        nic:RequestDrop_ToServer(froms,
            { X = loc.X, Y = loc.Y, Z = loc.Z + CONFIG.AlturaDrop }, true)   -- true = autopickup
    end)
    if not ok then return false, "RequestDrop_ToServer falhou" end
    return true, string.format("%d slots: %s", #froms, table.concat(entregues, ","))
end

-- ROTA 2 (reserva): spawner de incidente, offset relativo ao ator. Funciona,
-- mas o pickup exige interagir. NAO destruir o ator: leva os itens junto.
local SPAWNER = nil
local function dropReserva(loc)
    local UEHelpers = require("UEHelpers")
    local KML = UEHelpers.GetKismetMathLibrary()
    if alive(SPAWNER) then
        pcall(function()
            SPAWNER:K2_SetActorLocation({ X = loc.X, Y = loc.Y, Z = loc.Z }, false, {}, false)
        end)
    else
        local C = StaticFindObject("/Script/Pal.PalRandomIncidentMapObjectSpawner")
        local GS, W = UEHelpers.GetGameplayStatics(), UEHelpers.GetWorld()
        if not (C and GS and KML and W) then return false, "sem spawner/UEHelpers" end
        local T = KML:MakeTransform({ X = loc.X, Y = loc.Y, Z = loc.Z },
                                    { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 },
                                    { X = 1.0, Y = 1.0, Z = 1.0 })
        local A = GS:BeginDeferredActorSpawnFromClass(W, C, T, 1, nil)
        if not alive(A) then return false, "spawn do ator falhou" end
        GS:FinishSpawningActor(A, T)
        SPAWNER = A
    end
    local deu = {}
    for _, c in ipairs(CONFIG.Culturas) do
        if pcall(function()
            SPAWNER:SpawnDropItem(FName(c.id), c.num, { X = 0.0, Y = 0.0, Z = CONFIG.AlturaDrop })
        end) then deu[#deu + 1] = c.id end
    end
    return #deu > 0, "reserva: " .. table.concat(deu, ",")
end

RegisterHook("/Script/Pal.PalMapObjectFarmBlockV2ModelStateBehaviourHarvestable:OnFinishWorkInServer",
function(Context, WorkParam)
    local ok, err = pcall(function()
        local Work = WorkParam:get()
        if not alive(Work) then return end
        local model = Work.CachedOwnerMapObjectConcreteModel
        if not alive(model) then return end

        local id = "?"
        pcall(function() id = model:TryGetMapObjectId():ToString() end)
        if id ~= CONFIG.AnchorMapObjectId then return end

        local loc = nil
        pcall(function()
            local a = model:GetActor()
            if alive(a) then loc = a:K2_GetActorLocation() end
        end)
        if not loc then
            if CONFIG.Log then log("colheita sem posicao do canteiro") end
            return
        end

        local okn, info = dropNativo(loc)
        if okn then
            if CONFIG.Log then log("colheita -> " .. info) end
            return
        end
        local okr, infor = dropReserva(loc)
        if CONFIG.Log then
            log(string.format("colheita: rota 1 falhou (%s) | rota 2 %s (%s)",
                info, okr and "ok" or "falhou", infor))
        end
    end)
    if not ok then log("ERRO no hook: " .. tostring(err)) end
end)


-- =====================================================================
--  2. VISUAL PRISMATICO -- reparte as mudas entre as 7 culturas
--
--  O canteiro cresce com um ISM cheio (framboesa) e 6 ISMs irmaos vazios, um
--  por cultura. A cada passe, as mudas do ISM cheio sao redistribuidas em
--  rodizio entre os 7 -- entao o canteiro mostra trigo, tomate, alface, etc.
--  lado a lado, cada um com o mesh e o material reais do jogo.
--
--  Os 6 irmaos ficam FORA do GrowupProcessSets de proposito: com 7 entradas no
--  mesmo estado o jogo parava de popular qualquer ISM. Com o array no formato
--  vanilla (3 entradas) so o CropISM e alimentado, e este bloco reparte a
--  partir dele -- por isso os nomes dos irmaos precisam estar listados aqui.
-- =====================================================================

local INTERVALO = 3000     -- ms entre passes
local MIN_MUDAS = 7        -- abaixo disso nao ha o que repartir
local IRMAOS_PRISMA = { "RS_Prisma_Wheat", "RS_Prisma_Tomato", "RS_Prisma_Lettuce",
                        "RS_Prisma_Carrot", "RS_Prisma_Onion", "RS_Prisma_Potato" }

-- so mexemos nas NOSSAS plantacoes -- os canteiros vanilla do jogador ficam
-- intactos (senao o distribuidor os processaria a toa).
local function ehNossa(planta)
    local cls = ""
    pcall(function() cls = planta:GetClass():GetFullName() end)
    return string.find(cls, "RainbowStar", 1, true) ~= nil
end

-- componente pelo NOME EXATO da variavel do BP. O ator expoe cada componente
-- como ObjectProperty, entao planta[nome] resolve direto -- sem UFunction, sem
-- TArray, sem StaticFindObject.
local function pegaComp(planta, nome)
    local c
    local ok = pcall(function() c = planta[nome] end)
    if ok and alive(c) then return c end
    return nil
end

local function conta(c)
    local n = 0
    if alive(c) then pcall(function() n = c:GetInstanceCount() or 0 end) end
    return n or 0
end

-- le do PROPRIO ator quais componentes a engine usa no estagio colhivel
-- (ProcessRate 1.0 == colhivel). Nao chuma nome: trabalha com o que estiver la.
local function alvosColhiveis(planta)
    local nomes = {}
    pcall(function()
        local sets = planta.GrowupProcessSets
        if not sets then return end
        for i = 1, sets:GetArrayNum() do          -- GetArrayNum, nunca #
            local s = sets[i]
            if s then
                local rate = s.ProcessRate
                if rate and rate >= 1.0 then
                    local n
                    pcall(function() n = s.TargetCompRef.ComponentProperty:ToString() end)
                    if n and n ~= "" and n ~= "None" then nomes[#nomes + 1] = n end
                end
            end
        end
    end)
    return nomes
end

-- Ler a transform de uma instancia. GetInstanceTransform NAO serve neste UE4SS
-- (devolve so um bool; o out param nao volta como 2o retorno). A rota certa e
-- ler a propriedade PerInstanceSMData[i].Transform (FMatrix) e converter.
-- Transform em espaco LOCAL do componente; como origem e destino sao ISMs
-- irmaos sob a mesma raiz, copiar em local e o correto (AddInstance false).
local KML
local function kmath()
    if not KML then
        pcall(function() KML = require("UEHelpers").GetKismetMathLibrary() end)
    end
    return KML
end

local function transformDa(c, i)          -- i base 0, como o resto da API de ISM
    local t
    pcall(function()
        local d = c.PerInstanceSMData
        if not d then return end
        local e = d[i + 1]                -- TArray do UE4SS indexa a partir de 1
        if not e then return end
        local m = e.Transform
        if not m then return end
        local k = kmath()
        if k then t = k:Conv_MatrixToTransform(m) end
    end)
    return t
end

local function posDaInstancia(c, i)
    local t = transformDa(c, i)
    if not t then return nil end
    local p
    pcall(function() p = t.Translation end)
    return p
end

-- ja repartido? se duas culturas tem a 1a muda no MESMO ponto, estao
-- empilhadas e ainda falta repartir.
local function estaEmpilhado(a, b)
    local pa, pb = posDaInstancia(a, 0), posDaInstancia(b, 0)
    if not (pa and pb) then return nil end            -- indeterminado
    local d = math.abs(pa.X - pb.X) + math.abs(pa.Y - pb.Y) + math.abs(pa.Z - pb.Z)
    return d < 1.0
end

local feitos = {}          -- memo do passe anterior; reconstruido a cada passe
local vistosAgora = {}
local avisado = {}         -- 1 aviso por assinatura de problema

local function aviso(chave, msg)
    if not CONFIG.Log or avisado[chave] then return end
    avisado[chave] = true
    log("[prisma] " .. msg)
end

local function repartir(planta)
    if not alive(planta) then return end

    local chave = "?"
    pcall(function() chave = planta:GetFullName() end)
    if string.find(chave, "Default__", 1, true) then return end   -- CDO
    if not ehNossa(planta) then return end                        -- canteiro vanilla
    vistosAgora[chave] = true

    local nomes = alvosColhiveis(planta)
    if #nomes == 0 then
        aviso("sem-sets", "nao consegui ler GrowupProcessSets -- visual desligado")
        return
    end
    -- soma os 6 irmaos (ficam fora do GrowupProcessSets de proposito)
    local vistos = {}
    for _, n in ipairs(nomes) do vistos[n] = true end
    for _, n in ipairs(IRMAOS_PRISMA) do
        if not vistos[n] then nomes[#nomes + 1] = n end
    end

    local comps, faltando = {}, {}
    for _, n in ipairs(nomes) do
        local c = pegaComp(planta, n)
        if c then comps[#comps + 1] = c else faltando[#faltando + 1] = n end
    end
    if #faltando > 0 then
        aviso("faltando", "componentes que o ator nao expoe: " .. table.concat(faltando, ","))
    end
    if #comps == 0 then return end

    -- de onde vem as transforms: quem tiver mais instancias
    local maior, nMaior, total = nil, 0, 0
    for _, c in ipairs(comps) do
        local n = conta(c)
        total = total + n
        if n > nMaior then maior, nMaior = c, n end
    end

    if total == 0 then
        feitos[chave] = nil                     -- colhido/arrancado: reparte de novo depois
        return
    end
    if nMaior < MIN_MUDAS then return end        -- ainda brotando
    if feitos[chave] then return end

    -- ja esta repartido? (so da pra saber com 2+ componentes com instancia)
    if #comps > 1 then
        local a, b
        for _, c in ipairs(comps) do
            if conta(c) > 0 then
                if not a then a = c elseif not b then b = c end
            end
        end
        if a and b and estaEmpilhado(a, b) == false then
            feitos[chave] = true
            return                              -- ja repartido
        end
    end

    -- 1) guarda as transforms da fonte
    local tr = {}
    for i = 0, nMaior - 1 do
        local t = transformDa(maior, i)
        if t then tr[#tr + 1] = t end
    end
    if #tr < MIN_MUDAS then
        aviso("transforms", string.format("li so %d de %d transforms -- adiando", #tr, nMaior))
        return
    end

    -- 2) zera todos e reparte em rodizio
    for _, c in ipairs(comps) do
        if not pcall(function() c:ClearInstances() end) then
            aviso("clear", "ClearInstances falhou -- abortei pra nao deixar pela metade")
            return
        end
    end
    local postos = 0
    for i, t in ipairs(tr) do
        local destino = comps[((i - 1) % #comps) + 1]
        if alive(destino) and pcall(function() destino:AddInstance(t, false) end) then
            postos = postos + 1
        end
    end

    feitos[chave] = true
    if CONFIG.Log then
        log(string.format("planta prismatica: %d mudas repartidas em %d culturas", postos, #comps))
    end
end

if not _G.__RS_PRISMA then
    _G.__RS_PRISMA = true
    local function passe()
        vistosAgora = {}
        local l = FindAllOf("PalMapObjectFarmCrop")
        if l then
            for i = 1, #l do pcall(repartir, l[i]) end
        end
        -- poda o memo: so sobrevive quem foi visto neste passe (sem vazamento)
        local novo = {}
        for k in pairs(vistosAgora) do if feitos[k] then novo[k] = true end end
        feitos = novo
    end
    if type(LoopInGameThreadWithDelay) == "function" then
        pcall(LoopInGameThreadWithDelay, INTERVALO, passe)
    else
        log("AVISO: LoopInGameThreadWithDelay indisponivel -- visual prismatico desligado")
    end
end


log("carregado | ancora=" .. CONFIG.AnchorMapObjectId .. " | " .. #CONFIG.Culturas .. " culturas por colheita")
