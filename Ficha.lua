-- ============================================================================
--  LA FICHA   ·   01-09-2026
-- ============================================================================
--  Una celda de la rejilla. Es un muneco 3D con la pieza o el conjunto
--  puestos, como las de Ascension (`AppearanceModelMixin`).
--
--  🔑 POR QUE 3D Y NO UN ICONO. Lo pidio el dueno con sus capturas de
--  Ascension delante: ahi cada casilla ensena el yelmo puesto en la cabeza, no
--  un dibujito. Con iconos pasaba lo que el vio: *"hay sets que tienen el
--  mismo icono y son diferentes"* -porque el icono es el de la primera pieza y
--  ocho variantes de color comparten el mismo-.
--
--  🔴 Y POR QUE ESTA VEZ NO VA A IR LENTO. Ya se probaron fichas 3D y se
--  retiraron por eso. Leyendo su codigo aparecio la diferencia, y es una
--  linea de su `InternalUpdateAppearances`: ellos llenan **UN muneco por
--  fotograma, cada 0,01 s**, y una bandera cancela la cola si cambias de
--  pagina. Nosotros los llenabamos los 18 de golpe.
--
--  🪤 Y `TryOn` NO HACE NADA -sin dar error- mientras el cliente no tenga la
--  ficha del objeto. Ellos lo comprueban antes (`if not GetItemInfo(id) then
--  needsQuery`) y esperan. Es la causa de *"no sale el pj"* y de que a los dos
--  minutos empezara a funcionar solo.
-- ============================================================================

PLARM = PLARM or {}
PLARM.Ficha = {}

local c = PLARM.color

--  🎨 25-09-2026, GALERIA: la tarjeta de la maqueta, 152x262 (pasada a la
--     ventana con PLARM.MX / PLARM.MY). Coleccion.lua le cambia el alto en
--     Piezas, donde entra la fila de ranuras.
local ANCHO, ALTO = PLARM.MX(152), PLARM.MY(270)

--  🔴 EL INTERRUPTOR DEL 3D.  Hoy en `false`, y con motivo medido.
--
--  En `true` cada celda es un muneco vestido, como en Ascension. En `false`
--  es el icono real de la pieza principal.
--
--  ── POR QUE ESTA EN `false` (03-09-2026, tras cinco dias) ──────────────────
--
--  La rejilla 3D de 18 celdas **no se sostiene en 3.3.5a**. No es un fallo del
--  addon: es un limite del cliente. Medido con capturas:
--
--    | celdas | al abrir | minutos despues |
--    |--------|----------|-----------------|
--    |   6    |    ok    |        --       |
--    |  12    |    ok    |        --       |
--    |  18    |    ok    |  **se rompe**   |
--
--  Cada celda es un personaje completo que el cliente tiene que componer. Y
--  cada vez que cambia la apariencia del jugador, **el cliente borra lo
--  probado en TODOS los `DressUpModel` que usan `SetUnit("player")`** y hay
--  que rehacerlos. Rehacer 18 a la vez no le cabe: sobreviven ~3.
--
--  🔑 Y POR QUE A ELLOS SI LES CABE. Se comprobo buscando las cadenas en los
--  binarios, no suponiendo:
--
--    | funcion | Extensions.dll | Ascension.exe | nuestro Wow.exe |
--    |---|---|---|---|
--    | `SetModelApplyComponents` | **si** | no | no |
--    | `C_UICamera`              | **si** | no | no |
--
--  Las dos viven **solo en su DLL**. `SetModelApplyComponents(false)` monta el
--  muneco SIN las piezas del jugador, que es justo lo que quita el trabajo de
--  composicion y lo desata del personaje. Su addon la llama antes de CADA
--  `SetUnit`. Nosotros le estamos pidiendo al cliente algo que su cliente no
--  le pide.
--
--    🎯 La leccion mas cara de estos cinco dias: se hicieron VEINTE arreglos
--       en Lua --quitar reintentos, esperar al modelo, esperar las fichas,
--       escalonar, resetear con `ClearModel`, encolar el revestido-- y todos
--       tapaban sintomas de un limite que no esta en el Lua. Cuando algo falla
--       veinte veces seguidas, lo que esta mal no es el arreglo: es la
--       suposicion de que ahi se puede arreglar.
--
--  ⏳ Vuelve a `true` el dia que el DLL exponga su equivalente de
--     `SetModelApplyComponents`. Es una linea, y el resto ya esta escrito.
--
--  Mientras tanto la rejilla es utilizable de verdad: icono real por celda,
--  contador `10/10`, marca de variantes, nombre completo -- y al pulsar, el
--  muneco grande, que es UNO y si aguanta.
PLARM.USAR_3D = true    -- 3D otra vez: el DLL ya da SinComponentes

--  La pose de Ascension, copiada de su `AppearanceModelMixin:DisplayItemSet`.
--  No son numeros a ojo: sin `SetLight` el modelo sale NEGRO, y sin la
--  posicion sale encuadrado por las rodillas.
local LUZ = { 1, 0, -1, 1, -1, 1.05, 1, 1, 1, 0, 1, 1, 1 }
--  🎨 Lo bloqueado: el muñeco OPACO pero con luz tenue y gris. Con alfa 0,45
--     se veia el fondo a traves del cuerpo, como un fantasma (el dueño).
local LUZ_APAGADA = { 1, 0, -1, 1, -1, 0.62, 0.66, 0.66, 0.7, 0, 1, 1, 1 }

--  Como encuadrar segun lo que se ensena. Una cabeza vista de cuerpo entero
--  no se distingue de otra; un conjunto visto de cerca no se ve entero.
--  🔪 Las ranuras que son ARMA. No se encuadran: se ensenan solas, colgadas
--  de un portador invisible (ver el bloque grande en `Crear`).
local ES_ARMA = { [15] = true, [16] = true, [17] = true }

--  🔬 MEDIDO, NO SUPUESTO (03-09-2026). Ascension usa `SetDisplayInfo(44472)`.
--  Se pregunto al cliente si esa funcion existe aqui:
--
--      SetDisplayInfo=false  SetCreature=true  SetModel=true  TryOn=true
--
--  **No existe en 3.3.5a.** Su equivalente es `SetCreature`, que toma la
--  CRIATURA, no el display. Sin medirlo, el `pcall` se tragaba el fallo y la
--  celda caia al icono sin decir por que -- que es justo lo que se vio.
--
--    🎯 «No funciono» son dos cosas distintas: la funcion no existe, o existe
--       y el modelo no vale. Se arreglan en sitios opuestos, y preguntarlo
--       cuesta un minuto.
--
--  12999 = «World Invisible Trigger», sacado de `creature_template` del propio
--  servidor. Su display es el 11686.
local CRIATURA_INVISIBLE = 12999

