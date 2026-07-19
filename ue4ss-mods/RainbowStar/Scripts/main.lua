-- =====================================================================
--  Rainbow Star  --  plantacao que rende as 7 culturas
--
--  O que este script faz: ao colher a RainbowStar_Plantation, larga NO
--  CANTEIRO as 7 culturas, do jeito nativo (recolhe andando por cima, e
--  os pals carregam pro bau sozinhos).
--
--  O resto do mod NAO esta aqui:
--    construcao/icone/aba/custo ..... PalSchema  buildings/rainbowstar.json
--    row da cultura ................. PalSchema  raw/farmcrop.json
--    item colhido + nome ............ PalSchema  items/ e translations/
--    blueprints da planta/canteiro .. LogicMods/RainbowStar.pak
--
--  REGRAS DO UE4SS QUE ESTE ARQUIVO RESPEITA (aprendidas na marra em 19/07):
--   1. Callback de RegisterHook JA roda na game thread. Nunca LoopAsync com
--      UObject -- foi o que derrubava o AutoHatchLua (5 minidumps).
--   2. Ponteiro nulo NAO vira nil: vira userdata truthy. So :IsValid() prova.
--   3. "chamou sem erro" != "funcionou": pcall nao pega access violation.
-- =====================================================================

local CONFIG = {
    AnchorMapObjectId = "RainbowStar_Plantation",
    -- As 7 culturas. O drop nativo da row e o item "RainbowStar"; estas vem
    -- todas por aqui.
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

-- ---------------------------------------------------------------------
--  ROTA 1 (a boa): inventario -> RequestDrop_ToServer com autopickup.
--  Mesmo pipeline do botao "largar" do inventario, entao o item nasce
--  identico ao drop de colheita.
--  ATENCAO: GetInventoryData() vive no APalPlayerState, NAO no Controller.
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
--  ROTA 2 (reserva): spawner de incidente, offset relativo ao ator.
--  Funciona, mas o pickup exige interagir em vez de recolher andando.
--  NAO destruir o ator: e classe de incidente e leva os itens junto.
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
--  hook de colheita (RegisterHook ja roda na game thread)
-- ---------------------------------------------------------------------
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
--  VISUAL PRISMATICO
--
--  Como o jogo desenha um canteiro: cada estagio de crescimento tem UM
--  InstancedStaticMeshComponent, e o jogo enche em runtime o ISM do estagio
--  atual com N instancias (uma por muda). Um ISM so aceita UM mesh -- e por
--  isso que um canteiro vanilla e sempre uma cultura so.
--
--  Quem manda nesse endereçamento e o proprio ator: GrowupProcessSets e um
--  array de FPalFarmCropGrowupProcessSet, e cada entrada tem um
--  FComponentReference (TargetCompRef.ComponentProperty) que nomeia o
--  componente por NOME DE PROPRIEDADE. Nosso BP declara 7 entradas no estagio
--  colhivel, uma por cultura.
--
--  Este bloco NAO chumba nome de componente: ele le o GrowupProcessSets do
--  ator e trabalha com o que estiver la. Isso importa porque os nomes ja
--  mudaram uma vez (o BP e filho do BP do Tomate, entao existem tanto os ISMs
--  herdados 'CropISM' quanto os nossos 'CropISM_0') e chumbar o nome errado
--  faz o mod operar num componente morto, que nunca recebe instancia.
--
--  Dois cenarios possiveis, e o codigo cobre os dois sem saber qual e:
--    a) a engine honra so a 1a entrada  -> um ISM com N mudas, 6 vazios
--    b) a engine honra as 7             -> 7 ISMs com as MESMAS N mudas,
--                                          empilhadas no mesmo ponto
--  Nos dois casos a saida desejada e a mesma: as N mudas repartidas em
--  rodizio entre as 7 culturas. O algoritmo e unico -- junta as transforms
--  de quem tiver mais instancias, zera todos e redistribui.
--
--  ARMADILHAS DO UE4SS RESPEITADAS AQUI (todas ja custaram caro antes):
--   1. '#' num TArray do UE4SS NAO funciona -- use :GetArrayNum(). Foi
--      exatamente isso que quebrou a versao anterior: 'for i = 1, #cs' rodava
--      zero voltas e o diagnostico imprimia lista vazia.
--   2. Ponteiro nulo NAO vira nil, vira userdata truthy. So :IsValid() prova.
--   3. GetInstanceTransform(idx, FTransform& out, bWorldSpace) tem OUT PARAM:
--      devolve (bool, FTransform). Ler so o 1o retorno pega o bool.
--   4. Este callback ja roda na game thread (LoopInGameThreadWithDelay).
-- =====================================================================

