-- ---------------------------------------------------------------------------
--  🔴 ESTE ARCHIVO USA SU PROPIA TABLA: PLARM, NO LA GLOBAL "PLT"
--
--  `PLT` la comparten varios addons de PeruLand -la tienda tiene su propio
--  Estilo.lua que tambien define PLT.Boton- y los addons cargan por ORDEN
--  ALFABETICO: PeruLandArmario va antes que PeruLandTienda, asi que la tienda
--  MACHACABA la funcion del armario.
--
--  Costo ocho intentos: se corregia el boton del armario, se instalaba, y en
--  pantalla no cambiaba nada, porque el codigo bueno nunca llegaba a
--  ejecutarse. Ninguna comprobacion lo delataba: la sintaxis pasaba, el
--  archivo estaba en su sitio y el addon cargaba.
--
--  🎯 La regla: un addon NO comparte tabla global con otro. Si dos addons
--  definen la misma funcion en la misma global, gana el que cargue ultimo.
-- ---------------------------------------------------------------------------

--[[ =========================================================================
  Estilo.lua -- como se consigue que un addon NO parezca de 2008
  ===========================================================================
  EL TRUCO
  El WoW no sabe dibujar rectangulos: solo sabe estirar imagenes. Pero trae una
  imagen de un pixel blanco -- "Interface\Buttons\WHITE8X8" -- que se puede
  TINTAR de cualquier color. Estirandola sale un panel plano y liso.

  Con eso, y no usando NUNCA los marcos de Blizzard (esos con las esquinas
  doradas y el pergamino), se consiguen paneles planos oscuros como los de una
  aplicacion moderna. Es lo mismo que hacen ElvUI y Details.

  LO QUE SIGUE SIN PODERSE
  Esquinas redondeadas de verdad, sombras y desenfoques. Se pueden fingir con
  imagenes propias, pero eso ya es trabajo de arte: hay que DIBUJAR cada
  esquina. Aqui se usan angulos rectos a proposito, que es un estilo valido y
  no un apaño a medias.

  Los colores son los MISMOS que el launcher, para que se note que es lo mismo.
========================================================================== --]]

PLARM = {}

--  ---------------------------------------------------------------------------
--  EL INTERRUPTOR DEL RUIDO
--  ---------------------------------------------------------------------------
--  🔴 En `false` para los jugadores. Los mensajes de diagnostico del armario
--  --la sonda, la autoprueba, los limites, los "cargado: X"-- solo salen si
--  esto esta encendido.
--
--  ⚠️ `PLARM.DEPURAR` ya se usaba en `Ventana.lua` y **nunca se declaro**, asi
--  que estaba apagado por accidente. Ahora lo esta a proposito, y se puede
--  encender sin tocar archivos:
--
--      /armario diag
--
--    🎯 Un instrumento que no se puede apagar acaba borrado, y entonces la
--       proxima investigacion empieza de cero. Se apaga, no se tira.
--
--  ⛔ Lo que NO pasa por aqui: los errores de verdad y las respuestas a lo que
--  el jugador escribe. Eso lo tiene que ver siempre.
PLARM.DEPURAR = false

function PLARM.Diag(texto)
    if not PLARM.DEPURAR then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cff5AC8FA[Armario·diag]|r " .. tostring(texto))
end

local BLANCO = "Interface\\Buttons\\WHITE8X8"

PLARM.color = {
    fondo      = { 0.039, 0.043, 0.055 },   -- #0A0B0E
    panel      = { 0.078, 0.086, 0.110 },   -- #14161C
    panelAlto  = { 0.106, 0.118, 0.149 },   -- #1B1E26
    borde      = { 0.173, 0.184, 0.220 },   -- #2C2F38
    oro        = { 0.910, 0.710, 0.302 },   -- #E8B54D
    oroClaro   = { 1.000, 0.867, 0.580 },
    granate    = { 0.784, 0.220, 0.259 },   -- #C83842
    texto      = { 0.941, 0.945, 0.957 },
    textoSuave = { 0.604, 0.624, 0.671 },
    textoTenue = { 0.388, 0.408, 0.455 },
    verde      = { 0.298, 0.765, 0.478 }
}