--  🔴 EL ZOOM POR PIEZA **NO SE PUEDE HACER SIN EL DLL**. Medido (03-09-2026)
--
--  El dueno lo recordaba bien: para eso queria la extension del cliente. Se
--  intentaron las tres vias que ofrece 3.3.5a, y ninguna sirve:
--
--  | Que se probo | Resultado |
--  |---|---|
--  | `SetCameraDistance` / `SetCameraPosition` / `SetCamDistanceScale` | **no existen** |
--  | `SetPosition` de -0.40 a 1.60 | solo DESPLAZA; el muneco se ve igual de grande |
--  | `SetModelScale`, incluso a **8.0** | existe, y sobre un muneco de jugador **no hace nada** |
--  | `SetModel(<arma>.m2)` -- el arma sola | **si dibuja**, pero **sale BLANCA**: por esa via el cliente no aplica la textura de `ItemDisplayInfo` |
--  | `SetCreature(12999)` (invisible), la receta de Ascension | **no dibuja nada** |
--
--  🔑 Y asi es exactamente como lo resuelve Ascension: `C_UICamera.GetItemCameraID`
--  + `ApplyUICamera` + `SetModelApplyComponents(false)` -- **las tres las pone
--  su DLL**, ninguna existe aqui.
--
--    🎯 Lo que costo caro no fue el limite, fue tardar en verlo: se calibraron
--       numeros durante horas sobre una palanca que no movia nada. Con un
--       valor absurdo a proposito (escala 8) se habria visto en un intento.
--
--  ⏳ QUEDA PARA EL DLL: encuadre por pieza, cuerpo en gris y el arma sola.
--
--  🔴 **Y LA «VIA INTERMEDIA» QUE SE ANOTO AQUI NO EXISTE.** Se penso en un
--  humanoide invisible propio para colgarle el arma, como hace Ascension. Se
--  probo antes de escribirlo como plan, y menos mal:
--
--      SetCreature(12999)  criatura invisible  -> no dibuja nada
--      SetCreature(1423)   guardia VISIBLE     -> no dibuja nada
--      SetCreature(3258)   su display          -> no dibuja nada
--
--  O sea que no era el modelo: **`SetCreature` no dibuja en este cliente**, y
--  da igual que le pases criatura o display. Sin portador no hay arma sola.
--
--    🎯 Un experimento que puede fallar por dos motivos no prueba nada. Se
--       probo con una criatura VISIBLE justo para separar «la via no sirve»
--       de «ese modelo concreto no vale» -- y la respuesta fue la primera.
--
--    🎯 Y por eso se corrige la nota en vez de dejarla: una pista falsa en la
--       documentacion cuesta mas que no tener ninguna, porque el siguiente la
--       da por buena y construye encima.
--
--  Mientras tanto: el muneco se DESNUDA siempre, que es lo que de verdad
--  cambio la rejilla -- antes salian 18 personajes identicos con la armadura
--  del jugador y la pieza no se veia.
--
--  Formato: { x, y, z, escala }. Calibrable en vivo: `encuadre|<cat>|x|y|z|e`
--  La escala se deja en 1.0 porque hoy no hace nada; el hueco esta puesto para
--  cuando el DLL la habilite.
--  🧍 EL MANIQUI: piezas NEUTRAS para que la que se ensena no flote.
--
--  Copiado de su `WARDROBE_MODEL_SETUP` + `WARDROBE_MODEL_SETUP_GEAR`
--  (`AppearanceModelMixin.lua`, arriba del todo). Antes de probarse la pieza,
--  visten al muneco con ropa gris de Blizzard **en las ranuras que rodean a la
--  que se enseña**, y solo en esas:
--
--      cabeza   -> pecho                (ni manos, ni piernas, ni pies)
--      pecho    -> piernas y pies       (el pecho no, obvio)
--      muñecas  -> pecho, manos, piernas
--
--  🔑 Sin esto, enseñar un yelmo deja una cabeza con casco sobre un cuerpo
--  desnudo, que es exactamente lo que se veia aqui. Con esto se ve una pieza
--  puesta sobre alguien vestido, que es lo que sale en sus capturas.
--
--    🎯 Y es un recordatorio de por que el dueño insiste: esto llevaba dias
--       escrito en su codigo, en las PRIMERAS lineas del archivo que ya se
--       habia leido tres veces buscando otra cosa.
--
--  🪤 SUS CUATRO OBJETOS NO EXISTEN AQUI. Se copiaron tal cual
--  (135522, 135548, 135550, 135549) dando por hecho que «de Blizzard es de
--  Blizzard». Son IDs de RETAIL: en nuestra base hay **cero** de los cuatro,
--  asi que `TryOn` no hacia nada -- sin error-- y el maniqui no se vestia.
--
--    🎯 «Es de Blizzard» no significa «existe en 3.3.5a». Misma trampa que ya
--       costo cara con `ItemDisplayInfo`: de otro cliente se copia un NOMBRE,
--       nunca un ID.
--
--  Estos si existen aqui y hacen el mismo papel: ropa basica que no compite
--  con la pieza que se esta enseñando.
--  🩶 EL CUERPO GRIS: COMO LO HACE ASCENSION, Y NO ES UN COLOR.
--
--  El dueño lo pidio asi: *«el resto del cuerpo en asension no tiene color, es
--  como si fuese un plomo con poca opacidad»*, y luego, viendo el nuestro:
--  *«el maniqui no esta gris, solo parece que le pusiste una ropa gris pero su
--  cuello y pecho sigue viendose»*.
--
--  🔑 Al mirar su `AppearanceModelMixin` esta escrito en tres lineas, y el
--  orden es lo importante:
--
--      SetModelApplyComponents(false)   -- 1. sin componer la piel
--      self:SetUnit("player")           -- 2. cargar el cuerpo
--      SetModelApplyComponents(true)    -- 3. volver a encenderlos
--      self:TryOnTransmogGear(slot)     -- 4. y AHORA vestirlo
--
--  Con los componentes apagados, `SetUnit` carga el modelo **sin componer la
--  textura del personaje**: la piel sale plana y sin color, que es el gris que
--  se ve en sus capturas. Encenderlos otra vez ANTES de los `TryOn` es lo que
--  permite que la pieza si se dibuje.
--
--  🪤 Nosotros teniamos la funcion del DLL desde el 30-08 y la usabamos MAL:
--  se apagaban los componentes **una sola vez al abrir la ventana** y no se
--  volvian a encender. Asi que se apagaban para todo el rato -- incluidos los
--  `TryOn`-- en vez de solo para el `SetUnit` de cada muñeco.
--
--    🎯 Tener la pieza que hace falta no es usarla bien. Cuando algo se parece
--       pero no cuadra, mira el ORDEN antes de buscar otra pieza.
local function SinCuerpo(fn)
    if PeruLand_SinComponentes then pcall(PeruLand_SinComponentes) end
    local ok, err = pcall(fn)
    if PeruLand_ConComponentes then pcall(PeruLand_ConComponentes) end
    local log = ProjectJaina_Wardrobe_Apuntar or PeruLandArmarioApuntar
    if not ok and log then
        log("error", "SinCuerpo: " .. tostring(err))
    end
end

local MANIQUI_ROPA = { pecho   = 193,   -- Tattered Cloth Vest
                       piernas = 39,    -- Recruit's Pants
                       pies    = 195,   -- Tattered Cloth Boots
                       manos   = 711 }  -- Tattered Cloth Gloves

--  Nuestras categorias: 0 cabeza · 2 hombros · 3 camisa · 4 pecho · 5 cintura
--  6 piernas · 7 pies · 8 munecas · 9 manos · 14 espalda
local MANIQUI = {
    [0]  = { pecho = true },
    [2]  = { pecho = true },
    [14] = { pecho = true, manos = true, piernas = true },
    [4]  = { piernas = true, pies = true },
    [3]  = { piernas = true },
    [8]  = { pecho = true, manos = true, piernas = true },
    [9]  = { pecho = true, piernas = true, pies = true },
    [5]  = { pecho = true, manos = true, piernas = true },
    [6]  = { pecho = true, manos = true, pies = true },
    [7]  = { piernas = true },
}

local ENCUADRE = {
    --  🔴 ESTOS NUMEROS SI FUNCIONAN, Y SE LLEGO A DECIR QUE NO.
    --
    --  El 03-09 se concluyo que `SetPosition` «solo desplaza, no acerca» y se
    --  pusieron todos a cero. **Era falso.** Esa medicion se hizo durante el
    --  rato en que el bucle de vestir estaba muerto -- se habia perdido
    --  `local token = self.token` al revertir un parche-- asi que NADA de lo
    --  que se probo entonces llegaba a aplicarse.
    --
    --  La prueba de que si funcionan quedo en una captura de esa misma tarde:
    --  la rejilla enseñaba cabezas con casco en primer plano, porque un fallo
    --  distinto hacia que todas las piezas se trataran como `cat = 0`.
    --
    --    🎯 Una medicion hecha sobre codigo que no se ejecuta no dice «no
    --       funciona»: no dice nada. Y es peor que no medir, porque se
    --       archiva como hecho y cierra un camino que estaba abierto.
    --
    --  Primer numero = cuanto se acerca (mas alto, mas cerca).
    --  Tercero = arriba/abajo (negativo sube).  Calibrable con `encuadre|`.
    --  🔬 CALIBRADOS MIRANDO, contra las capturas de Ascension que paso el
    --  dueño. La cabeza es la que se ajusto en vivo (`encuadre|0|x|y|z`) hasta
    --  dar con su encuadre de BUSTO -- cabeza y hombros, centrado-- y el resto
    --  sale de bajar la vista manteniendo el acercamiento.
    [0]  = { 2.15, 0.00, -0.74 },   -- cabeza (verificado; NO subir: con 2.42 corta los yelmos)
    [2]  = { 2.00, 0.00, -0.60 },   -- hombros
    [3]  = { 1.50, 0.00, -0.28 },   -- camisa
    [4]  = { 1.50, 0.00, -0.28 },   -- pecho
    [5]  = { 1.70, 0.00, -0.02 },   -- cintura
    [6]  = { 1.45, 0.00, 0.24 },    -- piernas
    [7]  = { 2.00, 0.00, 0.62 },    -- pies
    [8]  = { 2.00, 0.00, -0.08 },   -- munecas
    [9]  = { 2.00, 0.00, -0.04 },   -- manos
    [14] = { 1.00, 0.00, -0.25 },   -- espalda
    --  ⏳ Las armas NO se encuadran: en Ascension salen SOLAS, sin cuerpo
    --     (su captura no deja duda). Eso necesita el portador invisible, que
    --     todavia no esta. De momento van como el conjunto.
    [15] = { 0.58, 0.00, -0.05 },   -- arma principal
    [16] = { 0.58, 0.00, -0.05 },   -- secundaria
    [17] = { 0.58, 0.00, -0.05 },   -- distancia
    CONJUNTO = { 0.58, 0.00, -0.05 },
}

-- ---------------------------------------------------------------------------
--  Esperar a que llegue la ficha del objeto
-- ---------------------------------------------------------------------------
--  Como su `ItemQueryListener`, que aqui no existe: se sondea por fotograma.
--  El `token` permite cancelar -si el jugador pasa de pagina mientras carga,
--  la respuesta vieja ya no debe vestir a nadie-.
--  🪤 DECLARADA AQUI ARRIBA A PROPOSITO. La sonda la llama y la sonda se
--  escribe ANTES; en Lua una funcion que aun no existe es `nil` y la llamada
--  revienta -- 2.908 veces en un minuto, y con los errores de Lua apagados de
--  fabrica no se ve NADA: solo que los munecos no aparecen.
--
--    🎯 Es la cuarta vez en este addon que muerde lo mismo. Si una funcion se
--       usa mas arriba de donde se define, va declarada arriba.

-- ---------------------------------------------------------------------------
--  Preguntar por una ficha SIN inundar al cliente
-- ---------------------------------------------------------------------------
--  🔴 `GetItemInfo` sobre un objeto que el cliente no conoce ENCOLA UNA
--  PETICION al servidor. La sonda lo llamaba en cada fotograma para cada
--  pieza de cada celda: 18 celdas x 9 piezas x 60 veces por segundo son
--  ~10.000 peticiones por segundo. La cola del cliente se atasca y no llega
--  ninguna -- por eso solo cargaban las fichas que uno pulsaba a mano, que
--  eran las unicas que el servidor mandaba por otra via.
--
--    🎯 Reintentar no es repetir mas rapido. Preguntar mas veces por algo que
--       tarda solo consigue que tarde mas.
--
--  Aqui se pregunta por cada objeto como mucho una vez cada 3 segundos.




