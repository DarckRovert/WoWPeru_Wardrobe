-- ============================================================================
--  LA VENTANA   ·   01-09-2026
-- ============================================================================
--  El marco, el muneco grande del jugador y los botones. Monta dentro la
--  coleccion y no sabe nada de paginas ni de filtros.
--
--  Mientras dure la mudanza se abre con `/armario2`; el viejo sigue en
--  `/armario` para poder comparar. El dia que este terminada, se cambia el
--  comando y se borra el viejo.
-- ============================================================================

PLARM = PLARM or {}
local c = PLARM.color

--  🎨 25-09-2026, GALERIA: la proporcion del marco (arte2/MarcoG, sacado de la
--     propia maqueta). Las medidas de dentro son las de la maqueta (1280x720)
--     pasadas con PLARM.MX / PLARM.MY.
--  🎨 +26 de alto sobre la maqueta: las flechas de pagina no cabian (el
--     dueño). El marco se estira solo en su franja lisa (ver abajo).
local EXTRA = 26
local ANCHO, ALTO = 1062, 600 + EXTRA
--  Lo que ocupa, bajo el muneco, la barra de colores + nombre + como se
--  consigue + el boton de comprar.
local ALTO_FICHA = 118
local LUZ = { 1, 0, -1, 1, -1, 1.05, 1, 1, 1, 0, 1, 1, 1 }

local V          -- la ventana

--  (declarada arriba, junto a `Crear`, porque `Crear` la usa)
--  🔴 LA BANDERA SE APAGA MIENTRAS EL ARMARIO ESTA ABIERTO, NO POR CELDA.
--
--  Ascension hace `SetModelApplyComponents(false)` justo antes de cada
--  `SetUnit` y lo vuelve a encender en la linea siguiente. Copiarlo tal cual
--  aqui NO funciona, y se vio en una captura: al abrir salian las 18 celdas
--  bien, y al volver de la pagina 2 salian quince con el personaje del
--  jugador.
--
--  La razon: en 3.3.5a `SetUnit` **no aplica el equipo en el acto**. Cuando el
--  cliente llega a aplicarlo, la bandera ya se habia vuelto a encender una
--  linea despues. En su cliente ese paso es sincrono; en el nuestro no.
--
--    🎯 Copiar una secuencia que depende del TIEMPO exige comprobar que el
--       tiempo se comporta igual. Aqui no lo hacia, y el sintoma --funciona
--       al abrir, falla al volver-- es exactamente el de una carrera.
--
--  Asi que se saca de la carrera: apagada mientras la ventana esta abierta,
--  encendida al cerrarla. El muneco grande tampoco la necesita, porque se
--  viste con `Undress` + `TryOn`.
local function Componentes(encender)
    if encender then
        if PeruLand_ConComponentes then PeruLand_ConComponentes() end
        --  Y la animacion vuelve a correr al cerrar: fuera del armario los
        --  munecos de la interfaz (ficha de personaje, vestidor) si deben
        --  moverse.

    else
        if PeruLand_SinComponentes then PeruLand_SinComponentes() end
        --  🧊 Y los munecos quietos, como los suyos: solo se mueven las
        --  particulas del objeto. Es su `FreezeSequence`, que aqui se hace
        --  poniendo la velocidad de animacion a 0 desde el DLL.
        --  🧊 CONGELADO MIENTRAS EL ARMARIO ESTA ABIERTO.
        --
        --  🔬 MEDIDO, NO SUPUESTO (03-09-2026). Se probo a congelar SOLO
        --  mientras se llenan las celdas, con la idea de que la velocidad se
        --  graba en el muñeco al arrancar su animacion y despues se podria
        --  apagar la bandera sin descongelar nada. **Es falso.** Dos capturas
        --  separadas 3 s y comparadas por regiones dieron entre 12 % y 26 %
        --  de pixeles distintos en las PIERNAS del maniqui de cada celda --
        --  o sea, el cuerpo seguia moviendose. Al terminar un ciclo de reposo
        --  arranca el siguiente y vuelve a leer velocidad 1.
        --
        --    🎯 La conclusion salio de MEDIR dos capturas, no de mirarlas: a
        --       ojo, un maniqui en reposo lento parece quieto.
        if PeruLand_Congelar then PeruLand_Congelar() end
    end
end

local modelo     -- el muneco grande
local estado     -- la linea de abajo