local c = PLARM.color

-- Iconos de las dos monedas. El del emblema se saca del OBJETO de verdad
-- (900100), así que si algún día se le cambia el dibujo, cambia solo aquí.
-- Si el cliente todavía no lo conoce, cae a una bolsa de monedas.
PLARM.ICONO_CREDITO = "Interface\\Icons\\INV_Misc_Coin_01"
PLARM.ICONO_EMBLEMA = GetItemIcon and (GetItemIcon(900100) or "Interface\\Icons\\INV_Misc_Coin_17")
                    or "Interface\\Icons\\INV_Misc_Coin_17"

--- Un rectangulo liso del color que sea.
function PLARM.Fondo(marco, color, alfa)
    local t = marco:CreateTexture(nil, "BACKGROUND")
    t:SetTexture(BLANCO)
    t:SetVertexColor(color[1], color[2], color[3], alfa or 1)
    t:SetAllPoints(marco)
    return t
end

--- Una linea de 1 pixel en cada lado. Cuatro texturas finas en vez del marco
--- de Blizzard: asi el borde es del color que queramos y del grosor exacto.
function PLARM.Borde(marco, color, alfa)
    color = color or c.borde
    alfa = alfa or 1
    local lados = {}
    for _, lado in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = marco:CreateTexture(nil, "BORDER")
        t:SetTexture(BLANCO)
        t:SetVertexColor(color[1], color[2], color[3], alfa)
        if lado == "TOP" or lado == "BOTTOM" then
            t:SetHeight(1)
            t:SetPoint(lado .. "LEFT")
            t:SetPoint(lado .. "RIGHT")
        else
            t:SetWidth(1)
            t:SetPoint("TOP" .. lado)
            t:SetPoint("BOTTOM" .. lado)
        end
        lados[#lados + 1] = t
    end
    return lados
end

--- Panel completo: fondo + borde. Es la pieza que se repite en todo el addon.
function PLARM.Panel(padre, color)
    local m = CreateFrame("Frame", nil, padre)
    PLARM.Fondo(m, color or c.panel)
    PLARM.Borde(m)
    return m
end

--- Texto. Se usan las fuentes del juego a proposito: meter un .ttf propio
--- mejoraria el aspecto, pero hay que tener licencia para repartirlo.
--- Cuando haya una, se cambia SOLO aqui.
function PLARM.Texto(padre, tamano, color, grosor)
    local t = padre:CreateFontString(nil, "OVERLAY")
    t:SetFont("Fonts" .. string.char(92) .. "FRIZQT__.TTF", tamano or 12,
              grosor and "OUTLINE" or "")

    --  SOMBRA. Es el detalle que mas separa un texto "de addon casero" de uno
    --  del juego: sin ella el texto flota sobre el fondo y se lee peor encima
    --  de una textura. Blizzard la pone en TODOS sus textos de interfaz.
    t:SetShadowColor(0, 0, 0, 0.9)
    t:SetShadowOffset(1, -1)

    color = color or c.texto
    t:SetTextColor(color[1], color[2], color[3])
    return t
end

--- Boton plano que se ilumina al pasar por encima. Sin texturas de Blizzard.
-- ---------------------------------------------------------------------------
--  PLARM.Trozos  ·  pinta una textura de boton en TRES piezas sobre un marco
-- ---------------------------------------------------------------------------
--  🪤 La textura mide 128x32 pero el boton solo ocupa 80x22 de ella; el resto
--  es relleno vacio. Usandola entera se pinta ese hueco y sale una barra
--  plana. Estas coordenadas son las que usa Blizzard por dentro.
-- ---------------------------------------------------------------------------
PLARM.BOTON_NORMAL  = "Interface\\Buttons\\UI-Panel-Button-Up"
PLARM.BOTON_PULSADO = "Interface\\Buttons\\UI-Panel-Button-Down"
PLARM.BOTON_ENCIMA  = "Interface\\Buttons\\UI-Panel-Button-Highlight"

function PLARM.Trozos(marco, ruta, capa)
    local IZQ_B, MED_B, DER_B, ALTO_T = 0.09375, 0.53125, 0.625, 0.6875

    local izq = marco:CreateTexture(nil, capa)
    izq:SetPoint("TOPLEFT"); izq:SetPoint("BOTTOMLEFT"); izq:SetWidth(12)
    izq:SetTexture(ruta); izq:SetTexCoord(0, IZQ_B, 0, ALTO_T)

    local der = marco:CreateTexture(nil, capa)
    der:SetPoint("TOPRIGHT"); der:SetPoint("BOTTOMRIGHT"); der:SetWidth(12)
    der:SetTexture(ruta); der:SetTexCoord(MED_B, DER_B, 0, ALTO_T)

    local med = marco:CreateTexture(nil, capa)
    med:SetPoint("TOPLEFT", izq, "TOPRIGHT")
    med:SetPoint("BOTTOMRIGHT", der, "BOTTOMLEFT")
    med:SetTexture(ruta); med:SetTexCoord(IZQ_B, MED_B, 0, ALTO_T)

    return { izq, med, der }
end

function PLARM.Boton(padre, texto, ancho, alto, principal)
    --  Boton con la textura del juego partida en TRES piezas. Estirarla entera
    --  deforma los biseles de los extremos y deja una barra plana; en tres
    --  trozos conserva el relieve a cualquier ancho. Es lo que hace Blizzard
    --  por dentro, y lo que se ve en la ventana de Ascension.
    --
    --  Si hay arte propio (arte/boton) manda el, en una sola pieza.
    local b = CreateFrame("Button", nil, padre)
    b:SetSize(ancho or 100, alto or 22)

    b.piezas = PLARM.Trozos(b, PLARM.BOTON_NORMAL, "BACKGROUND")
    local enc = PLARM.Trozos(b, PLARM.BOTON_ENCIMA, "HIGHLIGHT")
    for _, x in ipairs(enc) do x:SetBlendMode("ADD") end
    b.pulsadas = PLARM.Trozos(b, PLARM.BOTON_PULSADO, "BACKGROUND")
    for _, x in ipairs(b.pulsadas) do x:Hide() end

    --  En este cliente (esMX) el boton YA es rojo de fabrica: el principal se
    --  deja a brillo pleno y el secundario se apaga, para distinguir cual es
    --  la accion sin tenir nada encima.
    if principal then
        for _, x in ipairs(b.piezas) do x:SetVertexColor(1, 1, 1) end
    else
        for _, x in ipairs(b.piezas) do x:SetVertexColor(0.72, 0.72, 0.76) end
    end

    local et = PLARM.Texto(b, 12, principal and { 1, 0.93, 0.88 } or { 1, 0.82, 0.30 })
    et:SetPoint("CENTER", 0, 1)
    et:SetText(texto)
    b.etiqueta = et

    b:SetScript("OnMouseDown", function(self)
        if self.apagado or not self.piezas then return end
        for _, x in ipairs(self.piezas)   do x:Hide() end
        for _, x in ipairs(self.pulsadas) do x:Show() end
        et:SetPoint("CENTER", 1, 0)
    end)
    b:SetScript("OnMouseUp", function(self)
        if self.apagado or not self.piezas then return end
        for _, x in ipairs(self.pulsadas) do x:Hide() end
        for _, x in ipairs(self.piezas)   do x:Show() end
        et:SetPoint("CENTER", 0, 1)
    end)

    --- Apagar en vez de esconder: si el boton desaparece, lo de al lado da un
    --- salto y la ventana parece inestable.
    function b:Apagar(si, motivo)
        self.apagado = si
        if self.piezas then
            for _, x in ipairs(self.piezas) do
                x:SetVertexColor(si and 0.45 or 1, si and 0.45 or (principal and 0.55 or 1),
                                 si and 0.45 or (principal and 0.50 or 1))
            end
        end
        et:SetTextColor(unpack(si and PLARM.color.textoTenue
                               or (principal and { 1, 0.93, 0.88 } or { 1, 0.82, 0.30 })))
        self.motivo = motivo
    end

    return b
end

-- ---------------------------------------------------------------------------
--  PLARM.Arte  ·  el enchufe para el arte del disenador
-- ---------------------------------------------------------------------------
--  Pone una imagen de la carpeta del addon. Si el archivo todavia no existe,
--  deja el color plano que hay ahora y NO da error.
--
--  Asi la ventana se puede maquetar entera antes de tener una sola imagen: se
--  ve la forma con bloques de color, y segun el disenador va dejando archivos
--  con el nombre que toca, cada bloque se convierte en su pieza de arte.
--
--  Los nombres estan en cliente/addons/PeruLandArmario/ARTE.md
--
--  🪤 Una imagen NUEVA no la ve el cliente hasta REINICIARLO. /reload no basta.
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
--  Las cuatro rarezas
-- ---------------------------------------------------------------------------
--  Se usan los MISMOS colores que el juego ya emplea para la calidad de los
--  objetos. No es pereza: el jugador lleva anos leyendo que el morado es mejor
--  que el azul, y cambiarlos por una paleta propia solo obliga a explicarlo.
--
--  Cada rareza puede tener ademas su propia tarjeta: si existe el archivo
--  arte/celda-fondo-<n>, manda ese; si no, se tine la tarjeta comun.
PLARM.RAREZAS = {
    [1] = { nombre = "Comun",      color = { 1.00, 1.00, 1.00 } },
    [2] = { nombre = "Raro",       color = { 0.11, 0.53, 1.00 } },
    [3] = { nombre = "Epico",      color = { 0.64, 0.21, 0.93 } },
    [4] = { nombre = "Legendario", color = { 1.00, 0.50, 0.00 } },
}

PLARM.RUTA_ARTE = "Interface\\AddOns\\ProjectJaina_Wardrobe\\arte\\"

-- ---------------------------------------------------------------------------
--  PLARM.RutaArte  ·  la ruta que DE VERDAD carga, o nil
-- ---------------------------------------------------------------------------
--  El cliente acepta .blp y .tga, y pedir el nombre SIN extension no siempre
--  resuelve: si el archivo esta como .tga hay que nombrarlo asi. Se prueba con
--  una textura escondida y se devuelve la que cargo.
--
--  🪤 Esto funciona porque GetTexture() SI dice la verdad: devuelve nil cuando
--  el archivo no esta. El que miente es lo que devuelve SetTexture(), que da
--  algo valido para cualquier ruta inventada.
--  🔴 LA SONDA TIENE QUE ESTAR ANCLADA Y VISIBLE.
--  Una textura escondida y sin SetPoint NO LA CARGA EL CLIENTE, asi que
--  GetTexture() devuelve nil aunque el archivo exista y este perfecto. Con la
--  sonda oculta, TODO el arte se daba por ausente y la ventana se quedaba con
--  los respaldos -que es lo que el dueno vio diez veces seguidas-.
--  Se deja anclada a la pantalla y con alfa 0: se carga, y no se ve.
local sonda
local recordado = {}
function PLARM.RutaArte(nombre)
    if recordado[nombre] ~= nil then
        return recordado[nombre] or nil
    end
    if not sonda then
        sonda = UIParent:CreateTexture(nil, "BACKGROUND")
        sonda:SetAllPoints(UIParent)
        sonda:SetAlpha(0)
    end
    for _, ext in ipairs({ "", ".tga", ".blp" }) do
        local ruta = PLARM.RUTA_ARTE .. nombre .. ext
        sonda:SetTexture(nil)
        sonda:SetTexture(ruta)
        if sonda:GetTexture() then
            recordado[nombre] = ruta
            return ruta
        end
    end
    recordado[nombre] = false
    return nil
end

--  Pone la imagen en la textura si existe. Devuelve si la puso.
--
--  🔴 LA COMPROBACION SE HACE SIEMPRE CON LA SONDA, NUNCA CON LA TEXTURA DE
--  DESTINO. Las texturas de la ficha se crean ANTES de que la ficha tenga
--  posicion en la pantalla, y una textura sin colocar no se carga: preguntarle
--  a ella devuelve nil aunque el archivo este perfecto. La sonda vive anclada
--  a la pantalla desde el principio, asi que su respuesta si vale.
function PLARM.Poner(tex, nombre)
    local ruta = PLARM.RutaArte(nombre)
    if ruta then tex:SetTexture(ruta); return true end
    return false
end


function PLARM.Arte(marco, nombre, color, capa, respaldo, repetir)
    local t = marco:CreateTexture(nil, capa or "BACKGROUND")
    t:SetAllPoints()

    --  1. el arte del disenador manda
    if PLARM.Poner(t, nombre) then
        t.propia = true
        return t
    end

    --  2. si no lo hay, una textura del propio WoW: la ventana ya parece una
    --     ventana de juego, y asi se puede juzgar el diseno antes de dibujar
    --     una sola imagen.
    if respaldo then
        --  🪤 SetTexture DEVUELVE VERDADERO AUNQUE EL ARCHIVO NO EXISTA. Hay
        --  que preguntar despues con GetTexture(), o se da por bueno un hueco
        --  vacio -- que es justo lo que dejaba los botones planos.
        if repetir then t:SetTexture(respaldo, true, true)
        else            t:SetTexture(respaldo) end
        if t:GetTexture() then return t end
    end

    --  3. y en ultimo caso, color plano
    t:SetTexture(BLANCO)
    if color then t:SetVertexColor(color[1], color[2], color[3], color[4] or 1) end
    return t
end

-- ---------------------------------------------------------------------------
--  PLARM.Pestana  ·  una pestana de categoria (Cabeza, Hombros, Apariencias...)
-- ---------------------------------------------------------------------------
--  No es un boton normal: tiene dos estados, suelta y elegida, y cada uno con
--  su imagen. Es lo que separa una lista de botones grises de una barra de
--  categorias de verdad.
--
--     arte/pestana          128x32   suelta
--     arte/pestana-activa   128x32   la que esta elegida
--
--  Sin esos archivos usa las de Blizzard, que ya tienen la forma correcta.
-- ---------------------------------------------------------------------------
function PLARM.Pestana(padre, texto, ancho, alto)
    --  Misma textura que los botones, en tres trozos. La elegida va a brillo
    --  pleno y las demas apagadas: asi se distingue sin necesitar otra imagen.
    local b = CreateFrame("Button", nil, padre)
    b:SetSize(ancho or 100, alto or 22)

    b.piezas = PLARM.Trozos(b, PLARM.BOTON_NORMAL, "BACKGROUND")
    local enc = PLARM.Trozos(b, PLARM.BOTON_ENCIMA, "HIGHLIGHT")
    for _, x in ipairs(enc) do x:SetBlendMode("ADD") end

    b.etiqueta = PLARM.Texto(b, 11, PLARM.color.textoSuave)
    b.etiqueta:SetPoint("CENTER", 0, 1)
    b.etiqueta:SetText(texto or "")

    function b:Marcar(si)
        self.elegida = si
        for _, x in ipairs(self.piezas) do
            if si then x:SetVertexColor(1, 1, 1)
            else       x:SetVertexColor(0.55, 0.55, 0.58) end
        end
        self.etiqueta:SetTextColor(unpack(si and PLARM.color.oroClaro
                                             or PLARM.color.textoSuave))
    end

    b:SetScript("OnEnter", function(self)
        if not self.elegida then self.etiqueta:SetTextColor(unpack(PLARM.color.texto)) end
    end)
    b:SetScript("OnLeave", function(self)
        if not self.elegida then self.etiqueta:SetTextColor(unpack(PLARM.color.textoSuave)) end
    end)

    b:Marcar(false)
    return b
end

-- ---------------------------------------------------------------------------
--  PLARM.Titulo  ·  un titulo de seccion con su adorno debajo
-- ---------------------------------------------------------------------------
--  Un texto suelto se ve barato. Con una linea ornamentada debajo, la seccion
--  se lee como una seccion.   arte/titulo-adorno  ·  256x16
-- ---------------------------------------------------------------------------
function PLARM.Titulo(padre, texto, ancho)
    --  Mayusculas y espaciado: asi es como titula el juego sus secciones, y
    --  distingue un titulo de una etiqueta cualquiera sin necesitar mas arte.
    local t = PLARM.Texto(padre, 13, PLARM.color.oroClaro, true)
    t:SetText(string.upper(texto or ""))

    local adorno = padre:CreateTexture(nil, "ARTWORK")
    adorno:SetPoint("TOP", t, "BOTTOM", 0, -3)
    adorno:SetSize(ancho or 200, 8)
    if not PLARM.Poner(adorno, "titulo-adorno") then
        --  Respaldo: una linea dorada que se desvanece hacia los lados. Se
        --  hace con tres trozos porque una sola linea plana canta mucho.
        adorno:SetTexture(BLANCO)
        adorno:SetHeight(1)
        adorno:SetVertexColor(PLARM.color.oro[1], PLARM.color.oro[2], PLARM.color.oro[3], 0.55)
    end
    t.adorno = adorno
    return t
end


-- ---------------------------------------------------------------------------
--  Ensenar u ocultar
-- ---------------------------------------------------------------------------
--  🪤 `SetShown` NO EXISTE EN 3.3.5a. Llego con Cataclysm, esta en toda la
--  documentacion moderna de WoW y es lo primero que uno escribe por
--  costumbre. Aqui revienta el archivo entero al cargarlo -y como el fallo
--  ocurre al crear la ventana, lo que se ve es que "no pasa nada al abrir",
--  sin ninguna pista de por que.
--
--    🎯 Antes de usar una funcion de interfaz, mirar si existe en 3.3.5a.
--       Las que llegaron despues no dan "funcion desconocida": dan un error
--       en medio de tu codigo que corta lo que venia detras.
function PLARM.Ver(marco, si)
    if si then marco:Show() else marco:Hide() end
end

-- ---------------------------------------------------------------------------
--  Pedir la ficha de un objeto SIN tocar ningun muneco
-- ---------------------------------------------------------------------------
--  🔴 `TryOn` CON UNA PIEZA QUE EL CLIENTE NO CONOCE ENVENENA EL ARMADO DEL
--  PERSONAJE PARA TODO EL CLIENTE. No solo ese muneco: la ficha de Blizzard,
--  el retrato y el armario se quedan negros a la vez, y sigue asi hasta que
--  algo lo fuerce de nuevo.
--
--  El dueno lo aislo perfectamente: *"le di clic a uno de los sets y todo
--  volvio a fallar, se desaparecio el preview del armario y de mi pj despues
--  del clic"*. Funcionaba hasta el clic, y el clic es lo que dispara el
--  `TryOn` de un conjunto que aun no se habia descargado.
--
--  🔑 La forma de pedir un objeto sin tocar nada es un TOOLTIP: pedirle que
--  muestre el enlace del objeto obliga al cliente a bajarse su ficha, y si no
--  la tiene todavia no rompe nada -- simplemente no muestra el tooltip.
--
--    🎯 Para forzar una descarga, usa algo cuyo fallo no cueste nada. Yo
--       estaba usando justo lo contrario: la pieza mas fragil del sistema.
local sonda = CreateFrame("GameTooltip", "ProjectJaina_Wardrobe_Sonda", nil, "GameTooltipTemplate")
sonda:SetOwner(UIParent, "ANCHOR_NONE")

--  🔴 Y CON FRENO, QUE NO LO TENIA.
--
--  Esta funcion se llama cada medio segundo por cada pieza de cada celda: con
--  18 celdas son decenas de peticiones por segundo al cliente. La cola de
--  fichas se atasca y **la rejilla tarda cerca de un minuto en cargar**, que
--  es lo que el dueño describio como «el parpadeo se queda como 1 min y luego
--  carga».
--
--  🪤 Lo llamativo: el comentario de mas arriba ya decia «se pregunta por cada
--  objeto como mucho una vez cada 3 segundos». **Ese freno no estaba en el
--  codigo** -- se perdio en alguna edicion y el comentario se quedo.
--
--    🎯 Un comentario no es una comprobacion. Es la segunda vez hoy que uno
--       describe algo que el codigo de debajo no hace.
--
--    🎯 Y la regla de fondo, ya escrita en este proyecto: reintentar no es
--       repetir mas rapido. Preguntar mas veces por algo que tarda solo
--       consigue que tarde mas.
local pedidas = {}          -- [id] = cuando se pidio por ultima vez
local ESPERA  = 3           -- segundos entre peticiones del MISMO objeto

function PLARM.PedirFicha(id)
    id = tonumber(id)
    if not id then return false end
    if GetItemInfo(id) then pedidas[id] = nil; return true end

    local ahora = GetTime()
    if pedidas[id] and ahora - pedidas[id] < ESPERA then return false end
    pedidas[id] = ahora
    pcall(function() sonda:SetHyperlink("item:" .. id) end)
    return false
end


-- ---------------------------------------------------------------------------
--- Hacer algo dentro de N segundos, una sola vez.
---
--- 🪤 En 3.3.5a no hay `C_Timer.After`: hay que llevar el reloj a mano con un
--- `OnUpdate`. Y NO vale un marco por espera -- crear marcos sin parar los deja
--- vivos para siempre, porque en este cliente no se pueden destruir.
--- Aqui hay UN marco y una lista.
local esperas, relojEsperas = {}, nil
function PLARM.Tras(segundos, fn)
    esperas[#esperas + 1] = { cuando = GetTime() + (segundos or 0), fn = fn }
    if not relojEsperas then
        relojEsperas = CreateFrame("Frame")
        relojEsperas:SetScript("OnUpdate", function()
            if #esperas == 0 then return end
            local ahora = GetTime()
            local i = 1
            while i <= #esperas do
                if esperas[i].cuando <= ahora then
                    local e = table.remove(esperas, i)
                    pcall(e.fn)
                else
                    i = i + 1
                end
            end
        end)
    end
end

--  ---------------------------------------------------------------------------
--  /armario diag  --  encender o apagar el ruido sin tocar archivos
--  ---------------------------------------------------------------------------
--  🪤 Un comando de barra se registra `SLASH_NOMBRE1`, **sin guion bajo** entre
--  el nombre y el 1. Con el, queda sin registrar y no da ningun error.
SLASH_PLARMDIAG1 = "/armariodiag"
SlashCmdList["PLARMDIAG"] = function()
    PLARM.DEPURAR = not PLARM.DEPURAR
    DEFAULT_CHAT_FRAME:AddMessage("|cffE8B54D[Armario]|r diagnostico "
        .. (PLARM.DEPURAR and "|cff40C463ENCENDIDO|r" or "|cffC83842apagado|r"))
end