PLARM.Ficha.PedirBase = function() end

-- ---------------------------------------------------------------------------
--  Crear
-- ---------------------------------------------------------------------------
function PLARM.Ficha.Crear(padre, indice)
    local f = CreateFrame("Button", nil, padre)
    f:SetSize(ANCHO, ALTO)

    --  🎨 La tarjeta es arte (arte2/Tarjeta y TarjetaOn). `f.borde` sigue
    --     existiendo para el codigo de siempre, pero cambia la pieza.
    --  🎨 GALERIA: fondo de ambiente + marco redondeado encima del muñeco.
    f.fondo = f:CreateTexture(nil, "BACKGROUND")
    f.fondo:SetPoint("TOPLEFT", 1, -1)
    f.fondo:SetPoint("BOTTOMRIGHT", -1, 1)
    PLARM.PonerFondo(f.fondo, PLARM.FondoDe(indice), ANCHO - 6, ALTO - 6)
    --  Oscurece el pie para que el nombre se lea sobre cualquier fondo.
    local pieOsc = f:CreateTexture(nil, "BORDER")
    f.pieOsc = pieOsc
    pieOsc:SetTexture(PLARM.ARTE2 .. "GPieTarjeta")
    pieOsc:SetPoint("BOTTOMLEFT", 1, 1); pieOsc:SetPoint("BOTTOMRIGHT", -1, 1)
    pieOsc:SetHeight(84)
    --  🌑 Sombra bajo los pies, para que pise el suelo del fondo.
    f.sombra = f:CreateTexture(nil, "ARTWORK")
    f.sombra:SetTexture("Textures\\ShadowBlob")
    f.sombra:SetVertexColor(0, 0, 0)
    f.sombra:SetAlpha(0.75)
    f.sombra:SetSize(78, 18)
    f.sombra:SetPoint("CENTER", f, "BOTTOM", 0, 46)
    f.sombra:Hide()   -- el dueño: «un agujero negro en el piso». Fuera.
    --  El marco va en una capa POR ENCIMA del muñeco (si no, lo tapa).
    local capaMarco = CreateFrame("Frame", nil, f)
    capaMarco:SetAllPoints(f)
    capaMarco:SetFrameLevel(f:GetFrameLevel() + 7)
    f.borde = PLARM.BordeArte(capaMarco, "GTarjeta", "GTarjetaOn")
    f.candado = capaMarco:CreateTexture(nil, "OVERLAY")
    f.candado:SetTexture(PLARM.ARTE2 .. "GCandadoT")
    --  el icono ocupa 17x17 px de su lienzo de 32 (iconos_exactos.py)
    f.candado:SetTexCoord(0, 17 / 32, 0, 17 / 32)
    f.candado:SetSize(17 / (1760 / 1517), 17 / (1760 / 1517))
    f.candado:SetPoint("TOPRIGHT", -9, -9)
    f.capaMarco = capaMarco
    f.candado:Hide()

    --  El muneco. Va dentro de un marco propio para poder recortarlo sin
    --  tocar el borde ni el nombre.
    local hueco = CreateFrame("Frame", nil, f)
    --  🎨 Mas ancho que la tarjeta: el tamaño del muñeco lo da el ANCHO del
    --     marco, y en la maqueta el personaje llena la tarjeta.
    hueco:SetPoint("TOPLEFT", -18, -3)
    hueco:SetPoint("BOTTOMRIGHT", 18, 40)   -- deja sitio al nombre y la rareza
    f.hueco = hueco

    f.modelo = CreateFrame("DressUpModel", nil, hueco)
    f.modelo:SetAllPoints()
    --  🖱️ GIRAR LA PIEZA CON EL RATON, como en su rejilla.
    --
    --  Lo pidio el dueno: «incluso las armas y demas items sueltos puedo
    --  rotarlos con la camara con el mouse». En su addon es una linea de su
    --  `AppearanceModelMixin:OnLoad` -- `self:SetEnableDragRotation(true)`--
    --  pero esa funcion la pone su DLL: en 3.3.5a hay que hacerlo a mano.
    --
    --  🪤 Y el raton del muneco estaba DESACTIVADO a proposito, para que el
    --  clic fuera de la celda entera. Asi que se deja activado pero se
    --  reenvia el clic: si el raton no se movio, es un clic normal.
    --
    --    🎯 Anadir una interaccion no puede quitar la que ya habia. Arrastrar
    --       y pulsar comparten el mismo boton, y lo que los distingue es si
    --       hubo movimiento.
    f.modelo:EnableMouse(true)
    f.modelo:EnableMouseWheel(false)     -- la rueda es para pasar de pagina
    do
        local girando, ultimoX, movido = false, 0, false
        f.modelo:SetScript("OnMouseDown", function(m, boton)
            if boton ~= "LeftButton" then return end
            girando, movido = true, false
            ultimoX = GetCursorPosition()
        end)
        f.modelo:SetScript("OnMouseUp", function(m, boton)
            girando = false
            --  Un clic sin arrastre es un clic de la ficha: se reenvia.
            if boton == "LeftButton" and not movido then
                local padre = m:GetParent():GetParent()
                if padre and padre:GetScript("OnClick") then
                    padre:GetScript("OnClick")(padre)
                end
            end
        end)
        f.modelo:SetScript("OnUpdate", function(m)
            if not girando then return end
            local x = GetCursorPosition()
            local d = x - ultimoX
            if math.abs(d) < 1 then return end
            movido = true
            ultimoX = x
            --  El giro se guarda en la celda para que sobreviva al repintado.
            f.giro = (f.giro or 0) + d * 0.02
            pcall(function() m:SetFacing(f.giro) end)
        end)
    end
    --  🔴 EL MUNECO SE DIBUJA EN LA PASADA 3D Y LO TAPA CUALQUIER TEXTURA DEL
    --  MISMO NIVEL. El diagnostico lo dejo claro: `GetModel()` devolvia el
    --  modelo -- estaba cargado y bien vestido-- y aun asi la celda se veia
    --  vacia. No era que no cargara: era que se pintaba DEBAJO del fondo de
    --  la ficha.
    --
    --    🎯 "No se ve" y "no esta" se parecen mucho y se arreglan al reves.
    --       Preguntarle al modelo si existe costo dos minutos y ahorro seguir
    --       tocando el vestir, que estaba bien desde el principio.
    hueco:SetFrameLevel(f:GetFrameLevel() + 3)
    f.modelo:SetFrameLevel(f:GetFrameLevel() + 4)

    --  🪤 TRANSPARENTE HASTA QUE ESTA VESTIDA. `SetUnit("player")` pinta al
    --  instante lo que lleva el jugador, asi que sin esto se ve un fogonazo
    --  del personaje con SU ropa antes de cambiarse: 18 celdas iguales
    --  durante medio segundo.
    f.modelo:SetAlpha(0)

    --  🎨 MARCA DE «TIENE OTROS COLORES», en la esquina.
    --
    --  Sin esto no hay forma de saber que conjuntos tienen variantes sin
    --  pulsarlos uno a uno, y con 94 conjuntos nadie los pulsa todos.
    --
    --  🪤 LA PRIMERA VERSION PONIA EL NUMERO DE COLORES, Y CONFUNDIA. El
    --  dueno lo vio enseguida: en esta rejilla **los numeros ya significan
    --  otra cosa** -- las piezas que llevas del conjunto (`3/9`). Dos numeros
    --  con significados distintos en la misma celda se leen mal.
    --
    --    🎯 Un simbolo nuevo no puede reutilizar un lenguaje que ya esta
    --       usado para otra cosa. Si los numeros son piezas, los colores no
    --       pueden ser un numero.
    --
    --  Tres cuadraditos de color se entienden sin leyenda. Cuantos son exacto
    --  se dice al pasar el raton, que es donde va lo de segundo orden.
    --  🧩 CUANTAS PIEZAS DEL CONJUNTO TIENES, a la vista.
    --
    --  Estaba solo en el tooltip, o sea que habia que pasar el raton por las
    --  94 casillas para saber cual te falta poco. Lo interesante de una
    --  coleccion es justo eso, asi que va en la celda.
    --
    --  🪤 Y por eso el marcador de colores NO puede ser un numero: en esta
    --  celda un numero ya significa «piezas». Lo dijo el dueno antes de que
    --  se viera: *«ese numero en una esquina confunde»*.

    f.colores = CreateFrame("Frame", nil, f)
    f.colores:SetSize(26, 12)
    f.colores:SetPoint("TOPRIGHT", -4, -4)
    f.colores:SetFrameLevel(f:GetFrameLevel() + 6)   -- por encima del muneco
    do
        --  🔴 NO SON LOS COLORES DE VERDAD, Y POR ESO NO PUEDEN PARECERLO.
        --
        --  Antes eran rojo, azul y verde, IGUALES en todas las casillas: un
        --  conjunto que solo tiene variante dorada y plateada ensenaba tres
        --  cuadraditos de colores que no existen. Eso no es una marca, es una
        --  promesa falsa -- y con 94 conjuntos se nota enseguida.
        --
        --  Los colores reales los manda el servidor solo cuando se abre la
        --  ficha (`alt|`), asi que aqui no se conocen. La marca honesta es
        --  neutra: dice «hay variantes», no «hay estas».
        --
        --    🎯 Un indicador que no puede saber el dato no debe inventarselo:
        --       ensena que existe, y el dato se ve al abrirlo.
        local MUESTRA = { { 0.62, 0.62, 0.66 },      -- plata
                          { 0.91, 0.71, 0.30 },      -- oro
                          { 0.45, 0.45, 0.50 } }     -- pizarra
        for i, col in ipairs(MUESTRA) do
            local q = f.colores:CreateTexture(nil, "OVERLAY")
            q:SetTexture(unpack(col))
            q:SetSize(6, 10)
            q:SetPoint("LEFT", (i - 1) * 8 + 1, 0)
            --  Un borde oscuro fino: sobre un modelo claro, tres cuadrados a
            --  pelo se pierden.
            local b = f.colores:CreateTexture(nil, "ARTWORK")
            b:SetTexture(0, 0, 0, 0.7)
            b:SetSize(8, 12)
            b:SetPoint("CENTER", q, "CENTER")
        end
    end
    f.colores:Hide()

    f.icono = f:CreateTexture(nil, "ARTWORK")
    f.icono:SetSize(46, 46)
    f.icono:SetPoint("CENTER", 0, 12)
    f.icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.icono:Hide()

    --  🔴 DOS LINEAS, NO UNA. Con una sola se cortaban **6 de 18 nombres en
    --  la primera pagina**: «Almirante de Kul ...», «Coloso de los Tit...»,
    --  «Gladiador de Esc...». Y justo esos son los que hay que distinguir,
    --  porque las variantes de un mismo conjunto solo se diferencian por el
    --  final del nombre.
    --
    --    🎯 Un nombre cortado no es un detalle estetico en una rejilla donde
    --       lo unico que se hace es elegir por el nombre.
    --  🎨 Como la maqueta: nombre blanco a la izquierda, la rareza debajo
    --     en su color y el «9/9» en un chip a la derecha.
    f.nombre = PLARM.Texto(f, 11, c.texto)
    f.nombre:SetPoint("BOTTOMLEFT", 10, 24)
    f.nombre:SetPoint("BOTTOMRIGHT", -8, 24)
    --  Nombres largos («Almirante de Kul Tiras»): dos lineas hacia arriba
    --  en vez de cortarse con «...».
    f.nombre:SetJustifyH("LEFT")
    f.rareza = PLARM.Texto(f, 9, c.textoSuave)
    f.rareza:SetPoint("BOTTOMLEFT", 10, 10)
    f.nombre:SetJustifyV("BOTTOM")
    f.nombre:SetHeight(28)

    --  🧩 CUANTAS PIEZAS TIENES DEL CONJUNTO.
    --
    --  🪤 Esto ya estaba escrito y parecia roto: no salia nunca. **No era el
    --  addon: era que el servidor no mandaba el total.** El mensaje `pag|`
    --  llevaba id, tengo, rareza, variantes y ranura -- pero no de cuantas
    --  piezas consta-, asi que `d.total` era nil y el texto quedaba vacio.
    --
    --    🎯 Antes de reescribir algo que «no funciona», mira si le llega el
    --       dato. Se estuvo a punto de duplicar un contador que ya existia.
    --
    --  🪤 Y va en su propio marco POR ENCIMA del muneco: colgado de la celda a
    --  secas lo tapa el modelo, que vive en un marco de nivel mas alto. Es la
    --  misma razon por la que los cuadraditos de color llevan `+6`.
    --
    --  A la IZQUIERDA, porque la derecha ya la ocupan los colores: dos marcas
    --  encima la una de la otra no se leen.
    local marcaP = CreateFrame("Frame", nil, f)
    marcaP:SetAllPoints(f)
    marcaP:SetFrameLevel(f:GetFrameLevel() + 6)
    --  🎨 El nombre, la rareza y el oscurecido del pie van ENCIMA del muñeco:
    --     con dos lineas, el modelo tapaba la de arriba (medido en el juego).
    f.nombre:SetParent(marcaP); f.rareza:SetParent(marcaP); f.pieOsc:SetParent(marcaP)
    local chip = marcaP:CreateTexture(nil, "ARTWORK")
    chip:SetTexture(PLARM.ARTE2 .. "GChip"); chip:SetTexCoord(0, 1, 0, 30 / 32)
    chip:SetSize(36, 17)
    chip:SetPoint("BOTTOMRIGHT", -9, 8)
    f.chip = chip
    f.progreso = PLARM.Texto(marcaP, 9, { 0.9, 0.88, 0.84 })
    f.progreso:SetPoint("CENTER", chip, "CENTER", 0, 0)

    --  ⏳ LA RULETA DE CARGA, COMO LA DE ASCENSION
    --
    --  El dueño lo pidio asi: *«cuando doy clic a armas o sets siempre hay un
    --  preload de iconos... ¿no seria mejor reemplazar ese icono por uno de
    --  loading? yo vi que Ascension si tiene eso»*. Y lo tiene:
    --  `ShowLoadingAfterDelay()` / `CancelLoading()`.
    --
    --  🔑 SU PLANTILLA, sacada de SU CLIENTE (no inventada). Vive en
    --  `Interface\SharedXML\SharedPanelTemplates.xml`, dentro de
    --  `patch-B.MPQ`, y es exactamente esto:
    --
    --      <Texture parentKey="Spinner"> <Size x="128" y="128"/>
    --        <Anchor point="CENTER"/>
    --        <AnimationGroup looping="REPEAT">
    --          <Rotation duration="1" degrees="-360"/>
    --
    --  o sea: una textura centrada girando una vuelta por segundo, sobre un
    --  fondo oscuro, y **solo si la carga tarda**.
    --
    --  🪤 Su textura es el atlas `specdial_edgeshine`, de una expansion
    --  posterior: aqui no existe. Se busco un equivalente **comprobando cuales
    --  existen de verdad en nuestro cliente**, no suponiendolo -- `SetTexture`
    --  no da error con una ruta inventada. `Interface\Cooldown\starburst`
    --  esta en `locale-esMX.MPQ`.
    --
    --  🪤 Y el arte de la interfaz de 3.3.5a **no esta en `common.MPQ`**: esta
    --  en los MPQ de IDIOMA. Buscarlo en los comunes da cero y parece que la
    --  textura no existe.
    f.cargando = CreateFrame("Frame", nil, f)
    f.cargando:SetAllPoints(f)
    f.cargando:SetFrameLevel(f:GetFrameLevel() + 8)
    local sombra = f.cargando:CreateTexture(nil, "BACKGROUND")
    sombra:SetAllPoints(f.cargando)
    sombra:SetTexture(0, 0, 0, 0.35)
    local ruleta = f.cargando:CreateTexture(nil, "OVERLAY")
    --  🪤 LA RUTA LLEVA BARRAS DOBLES, Y AQUI SE PERDIERON.
    --
    --  Se escribio con una sola barra, asi que en Lua `\C` y `\s`
    --  dejan de ser barras y la ruta quedo en `InterfaceCooldownstarburst`.
    --  El cliente no encuentra esa textura y **no da ningun error**: el
    --  cuadro sale vacio. Diez intentos persiguiendo el modo de mezcla, el
    --  tamaño y la animacion, y la causa era la ruta.
    --
    --  🔬 Lo zanjo la sonda `verruleta`, que dejo el aviso fijo y conto lo
    --  que habia: `marco=1 tex=nil ancho=44 alto=44 alpha=1.00`. **El
    --  marco estaba, con tamaño y opaco: lo unico nulo era la textura.**
    --
    --    🎯 Ya estaba escrito en el proyecto que este entorno se come las
    --       barras invertidas al escribir ficheros. Volvio a pasar, y se
    --       tardo diez intentos en mirarlo porque «no se ve» parecia un
    --       problema de dibujo y era de ruta.
    ruleta:SetTexture("Interface\\AddOns\\ProjectJaina_Wardrobe\\arte\\medallon.tga")
    --  🔴 ADITIVA, O SOLO SE VE UN CUADRADO NEGRO.
    --
    --  Se extrajo el `.blp` y **se miro**: es una estrella blanca sobre fondo
    --  NEGRO, sin canal de transparencia. Dibujada normal, el cuadro negro
    --  tapa la celda -- el dueño lo vio exacto: *«sale simplemente la
    --  cuadricula ploma, pero no el icono de carga»*. En modo ADD el negro no
    --  suma nada y solo se ve la estrella.
    --
    --    🎯 Mirar la textura cuesta un minuto y evita adivinar por que «no se
    --       ve». `SetTexture` no avisa de nada: ni de una ruta inventada ni de
    --       un modo de mezcla equivocado.
    ruleta:SetBlendMode("BLEND")
    --  🪤 `SetSize` sobre una TEXTURA no es fiable en 3.3.5a: `SetWidth` y
    --  `SetHeight` si estan siempre. Una textura sin tamaño no se dibuja, y
    --  tampoco da error.
    ruleta:SetWidth(38)
    ruleta:SetHeight(38)
    ruleta:SetPoint("CENTER", f.cargando, "CENTER", 0, 6)
    --  🎯 ES SU PROPIA TEXTURA, sacada de su cliente: no se tiñe ni se
    --  retoca. Ya trae su color y su difuminado.
    ruleta:SetVertexColor(1, 1, 1)
    ruleta:SetAlpha(1)
    --  🔴 LA ANIMACION SE CREA SOBRE EL MARCO, NO SOBRE LA TEXTURA.
    --
    --  En el XML de Ascension las animaciones cuelgan de la propia `<Texture>`,
    --  y al copiarlo a Lua se escribio `ruleta:CreateAnimationGroup()`. En
    --  3.3.5a **eso no existe**: los grupos de animacion se crean sobre un
    --  marco y se les dice a que region apuntan (`SetTarget`).
    --
    --  🪤 Y no dio ningun error, porque los errores de Lua vienen APAGADOS de
    --  fabrica: la funcion moria ahi y la celda se quedaba con el fondo gris y
    --  sin ruleta. El dueño lo describio tal cual: *«sale simplemente la
    --  cuadricula ploma, pero no el icono de carga»*.
    --
    --    🎯 Traducir XML a Lua no es copiar la estructura: cada API tiene su
    --       dueño. Y en este cliente, si una llamada no existe, no te enteras.
    --
    --  Se guarda si funciono para poder preguntarlo desde la sonda.
    local giro = nil
    local ok = pcall(function()
        giro = f.cargando:CreateAnimationGroup()
        giro:SetLooping("REPEAT")
        local rot = giro:CreateAnimation("Rotation")
        rot:SetTarget(ruleta)          -- <- lo que faltaba
        rot:SetDuration(1)
        rot:SetDegrees(-360)
    end)
    PLARM.RULETA_ANIMA = ok and giro ~= nil
    f.cargando.giro = giro
    f.cargando.ruleta = ruleta


    --  Plan B si el cliente no admite la animacion: latir la opacidad, que
    --  se ve igual de claro que «esto esta cargando» y no depende de nada.
    f.cargando:SetScript("OnShow", function(s)
        if s.giro then s.giro:Play()
        else s.reloj = 0 end
    end)
    f.cargando:SetScript("OnHide", function(s)
        if s.giro then s.giro:Stop() end
    end)
    --  🔄 GIRA DE VERDAD, MOVIENDO LAS COORDENADAS DE LA TEXTURA.
    --
    --  Ascension la gira con una `<Rotation>` de su grupo de animacion. **Esa
    --  API no existe en 3.3.5a** -- medido: crear el grupo falla y
    --  `PLARM.RULETA_ANIMA` sale `false`.
    --
    --  🔑 Pero girar SI se puede, y sin tocar el DLL: `SetTexCoord` admite la
    --  forma de OCHO argumentos -- las cuatro esquinas sueltas-- asi que se
    --  rotan esas cuatro esquinas alrededor del centro en cada fotograma. Es
    --  como lo hacian los addons de esta epoca, y da una rotacion real.
    --
    --    🎯 Cuando la API de la referencia no existe aqui, no se rebaja lo que
    --       se pidio: se busca el otro camino que el cliente SI tiene. Rotar
    --       era posible; lo que no existia era su forma de pedirlo.
    --  🐢 DESPACIO. A una vuelta por segundo parecia una explosion, no una
    --  espera: *«veo algo girando pero demasiado rapido y no parece un
    --  loading»*. Un indicador de carga tiene que sugerir paciencia, no prisa.
    --  🕐 A 1,4 s por vuelta apenas se apreciaba: la carga suele durar menos
    --  de medio segundo, asi que solo se veia un cuarto de giro y parecia
    --  quieto. A 0,8 s da una vuelta entera aunque cargue rapido.
    local VUELTA = 0.62                     -- segundos por vuelta
    f.cargando:SetScript("OnUpdate", function(s, e)
        --  🔴 RELOJ COMPARTIDO, NO UNO POR CELDA.
        --
        --  Cada celda llevaba su propio contador y empezaba a girar cuando le
        --  tocaba, asi que las dieciocho iban desfasadas: *«se nota muy raro
        --  porque todos salen a destiempo y mas parecen hormigas»*.
        --
        --  Con `GetTime()` -- el mismo reloj para todas-- el angulo depende solo
        --  del instante, no de cuando aparecio cada una: giran a la vez y se
        --  lee como UN indicador de carga, no como dieciocho bichos.
        --
        --    🎯 Varias copias de la misma animacion tienen que compartir el
        --       origen del tiempo, o el conjunto se ve nervioso aunque cada
        --       pieza sea correcta.
        local a  = -2 * math.pi * (GetTime() / VUELTA)
        local co, si = math.cos(a), math.sin(a)
        --  Media diagonal, para que al girar no se salga de la imagen.
        local h = 0.5
        local function esq(x, y)
            return 0.5 + (x * co - y * si) * h, 0.5 + (x * si + y * co) * h
        end
        local ax, ay = esq(-1,  1)          -- arriba izquierda
        local bx, by = esq(-1, -1)          -- abajo  izquierda
        local cx, cy = esq( 1,  1)          -- arriba derecha
        local dx, dy = esq( 1, -1)          -- abajo  derecha
        pcall(function() s.ruleta:SetTexCoord(ax, ay, bx, by, cx, cy, dx, dy) end)
        --  Y un latido suave: gira despacio y respira, que es lo que se lee
        --  como «esperando» y no como un efecto.

    end)
    f.cargando:Hide()

    f:SetScript("OnEnter", function(self)
        if self.datos then PLARM.Eventos.Disparar("FICHA_ENCIMA", self.datos) end

        --  Nombre y rareza SIN pulsar. El nombre de abajo se recorta con
        --  «...» -la celda mide 130 px- y ademas asi se ve cuantas piezas
        --  llevas antes de gastar un clic. El dueno ya se habia quejado de
        --  tener que hacer muchos clics para ver lo mismo.
        local d = self.datos
        if d and d.nombreCompleto then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local r = PLARM.RAREZAS[d.r or 1] or PLARM.RAREZAS[1]
            GameTooltip:AddLine(d.nombreCompleto, unpack(r.color))
            if d.total and d.total > 0 then
                GameTooltip:AddLine(string.format("%s  ·  %d de %d piezas",
                    r.nombre, d.t or 0, d.total), 0.6, 0.62, 0.67)
            end
            if (d.variantes or 0) > 1 then
                GameTooltip:AddLine(d.variantes .. " colores", 0.91, 0.71, 0.30)
            end
            GameTooltip:Show()
        end
        self.borde[1]:SetVertexColor(unpack(c.oro))
        self.borde[2]:SetVertexColor(unpack(c.oro))
        self.borde[3]:SetVertexColor(unpack(c.oro))
        self.borde[4]:SetVertexColor(unpack(c.oro))
    end)
    f:SetScript("OnLeave", function(self) GameTooltip:Hide(); self:Pintar() end)
    f:SetScript("OnClick", function(self)
        if not self.datos then return end
        --  🎯 PULSAR = PROBARSELO EN EL MUNECO QUE YA HAY. Antes esto abria
        --  una segunda ventana con su propio muneco; el dueno lo corto:
        --
        --      «no es necesario otro muneco ya que se puede reutilizar el que
        --       ya se tiene en la interfaz: de esa manera se previsualiza en
        --       vivo sin hacer mas cosas»
        --
        --  Tenia razon. La ventana aparte duplicaba un modelo, tapaba la
        --  rejilla y costo tres intentos de colocacion. Los colores caben en
        --  una barra debajo del muneco.
        --
        --    🎯 Antes de anadir una ventana, mira si lo que hace ya esta en
        --       pantalla.
        --  🎨 La que acabas de pulsar se queda iluminada (el diseño nuevo lo
        --     pide, y antes solo se marcaba lo «pendiente» del servidor).
        PLARM.fichaElegida = self.datos.id
        for _, o in ipairs({ self:GetParent():GetChildren() }) do
            if o.Pintar and o.datos then o:Pintar() end
        end
        PLARM.Eventos.Disparar("FICHA_PULSADA", self.datos)
    end)

    --- Pide el icono; si el cliente aun no lo conoce, no hace nada y se
    --- volvera a intentar en el siguiente repintado (Vestir la llama en su
    --- propio bucle).
    --  🔴 EL NOMBRE TAMBIEN SE REINTENTA, POR LA MISMA RAZON QUE EL ICONO.
    --
    --  Se pedia UNA sola vez al poner la celda, y si el catalogo todavia no
    --  habia llegado se quedaba con "..." **para siempre**, aunque el nombre
    --  apareciera medio segundo despues. Medido el 04-09-2026 con la sonda
    --  `nombres`: seis celdas mostraban "..." y el dato ya estaba puesto
    --  (`ahora=Hacha de las Tierras de Fuego - roja`).
    --
    --    🎯 Justo debajo estaba escrito para el icono: «pedirlo una vez y
    --       quedarse con ese nil PARA SIEMPRE es el mismo error que ya costo
    --       el muneco». El arreglo se hizo para el icono y el nombre se quedo
    --       fuera -- una leccion aprendida se aplica a TODOS los datos que
    --       vienen del servidor, no solo al que la enseño.
    function f:ActualizarNombre()
        local d = self.datos
        if not d or not d.id or d.piezasFijas then return end
        local puesto = self.nombre:GetText()
        if puesto and puesto ~= "" and puesto ~= "..." then return end
        local ok, _, _, n = pcall(C_Appearance.GetAppearanceDisplayInfo, d.id)
        if ok and n and n ~= "" then
            self.nombre:SetText(n)
            d.nombreCompleto = n
        end
    end

    function f:ActualizarIcono()
        if self.icono:IsShown() then return end   -- ya lo tenemos
        local id = self.idIcono
        if not id then return end
        local ok, ico = pcall(GetItemIcon, id)
        if ok and ico then
            self.icono:SetTexture(ico)
            self.icono:Show()
        end
    end

    --- Repinta bordes y textos segun el estado. No toca el modelo.
    function f:Pintar()
        local d = self.datos
        if not d then return end
        --  🔴 EL BORDE YA NO LLEVA EL COLOR DE LA RAREZA (04-09-2026).
        --
        --  El dueño: *«hay un borde de color en cada set, es innecesario,
        --  Ascension tampoco lo tiene; en lugar de eso podrias pintar el
        --  titulo del color de su rareza»*.
        --
        --  Y tiene razon en lo de fondo: la rejilla tenia DOS cosas gritando
        --  el mismo dato -- el borde y el nombre-- y una rejilla de 18 celdas
        --  con 18 bordes de colores distintos se lee peor, no mejor.
        --  Ascension deja el marco neutro y usa el color solo en el texto.
        --
        --  El borde se reserva para lo que SI es estado del momento y cambia:
        --  lo que has elegido y lo que llevas puesto.
        --
        --    🎯 Un color por dato. Si dos elementos dicen lo mismo, uno sobra.
        local col = c.borde
        if d.id and d.id == PLARM.fichaElegida then col = c.oro  -- la que miras
        elseif d.pendiente then col = { 0.64, 0.21, 0.93 }    -- morado: elegido
        elseif d.puesto then col = c.oro                      -- dorado: puesto
        end
        for i = 1, 4 do self.borde[i]:SetVertexColor(unpack(col)) end

        --  Lo que no tienes se apaga. De un vistazo se ve que te falta, que es
        --  la mitad de la gracia de coleccionar -y sin esto un conjunto con 0
        --  de 11 piezas se veia igual de encendido que uno completo-.
        --
        --  🔑 Y el NOMBRE lleva el color de la rareza, que es donde lo pone
        --  Ascension. Apagado si no lo tienes: el color se gana.
        local tengoAlgo = (d.t or 0) > 0

        --  🔒 Y LO QUE ESTA CLASE NO PUEDE PONERSE, TAMBIEN APAGADO.
        --
        --  Lo pidio el dueno: *«asi deberia salir los que no puedo ponerme:
        --  bloqueados»*. No se esconden porque **la coleccion es de CUENTA**:
        --  un conjunto de tela que su paladin no puede llevar si lo usa su
        --  mago, y esconderselo seria esconderle algo que tiene.
        --
        --  🩤 Antes ni siquiera llegaban marcados: el servidor decidia por la
        --  PRIMERA pieza del conjunto, y si esa era la capa --exenta para
        --  todos-- pasaba entero. Por eso «Almirante de Kul Tiras» le salia a
        --  un paladin y al aplicarlo se caian nueve de diez.
        local usable = not d.bloq
        local vivo = tengoAlgo and usable

        local colNombre = c.textoTenue
        --  🎨 La maqueta pinta el nombre en blanco y la RAREZA en su color.
        --  Lo que no puedes llevar sigue LEYENDOSE (la maqueta lo enseña a
        --  color con candado); solo se apaga un poco.
        colNombre = vivo and { 0.96, 0.95, 0.92 } or { 0.72, 0.71, 0.68 }
        self.nombre:SetTextColor(unpack(colNombre))
        self.modelo:SetAlpha(self.vestida and 1 or 0)
        self.luz = vivo and LUZ or LUZ_APAGADA
        if self.vestida and self.modelo.SetLight then self.modelo:SetLight(unpack(self.luz)) end
        self.icono:SetDesaturated(not vivo)
        self.icono:SetAlpha(vivo and 1 or 0.5)

        --  🎨 Sin colores por ahora (el dueño, 25-09-2026).
        self.colores:Hide()
        --  🎨 GALERIA: su fondo de siempre y el candado si no lo tienes.
        PLARM.PonerFondo(self.fondo, PLARM.FondoDe(d.id, d.atuendo or d.nombre), ANCHO - 2, self:GetHeight() - 2)
        --  Un atuendo guardado no tiene rareza: salia «COMÚN» (26-09).
        if d.piezasFijas then
            local n = #d.piezasFijas
            self.rareza:SetText(n == 1 and "1 pieza" or (n .. " piezas"))
        else
            self.rareza:SetText(PLARM.RarezaTexto(d.r))
        end
        self.chip:Hide(); if (self.progreso:GetText() or "") ~= "" then self.chip:Show() end
        --  Lo bloqueado en gris y apagado (el dueño: «asi si parecian bloqueados»).
        self.fondo:SetDesaturated(not vivo)
        --  Filtro oscuro: el fondo no se come al muñeco (el dueño).
        if vivo then self.fondo:SetVertexColor(0.6, 0.58, 0.55)
        else self.fondo:SetVertexColor(0.4, 0.4, 0.4) end
        if vivo then self.candado:Hide() else self.candado:Show() end

    end

    --- Solo el NOMBRE y el estado, sin tocar el muneco.
    ---
    --- 🔴 POR QUE EXISTE (03-09-2026). Cuando llegaban los nombres del
    --- servidor, `Coleccion.lua` llamaba a `Poner()` en **las 18 celdas del
    --- mismo fotograma**, saltandose la cola escalonada. Y `Poner()` rehace el
    --- muneco entero.
    ---
    --- El cliente no puede armar 18 personajes a la vez: los primeros salian y
    --- **el resto se quedaba con lo que llevaba puesto el jugador**. Eso era el
    --- «me salen todos repetidos» que el dueno reporto SEIS veces, y no tenia
    --- nada que ver con la paginacion -- pasaba tambien al abrir.
    ---
    ---   🎯 Tener la cola escalonada no sirve de nada si hay OTRO camino que
    ---      la esquiva. Ascension no lo tiene: en su rejilla, lo unico que
    ---      toca los munecos es su cola (`InternalUpdateAppearances`).
    ---
    ---   🎯 Y la pista estaba en el sintoma: cargaban 3 de 18 SIEMPRE, tambien
    ---      en la primera pagina. Un fallo que respeta un numero fijo no es una
    ---      carrera: es un limite.
    function f:PonerNombre(datos)
        if not self.datos or not datos then return end
        self.datos.nombreCompleto = datos.nombreCompleto
        self.nombre:SetText(datos.nombreCompleto or datos.nombre or "...")
        self:Pintar()
    end

    --- Pone en esta celda lo que diga `datos`. Cancela lo que estuviera
    --- cargando: es lo que impide que la pagina anterior se pinte encima.
    function f:Poner(datos)
        --  🔬 Se cuenta aparte de `Vestir`: si `Poner` sale 1 y `Vestir` 17,
        --  el que repite es la respuesta de las piezas; si salen los dos 17,
        --  alguien esta llamando a `Poner` diecisiete veces.
        self.vecesPoner = (self.vecesPoner or 0) + 1
        --  🔑 SI YA ESTA ENSENANDO ESO, NO SE REHACE. Copiado de Ascension:
        --
        --      if self.appearanceID == appearanceID and ... then
        --          self:UpdateBorder()
        --          return
        --      end
        --
        --  Repintar la pagina -- al aplicar, al comprar, al volver de otra
        --  pagina -- reconstruia los 18 munecos desde cero. Con esto solo se
        --  actualiza el borde, que es lo unico que pudo cambiar.
        --
        --    🎯 Pintar de nuevo no es reconstruir. Lo que ya esta bien, se
        --       deja.
        --  🪤 Y AQUI FALTABA `Show()`. Las celdas se ESCONDEN cuando la
        --  pagina trae menos de 18, y al volver a una pagina llena este
        --  atajo las daba por buenas sin volver a ensenarlas: la rejilla
        --  entera se quedaba en negro, con el contador diciendo «26 de 26».
        --
        --  Ascension no lo necesita porque su `SetAppearanceID` hace el
        --  `Show()`/`Hide()` mas abajo, fuera del atajo. Al copiar el atajo
        --  sin copiar donde acaba, se copio medio mecanismo.
        --
        --    🎯 Copiar un atajo exige copiar TAMBIEN lo que el atajo se
        --       salta, y comprobar que nada de eso hacia falta.
        if datos and self.datos and self.datos.id == datos.id and self.vestida then
            self.datos = datos
            self:Show()
            self:Pintar()
            return
        end

        self.token = (self.token or 0) + 1
        self.datos = datos
        self.vestida = false
        --  🔴 LA CELDA NO SE VACIA AL INSTANTE. ESO ERA EL PARPADEO.
        --
        --  Aqui habia un `SetAlpha(0)` seco: al cambiar de categoria las 18
        --  celdas se quedaban en negro de golpe y se iban rellenando una a
        --  una. El dueño lo describio como *«2 parpadeos cuando voy a cabeza o
        --  a sets»* -- y no eran dos repintados: **se midio y sale uno solo**
        --  (`refrescar=2 llenar=2 poner=36` para dos cambios, o sea 18 celdas
        --  cada uno, y `apariencia=0`). Las dos «fases» eran el vaciado y el
        --  rellenado del MISMO repintado.
        --
        --    🎯 «Parpadea dos veces» no significa que se pinte dos veces. Sin
        --       contar, se habrian buscado repintados que no existen.
        --
        --  Ascension tampoco vacia: mantiene el muñeco y solo saca un aviso de
        --  carga **si tarda** (`ShowLoadingAfterDelay`). Aqui igual -- se deja
        --  lo anterior a la vista y se apaga solo si a los 0,4 s todavia no
        --  hay nada nuevo, que es cuando el hueco informa en vez de molestar.
        local miToken = self.token
        if self.modelo:GetAlpha() > 0 then
            PLARM.Tras(0.4, function()
                if self.token == miToken and not self.vestida then
                    self.modelo:SetAlpha(0)
                end
            end)
        end

        if not datos then self:Hide() return end
        self:Show()

        local _, _, nombre = C_Appearance.GetAppearanceDisplayInfo(datos.id)
        --  🔑 Si la respuesta de nombres ya llego, manda ella: viene en la
        --     propia entrada y no depende de que la cache este poblada
        --     en este instante.
        nombre = datos.nombreCompleto or nombre
        --  🔴 EL ICONO SE REINTENTA, NO SE PIDE UNA SOLA VEZ.
        --
        --  `GetItemIcon(id)` devuelve nil si el cliente todavia no conoce esa
        --  pieza -- exactamente igual que `GetItemInfo`. Pedirlo una vez al
        --  crear la ficha y quedarse con ese nil PARA SIEMPRE es el mismo
        --  error que ya costo el muneco: no se reintenta, asi que la celda
        --  se queda en blanco aunque la pieza llegue un segundo despues.
        --
        --    🎯 Cualquier dato que dependa del cliente se pide, se reintenta
        --       y se actualiza cuando llega. Una sola pregunta no basta.
        local c2 = PLARM.Contrato.Cache and PLARM.Contrato.Cache()[datos.id]
        self.idIcono = (c2 and tonumber(c2.pieza)) or tonumber(datos.id)
        self:ActualizarIcono()
        --  ⏳ MIENTRAS CARGA SE VE LA RULETA, NO EL ICONO.
        --
        --  La primera version la ponia ENCIMA del icono y solo tras un
        --  segundo, copiando el `ShowLoadingAfterDelay` de Ascension. El dueño
        --  no vio ningun cambio, y con razon: casi todas las celdas cargan
        --  antes de ese segundo, asi que lo unico que llegaba a verse era el
        --  icono -- que es justo lo que queria quitar.
        --
        --    🎯 Copiar el comportamiento de la referencia no es lo mismo que
        --       resolver lo que te han pedido. El pidio **sustituir** el
        --       icono, no acompañarlo.
        self.icono:Hide()
        self.cargando:Show()
        self.nombre:SetText(nombre or "...")
        --  El nombre de la celda se recorta con «...»; el aviso al pasar por
        --  encima lo ensena entero, y por eso se guarda aparte.
        datos.nombreCompleto = nombre
        if datos.total and datos.total > 1 then
            self.progreso:SetText(datos.t .. "/" .. datos.total)
        elseif datos.precio and datos.precio > 0 then
            self.progreso:SetText("|cffE8B54D" .. datos.precio .. "|r")
        else
            self.progreso:SetText("")
        end
        self:Pintar()

        --  Vestir: primero se averigua QUE piezas, luego se espera a que el
        --  cliente las conozca, y solo entonces se prueba.
        --  🔑 UN ATUENDO GUARDADO YA TRAE SUS PIEZAS: no hay que pedirlas.
        --  Es lo mismo que hace un conjunto, pero sin viaje al servidor --
        --  el atuendo se guardo con la lista dentro.
        if datos.piezasFijas then
            self.nombre:SetText(datos.atuendo or "")
            datos.nombreCompleto = datos.atuendo
            self:Vestir(datos.piezasFijas, #datos.piezasFijas > 1)
        elseif datos.id >= 2000000 and datos.id < 3000000 then
            local token = self.token
            C_ItemSet.GetAppearances(datos.id, function(piezas)
                --  Si el jugador ya paso de pagina, esta respuesta no vale.
                if self.token ~= token then return end
                --  🪤 UN ARMA ES UN «CONJUNTO» DE UNA PIEZA. Desnudar al
                --  muneco para ensenar un arco deja un cuerpo desnudo con un
                --  arco -- que es justo lo que se veia. Lo que decide no es
                --  el tipo, es cuantas piezas trae.
                self:Vestir(piezas, #piezas > 1)
            end)
        else
            --  🔴 AQUI PONIA `cat = 0` A FUEGO, Y `0` ES «CABEZA».
            --
            --  O sea que **toda pieza suelta se trataba como un yelmo**: el
            --  encuadre por ranura --que existe desde hace dias y parecia no
            --  funcionar-- siempre usaba el de la cabeza, y la deteccion de
            --  «esto es un arma» no podia dispararse nunca.
            --
            --  El dato estaba a mano: el servidor manda la categoria en el
            --  mensaje `pag|` (`id:t:rareza:variantes:cat`) y `Contrato.lua`
            --  ya la guardaba en `datos.cat`. Solo que nadie la leia.
            --
            --    🎯 «El encuadre no se aplica» y «el encuadre se aplica MAL»
            --       se ven igual en pantalla y se arreglan en sitios
            --       distintos. Costo calibrar numeros que nunca se usaron.
            self:Vestir({ { cat = datos.cat or 0, id = datos.id } }, false)
        end
    end

    --- Viste el muneco. `piezas` son { cat, id }.
    --- Viste la celda.
    ---
    --- 🔴 SE VISTE DIRECTAMENTE, SIN ESPERAR A NADA.
    ---
    --- Aqui estuvo el error que costo toda la tarde. La celda esperaba a que
    --- `GetItemInfo` devolviera la ficha del objeto antes de llamar a
    --- `TryOn`... y `GetItemInfo` casi nunca devolvia nada, asi que `TryOn`
    --- no se llamaba NUNCA y la ficha se quedaba en el icono.
    ---
    --- El propio armario tenia la respuesta: al PULSAR una ficha si cargaba.
    --- Y lo que hace ese camino -el muneco grande- es llamar a `TryOn` a
    --- secas, sin preguntar nada antes.
    ---
    ---   🎯 **`TryOn` es lo que hace que el cliente pida el objeto.** No hay
    ---      que esperar el dato para pedirlo: pedirlo ES intentarlo. Esperar
    ---      antes de intentar era esperar a algo que solo iba a pasar si
    ---      intentabas.
    ---
    --- Asi que se intenta y se repite cada medio segundo hasta que el muneco
    --- aparece. Sin plazo: la espera se cancela sola al cambiar de pagina.
    function f:Vestir(piezas, esConjunto)
        local m = self.modelo

        --  🔬 CUANTAS VECES SE RE-VISTE ESTA CELDA.
        --
        --  Cinco intentos arreglando el parpadeo mirando la pantalla, y cinco
        --  veces igual. Un parpadeo = una reconstruccion del muñeco, asi que
        --  la pregunta no es «por que parpadea» sino **cuantas veces se
        --  llama aqui** -- y eso se cuenta, no se supone.
        --
        --    🎯 Es la misma leccion que ya resolvio el enganche del DLL: dos
        --       variables contando separan en un intento lo que veinte
        --       parches no separan mirando.
        PLARM.vecesVestir = (PLARM.vecesVestir or 0) + 1
        self.vecesVestir  = (self.vecesVestir or 0) + 1

        --  🔴 SIN ESTA LINEA NO SE VISTE NINGUNA CELDA, Y NO DA ERROR.
        --
        --  El bucle de abajo comprueba `self.token ~= token` para abandonar si
        --  la celda ha pasado a ensenar otra cosa. Al revertir un cambio se
        --  perdio esta declaracion, y en Lua una variable que no existe es
        --  `nil`: la comparacion daba SIEMPRE verdadera y el bucle **se mataba
        --  en su primer fotograma**. Las 18 celdas se quedaban en el icono.
        --
        --    🎯 Y la consecuencia peor no fue la rejilla: fue que la prueba
        --       del DLL que venia despues no probaba NADA, porque el codigo
        --       que iba a usarlo no llegaba a ejecutarse. Un fallo silencioso
        --       arriba invalida todo lo que se mida debajo.
        local token = self.token

        local vueltas, reloj = 0, 0
        local g = CreateFrame("Frame")
        g:SetScript("OnUpdate", function(gg, ee)
            if self.token ~= token then gg:SetScript("OnUpdate", nil) return end
            reloj = reloj + ee
            if reloj < 0.5 then return end
            reloj = 0
            vueltas = vueltas + 1

            self:ActualizarIcono()
            self:ActualizarNombre()
            local puestas = 0
            --  🪤 LAS CELDAS SI NECESITAN CAMARA, LUZ Y ENCUADRE; EL MUNECO
            --  GRANDE NO. Parece contradictorio y no lo es: el grande ocupa
            --  el panel entero y le vale la vista por defecto, mientras que
            --  una celda de 86x95 sin encuadrar ensena un trozo de rodilla.
            --
            --  Se quitaron de los dos a la vez «por coherencia» y las celdas
            --  se apagaron -- cuando con esto puesto ya se habian visto 13 de
            --  18 funcionando.
            --
            --    🎯 Que dos cosas se parezcan no significa que necesiten lo
            --       mismo. Lo que decide es cual de las dos YA funcionaba.
            local soloArma = (not esConjunto) and piezas[1]
                             and ES_ARMA[piezas[1].cat] or false

            pcall(function()
                --  🔴 EL RESETEO QUE FALTABA: `ClearModel()` ANTES DE NADA.
                --
                --  Es lo que Ascension hace en `RefreshDisplay()` justo antes
                --  de vestir cada celda, y nosotros no haciamos:
                --
                --      self:SetPosition(0, 0, 0)
                --      self:SetFacing(-0.3)
                --      self:StopSequence()
                --      self:ClearModel()     <-- ESTA
                --      self:SetCamera(1)
                --
                --  Sin `ClearModel`, el marco conserva el personaje anterior.
                --  Un `SetUnit` sobre un marco que YA tiene modelo no lo
                --  reconstruye igual, asi que el `Undress` y los `TryOn` caen
                --  sobre algo viejo -- y queda la apariencia del jugador,
                --  repetida en celda tras celda.
                --
                --    🎯 La leccion de metodo, que es la que de verdad importa:
                --       se intentaron DIEZ arreglos --quitar reintentos,
                --       esperar al modelo, esperar las fichas, escalonar el
                --       llenado-- todos sobre sintomas, y ninguno podia
                --       funcionar porque el paso que faltaba no estaba en
                --       ninguna de esas partes. El dueno lo dijo tres veces:
                --       «revisa como lo hace Ascension, deja de adivinar».
                --       Leer su `RefreshDisplay` ENTERO costo diez minutos;
                --       adivinar costo cinco dias.
                pcall(function() m:ClearModel() end)
                m:SetPosition(0, 0, 0)
                m:SetCamera(0)


                if soloArma then
                    --  🔴 UN ARMA NO SE ENSENA CON ZOOM: SE ENSENA SOLA.
                    --
                    --  Esto lo corrigio el dueno, y tenia razon:
                    --
                    --    «en Ascension no hacian un encuadre para las armas,
                    --     simplemente ponian solo el modelo del arma ahi»
                    --
                    --  Su codigo lo confirma (`AppearanceModelMixin:DisplayWeapon`):
                    --
                    --      self:SetDisplayInfo(44472, function()
                    --          ... self:TryOn(self.displayID)
                    --
                    --  44472 es una criatura INVISIBLE. Le cuelgan el arma y,
                    --  como el portador no se ve, en la celda solo queda el
                    --  arma. Nada de calibrar camaras.
                    --
                    --  🔑 Aqui el equivalente es el **11686**, «World Invisible
                    --  Trigger», que si existe en 3.3.5a -- sacado de la base,
                    --  no inventado: lo usan Onyxia Trigger, Noxxion Trigger y
                    --  otros doce.
                    --
                    --    🎯 Cuando algo se ve raro, la pregunta no siempre es
                    --       «como lo encuadro»: a veces es «que sobra en la
                    --       imagen». Aqui sobraba el cuerpo entero.
                    --  🔴 LO PROBADO, Y POR QUE ACABA ASI (03-09-2026)
                    --
                    --  Se intentaron las dos vias de Ascension, midiendo:
                    --
                    --   1. `SetDisplayInfo(<invisible>)` -- NO EXISTE aqui.
                    --      Medido: SetDisplayInfo=false, SetCreature=true.
                    --   2. `SetCreature(12999)` (su equivalente, «World
                    --      Invisible Trigger») -- **no dibuja nada**, y el
                    --      volcado de celdas confirmo que la rama SI corria
                    --      (cat=15 en las cuatro): el modelo anterior se
                    --      quedaba puesto y parecia otro fallo.
                    --   3. `SetModel("Item\ObjectComponents\Weapon\x.m2")`
                    --      -- SI dibuja el arma sola (comprobado en captura,
                    --      la Ashbringer), y ojo: la extension tiene que ser
                    --      **.m2**, no el `.mdx` que dice el DBC. **Pero sale
                    --      BLANCA**: por esa via el cliente no aplica la
                    --      textura de `ItemDisplayInfo`.
                    --
                    --    🎯 «Solo el arma» y «el arma bien pintada» resultaron
                    --       ser incompatibles sin el DLL. Entre ensenar el
                    --       arma correcta con un cuerpo detras o una silueta
                    --       blanca sin cuerpo, gana la que se reconoce.
                    --
                    --  Asi que de momento: el jugador desnudo y la camara
                    --  encima del arma. Se ve el arma con su color y sus
                    --  efectos, que es lo que hay que elegir.
                    --
                    --  ⏳ LA BUENA, pendiente: un modelo humanoide INVISIBLE
                    --  propio -- una copia de `humanmale.m2` sin geometria
                    --  pero CON sus puntos de anclaje-- metido en nuestro
                    --  parche. Entonces `SetCreature(<el nuestro>)` + `TryOn`
                    --  da exactamente lo de Ascension, con textura y todo.
                    --  Tenemos las herramientas para hacerlo (`modelos/`).
                    SinCuerpo(function() m:SetUnit("player") end)
                    m:Undress()
                else
                    SinCuerpo(function() m:SetUnit("player") end)
                    --  🔴 SE DESNUDA SIEMPRE, TAMBIEN PARA UNA PIEZA SUELTA.
                    --
                    --  Aqui ponia `if esConjunto then`. Para una pieza el
                    --  muneco conservaba el equipo del jugador, asi que la
                    --  rejilla ensenaba dieciocho veces el mismo personaje con
                    --  su armadura dorada y la pieza era una mancha.
                    m:Undress()
                end

                m:SetLight(unpack(self.luz or LUZ))
                --  🔑 Las piezas van ligeramente de lado, como en su
                --  `RefreshDisplay` (`self:SetFacing(-0.3)`); un conjunto va
                --  de frente, como en su `DisplayItemSet` (`SetFacing(0)`).
                self.giro = esConjunto and 0 or -0.35
                m:SetFacing(self.giro)
                local e = ENCUADRE.CONJUNTO
                if not esConjunto and piezas[1] then
                    e = ENCUADRE[piezas[1].cat] or e
                end
                --  🔴 SOLO SE PRUEBA LO QUE EL CLIENTE YA CONOCE. Probarse
                --  una pieza sin descargar rompe el armado del personaje en
                --  TODO el cliente -- ver la nota de `PLARM.PedirFicha`.
                --  Primero la ropa neutra (solo para una pieza suelta: un
                --  conjunto ya se viste entero), y despues la pieza.
                if not esConjunto and piezas[1] then
                    local cfg = MANIQUI[piezas[1].cat]
                    if cfg then
                        for ranura, si in pairs(cfg) do
                            local id = si and MANIQUI_ROPA[ranura]
                            if id and PLARM.PedirFicha(id) then m:TryOn(id) end
                        end
                    end
                end

                for _, p in ipairs(piezas) do
                    if PLARM.PedirFicha(p.id) then
                        m:TryOn(p.id)
                        puestas = puestas + 1
                    end
                end

                --  🔴 EL ENCUADRE VA **DESPUES** DE `TryOn`, NO ANTES.
                --
                --  Puesto antes no hacia nada: se probo `SetModelScale(8)` --un
                --  valor absurdo a proposito, para que fuera imposible no
                --  verlo-- y la rejilla salio identica. `TryOn` rehace el
                --  modelo y se lleva por delante la escala y la posicion.
                --
                --    🎯 Cuando un ajuste «no hace nada» y encima da igual el
                --       valor, no es que la funcion no sirva: es que algo lo
                --       pisa despues. Probar con un valor exagerado distingue
                --       las dos cosas en un intento.
                --
                --  🪤 Y se ponen SIEMPRE, tambien la escala 1.0: la celda se
                --  reutiliza al cambiar de pagina, asi que un conjunto heredaria
                --  el zoom del yelmo que hubiera antes en esa casilla.
                m:SetPosition(e[1], e[2], e[3])
                pcall(function() m:SetModelScale(e[4] or 1.0) end)
            end)

            --  listo cuando el cliente ya conoce todas las piezas y el muneco
            --  existe; entonces el icono sobra
            --  🔴 NO BASTA CON QUE «HAYA MODELO»: TIENE QUE SER EL PERSONAJE.
            --
            --  `GetModel()` devuelve algo en cuanto existe CUALQUIER modelo en
            --  el marco, y mientras el personaje se arma eso puede ser el
            --  propio yelmo suelto. Enseñar la celda ahi es el parpadeo que
            --  reporto el dueño: «se pone a parpadear varios segundos y
            --  termina bien».
            --
            --    🎯 La señal correcta no es «existe algo», es «existe LO QUE
            --       ESPERO». Y se puede comprobar: la ruta de un personaje
            --       lleva `character`; la de una pieza, `item`.
            local hay = false
            pcall(function()
                local r = m:GetModel()
                hay = type(r) == "string" and r:lower():find("character") ~= nil
            end)
            --  🔴 AQUI ESTABAN LOS 4-5 PARPADEOS, Y EN UNA SOLA LINEA.
            --
            --  Ponia `if vueltas > 2 then parar`. O sea: en cuanto la celda
            --  estaba lista se ENSENABA (`Pintar` le sube la opacidad), **y el
            --  bucle seguia**, rehaciendo el muneco entero dos veces mas ya a
            --  la vista. Cada reconstruccion es un parpadeo.
            --
            --  🪤 Y lo que costo cuatro rondas: los reintentos NO sobran. En
            --  3.3.5a `SetUnit` no arma el modelo en el acto, asi que un
            --  `TryOn` pegado a el se pierde en silencio. Se probo quitarlos
            --  --y esperar al modelo, y esperar a las fichas-- y cada version
            --  arreglo un sintoma creando otro: celdas con el personaje del
            --  jugador repetido, y la pagina 2 tardando.
            --
            --    🎯 Un reintento que tapa una carrera no se quita: se hace
            --       INVISIBLE. Aqui basta con parar en cuanto acierta, porque
            --       hasta ese momento la celda esta a opacidad 0.
            --
            --  Ascension llega a lo mismo por otro camino: monta el muneco una
            --  vez y aplaza solo el `TryOn` hasta que llega la ficha
            --  (`ItemQueryListener`). Aqui no hay ese aviso, asi que se sondea
            --  -- pero se sondea sin que se vea.
            --  🪤 Y SI SE RINDE, QUE VUELVA EL ICONO. Sin esto una celda que
            --  no llega a armarse -- una pieza que el servidor no conoce--
            --  se quedaria girando para siempre, que es peor que el icono.
            if not self.vestida and vueltas >= 30 then
                self.cargando:Hide()
                self.icono:Show()
            end

            if hay and puestas >= #piezas then
                self.vestida = true
                self.cargando:Hide()
                self.icono:Hide()
                self:Pintar()
                --  🪤 NO SE PARA HASTA QUE TAMBIEN HAYA NOMBRE. Vestirse y
                --  saber como se llama son dos datos distintos que llegan por
                --  caminos distintos: parar al vestirse dejaba celdas bien
                --  dibujadas y con "..." debajo, para siempre. El tope de
                --  vueltas sigue mandando, asi que esto no puede colgarse.
                local n = self.nombre:GetText()
                if (n and n ~= "" and n ~= "...") or vueltas >= 30 then
                    gg:SetScript("OnUpdate", nil)
                end
            end
        end)
    end

    return f
end

PLARM.Ficha.ANCHO, PLARM.Ficha.ALTO = ANCHO, ALTO

--  Se expone para poder CALIBRARLA en vivo desde `Sonda.lua` (orden
--  `encuadre|`). Los numeros no se pueden razonar: hay que verlos.
PLARM.Ficha.ENCUADRE = ENCUADRE

--  Marca de carga: si este archivo revienta, su linea NO sale y se ve al
--  instante cual es. Los errores de Lua vienen apagados de fabrica.
PLARM_CARGADO = (PLARM_CARGADO or "") .. " Ficha"