-- ---------------------------------------------------------------------------
local function Crear()
    local E = PLARM.Contrato.Estado

    V = CreateFrame("Frame", "ProjectJaina_Wardrobe_Frame", UIParent)
    V:SetSize(ANCHO, ALTO)
    V:SetPoint("CENTER")
    V:SetFrameStrata("HIGH")
    V:EnableMouse(true)
    V:SetMovable(true)
    V:RegisterForDrag("LeftButton")
    V:SetScript("OnDragStart", V.StartMoving)
    V:SetScript("OnDragStop", V.StopMovingOrSizing)

    -- Fondo base oscuro y borde dorado pulido (seguridad arquitectónica si falta textura externa)
    PLARM.Fondo(V, { 0.08, 0.08, 0.10 }, 0.96)
    PLARM.Borde(V, { 0.83, 0.69, 0.22 }, 1)

    --  🎨 El marco entero es UNA imagen: borde redondeado, el sol encima del
    --     borde, el titulo «ARMARIO» y el panel del muñeco con su disco.
    --  En TRES tiras para crecer sin deformar las esquinas redondeadas: arriba
    --  (hasta y 640 de la maqueta) y abajo (700-720) a su escala, y la franja
    --  del medio (640-700, bordes rectos) estirada EXTRA.
    local V_ = function(y) return y / 720 * 579 / 1024 end
    local function tira(y0, y1, alto, arriba)
        local t = V:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(PLARM.ARTE2 .. "MarcoG")
        t:SetTexCoord(0, 1, V_(y0), V_(y1))
        t:SetPoint("TOPLEFT", V, "TOPLEFT", 0, -arriba)
        t:SetSize(ANCHO, alto)
    end
    local MYl = function(v) return v * 600 / 720 end
    tira(0, 640, MYl(640), 0)
    tira(640, 700, MYl(60) + EXTRA, MYl(640))
    tira(700, 720, MYl(20), MYl(700) + EXTRA)
    tinsert(UISpecialFrames, "ProjectJaina_Wardrobe_Frame")     -- se cierra con Escape

    --  El titulo va pintado en el marco: el de texto se esconde.
    local titulo = PLARM.Titulo(V, "GUARDARROPA", 300)
    titulo:SetPoint("TOP", 0, -12)
    titulo:Hide(); if titulo.adorno then titulo.adorno:Hide() end

    local MX, MY = PLARM.MX, PLARM.MY
    local cerrar = PLARM.Boton(V, "X", 16.4, 16.4)
    cerrar:SetPoint("CENTER", V, "TOPLEFT", MX(1238), -MY(48))
    cerrar:SetScript("OnClick", function()
        Componentes(true)
        if PeruLand_Descongelar then PeruLand_Descongelar() end
        V:Hide()
    end)

    --  Saldo, arriba a la izquierda
    --  🎨 Arriba de la barra lateral: moneda, el numero grande y «CREDITOS».
    local moneda = PLARM.Icono(V, "GMoneda", MX(30))
    moneda:SetPoint("CENTER", V, "TOPLEFT", MX(37), -MY(49))
    local saldo = PLARM.Texto(V, 13, { 0.95, 0.93, 0.88 })
    saldo:SetPoint("TOPLEFT", V, "TOPLEFT", MX(57), -MY(38))
    local saldoEt = PLARM.Texto(V, 7, { 0.72, 0.70, 0.66 })
    saldoEt:SetPoint("TOPLEFT", saldo, "BOTTOMLEFT", 0, -2)
    saldoEt:SetText("CR\195\137DITOS")
    local sep = V:CreateTexture(nil, "ARTWORK")
    sep:SetTexture("Interface\\Buttons\\WHITE8X8")
    sep:SetVertexColor(0.55, 0.45, 0.25, 0.45)
    sep:SetPoint("TOPLEFT", V, "TOPLEFT", MX(12), -MY(94)); sep:SetSize(MX(96), 1)
    PLARM.Eventos.Registrar("ARMARIO_SALDO", function(cr)
        saldo:SetText(tostring(cr or 0))
    end)
    --  🎨 Abajo de la barra lateral, como la maqueta: ajustes y ayuda.
    for i, info in ipairs({
        { "GEngranaje", "Ajustes", "Pr\195\179ximamente." },
        { "GAyuda", "Ayuda", "Pulsa un conjunto para prob\195\161rtelo. «Aplicar» te lo pone de verdad; «Guardar atuendo» lo guarda para m\195\161s tarde." },
    }) do
        local b = CreateFrame("Button", nil, V)
        b:SetSize(MX(22), MX(22))
        b:SetPoint("CENTER", V, "TOPLEFT", MX(i == 1 and 40 or 79), -MY(669) - EXTRA)
        local t = PLARM.Icono(b, info[1], MX(22)); t:SetPoint("CENTER"); t:SetVertexColor(0.62, 0.6, 0.56)
        b:SetScript("OnEnter", function(s)
            t:SetVertexColor(1, 0.9, 0.7)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(info[2], 1, 0.85, 0.5)
            GameTooltip:AddLine(info[3], 0.85, 0.85, 0.85, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() t:SetVertexColor(0.62, 0.6, 0.56); GameTooltip:Hide() end)
    end

    -- -----------------------------------------------------------------------
    --  Panel izquierdo: el muneco del jugador
    -- -----------------------------------------------------------------------
    local izq = PLARM.Panel(V, c.panel)
    --  🎨 El panel va pintado en el marco (x 32-285, y 68-378): el marco
    --     de codigo solo coloca el muñeco encima, sin fondo ni borde propios.
    --  🎨 GALERIA: el muñeco va en el PANEL DE LA DERECHA (pintado en Marco2,
    --     x 810-1046), sobre el fondo de ambiente del conjunto elegido.
    --  🎨 La imagen del panel derecho de la maqueta: x 980-1264, y 25-400.
    izq:SetPoint("TOPLEFT", V, "TOPLEFT", MX(981), -MY(26))
    izq:SetSize(MX(282), MY(374) + 18)
    for _, r in ipairs({ izq:GetRegions() }) do r:Hide() end
    --  El fondo va en el PANEL, no dentro del muñeco (una textura dentro del
    --  DressUpModel lo deja sin dibujar: memoria muneco-3d-sin-texturas-dentro).
    V.fondoDetalle = izq:CreateTexture(nil, "BACKGROUND")
    V.fondoDetalle:SetAllPoints(izq)
    --  🎨 Filtro oscuro sobre el fondo (el dueño: «no color puro tal cual»).
    V.fondoDetalle:SetVertexColor(0.6, 0.58, 0.55)
    PLARM.PonerFondo(V.fondoDetalle, PLARM.FondoDe(1), MX(282), MY(374) + 18)
    --  Se funde con el panel por abajo, como la maqueta.
    local fundido = izq:CreateTexture(nil, "BORDER")
    fundido:SetTexture(PLARM.ARTE2 .. "GFundido")
    fundido:SetPoint("BOTTOMLEFT"); fundido:SetPoint("BOTTOMRIGHT")
    fundido:SetHeight(MY(90))
    --  🌑 Sombra en el suelo: sin ella el muñeco parece flotar (el dueño).
    --     La de Blizzard teñida: nuestras TGA oscuras no se dibujan (doc 71).
    V.sombraDetalle = izq:CreateTexture(nil, "ARTWORK")
    V.sombraDetalle:SetTexture("Textures\\ShadowBlob")
    V.sombraDetalle:SetVertexColor(0, 0, 0)
    V.sombraDetalle:SetAlpha(0.8)
    V.sombraDetalle:SetSize(MX(170), MY(40))
    V.sombraDetalle:SetPoint("CENTER", izq, "BOTTOM", 0, MY(48))
    V.sombraDetalle:Hide()   -- fuera: se veia como un agujero negro
    --  🎨 El borde redondeado del panel ENCIMA de la imagen (sin el, la imagen
    --     llegaba al canto y el panel no tenia contorno lateral: el dueño).
    local bordePanel = CreateFrame("Frame", nil, V)
    bordePanel:SetPoint("TOPLEFT", V, "TOPLEFT", MX(976), -MY(22))
    bordePanel:SetSize(MX(291), MY(671) + EXTRA)
    bordePanel:SetFrameLevel(izq:GetFrameLevel() + 10)
    local bt = bordePanel:CreateTexture(nil, "OVERLAY")
    bt:SetTexture(PLARM.ARTE2 .. "GPanelBorde"); bt:SetTexCoord(0, 1, 0, 590 / 1024)
    bt:SetAllPoints(bordePanel)
    cerrar:SetFrameLevel(izq:GetFrameLevel() + 12)

    modelo = CreateFrame("DressUpModel", nil, izq)
    V.modeloGrande = modelo
    modelo:SetFrameLevel(izq:GetFrameLevel() + 4)   -- ver la nota en Ficha.lua
    --  🎨 Mas grande (el dueño: «esta volando, tiene que ser mas grande»):
    --     el tamaño lo da el ANCHO del marco, asi que el muñeco sobresale a
    --     los lados del panel y pisa la sombra.
    modelo:SetPoint("TOPLEFT", -MX(38), -MY(14))
    modelo:SetPoint("BOTTOMRIGHT", PLARM.MX(38), PLARM.MY(30))
    modelo:EnableMouse(true)
    modelo:EnableMouseWheel(true)

    local girando, ultimoX = false, 0
    modelo:SetScript("OnMouseDown", function() girando, ultimoX = true, GetCursorPosition() end)
    modelo:SetScript("OnMouseUp", function() girando = false end)
    modelo:SetScript("OnUpdate", function(self)
        if not girando then return end
        local x = GetCursorPosition()
        self:SetRotation((self:GetFacing() or 0) + (x - ultimoX) * 0.01)
        ultimoX = x
    end)
    --  🪤 EL ZOOM LLEVA TOPE Y SE DEVUELVE AL REENCUADRAR. Sin tope, unas
    --  vueltas de rueda empujaban al muneco fuera del cuadro y no volvia con
    --  ningun conjunto: el pergamino se quedaba vacio para siempre y parecia
    --  que el armario estaba roto.
    modelo:SetScript("OnMouseWheel", function(self, d)
        local z = (self.zoom or 0) + d * 0.4
        if z < -4 then z = -4 elseif z > 4 then z = 4 end
        self.zoom = z
        self:SetPosition(z, 0, 0)
    end)

    local function Reencuadrar()
        --  🔴 LA SECUENCIA ES DE ASCENSION, Y EL ORDEN IMPORTA. De su
    --  `StoreCollectionFrameModelPreviewInitModel` (VanityStore.lua):
    --
    --      self:SetCamera(0)
    --      self:SetUnit("player")
    --      self:RefreshUnit()          <-- lo que nos faltaba
    --      self:SetFacing(...)
    --      self:SetModelScale(...)
    --
    --  Con solo `SetUnit` el marco se queda VACIO y `GetModel()` devuelve un
    --  modelo -asi que parece cargado-. Se comprobo con un muneco suelto en
    --  la esquina de la pantalla, sin panel ni nada encima: tambien salia
    --  vacio. O sea que no era la ventana ni el nivel de dibujo.
    --
    --    🎯 Cuando algo no se ve y "existe", la respuesta no esta en tu
    --       codigo: esta en el codigo de quien ya lo tiene funcionando.
        --  🔴 LO MINIMO QUE YA FUNCIONA, Y NADA MAS.
        --
        --  El vestidor de Blizzard -que SI se ve- hace una sola cosa con su
        --  muneco: `SetUnit("player")`. Yo le habia anadido camara, luz,
        --  escala y posicion copiadas de Ascension... que tiene otro cliente.
        --  Cualquiera de esas cuatro deja el marco NEGRO, y como el modelo si
        --  existe (`GetModel()` devuelve algo) parece que esta cargado.
        --
        --    🎯 Cuando algo equivalente ya funciona en el propio juego, se
        --       copia ESO. Añadir pasos "por si acaso" no es mas seguro: cada
        --       paso de mas es una forma nueva de romperlo.
        pcall(function()
            modelo:SetUnit("player")
            modelo:SetRotation(0.4)
            modelo.zoom = 0
        end)
    end

    --- Viste el muneco con lo PUESTO mas lo PENDIENTE, que es lo que Ascension
    --- ensena: la vista previa es "como quedarias si le das a Aplicar".
    --  🔴 UN TOKEN, PARA QUE SOLO HAYA UN INTENTO VIVO A LA VEZ.
    --
    --  `VestirJugador` se llama en cada `PENDING_APPEARANCE_CHANGED` y en
    --  cada `APPEARANCE_CHANGED`, y con la rejilla activa esos eventos
    --  pueden llegar varias veces por segundo. Cada llamada creaba un
    --  `CreateFrame` + `OnUpdate` NUEVO sin cancelar el anterior: en pocos
    --  segundos habia decenas de temporizadores llamando a `SetUnit` y
    --  `TryOn` sobre el MISMO muneco al mismo tiempo, pisandose unos a
    --  otros. El registro lo delato: `vuelta=1` una y otra vez, nunca
    --  `vuelta=6` -- cada intento moria antes de progresar porque el
    --  siguiente ya le habia cambiado el modelo por debajo.
    --
    --    🎯 Un evento que puede repetirse necesita un token que cancele el
    --       intento anterior. Sin eso, cada evento nuevo no se SUMA al
    --       trabajo: LO ESTORBA.
    local tokenVestir = 0

    local function VestirJugador()
        tokenVestir = tokenVestir + 1
        local miToken = tokenVestir

        Reencuadrar()

        --  Lo que hay que tener en la cache ANTES de armar el muneco: lo que
        --  llevas puesto (o `SetUnit` falla) y lo que te vas a probar.
        local piezas, ids = {}, {}
        for cat, id in pairs(E.puesto)     do piezas[cat] = id end
        for cat, id in pairs(V.montaje or {}) do piezas[cat] = id end
        for _, id in pairs(piezas) do ids[#ids + 1] = id end
        for _, id in ipairs(ids) do PLARM.PedirFicha(id) end

        --  🔴 Y SE REINTENTA HASTA QUE EL CLIENTE PUEDE. No hay ningun aviso
        --  de "ya tengo la ficha": se prueba, se mira si el muneco se armo, y
        --  si no, se vuelve. Es lo mismo que hace Ascension con su
        --  `ItemQueryListener`, que aqui no existe.
        local vueltas = 0
        local g = CreateFrame("Frame")
        local reloj = 0
        g:SetScript("OnUpdate", function(s, e)
            if tokenVestir ~= miToken then s:SetScript("OnUpdate", nil) return end
            reloj = reloj + e
            if reloj < 0.5 then return end
            reloj = 0
            vueltas = vueltas + 1

            local faltan = 0
            for _, id in ipairs(ids) do
                if not PLARM.PedirFicha(id) then faltan = faltan + 1 end
            end

            --  🔴 NO SE TOCA EL MUNECO HASTA QUE ESTAN TODAS LAS FICHAS.
            --
            --  El dueno lo dijo del muneco grande: «cuando doy clic tambien
            --  hay como 5 parpadeos». Era el mismo fallo que en la rejilla:
            --  este bloque rehacia el personaje --`SetUnit`, `Undress`, un
            --  `TryOn` por pieza-- **en cada vuelta**, hasta que el cliente
            --  conocia todo. Cinco vueltas, cinco reconstrucciones, cinco
            --  parpadeos.
            --
            --  Ascension no reintenta: su `UpdateModel` hace `SetUnit` +
            --  `Dress` **una sola vez**, cuando salta el evento
            --  (`AppearancePlayerModelMixin.lua:296`). Lo que espera es el
            --  DATO, no el modelo.
            --
            --    🎯 Reintentar no es esperar. Si falta un dato que viene solo,
            --       rehacer el trabajo mientras llega no lo adelanta: solo lo
            --       hace visible.
            --
            --  🪤 Y el tope no sobra: una pieza que el servidor no conoce no
            --  llega nunca, y sin el el muneco se quedaria vacio para siempre.
            if faltan > 0 and vueltas < 30 then return end
            s:SetScript("OnUpdate", nil)      -- se arma una vez y se acabo

            --  🔴 LA LUZ SE REINICIA CADA VEZ QUE SE LLAMA A `RefreshUnit`.
            --  Solo se ponia una vez, al principio, fuera de este bucle: cada
            --  vuelta siguiente dejaba el muneco A OSCURAS, indistinguible de
            --  vacio en una captura. `GetModel()` seguia devolviendo algo
            --  -- por eso `hay=true`-- pero no se veia nada.
            --  🎯 `TryOn` a secas, sin preguntar antes si el cliente conoce
            --  la pieza: PEDIRLO ES INTENTARLO. Esperar la ficha antes de
            --  probar era esperar a algo que solo pasaba si probabas.
            local probadas, sinFicha = 0, 0
            pcall(function()
                --  🔴 REINICIAR EL MUNECO EN CADA VUELTA, ANTES DE PROBAR.
                --
                --  `TryOn` NO SUSTITUYE una ranura ya ocupada: se llama, no
                --  da error y no cambia nada. El muneco grande hacia
                --  `SetUnit` UNA vez al abrir y luego solo acumulaba pruebas,
                --  asi que al pulsar un arma el titulo cambiaba y el modelo
                --  seguia con la anterior -- «la previsualizacion no funciona,
                --  aplicar si». Aplicar si funcionaba porque ahi el cliente
                --  rehace el personaje entero.
                --
                --  Las celdas de la rejilla nunca lo tuvieron: ellas rehacen
                --  el modelo en cada vuelta, justo antes de probar. La
                --  respuesta estaba dentro del propio armario.
                --
                --    🎯 Cuando una parte del programa hace bien lo mismo que
                --       otra hace mal, compara las dos antes de teorizar.
                --  🔑 LA MISMA SECUENCIA QUE LA CELDA, QUE SI FUNCIONA.
                --
                --  La vista previa de un ARMA no se dibujaba aqui aunque el
                --  dato llegara bien -- medido: la pieza entraba en el
                --  montaje, se probaba la correcta y el `TryOn` se ejecutaba.
                --  Las celdas de la rejilla si la dibujaban con el MISMO
                --  `TryOn`.
                --
                --  Comparando las dos campo a campo, la diferencia era
                --  `SetCamera(0)` ANTES de `SetUnit`: sin el, el marco no
                --  vuelve a armar el personaje y el `TryOn` se pierde.
                --
                --    🎯 Cuando una parte del programa hace bien lo mismo que
                --       otra hace mal, se comparan LAS DOS campo a campo. Es
                --       lo que resolvio el muneco vacio, y aqui se tardo en
                --       aplicar por ponerse a teorizar primero.
                modelo:SetCamera(0)
                modelo:SetUnit("player")
                --  ⚠️ Desnudar SOLO si hay conjunto. La celda tampoco desnuda
                --  para una pieza suelta: quitarle todo para ensenar un arco
                --  deja un cuerpo desnudo con un arco.
                if V.montaje and next(V.montaje) and #ids > 3 then modelo:Undress() end
                --  🔴 EL ORDEN DE `TryOn` DECIDE QUE ARMA SE VE, Y `pairs`
                --  NO TIENE ORDEN.
                --
                --  El dueno lo describio exacto: «hago clic en un arma,
                --  aparece la correcta, y despues de 1s vuelve un arma que
                --  nunca vi, parece un fusil, y sale la misma para todos».
                --  Ese fusil era el `Almirante de Kul Tiras`, su arma a
                --  distancia: se probaba DESPUES y pisaba a la elegida.
                --
                --  El cliente dibuja UNA arma en la mano; la ultima que
                --  reciba gana. Con `pairs` el orden cambia en cada vuelta,
                --  asi que el resultado parpadeaba.
                --
                --    🎯 Si el ultimo en escribir gana, el orden no puede ser
                --       casual. Y lo que acaba de elegir el jugador tiene que
                --       escribirse el ULTIMO.
                --  🔴 Y LAS ARMAS, DE LA ULTIMA A LA PRIMERA.
                --
                --  Ordenar de menor a mayor parecia lo natural y era justo
                --  al reves: la ranura 17 (a distancia) se probaba DESPUES
                --  de la 15 (mano principal) y la pisaba. El dueno veia su
                --  arma un segundo y luego el arma de fuego, siempre la
                --  misma, y nunca la que habia elegido.
                --
                --  El cliente dibuja una sola arma: manda la ultima. Asi que
                --  la mano principal tiene que ir la ULTIMA de las tres.
                --
                --    🎯 Un orden «natural» no es un orden correcto. El que
                --       vale es el que deja al final lo que debe verse.
                local PESO = { [17] = 1, [16] = 2, [15] = 3 }   -- distancia < secundaria < principal
                local orden = {}
                for cat in pairs(piezas) do orden[#orden + 1] = cat end
                table.sort(orden, function(a, b)
                    local pa, pb = PESO[a], PESO[b]
                    if pa and pb then return pa < pb end
                    if pa then return false end      -- las armas, al final
                    if pb then return true end
                    return a < b
                end)
                for _, cat in ipairs(orden) do
                    local id = piezas[cat]
                    if GetItemInfo(id) then modelo:TryOn(id); probadas = probadas + 1
                    else sinFicha = sinFicha + 1 end
                end
                --  Y lo elegido, al final: es lo que el jugador quiere ver.
                for _, id in pairs(V.montaje or {}) do
                    if GetItemInfo(id) then modelo:TryOn(id) end
                end
            end)

            --  se para cuando el muneco existe Y no falta ninguna ficha
            local hay = false
            pcall(function() hay = modelo:GetModel() ~= nil end)
            --  ⚠️ Aqui habia un mensaje al chat por cada vuelta. Servia para
            --  diagnosticar y se quedo puesto: llenaba el chat del dueno. Si
            --  hace falta volver a verlo, ponlo detras de PLARM.DEPURAR.
            if PLARM.DEPURAR then
                DEFAULT_CHAT_FRAME:AddMessage(string.format(
                    "|cff00FFFF[VJ]|r vuelta=%d ids=%d faltan=%d hay=%s",
                    vueltas, #ids, faltan, tostring(hay)))
            end
            --  🔴 AQUI PONIA `vueltas >= 4`, Y ESO **OBLIGABA A REPETIR CUATRO
            --  VECES** aunque el muneco ya estuviera bien a la primera.
            --
            --  Era la causa exacta de lo que reporto el dueno: «cuando doy
            --  clic tambien hay como 5 parpadeos». Cada vuelta rehacia el
            --  personaje entero, asi que el minimo de vueltas ERA el numero de
            --  parpadeos. Se puso para dar tiempo a que llegaran las fichas --
            --  pero eso ya se resuelve esperando el DATO, mas arriba, sin
            --  tocar el modelo.
            --
            --    🎯 Un «reintenta unas cuantas veces por si acaso» es una
            --       espera disfrazada de trabajo. Cuesta lo mismo esperar
            --       bien, y no se ve.
            --
            --  Ya se corta arriba en cuanto estan todas las fichas; esto solo
            --  queda como red por si algo se cuela.
            if hay or vueltas > 120 then
                s:SetScript("OnUpdate", nil)
            end
        end)
    end

    V.VestirJugador = VestirJugador
    PLARM.Eventos.Registrar("PENDING_APPEARANCE_CHANGED", VestirJugador)
    PLARM.Eventos.Registrar("APPEARANCE_CHANGED", VestirJugador)

    -- -----------------------------------------------------------------------
    --  LA FICHA DEL CONJUNTO, debajo del muneco que ya hay
    --
    --  🔴 Esto estuvo un rato en una VENTANA APARTE, con su propio muneco. El
    --  dueno lo corto y tenia razon:
    --
    --      «no es necesario otro muneco ya que se puede reutilizar el que ya
    --       se tiene en la interfaz... solo una barra adicional para los
    --       colores y listo»
    --
    --  La ventana aparte duplicaba un modelo, tapaba la rejilla y costo tres
    --  intentos de colocacion. Esto son cuatro elementos bajo el muneco.
    --
    --    🎯 Antes de anadir una ventana, mira si lo que hace ya esta en
    --       pantalla.
    -- -----------------------------------------------------------------------
    --  🎨 El solecito con sus dos lineas (y 411 en la maqueta).
    local solito = PLARM.Icono(V, "GSolito", 21)
    solito:SetPoint("CENTER", V, "TOPLEFT", MX(1115), -MY(411) - 18)
    for _, lado in ipairs({ -1, 1 }) do
        local l = V:CreateTexture(nil, "ARTWORK")
        l:SetTexture("Interface\\Buttons\\WHITE8X8")
        l:SetVertexColor(0.62, 0.5, 0.28, 0.5)
        l:SetSize(MX(95), 1)
        l:SetPoint(lado < 0 and "RIGHT" or "LEFT", solito, lado < 0 and "LEFT" or "RIGHT", lado * 6, 0)
    end
    local fichaNombre = PLARM.Texto(V, 17, { 0.96, 0.94, 0.9 })
    fichaNombre:SetPoint("TOP", V, "TOPLEFT", MX(1122), -MY(428) - 18)
    fichaNombre:SetWidth(MX(270))
    fichaNombre:SetJustifyH("CENTER")

    local fichaSub = PLARM.Texto(V, 10, c.textoSuave)
    fichaSub:SetPoint("TOP", fichaNombre, "BOTTOM", 0, -6)
    fichaSub:SetJustifyH("CENTER")

    --  La barra de colores. Se rellena sola cuando el conjunto tiene mas de
    --  una variante, y desaparece cuando no.
    local muestras = {}
    --  🔑 LA RANURA DE LO QUE SE ESTA MIRANDO.
    --
    --  Hace falta para las muestras de color: un color es la MISMA pieza en
    --  otro tono, asi que va a la misma ranura. Sin esto, pulsar una muestra
    --  no hacia nada -- ver el comentario del clic, mas abajo.
    local mirandoCat = nil
    local function PintarColores(alternativas, actual)
        for _, b in ipairs(muestras) do b:Hide() end
        muestras = {}
        --  🎨 25-09-2026, el dueño: «los colores aún no» -- no se regalan
        --     conjuntos con variantes todavia. Se apagan, no se borran.
        do return end
        if not alternativas or #alternativas <= 1 then return end

        local LADO, HUECO, POR_FILA = 20, 3, 11
        for i, alt in ipairs(alternativas) do
            local fila, col = math.floor((i - 1) / POR_FILA), (i - 1) % POR_FILA
            local b = CreateFrame("Button", nil, V)
            b:SetSize(LADO, LADO)
            b:SetPoint("TOPLEFT", fichaSub, "BOTTOMLEFT",
                       col * (LADO + HUECO), -6 - fila * (LADO + HUECO))

            --  🎨 El color sale de la TEXTURA de la pieza, no del nombre del
            --  archivo (`modelos/color_variante.py`). Los nombres de Ascension
            --  -`fel2`, `chi`, `iii`- no valen para un jugador y cambian de
            --  una familia a otra.
            local hex = alt.hex or "808080"
            PLARM.Fondo(b, { tonumber(hex:sub(1,2),16)/255,
                             tonumber(hex:sub(3,4),16)/255,
                             tonumber(hex:sub(5,6),16)/255 }, 1)
            PLARM.Borde(b, alt.id == actual and c.oroClaro or c.borde, 1)

            --  El nombre del color, solo al pasar por encima: es informacion
            --  de segundo orden y ocuparia el sitio de lo que se compara.
            b:SetScript("OnEnter", function(s)
                GameTooltip:SetOwner(s, "ANCHOR_TOP")
                GameTooltip:SetText(alt.color ~= "" and alt.color or "original")
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:SetScript("OnClick", function()
                --  🪤 LA RANURA VIAJA CON EL CLIC, NO SE BUSCA.
                --
                --  El manejador de `FICHA_PULSADA`, cuando no le dan ranura,
                --  la busca entre las entradas de la pagina. Eso funciona para
                --  una celda -- esta en la pagina-- y **no puede funcionar
                --  para una muestra de color**: desde que las piezas se
                --  agrupan por familia, la rejilla solo enseña el color
                --  representante y las demas variantes no aparecen por
                --  ninguna parte. Se quedaba sin ranura y no pasaba nada:
                --  cambiaba el nombre de la ficha y el muñeco seguia igual.
                --
                --    🎯 Un dato que el que llama SI tiene no se busca despues:
                --       se pasa. Buscarlo solo funciona mientras el sitio
                --       donde se busca lo contenga, y eso cambia.
                --  🔑 La ranura de la PROPIA variante si viene, y la de lo
                --  que se esta mirando como respaldo. La suya es mas fiable:
                --  `mirandoCat` se queda de un clic anterior y puede ser nil
                --  o de otra cosa.
                PLARM.Eventos.Disparar("FICHA_PULSADA",
                                       { id = alt.id,
                                         cat = alt.cat or mirandoCat })
            end)
            muestras[#muestras + 1] = b
            --  🔬 Para poder pulsarlas desde la sonda: sin esto no hay forma
            --  de comprobar el selector de color sin un raton.
            PLARM._muestras = muestras
        end
    end

    local fichaComo = PLARM.Texto(V, 10, c.textoTenue)
    fichaComo:SetPoint("TOP", fichaSub, "BOTTOM", 0, -9)
    fichaComo:SetWidth(MX(270))
    fichaComo:SetJustifyH("CENTER")

    --  ⚠️ A la DERECHA del panel del muneco, no debajo: abajo estan Aplicar
    --  y Cancelar, y se solapaban.
    local comprar = PLARM.Boton(V, "Comprar", 100, 26, true)
    comprar:SetPoint("BOTTOMRIGHT", izq, "BOTTOM", -3, MY(10))
    comprar:Hide()

    --  🔑 RECARGAR: EL PRIMER USO REAL DE LA EXTENSION DEL CLIENTE.
    --
    --  En 3.3.5a no existe ninguna API de Lua para abrir una direccion --
    --  Blizzard la quito--, asi que el plan era ensenar la direccion en una
    --  cajita para copiarla a mano. El dueno lo vio venir: «necesitabamos la
    --  opcion de hacer clic y enviarlo a una pagina web».
    --
    --  Con la extension es un clic. Sin ella, la cajita: quien juegue con un
    --  cliente normal tiene que poder recargar igual.
    --
    --    🎯 Una capacidad nueva no puede volverse un requisito. Si la
    --       extension falta, la accion sigue existiendo, mas incomoda.
    local RECARGA = "https://darckrovert.github.io/ProjectJaina_Web/tienda.html"

    local recargar = PLARM.Boton(V, "Recargar", 96, 26)
    recargar:ClearAllPoints()
    recargar:SetPoint("LEFT", comprar, "RIGHT", 6, 0)
    recargar:Hide()
    recargar:SetScript("OnClick", function()
        if PeruLand_AbrirWeb then
            PeruLand_AbrirWeb(RECARGA)
            estado:SetText("Te abri la pagina de recarga en el navegador.")
        else
            --  Sin extension: la direccion en una caja ya seleccionada, para
            --  que baste Ctrl+C.
            StaticPopup_Show("WOWPERU_WARDROBE_RECARGA")
        end
    end)

    StaticPopupDialogs["WOWPERU_WARDROBE_RECARGA"] = {
        text = "Copia esta direccion y abrela en tu navegador:",
        button1 = "Cerrar",
        hasEditBox = 1, editBoxWidth = 260,
        timeout = 0, whileDead = 1, hideOnEscape = 1,
        OnShow = function(self)
            local caja = self.editBox or _G[self:GetName() .. "EditBox"]
            if caja then caja:SetText(RECARGA); caja:HighlightText() end
        end,
    }
    StaticPopupDialogs["PERULAND_ARMARIO_RECARGA"] = StaticPopupDialogs["WOWPERU_WARDROBE_RECARGA"]

    --- Rellena la ficha con lo que diga el servidor de ese conjunto.
    local mirando
    function V.MirarConjunto(id)
        mirando = id
        fichaNombre:SetText("")
        fichaSub:SetText("")
        fichaComo:SetText("")
        PLARM.Ver(comprar, false)
        PLARM.Ver(recargar, false)
        PintarColores(nil)

        --  Canal propio: si compartiera el de la rejilla, cambiar de pagina
        --  anularia esta peticion y la ficha se quedaria en blanco.
        C_Appearance.GetAppearanceDetails(id, function(d)
            if not d or mirando ~= id then return end
            local r = PLARM.RAREZAS[d.rareza] or PLARM.RAREZAS[1]
            fichaNombre:SetText(d.nombre or "")
            PLARM.PonerFondo(V.fondoDetalle, PLARM.FondoDe(id, d.nombre), MX(282), MY(374) + 18)
            fichaSub:SetText(string.format("%s  \194\183  %d de %d piezas",
                             PLARM.RarezaTexto(d.rareza), d.t or 0, d.total or 0))

            local como = d.comoTexto
            if not como or como == "" then
                como = ({ tienda = "Se compra en la tienda.",
                          logro  = "Se desbloquea con un logro.",
                          evento = "Se consigue en un evento.",
                          mision = "Se consigue con una mision.",
                          gratis = "Lo tienen todos." })[d.como] or ""
            end

            local tengoTodo = (d.t or 0) >= (d.total or 1)
            if (d.precio or 0) > 0 and not tengoTodo then
                --  🪤 El boton NO tiene `SetText`: su texto vive en
                --  `b.etiqueta`, porque esta hecho con la textura del juego
                --  partida en tres piezas. Llamar a `SetText` no da error y
                --  no cambia nada -- el precio simplemente no aparecia.
                comprar.etiqueta:SetText("Comprar  " .. d.precio)
                comprar:SetScript("OnClick", function()
                    PLARM.Contrato.Mandar("comprar|" .. id)
                end)
                PLARM.Ver(comprar, true)
                --  Solo cuando NO te alcanza: ofrecer recargar a quien puede
                --  pagar es ruido, y a quien no puede es lo unico util.
                PLARM.Ver(recargar, (E.creditos or 0) < (d.precio or 0))
            end
            fichaComo:SetText(como ~= "" and ("|T" .. PLARM.ARTE2 .. "GCandadoT:12:12:0:0:32:32:0:17:0:17|t  " .. como) or "")
            --  🔴 Y LAS PIEZAS DE LOS OTROS COLORES, EN UN MENSAJE.
            --
            --  Las variantes NO estan en la pagina -- la rejilla solo ensena
            --  la familia--, asi que sus piezas nunca se habian pedido. Y
            --  como una celda no puede pedir por su cuenta (esa regla existe
            --  para no inundar al servidor), al pulsar un color no pasaba
            --  nada: «siempre veo lo mismo, solo parpadea el primero».
            --
            --    🎯 Una regla que impide pedir obliga a que ALGUIEN pida. Si
            --       se cierra una puerta, hay que abrir la otra.
            --  🪤 Solo para CONJUNTOS. `PedirPiezasDePagina` pide las piezas
            --  que componen unos conjuntos; pasarle ids de piezas sueltas es
            --  preguntar por las piezas de una pieza. No da error -- devuelve
            --  vacio-- y ese es justo el tipo de llamada que luego cuesta
            --  entender cuando algo no llega.
            if (d.total or 1) > 1 then
                local otros = {}
                for _, alt in ipairs(d.alternativas or {}) do otros[#otros + 1] = alt.id end
                if #otros > 0 then C_ItemSet.PedirPiezasDePagina(otros) end
            end

            PintarColores(d.alternativas, id)
        end, "ficha")
    end

    --  Tras comprar, refrescar: el jugador tiene que ver que ya es suyo.
    PLARM.Eventos.Registrar("WEB_SHOP_PURCHASE_SUCCESS", function()
        if mirando then V.MirarConjunto(mirando) end
    end)

    -- -----------------------------------------------------------------------
    --  Botones de abajo
    -- -----------------------------------------------------------------------
    --  🎨 GALERIA: los tres apilados al pie del panel de la derecha.
    local aplicar = PLARM.BotonG(V, "Aplicar", MX(252), MY(47), true, "GSolito")
    aplicar:SetPoint("TOPLEFT", V, "TOPLEFT", MX(994), -MY(523) - EXTRA)
    --  Se saca a una funcion con nombre para poder dispararla tambien desde
    --  el control remoto de pruebas (Sonda.lua), sin simular un clic.
    --  🪄 TRANSFIGURAR: las ordenes `.transmog aplicar` salen DE UNA EN UNA,
    --     con aire entre ellas. Son mensajes de chat, y nueve seguidos
    --     desconectan al jugador por inundacion (ver arriba).
    local colaTmog, relojTmog = {}, CreateFrame("Frame")
    relojTmog:Hide()
    relojTmog:SetScript("OnUpdate", function(self, dt)
        self.t = (self.t or 0) + dt
        if self.t < 0.4 then return end
        self.t = 0
        local o = table.remove(colaTmog, 1)
        if not o then self:Hide() return end
        -- o[1] = objeto (appearanceId), o[2] = ranura (slotId), o[3] = creditos (boolean)
        local modoPago = o[3] and "creditos" or "oro"
        PLARM.Contrato.Mandar(string.format("tmog|%d|%d|%s", o[2], o[1], modoPago))
    end)
    local function Transfigurar(objeto, ranura, creditos)
        colaTmog[#colaTmog + 1] = { objeto, ranura, creditos }
        relojTmog:Show()
    end
    PLARM.Transfigurar = Transfigurar

    --  🪄 01-10-2026 (el dueño): transfigurar SOLO en Ventormenta y Ogrimmar,
    --     15 de oro por pieza O 5 creditos PeruLand. Quitar, gratis y en
    --     cualquier sitio. Lo hace cumplir el SERVIDOR (cs_transmog.cpp,
    --     tmog-capital-creditos-v1); esto solo lo explica antes de cobrar.
    --  🔴 Si se cambia el precio en el servidor (transmog.conf CopperCost /
    --     Peruland.Transmog.Creditos), cambiarlo TAMBIEN aqui.
    PLARM.TMOG_ORO, PLARM.TMOG_CRED = 15, 5
    local function EnCapital()
        local z = GetRealZoneText() or ""
        return z == "Ventormenta" or z == "Ciudad de Ventormenta" or z == "Stormwind City"
            or z == "Orgrimmar"
    end
    PLARM.EnCapitalTmog = EnCapital

    local function Aplicar2(modo)
        local hayTmog = false
        for cat, id in pairs(V.montaje or {}) do
            if V.transmog and V.transmog[cat] == id then hayTmog = true end
        end
        if hayTmog and not modo then
            if not EnCapital() then
                StaticPopup_Show("WOWPERU_WARDROBE_TMOG_LEJOS")
                return
            end
            local n = 0
            for cat, id in pairs(V.montaje or {}) do
                if V.transmog and V.transmog[cat] == id then n = n + 1 end
            end
            --  🪤 StaticPopup_Show de 3.3.5a solo pasa DOS valores al texto
            --     (el tercero revienta en SetFormattedText): se escribe aqui.
            StaticPopupDialogs["WOWPERU_WARDROBE_TMOG_PAGO"].text = string.format(
                "Transfigurar %d pieza(s).\n\nCuesta %d de oro, o %d Tokens Andinos.\n¿Cómo quieres pagar?",
                n, n * PLARM.TMOG_ORO, n * PLARM.TMOG_CRED)
            StaticPopup_Show("WOWPERU_WARDROBE_TMOG_PAGO")
            return
        end
        local creditos = (modo == "creditos")
        --  Un solo mensaje con todo el conjunto, como la v1. Nueve mensajes
        --  seguidos desconectan al jugador por inundacion.
        local trozos = {}
        for cat, id in pairs(V.montaje or {}) do
            if V.transmog and V.transmog[cat] == id then
                --  Una TRANSFIGURACION: va por el nucleo (cobra y valida), y se
                --  quita el cosmetico del armario de esa ranura, que si no
                --  la taparia (el armario manda sobre la transfiguracion).
                trozos[#trozos + 1] = cat .. ":0"
                Transfigurar(id, cat, creditos)
            else
                trozos[#trozos + 1] = cat .. ":" .. id
            end
        end
        if #trozos == 0 then
            estado:SetText("Elige un conjunto primero.")
            return
        end
        PLARM.Contrato.Mandar("vestir|" .. table.concat(trozos, ","))
        estado:SetText("Aplicando...")
        V.transmog = {}
    end
    PLARM.Aplicar2 = function(modo) Aplicar2(modo) end
    aplicar:SetScript("OnClick", function() Aplicar2() end)

    --  Mismo arreglo que WOWPERU_WARDROBE_QUITAR: encima del armario y con
    --  fondo solido (si no, sale debajo y se transparenta).
    function PLARM.PopupEncima(self, mostrar)
        if mostrar then
            self:SetFrameStrata("TOOLTIP")
            if not self.PLFondo then
                self.PLFondo = self:CreateTexture(nil, "BACKGROUND")
                self.PLFondo:SetTexture(0.04, 0.04, 0.05, 0.96)
                self.PLFondo:SetPoint("TOPLEFT", 11, -11)
                self.PLFondo:SetPoint("BOTTOMRIGHT", -11, 11)
            end
            self.PLFondo:Show()
        else
            self:SetFrameStrata("DIALOG")
            if self.PLFondo then self.PLFondo:Hide() end
        end
    end
    StaticPopupDialogs["WOWPERU_WARDROBE_TMOG_PAGO"] = {
        text = "",   -- se rellena al mostrarla (ver Aplicar2)
        button1 = "Pagar con oro", button2 = "Cancelar", button3 = "Pagar con Tokens",
        OnAccept = function() Aplicar2("oro") end,
        OnAlt = function() Aplicar2("creditos") end,
        OnShow = function(self) PLARM.PopupEncima(self, true) end,
        OnHide = function(self) PLARM.PopupEncima(self, false) end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs["PERULAND_ARMARIO_TMOG_PAGO"] = StaticPopupDialogs["WOWPERU_WARDROBE_TMOG_PAGO"]

    StaticPopupDialogs["WOWPERU_WARDROBE_TMOG_LEJOS"] = {
        text = "Para transfigurar tienes que estar en Ventormenta u Orgrimmar.\n\n(Quitar una transfiguración se puede en cualquier sitio.)",
        button1 = "Entendido",
        OnShow = function(self) PLARM.PopupEncima(self, true) end,
        OnHide = function(self) PLARM.PopupEncima(self, false) end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs["PERULAND_ARMARIO_TMOG_LEJOS"] = StaticPopupDialogs["WOWPERU_WARDROBE_TMOG_LEJOS"]

    --  🔑 GUARDAR ATUENDO: pide el nombre y lo manda. Lo que se guarda es lo
    --  que llevas PUESTO segun el servidor, no lo que crea el addon -- si no,
    --  dos sitios tendrian su propia idea de como vas vestido.
    local guardar = PLARM.BotonG(V, "Guardar atuendo", MX(252), MY(41), false, "GMarcador")
    guardar:SetPoint("TOPLEFT", V, "TOPLEFT", MX(994), -MY(580) - EXTRA)
    guardar:SetScript("OnClick", function()
        StaticPopup_Show("WOWPERU_WARDROBE_GUARDAR")
    end)

    StaticPopupDialogs["WOWPERU_WARDROBE_GUARDAR"] = {
        text = "Nombre para este atuendo:",
        button1 = "Guardar", button2 = "Cancelar",
        hasEditBox = 1, maxLetters = 32,
        timeout = 0, whileDead = 1, hideOnEscape = 1,
        OnAccept = function(self)
            local caja = self.editBox or _G[self:GetName() .. "EditBox"]
            local n = caja and caja:GetText() or ""
            if n ~= "" then C_AppearanceOutfit.Save(n) end
        end,
        --  ⚠️ Enter tambien guarda: obligar a pulsar el boton con el raton
        --  despues de escribir es un paso de mas que nadie espera.
        EditBoxOnEnterPressed = function(self)
            local n = self:GetText() or ""
            if n ~= "" then C_AppearanceOutfit.Save(n) end
            self:GetParent():Hide()
        end,
    }
    StaticPopupDialogs["PERULAND_ARMARIO_GUARDAR"] = StaticPopupDialogs["WOWPERU_WARDROBE_GUARDAR"]

    --  🔴 30-09-2026: NO HABIA FORMA DE QUITARSE UNA APARIENCIA. «Cancelar»
    --     solo deshace la PRUEBA en el muñeco; lo aplicado se quedaba para
    --     siempre. El servidor ya sabia hacerlo (`desnudo` en apariencias.lua:
    --     te devuelve tu equipo real), solo faltaba el boton. Comparte la fila
    --     con «Cancelar», a medias, para no mover nada mas del panel.
    local cancelar = PLARM.BotonG(V, "Cancelar", MX(124), MY(41), false)
    cancelar:SetPoint("TOPLEFT", V, "TOPLEFT", MX(994), -MY(633) - EXTRA)
    cancelar:SetScript("OnClick", function()
        V.montaje = {}
        V.transmog = {}
        VestirJugador()
    end)

    local quitar = PLARM.BotonG(V, "Quitar todo", MX(124), MY(41), false)
    quitar:SetPoint("TOPLEFT", V, "TOPLEFT", MX(1122), -MY(633) - EXTRA)
    quitar:SetScript("OnClick", function()
        StaticPopup_Show("WOWPERU_WARDROBE_QUITAR")
    end)
    StaticPopupDialogs["WOWPERU_WARDROBE_QUITAR"] = {
        text = "¿Quitarte todas las apariencias y volver a verte con tu equipo real?\n\nLas apariencias siguen en tu colección: te las puedes volver a poner.",
        button1 = "Quitar", button2 = "Cancelar",
        timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
        --  El armario va en una capa alta: sin esto la pregunta sale DEBAJO y
        --  se le transparentan sus letras. Los marcos de StaticPopup se
        --  reutilizan, asi que al cerrar se devuelve la capa de siempre.
        --  Y el fondo de serie de StaticPopup es semitransparente: encima del
        --  armario se leian sus letras a traves. Fondo solido, solo aqui.
        OnShow = function(self)
            self:SetFrameStrata("TOOLTIP")
            if not self.PLFondo then
                self.PLFondo = self:CreateTexture(nil, "BACKGROUND")
                self.PLFondo:SetTexture(0.04, 0.04, 0.05, 0.96)
                self.PLFondo:SetPoint("TOPLEFT", 11, -11)
                self.PLFondo:SetPoint("BOTTOMRIGHT", -11, 11)
            end
            self.PLFondo:Show()
        end,
        OnHide = function(self)
            self:SetFrameStrata("DIALOG")
            if self.PLFondo then self.PLFondo:Hide() end
        end,
        OnAccept = function()
            PLARM.Contrato.Mandar("desnudo")
            --  Y las transfiguraciones: «tu equipo real» es sin ninguna de las dos.
            for _, r in ipairs({ 0, 2, 3, 4, 5, 6, 7, 8, 9, 14, 15, 16, 17, 18 }) do
                PLARM.Transfigurar(0, r)
            end
            estado:SetText("Quitando...")
        end,
    }
    StaticPopupDialogs["PERULAND_ARMARIO_QUITAR"] = StaticPopupDialogs["WOWPERU_WARDROBE_QUITAR"]

    -- -----------------------------------------------------------------------
    --  🔴 LA FILA DE ABAJO: SIN ESTO, DEL ARMARIO NO SE SALE
    -- -----------------------------------------------------------------------
    --
    --  Lo vio el dueño en cuanto la pestaña «Armario» del pase empezo a
    --  funcionar: *«cuando se abre el armario, el armario no tiene forma de
    --  volver al pase de batalla, porque no tiene las opciones o secciones de
    --  abajo, igual que el pase»*.
    --
    --  🔑 En Ascension esto no pasa porque su armario **es una pestaña mas**
    --     de la ventana de Colecciones: la fila es la misma y siempre esta
    --     ahi. El nuestro es una ventana aparte, asi que al entrar se pierde
    --     la fila y con ella el camino de vuelta.
    --
    --    🎯 Una puerta de ida sin puerta de vuelta no es una puerta: es un
    --       callejon. Y no se nota al programarla, porque quien la escribe ya
    --       sabe volver con `/pase`.
    --
    --  Se replica la fila con las mismas cuatro, en el mismo sitio y con el
    --  mismo aspecto. «Armario» sale marcada -- es donde estas--, «Temporada»
    --  devuelve al pase, y las otras dos siguen apagadas porque son pantallas
    --  suyas que no se han portado.
    --  🔑 A DONDE LLEVA CADA UNA LO DECIDE EL PASE, NO ESTA LISTA.
    --     `PeruLandPaseIrA` / `PeruLandPaseTieneDestino` los usan las dos
    --     filas. Tener aqui una copia del «a donde va» es tener dos
    --     versiones de lo mismo, y la segunda siempre acaba vieja.
    local PESTANAS = {
        { texto = "Progresión",
          alPulsar = function()
              local abrir = SlashCmdList and (SlashCmdList["WOWPERU_MODES"] or SlashCmdList["WOWPERUPRIDE"])
              if abrir then
                  ProjectJaina_Cruzar(V, function() abrir("") end)
              end
          end },
        { texto = "Tienda",
          alPulsar = function()
              local abrir = SlashCmdList and (SlashCmdList["WOWPERU_VISUAL"] or SlashCmdList["WOWPERUVISUALSHOP"])
              if abrir then
                  ProjectJaina_Cruzar(V, function() abrir("") end)
              end
          end },
        { texto = "Armario", aqui = true },
        { texto = "Pase de Batalla",
          alPulsar = function()
              local abrir = SlashCmdList and SlashCmdList["WOWPERUBP"]
              if abrir then
                  ProjectJaina_Cruzar(V, function() abrir("") end)
              end
          end },
    }

    local anterior
    for i, p in ipairs(PESTANAS) do
        local t = CreateFrame("Button", "ProjectJaina_Wardrobe_Tab" .. i, V,
                              "CharacterFrameTabButtonTemplate")
        t:SetText(p.texto)
        --  🪤 El ancho no se pone a mano: la plantilla lo calcula del texto.
        PanelTemplates_TabResize(t, 0)

        if anterior then
            t:SetPoint("LEFT", anterior, "RIGHT", -16, 0)
        else
            t:SetPoint("TOPLEFT", V, "BOTTOMLEFT", 12, 2)
        end
        anterior = t

        if p.aqui then
            t:Disable()
            t:SetAlpha(1)
        elseif p.alPulsar then
            t:SetScript("OnClick", p.alPulsar)
        else
            t:Disable()
            t:SetAlpha(0.5)
        end
    end

    estado = PLARM.Texto(V, 11, c.textoSuave)
    --  🪤 ENCIMA DE LOS BOTONES, NO A SU LADO.
    --  Estaba a 20 px del borde, la MISMA altura que «Aplicar / Cancelar /
    --  Guardar atuendo», que llegan hasta x=380. El aviso empezaba en 290, asi
    --  que los botones se comian su principio y solo se leia el final --
    --  «...esa apariencia» en rojo, sin saber de que hablaba.
    estado:SetPoint("TOPLEFT", V, "TOPLEFT", MX(146), -MY(676))
    estado:SetWidth(MX(250))
    estado:SetJustifyH("LEFT")

    PLARM.Eventos.Registrar("ARMARIO_AVISO", function(texto, malo)
        estado:SetText(texto or "")
        estado:SetTextColor(unpack(malo and c.granate or c.textoSuave))
    end)
    PLARM.Eventos.Registrar("ARMARIO_SIN_RESPUESTA", function(canal)
        estado:SetText("El servidor no contesta (" .. tostring(canal) .. "). Vuelve a intentarlo.")
        estado:SetTextColor(unpack(c.granate))
    end)
    PLARM.Eventos.Registrar("APPLY_PENDING_APPEARANCE_RESULT", function(ok, texto)
        estado:SetText(texto or "")
        estado:SetTextColor(unpack(ok == "1" and c.verde or c.granate))
    end)

    --  🪤 AQUI HABIA UN ROTULO con el nombre de lo que hay BAJO EL RATON, y
    --  se quito porque enganaba: debajo del muneco esta el nombre del
    --  conjunto SELECCIONADO, asi que en pantalla salian dos nombres
    --  distintos a la vez y parecia que uno de los dos estaba mal.
    --
    --  Lo que hacia lo cubre ahora el aviso al pasar por encima de la ficha,
    --  que ademas dice la rareza y las piezas.
    --
    --    🎯 Dos sitios ensenando «el nombre» con criterios distintos no es
    --       mas informacion: es una contradiccion en pantalla.

    -- -----------------------------------------------------------------------
    --  Panel derecho: la coleccion
    -- -----------------------------------------------------------------------
    V.coleccion = PLARM.Coleccion.Crear(V, MX(143), -MY(62), MX(808), MY(632))
    --  🎨 La QUINTA seccion: el pase de batalla (el dueño). Abre el pase.
    local pase = PLARM.SeccionLateral(V, "Pase", MX(106), MY(94))
    pase:SetPoint("TOPLEFT", V, "TOPLEFT", MX(6), -MY(97 + 5 * 97))   -- 6.a: «Transfigurar» es la 5.a
    pase:PonerIcono("GIcoPase")
    pase:SetScript("OnClick", function()
        local abrir = SlashCmdList and (SlashCmdList["WOWPERUBP"] or SlashCmdList["PERULANDPASE"])
        if abrir then
            ProjectJaina_Cruzar(V, function() abrir("") end)
        end
    end)

    --  Pulsar una ficha se la prueba. Aplicar es otro boton, como en Ascension:
    --  probarse cosas no escribe nada en la base.
    --  🔴 VUELTA AL CAMINO DE LA v1, QUE ERA EL QUE FUNCIONABA.
    --
    --  La v1 tenia mala interfaz pero APLICABA BIEN. En la v2 se arreglo la
    --  interfaz y de paso se anadio una maquinaria que la v1 no tenia: estado
    --  "pendiente" en el servidor, mensajes de ida y vuelta por cada clic,
    --  esperas, repintados y firmas. Todo eso es lo que se rompia.
    --
    --    🎯 Cuando una version anterior HACIA algo bien, no se reinventa esa
    --       parte: se conserva. Se cambia solo lo que estaba mal.
    --
    --  Ahora: pulsar una ficha se PRUEBA EN LOCAL -- el servidor ni se entera.
    --  Y «Aplicar» manda un unico mensaje `vestir|`, exactamente como la v1.
    PLARM.Eventos.Registrar("FICHA_PULSADA", function(d)
        if V.MirarConjunto and d and d.id then V.MirarConjunto(d.id) end
        if d.id >= 2000000 and d.id < 3000000 then
            --  Un conjunto SUSTITUYE el montaje entero: es un traje.
            C_ItemSet.GetAppearances(d.id, function(piezas)
                if not piezas then return end
                V.montaje = {}
                V.transmog = {}
                for _, p in ipairs(piezas) do V.montaje[p.cat] = p.id end
                VestirJugador()
            end)
        else
            --  🪤 SI NO VIENE LA RANURA, SE BUSCA. La ficha de la rejilla la
            --  trae en sus datos, pero cualquier otra via -- el control remoto
            --  de las pruebas, un boton nuevo manana-- puede pasar solo el id.
            --  Sin ranura, esta rama no hacia nada y el arma «no se aplicaba»
            --  sin dar ninguna senal.
            --
            --    🎯 Un manejador que necesita dos datos y solo comprueba uno
            --       falla en silencio para quien llama con uno.
            local cat = d.cat
            if not cat then
                for _, e in ipairs(PLARM.Contrato.Estado.entradas or {}) do
                    if e.id == d.id then cat = e.cat break end
                end
            end
            mirandoCat = cat
            if cat then
            --  🔑 UNA PIEZA SUELTA SE SUMA, NO SUSTITUYE. Es lo que pidio el
            --  dueno: «le doy a aplicar y no se aplica o complementa a mis
            --  cosmeticos». Un arma se anade a lo que ya llevas puesto; solo
            --  un conjunto entero cambia el traje completo.
            --
            --  Antes esta rama no existia y pulsar un arma no hacia
            --  absolutamente nada -- ni vista previa ni aplicar.
            V.montaje = V.montaje or {}
                V.montaje[cat] = d.id
                --  🪄 Si viene de «Transfigurar», al aplicar va por el nucleo.
                V.transmog = V.transmog or {}
                if (PLARM.Contrato.Estado.categoria or 0) >= 200 then
                    V.transmog[cat] = d.id
                else
                    V.transmog[cat] = nil
                end
                VestirJugador()
            end
        end
    end)

    Reencuadrar()
    return V
end

-- ---------------------------------------------------------------------------
function PLARM.Abrir2()
    --  🔴 SI CREAR LA VENTANA FALLA, QUE SE VEA. Sin este pcall el error se
    --  perdia y el sintoma era "le doy al comando y no pasa nada", que no
    --  dice absolutamente nada de la causa. Paso con `SetShown`, que no
    --  existe en 3.3.5a: cortaba el archivo por la mitad en silencio.
    if not V then
        local ok, err = pcall(Crear)
        if not ok then
            DEFAULT_CHAT_FRAME:AddMessage("|cffC83842[Armario]|r no pude abrir: "
                                          .. tostring(err))
            return
        end
    end
    V:Show()
    ProjectJaina_Aparecer(V)     -- Transicion.lua: sin saltos bruscos
    PLARM.Contrato.Saludar()
    --  🔴 NO SE PIDE LA PRIMERA PAGINA HASTA QUE EL SERVIDOR HA CONTESTADO.
    --
    --  Aqui se llamaba a `Refrescar(1)` de inmediato. Si el saludo (`hola`)
    --  todavia no habia llegado, el servidor filtraba contra una sesion vacia
    --  y devolvia **cero resultados**: el armario salia en blanco -- «no hay
    --  conjuntos que coincidan»-- y bastaba cerrar y volver a abrir para
    --  verlo bien, porque para entonces ya habia contestado.
    --
    --  🪤 Y el aviso que resuelve esto **ya existia y nadie lo escuchaba**:
    --  `Contrato.lua` dispara `ARMARIO_LISTO` desde hace semanas y no habia ni
    --  un `Registrar` para el en todo el addon.
    --
    --    🎯 Un evento que nadie escucha no da error, no aparece en ningun
    --       registro y se ve igual que si no existiera. Si algo «va bien al
    --       segundo intento», busca la señal de listo antes de meter esperas.
    if PLARM.Contrato.Estado.listo then
        V.coleccion:Refrescar(1)
    else
        PLARM.Eventos.Registrar("ARMARIO_LISTO", function()
            if V and V:IsShown() then V.coleccion:Refrescar(1) end
        end)
    end
    --  El muneco se viste al abrir, no solo cuando algo cambia: si entras y
    --  no tocas nada, tiene que salir tu personaje igualmente.
    if V.VestirJugador then V.VestirJugador() end
    --  las fichas del jugador, una vez: las 18 celdas las necesitan todas
    if PLARM.Ficha and PLARM.Ficha.PedirBase then PLARM.Ficha.PedirBase() end

    --  🔬 SE LLAMA AQUI, NO POR EVENTO. El `HookScript("OnShow")` NO disparaba:
    --  el contador del DLL lo dijo sin lugar a dudas -- `aplicados=0
    --  saltados=0 bandera=ON`, o sea que ni siquiera se habia instalado el
    --  enganche porque nadie llamo a la funcion.
    --
    --    🎯 Ese contador es lo que ahorro la siguiente ronda de suposiciones.
    --       «No corta» y «no llega a ejecutarse» se ven IGUAL en pantalla y se
    --       arreglan en sitios opuestos; dos variables en el DLL lo zanjaron.
    --  🔴 LOS COMPONENTES YA NO SE APAGAN AQUI.
    --
    --  Se apagaban al abrir la ventana y no se volvian a encender, asi que
    --  quedaban apagados tambien durante los `TryOn` de cada celda. Ascension
    --  los apaga SOLO alrededor del `SetUnit` de cada muñeco y los enciende
    --  antes de vestirlo. Eso vive ahora en `Ficha.lua` (`SinCuerpo`).
    if PeruLand_ConComponentes then pcall(PeruLand_ConComponentes) end

    --  🔴 LA FICHA Y EL ARMARIO NO CONVIVEN. A PROPOSITO.
    --
    --  El congelado del DLL es una bandera GLOBAL: o esta parado todo el
    --  cliente o no lo esta ninguno. Asi que «celdas quietas y mi personaje de
    --  la ficha moviendose, a la vez» **no se puede** -- y todo intento de
    --  repartirlo por eventos daba el mismo resultado visto de dos maneras:
    --  *«mi personaje esta congelado»* o *«los objetos volvieron a animarse»*.
    --
    --  🔑 Ascension no tiene este problema porque su ventana de coleccion ocupa
    --  la pantalla y **no convive con la ficha**. Se hace igual: al abrir el
    --  armario se cierra la ficha. Fuera del armario, todo se anima como
    --  siempre.
    --
    --    🎯 Cuando dos requisitos no pueden cumplirse a la vez, la respuesta no
    --       es turnarse entre ellos con enganches -- eso solo reparte el fallo
    --       en el tiempo. Es quitar la simultaneidad.
    if CharacterFrame and CharacterFrame:IsShown() then
        pcall(function() HideUIPanel(CharacterFrame) end)
    end
end

--  🪤 EL NUMERO VA PEGADO AL NOMBRE, SIN GUION BAJO.
--
--  WoW recorre `SlashCmdList` y para cada clave busca la variable global
--  `SLASH_<clave><n>`. Con la clave "WP_WARDROBEV2" busca `SLASH_WP_WARDROBEV21`.
--  Yo habia escrito `SLASH_WP_WARDROBEV2_1`, que es lo que le corresponderia a
--  una clave llamada "WP_WARDROBEV2_" -- y esa no existe.
--
--  Resultado: el comando NO queda registrado, y no hay ningun error. Abrir la
--  ventana desde codigo funcionaba; teclear `/armario2` decia "escribe /ayuda".
--  El dueno lo aislo en una frase: *"cuando tu lo abres por tu cuenta si abre,
--  si yo lo hago en el teclado no"*.
--
--    🎯 Cuando algo funciona por un camino y no por el otro, el fallo esta en
--       el camino, no en lo que hace al final.
--  🔴 `/armario` ES EL NOMBRE BUENO, Y FALTABA.
--
--  Lo prometia el propio `.toc` ("Se abre con /armario") y lo tecleaba el
--  dueno, pero **no estaba registrado en ningun sitio que el juego cargue**: lo
--  registraba `Armario.lua`, el monolito viejo, que esta comentado en el `.toc`
--  desde que se vio que tener los dos armarios cargados rompia TODOS los
--  munecos 3D -- incluidos la ficha de personaje y el vestidor de Blizzard.
--
--    🎯 Un comando que documentas y no registras es peor que no tenerlo: el que
--       lo teclea cree que el sistema esta roto, no que se llama de otra forma.
--
--  `/armario2` se queda por si alguien lo tiene en una macro.
SLASH_WP_WARDROBEV21 = "/armario"
SLASH_WP_WARDROBEV22 = "/arm"
SLASH_WP_WARDROBEV23 = "/armario2"
SLASH_WP_WARDROBEV24 = "/guardarropa"
SLASH_WP_WARDROBEV25 = "/wardrobe"
SlashCmdList["WP_WARDROBEV2"] = function(arg)
    if arg == "prueba" then PLARM.Contrato.Autoprueba() return end
    if arg == "diag" then PLARM.Contrato.Diag() return end
    if V and V:IsShown() then V:Hide() else PLARM.Abrir2() end
end

--  Marca de carga: si este archivo revienta, su linea NO sale y se ve al
--  instante cual es. Los errores de Lua vienen apagados de fabrica.
PLARM_CARGADO = (PLARM_CARGADO or "") .. " Ventana"


--  🧊 LA FICHA DE PERSONAJE NO SE CONGELA CON EL ARMARIO
--
--  La bandera del DLL es GLOBAL: para la animacion de TODOS los muñecos del
--  cliente, tambien la de tu personaje en la ficha (tecla C). El dueño lo vio
--  en cuanto abrio la ficha con el armario abierto: *«lo que has hecho de
--  congelar el muñeco tambien afecto a esta parte y no deberia ser asi»*.
--
--  No se puede congelar «solo estas celdas»: los sitios que se parchean son
--  codigo COMPARTIDO por todos los muñecos. Asi que la bandera se apaga
--  mientras la ficha esta a la vista.
--
--  🔴 Y ESTO NO VA POR EVENTOS, VA POR VIGILANCIA. Primero se hizo con
--  `HookScript("OnShow"/"OnHide")` sobre `CharacterFrame` y fallaba «a veces»:
--  el dueño encontro el caso que lo desmontaba -- *«le di clic a Rotar en los
--  iconos de la ficha, y todos los demas muñecos del armario volvieron a
--  animarse»*. Rotar no abre ni cierra nada, asi que ningun engancho de esos
--  se enteraba, y el estado se quedaba al reves.
--
--    🎯 Cuando el estado correcto se puede CALCULAR en cualquier momento, no
--       se mantiene a base de enganches: se calcula. Un engranaje de eventos
--       tiene tantos agujeros como caminos no previstos, y cada agujero se ve
--       igual -- «a veces si y a veces no». Esto se corrige solo en 0,25 s
--       venga de donde venga el cambio.
local vigia = CreateFrame("Frame")
local ultimo, reloj = nil, 0
vigia:SetScript("OnUpdate", function(self, elapsed)
    reloj = reloj + elapsed
    if reloj < 0.25 then return end
    reloj = 0
    --  Congelado = el armario esta abierto Y la ficha de personaje no.
    --  Congelado = el armario esta abierto. Y punto: la ficha no puede estar
    --  abierta a la vez (se cierra al abrir el armario), asi que no hay que
    --  mirarla.
    local quiero = (V and V:IsShown()) and true or false
    PLARM._hielo = { v = (V and V:IsShown()) and true or false,
                     ficha = (CharacterFrame and CharacterFrame:IsShown()) and true or false,
                     quiero = quiero, ultimo = ultimo,
                     hayCong = PeruLand_Congelar ~= nil,
                     hayDesc = PeruLand_Descongelar ~= nil }
    if quiero == ultimo then return end
    ultimo = quiero
    PLARM._hielo.ultimo = ultimo
    if quiero then
        if PeruLand_Congelar then PeruLand_Congelar() end
    else
        if PeruLand_Descongelar then PeruLand_Descongelar() end
    end
end)


--  ---------------------------------------------------------------------------
--  Apertura automatica  (SOLO PARA PROBAR — apagar antes de publicar)
--  ---------------------------------------------------------------------------
--  🔴 EXISTE PORQUE EL TECLADO NO ES FIABLE PARA PROBAR. Mandar `/armario` con
--     SendKeys falla una de cada dos veces: si la caja de chat no ha abierto,
--     las letras caen sobre el MUNDO y disparan sus atajos — la `a` es
--     autoataque, la `m` abre el mapa. Y la captura sale igual que si el addon
--     no respondiera.
--
--    🎯 Un instrumento que falla la mitad de las veces no separa «no funciona»
--       de «no llego la orden». Mejor quitar el teclado del medio.
--
--  ⚠️ `PLARM_ABRIR_SOLA = false` ANTES DE PUBLICAR.
PLARM_ABRIR_SOLA = false

if PLARM_ABRIR_SOLA then
    local v = CreateFrame("Frame")
    v:RegisterEvent("PLAYER_ENTERING_WORLD")
    v:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        local t = 0
        self:SetScript("OnUpdate", function(s, dt)
            t = t + dt
            if t < 4 then return end
            s:SetScript("OnUpdate", nil)
            pcall(function() PLARM.Abrir2() end)
        end)
    end)
end