local INTERVALO = 3000     -- ms entre passes
local MIN_MUDAS = 7        -- abaixo disso nao ha o que repartir

-- pega componente pelo NOME EXATO da variavel do BP. O ator expoe cada
-- componente como ObjectProperty, entao planta[nome] resolve direto: sem
-- UFunction, sem TArray, sem StaticFindObject -- nao ha o que dar errado.
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

-- le do PROPRIO ator quais componentes a engine usa no estagio colhivel.
-- ProcessRate 1.0 == estagio colhivel (vale pro vanilla e pro nosso BP).
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

-- GetInstanceTransform(InstanceIndex, OutInstanceTransform, bWorldSpace) -- 3 PARAMETROS
-- (Engine.lua:17144-17148). O out param TEM que ser passado como placeholder {},
-- senao o argumento seguinte escorrega pra vaga errada: chamar (i, true) enfia o
-- 'true' no OutInstanceTransform, deixa bWorldSpace vazio e nao volta transform
-- nenhuma. Foi esse o bug do "li so 0 de 9 transforms". O util e o 2o RETORNO.
local function transformDa(c, i)
    local t
    pcall(function()
        local _, out = c:GetInstanceTransform(i, {}, true)
        t = out
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

-- ja repartido? se duas culturas diferentes tem a 1a muda no MESMO ponto,
-- entao estao empilhadas (cenario b) e ainda falta repartir.
local function estaEmpilhado(a, b)
    local pa, pb = posDaInstancia(a, 0), posDaInstancia(b, 0)
    if not (pa and pb) then return nil end            -- indeterminado
    local d = math.abs(pa.X - pb.X) + math.abs(pa.Y - pb.Y) + math.abs(pa.Z - pb.Z)
    return d < 1.0
end

local feitos = {}          -- memo do passe anterior; reconstruido a cada passe
local vistosAgora = {}
local diagnosticado = {}   -- 1 diagnostico por assinatura de problema

local function diag(chave, msg)
    if not CONFIG.Log or diagnosticado[chave] then return end
    diagnosticado[chave] = true
    log("[prisma] " .. msg)
end

-- ---------------------------------------------------------------------
--  RAIO-X do canteiro: uma vez por ator, despeja TUDO no log.
--  Existe porque diagnostico picado custou varias idas e vindas: cada
--  rodada respondia uma pergunta e levantava outra. Isso aqui responde
--  "de que classe e", "quais componentes existem de verdade", "quantas
--  mudas cada um tem" e "qual GrowupProcessSets o ator realmente carrega"
--  de uma vez so.
-- ---------------------------------------------------------------------
local raioXFeito = {}

local function nomeDe(o)
    local n = "?"
    pcall(function() n = o:GetName():ToString() end)
    return n
end

local function raioX(planta, chave)
    if raioXFeito[chave] then return end
    raioXFeito[chave] = true

    local cls = "?"
    pcall(function() cls = planta:GetClass():GetFullName() end)
    log("[raio-x] ator=" .. chave)
    log("[raio-x]   classe=" .. cls)

    -- GrowupProcessSets como o ATOR realmente carrega (nao como o pak diz)
    local ok, err = pcall(function()
        local sets = planta.GrowupProcessSets
        if not sets then log("[raio-x]   GrowupProcessSets = nil"); return end
        local n = sets:GetArrayNum()
        log("[raio-x]   GrowupProcessSets: " .. tostring(n) .. " entradas")
        for i = 1, n do
            local s = sets[i]
            local est, rate, comp = "?", "?", "?"
            pcall(function() est = tostring(s.State) end)
            pcall(function() rate = tostring(s.ProcessRate) end)
            pcall(function() comp = s.TargetCompRef.ComponentProperty:ToString() end)
            log(string.format("[raio-x]     %d) estado=%s rate=%s comp=%s", i, est, rate, comp))
        end
    end)
    if not ok then log("[raio-x]   ERRO lendo GrowupProcessSets: " .. tostring(err)) end

    -- todos os ISMs do ator (agora com GetArrayNum, nao '#')
    local ok2, err2 = pcall(function()
        local classe = StaticFindObject("/Script/Engine.InstancedStaticMeshComponent")
        if not classe then log("[raio-x]   classe ISM nao resolveu"); return end
        local cs = planta:K2_GetComponentsByClass(classe)
        if not cs then log("[raio-x]   K2_GetComponentsByClass -> nil"); return end
        local n = cs:GetArrayNum()
        log("[raio-x]   ISMs no ator: " .. tostring(n))
        for i = 1, n do
            local c = cs[i]
            if alive(c) then
                local qtd, mesh = 0, "?"
                pcall(function() qtd = c:GetInstanceCount() end)
                pcall(function() mesh = nomeDe(c.StaticMesh) end)
                log(string.format("[raio-x]     %-22s mudas=%-4s mesh=%s", nomeDe(c), tostring(qtd), mesh))
            end
        end
    end)
    if not ok2 then log("[raio-x]   ERRO enumerando ISMs: " .. tostring(err2)) end
end

local function repartir(planta)
    if not alive(planta) then return end

    local chave = "?"
    pcall(function() chave = planta:GetFullName() end)
    if string.find(chave, "Default__", 1, true) then return end   -- CDO, nao tem componente
    vistosAgora[chave] = true
    raioX(planta, chave)

    local nomes = alvosColhiveis(planta)
    if #nomes == 0 then
        diag("sem-sets", "nao consegui ler GrowupProcessSets do canteiro -- " ..
             "visual prismatico desligado pra este ator")
        return
    end

    local comps = {}
    local faltando = {}
    for _, n in ipairs(nomes) do
        local c = pegaComp(planta, n)
        if c then comps[#comps + 1] = c else faltando[#faltando + 1] = n end
    end
    if #faltando > 0 then
        diag("faltando", "GrowupProcessSets cita componentes que o ator nao expoe: " ..
             table.concat(faltando, ","))
    end
    if #comps == 0 then return end

    if #comps == 1 then
        diag("uma-entrada", "a engine honra so 1 entrada por estagio -- " ..
             "as outras 6 culturas nao serao alimentadas por ela")
    end

    -- de onde vem as transforms: quem tiver mais instancias
    local maior, nMaior, total = nil, 0, 0
    for _, c in ipairs(comps) do
        local n = conta(c)
        total = total + n
        if n > nMaior then maior, nMaior = c, n end
    end

    if total == 0 then
        feitos[chave] = nil                     -- colhido/arrancado: pode repartir de novo
        return
    end
    if nMaior < MIN_MUDAS then return end       -- ainda brotando

    if feitos[chave] then return end

    -- ja esta repartido? (so da pra saber com 2+ componentes com instancia)
    if #comps > 1 then
        local a, b
        for _, c in ipairs(comps) do
            if conta(c) > 0 then
                if not a then a = c elseif not b then b = c end
            end
        end
        if a and b then
            local emp = estaEmpilhado(a, b)
            if emp == false then feitos[chave] = true; return end   -- ja repartido
        end
    end

    -- 1) guarda as transforms da fonte
    local tr = {}
    for i = 0, nMaior - 1 do
        local t = transformDa(maior, i)
        if t then tr[#tr + 1] = t end
    end
    if #tr < MIN_MUDAS then
        diag("transforms", string.format("li so %d de %d transforms -- adiando", #tr, nMaior))
        return
    end

    -- 2) zera todos e reparte em rodizio
    for _, c in ipairs(comps) do
        if not pcall(function() c:ClearInstances() end) then
            diag("clear", "ClearInstances falhou -- abortei pra nao deixar canteiro pela metade")
            return
        end
    end

    local postos = 0
    for i, t in ipairs(tr) do
        local destino = comps[((i - 1) % #comps) + 1]
        if alive(destino) and pcall(function() destino:AddInstance(t, true) end) then
            postos = postos + 1
        end
    end

    feitos[chave] = true
    if CONFIG.Log then
        log(string.format("planta prismatica: %d mudas repartidas em %d culturas",
                          postos, #comps))
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
