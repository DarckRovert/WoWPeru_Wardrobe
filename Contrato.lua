-- ============================================================================
--  EL CONTRATO   ·   01-09-2026
-- ============================================================================
--  Las mismas funciones que usa el armario de Ascension, con sus mismos
--  nombres. Detras, hoy, hay mensajes al servidor.
--
--  POR QUE LOS MISMOS NOMBRES
--  --------------------------
--  Su addon llama a `C_AppearanceCollection.GetCategoryAppearances(page)` y
--  pinta lo que le devuelven. Ese `C_...` es su DLL. Nosotros no lo tenemos,
--  pero si tenemos servidor.
--
--    🎯 Copiando la FORMA de su interfaz, el dia que el motor cambie -de
--       mensajes al servidor a un DLL propio- no hay que tocar ni una linea
--       de la ventana. Lo unico que cambia es lo que hay debajo de estas
--       funciones.
--
--  LO UNICO QUE NO SE PUDO COPIAR: EL TIEMPO
--  -----------------------------------------
--  Las suyas responden en el acto porque el dato esta en el cliente. Las
--  nuestras tienen que ir al servidor y volver. Asi que:
--
--      · si el dato ya esta en la cache, se devuelve EN EL ACTO (sincrono)
--      · si no, se devuelve nil y llega por `alListo(resultado)`
--
--  Nunca se bloquea, y quien pinta no tiene que saber cual de los dos casos
--  ha tocado.
--
--  🔴 Y LO MAS IMPORTANTE: EL `rid`.
--
--  Cada peticion lleva un numero creciente, y cada canal -paginas, filtro,
--  fichas- recuerda cual fue el ultimo. Una respuesta de un `rid` viejo SE
--  TIRA. Sin eso, pedir la pagina 3 y despues la 1 podia acabar pintando la 3
--  encima de la 1 mientras el numero decia otra cosa. Ese fue, literalmente,
--  el fallo que el dueno reporto siete veces.
-- ============================================================================

PLARM = PLARM or {}
PLARM.Contrato = { VERSION = 1 }

local PREFIJO = "WP_WARDROBE"

-- ---------------------------------------------------------------------------
--  Eventos propios
-- ---------------------------------------------------------------------------
--  El servidor avisa cuando algo cambia; la ventana no pregunta nunca. Es lo
--  que hace Ascension con sus 12 eventos (`APPEARANCE_COLLECTED`,
--  `PENDING_APPEARANCE_CHANGED`...) y es lo que evita el "repinta por si
--  acaso" que llenaba de trabajo la ventana vieja.
local oyentes = {}

PLARM.Eventos = {}

function PLARM.Eventos.Registrar(nombre, fn, dueno)
    oyentes[nombre] = oyentes[nombre] or {}
    table.insert(oyentes[nombre], { fn = fn, dueno = dueno })
end

function PLARM.Eventos.Disparar(nombre, ...)
    for _, o in ipairs(oyentes[nombre] or {}) do
        --  Un oyente que revienta NO puede llevarse a los demas por delante:
        --  si la ficha falla, la ventana tiene que seguir respondiendo.
        local ok, err = pcall(o.fn, ...)
        if not ok then
            print("|cffC83842[Armario]|r fallo en " .. nombre .. ": " .. tostring(err))
        end
    end
end

-- ---------------------------------------------------------------------------
--  Transporte
-- ---------------------------------------------------------------------------
local siguienteRid = 0
local esperando    = {}     -- rid -> { fn, canal, creado, trozos, m }
local ultimaFirmaPuesto = nil
local ultimoDe     = {}     -- canal -> rid mas nuevo pedido

--  🪤 EL ADDON SE OYE A SI MISMO. Las peticiones se mandan como un susurro
--  al propio jugador, asi que el cliente RECIBE TAMBIEN LO QUE ENVIA -- y el
--  oyente intentaba leer su propia peticion como si fuera la respuesta del
--  servidor. Sintoma: "info ilegible: 8|2000010", que es exactamente el
--  mensaje que se acababa de mandar. No rompia nada, pero manda a buscar un
--  fallo de protocolo donde no lo hay.
--
--    🎯 Si emisor y receptor son el mismo canal, hay que saber distinguir el
--       eco. Aqui se apunta lo enviado y se descarta al volver.
local eco = {}

--  Quien espera las piezas de un conjunto que todavia no ha llegado.
local esperandoPiezas = {}

--  🔴 FRENO DE INUNDACION. Los mensajes de addon viajan como susurros y el
--  servidor corta a los 10 por segundo. Se midieron **39 en un segundo** y el
--  dueno se desconectaba a los pocos minutos, sin caida y sin ninguna pista.
--
--  El arreglo de fondo es no mandar mensajes (el catalogo va en cache), pero
--  esto es la red debajo: aunque alguien anada manana una peticion por celda,
--  el addon la encolara en vez de tumbar la sesion.
--
--    🎯 Un limite que solo se respeta si te acuerdas, no es un limite.
--  ⚠️ Cuatro, no seis: con el tope en 6 se midieron picos de 8 -- el
--  servidor cuenta tambien lo que no pasa por aqui, y el corte esta en
--  10. Cuatro deja margen y no se nota: una pagina son 2 mensajes.
local TOPE_POR_SEGUNDO = 4
local colaSalida, segundoActual, enviadosEsteSegundo = {}, 0, 0

local function Soltar(texto)
    eco[texto] = GetTime()
    SendAddonMessage(PREFIJO, texto, "WHISPER", UnitName("player"))
end

local grifo = CreateFrame("Frame")
grifo:SetScript("OnUpdate", function()
    local s = math.floor(GetTime())
    if s ~= segundoActual then segundoActual, enviadosEsteSegundo = s, 0 end
    while #colaSalida > 0 and enviadosEsteSegundo < TOPE_POR_SEGUNDO do
        enviadosEsteSegundo = enviadosEsteSegundo + 1
        Soltar(table.remove(colaSalida, 1))
    end
end)

local function Mandar(texto)
    local s = math.floor(GetTime())
    if s ~= segundoActual then segundoActual, enviadosEsteSegundo = s, 0 end
    if enviadosEsteSegundo < TOPE_POR_SEGUNDO and #colaSalida == 0 then
        enviadosEsteSegundo = enviadosEsteSegundo + 1
        Soltar(texto)
    else
        colaSalida[#colaSalida + 1] = texto
    end
end
PLARM.Contrato.Mandar = Mandar

--- Pide algo al servidor. `canal` agrupa peticiones que se pisan entre si.
local function Pedir(canal, orden, cuerpo, fn)
    --  🪤 LA PETICION VIEJA HAY QUE CERRARLA, NO SOLO IGNORARLA. Se
    --  descartaba su respuesta -bien- pero se quedaba en la lista de
    --  espera, y a los 6 s el vigilante la daba por perdida y escribia
    --  "El servidor no contesta" cuando el servidor habia contestado
    --  perfectamente a la peticion buena.
    --
    --    🎯 Un aviso de error falso es peor que no avisar: manda a buscar
    --       el fallo donde no esta.
    for viejo, p in pairs(esperando) do
        if p.canal == canal then esperando[viejo] = nil end
    end
    siguienteRid = siguienteRid + 1
    local rid = siguienteRid
    ultimoDe[canal] = rid
    esperando[rid] = { fn = fn, canal = canal, creado = GetTime(), trozos = {} }
    Mandar(orden .. "|" .. rid .. (cuerpo and ("|" .. cuerpo) or ""))
    return rid
end
PLARM.Contrato.Pedir = Pedir

--- ¿Sigue interesando esta respuesta, o ya pedimos otra cosa?
local function Vigente(rid)
    local e = esperando[rid]
    if not e then return false end
    return ultimoDe[e.canal] == rid
end

--  Las peticiones sin respuesta se cierran a los 6 s. Un armario que se queda
--  esperando para siempre parece colgado, y el jugador no puede saber si es
--  lento o esta roto: se le dice.
local vigilante = CreateFrame("Frame")
vigilante:SetScript("OnUpdate", function(self, e)
    self.reloj = (self.reloj or 0) + e
    if self.reloj < 1 then return end
    self.reloj = 0
    local ahora = GetTime()
    for rid, p in pairs(esperando) do
        if ahora - p.creado > 6 then
            esperando[rid] = nil
            if Vigente(rid) and p.fn then pcall(p.fn, nil, "sin respuesta") end
            PLARM.Eventos.Disparar("ARMARIO_SIN_RESPUESTA", p.canal)
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Cache de nombres
-- ---------------------------------------------------------------------------
--  Los nombres son el campo mas largo del protocolo y el unico que no cambia
--  nunca. Se guardan entre sesiones y solo se piden los que faltan: abrir la
--  ventana la segunda vez no vuelve a traer 1.500 nombres.
--
--  🪤 SE LEE DENTRO DE `ADDON_LOADED`, NO AQUI ARRIBA. Los `SavedVariables`
--  se cargan DESPUES del fichero del addon: inicializar la tabla en la
--  cabecera la deja en nil y las lecturas fallan calladas. Eso provoco 2.844
--  errores mudos en PeruTickets.
local cache = { nombres = {}, version = 0, piezas = nil, piezasVersion = -1 }

local cargador = CreateFrame("Frame")
cargador:RegisterEvent("ADDON_LOADED")
cargador:SetScript("OnEvent", function(self, _, quien)
    if quien ~= "ProjectJaina_Wardrobe" then return end
    ProjectJaina_Wardrobe_Cache = ProjectJaina_Wardrobe_Cache or { nombres = {}, version = 0 }
    cache = ProjectJaina_Wardrobe_Cache
    cache.nombres = cache.nombres or {}
end)

-- ---------------------------------------------------------------------------
--  Estado que el servidor nos ha contado
-- ---------------------------------------------------------------------------
--  Es una COPIA de lo que decidio el servidor, nunca una segunda opinion:
--  aqui no se calcula nada, solo se guarda lo ultimo que llego.
local E = {
    version = 0, creditos = 0, emblemas = 0,
    tengoTotal = 0, catalogoTotal = 0,
    categoria = 100, tipo = "S", orden = 0, flags = 0, texto = "",
    total = 0, tengo = 0, paginas = 1, filtrados = 0, pagina = 1,
    entradas = {},          -- lo de la pagina actual: { id, t, r, precio }
    puesto = {}, pendiente = {},
    listo = false,
}
PLARM.Contrato.Estado = E

-- ---------------------------------------------------------------------------
--  Recibir
-- ---------------------------------------------------------------------------
local EsperarPuesto

local respuestas = {}

respuestas["hola2"] = function(resto)
    local v, cr, em, tengo, total = resto:match("^(%d+)|(%d+)|(%d+)|(%d+)|(%d+)$")
    if not v then return end
    E.version, E.creditos, E.emblemas = tonumber(v), tonumber(cr), tonumber(em)
    E.tengoTotal, E.catalogoTotal = tonumber(tengo), tonumber(total)
    --  Si el catalogo del servidor cambio, lo que teniamos guardado ya no
    --  vale. Es la unica forma de que anadir 100 conjuntos no obligue a nadie
    --  a borrar nada a mano.
    if cache.version ~= E.version then
        cache.nombres, cache.version = {}, E.version
    end
    --  🪤 AQUI SE TRAIA EL CATALOGO ENTERO, Y ERA PASARSE. Lo corto el dueno,
    --  que ademas lo habia comprobado en el juego de ellos:
    --
    --      «no habiamos hecho que me pida pagina por pagina para el
    --       rendimiento? yo mismo probe Ascension y vi que solo me cargaba
    --       por pagina»
    --
    --  Tenia razon. Con 94 conjuntos da igual, con 1.500 no. Lo que hacia
    --  falta no era traerlo todo: era dejar de pedir UNA COSA POR CELDA.
    --  Ahora se piden las piezas de las 18 de la pagina en UN mensaje.
    --
    --    🎯 Arreglar una rafaga trayendolo todo por adelantado cambia un
    --       problema por otro. Se agrupa por lo que se va a pintar.
    if cache.piezasVersion ~= E.version then
        cache.piezas, cache.piezasVersion = {}, E.version
    end
    --  Barrido de una vez: tira lo que quedo guardado vacio en sesiones
    --  anteriores, que es lo que impedia volver a pedirlo.
    if cache.piezas then
        for id, lista in pairs(cache.piezas) do
            if type(lista) ~= "table" or #lista == 0 then cache.piezas[id] = nil end
        end
    end
    E.listo = true
    PLARM.Eventos.Disparar("ARMARIO_SALDO", E.creditos, E.emblemas)
    PLARM.Eventos.Disparar("ARMARIO_LISTO")
end

respuestas["puesto"] = function(resto)
    E.puesto = {}
    for cat, id in resto:gmatch("(%d+):(%d+)") do
        E.puesto[tonumber(cat)] = tonumber(id)
        --  🔴 SE PIDE LA FICHA DE LO QUE YA LLEVAS PUESTO, Y CUANTO ANTES.
        --
        --  Aqui estaba el fallo que costo el dia entero. `SetUnit("player")`
        --  arma el muneco a partir de las piezas VISIBLES del jugador, y esas
        --  son nuestras piezas cosmeticas. Si el cliente todavia no tiene su
        --  ficha, el muneco NO SE ARMA: sale vacio, sin ningun error.
        --
        --  Por eso el dueno recordaba que "salia despues de 2 minutos": eran
        --  los dos minutos que tardaban en llegar solas. Y por eso tampoco
        --  servia un muneco de prueba desnudo en una esquina -- tambien
        --  empieza por `SetUnit("player")`.
        --
        --    🎯 No basta con esperar la ficha de LO QUE VAS A PROBARTE:
        --       tambien hace falta la de LO QUE YA LLEVAS. Se me paso porque
        --       "el jugador" parecia un dato que el cliente ya tiene.
        PLARM.PedirFicha(id)
    end
    PLARM.Eventos.Disparar("APPEARANCE_CHANGED")

end

--  Espera a que el cliente conozca todas las piezas puestas y entonces pide
--  al servidor que las vuelva a pintar.
EsperarPuesto = function() end
respuestas["pend"] = function(resto)
    E.pendiente = {}
    for cat, id in resto:gmatch("(%d+):(%d+)") do
        E.pendiente[tonumber(cat)] = tonumber(id)
    end
    PLARM.Eventos.Disparar("PENDING_APPEARANCE_CHANGED")
end

respuestas["filtro"] = function(resto)
    local rid, total, tengo, paginas, filtrados =
        resto:match("^(%d+)|(%d+)|(%d+)|(%d+)|(%d+)$")
    if not rid or not Vigente(tonumber(rid)) then return end
    E.total, E.tengo = tonumber(total), tonumber(tengo)
    E.paginas, E.filtrados = tonumber(paginas), tonumber(filtrados)
    local p = esperando[tonumber(rid)]
    esperando[tonumber(rid)] = nil
    if p and p.fn then p.fn(E) end
end

respuestas["pag"] = function(resto)
    local rid, n, i, m, cuerpo = resto:match("^(%d+)|(%d+)|(%d+)/(%d+)|(.*)$")
    if not rid or not Vigente(tonumber(rid)) then return end
    rid = tonumber(rid)
    local p = esperando[rid]
    if not p then return end
    if tonumber(i) == 1 then p.acum = {} end
    p.acum = p.acum or {}
    --  🪤 EL SEXTO CAMPO ES OPCIONAL A PROPOSITO (`:?(%d*)`). Durante un
    --  despliegue conviven el servidor nuevo y el addon viejo, y al reves; un
    --  patron que EXIJA los seis campos deja de casar con los mensajes del
    --  otro lado y la rejilla sale vacia sin dar ningun error.
    --  🔒 SEPTIMO CAMPO: si esta clase NO puede ponerselo. Opcional por el
    --  mismo motivo que el sexto -- durante un despliegue conviven las dos
    --  versiones, y un patron que lo exija deja la rejilla vacia sin dar error.
    for id, tg, r, v, cat, tot, bloq in
            cuerpo:gmatch("(%d+):(%d+):(%d+):(%d+):(%d+):?(%d*):?(%d*)") do
        p.acum[#p.acum + 1] = { id = tonumber(id), t = tonumber(tg),
                                r = tonumber(r), variantes = tonumber(v),
                                cat = tonumber(cat),
                                total = tonumber(tot) or 0,
                                bloq = (tonumber(bloq) or 0) == 1 }
    end
    if tonumber(i) < tonumber(m) then return end     -- faltan trozos
    esperando[rid] = nil
    E.pagina, E.entradas = tonumber(n), p.acum

    --  🔑 LAS PIEZAS DE LA PAGINA SE PIDEN AQUI, donde llega la pagina.
    --
    --  Estaban pidiendose desde la rejilla y se colaban: en una prueba real
    --  llegaron **18 peticiones de pagina y solo 1 de piezas**. Las celdas se
    --  quedaban esperando datos que no llegaban nunca y, como `SetUnit`
    --  ensena al jugador con SU ropa, se veian todos los conjuntos iguales al
    --  que el dueno acababa de aplicarse.
    --
    --    🎯 Si un dato acompana siempre a otro, se pide donde llega ese otro.
    --       Dejarlo en manos de quien pinta es dejarlo a que se acuerde.
    local faltan = {}
    for _, e in ipairs(p.acum) do
        --  🪤 UNA ENTRADA VACIA NO ES UNA ENTRADA. La cache tenia conjuntos
        --  con CERO piezas -- de un intento anterior que no llego a
        --  responder--, y `cache.piezas[id]` daba «ya lo tengo», asi que no
        --  se volvia a pedir nunca. La celda vestia una lista vacia, que no
        --  desnuda ni prueba nada, y acababa ensenando al jugador con SU
        --  ropa: todos los conjuntos identicos al que se acababa de aplicar.
        --
        --    🎯 «Esta en la cache» tiene que significar «tengo el dato»,
        --       no «alguien apunto la clave».
        local c = cache.piezas and cache.piezas[e.id]
        if e.id >= 2000000 and e.id < 3000000 and not (c and #c > 0) then
            faltan[#faltan + 1] = e.id
        end
    end
    if #faltan > 0 then
        Pedir("piezasv", "piezasv", table.concat(faltan, ","))
    end

    if p.fn then p.fn(p.acum) end
end

respuestas["tienda"] = function(resto)
    local rid, n, i, m, cuerpo = resto:match("^(%d+)|(%d+)|(%d+)/(%d+)|(.*)$")
    if not rid or not Vigente(tonumber(rid)) then return end
    rid = tonumber(rid)
    local p = esperando[rid]
    if not p then return end
    if tonumber(i) == 1 then p.acum = {} end
    p.acum = p.acum or {}
    for id, tg, r, v, precio in cuerpo:gmatch("(%d+):(%d+):(%d+):(%d+):(%d+)") do
        p.acum[#p.acum + 1] = { id = tonumber(id), t = tonumber(tg),
                                r = tonumber(r), variantes = tonumber(v),
                                precio = tonumber(precio) }
    end
    if tonumber(i) < tonumber(m) then return end
    esperando[rid] = nil
    E.pagina, E.entradas = tonumber(n), p.acum
    if p.fn then p.fn(p.acum) end
end

respuestas["nom"] = function(resto)
    local rid, i, m, cuerpo = resto:match("^(%d+)|(%d+)/(%d+)|(.*)$")
    if not rid then return end
    rid = tonumber(rid)
    for id, nombre, rareza, ncolores, total, pieza in
            cuerpo:gmatch("(%d+)=([^~]*)~(%d+)~(%d+)~(%d+)~(%d+)") do
        cache.nombres[tonumber(id)] = {
            nombre = nombre, rareza = tonumber(rareza),
            colores = tonumber(ncolores), total = tonumber(total),
            pieza = tonumber(pieza),
        }
        --  se pide su ficha: es lo que da el icono
        if tonumber(pieza) > 0 then GetItemInfo(tonumber(pieza)) end
    end
    if tonumber(i) < tonumber(m) then return end
    local p = esperando[rid]
    esperando[rid] = nil
    if p and p.fn then p.fn(cache.nombres) end
    PLARM.Eventos.Disparar("ARMARIO_NOMBRES")
end

respuestas["info"] = function(resto)
    --  🪤 UN CAMPO VACIO TIRABA EL MENSAJE ENTERO. El patron pedia `%a+`
    --  para «como se consigue»; si ese campo llega vacio -que es lo normal en
    --  un conjunto que todavia no tiene forma de conseguirse- el `match`
    --  devuelve nil y la respuesta se descarta SIN DECIR NADA. Se veia como
    --  "la ficha no llega".
    --
    --    🎯 Al leer un mensaje, lo que puede venir vacio se lee con `*`, no
    --       con `+`. Un patron estricto no protege: solo pierde mensajes.
    local rid, id, tipo, nombre, rareza, t, total, precio, como, comoTexto =
        resto:match("^(%d+)|(%d+)|(%a*)|([^|]*)|(%d+)|(%d+)|(%d+)|(%d+)|([%a_]*)|(.*)$")
    if not rid then
        DEFAULT_CHAT_FRAME:AddMessage("|cffC83842[Armario]|r info ilegible: "
                                      .. tostring(resto):sub(1, 80))
        return
    end
    local d = {
        id = tonumber(id), tipo = tipo, nombre = nombre,
        rareza = tonumber(rareza), t = tonumber(t), total = tonumber(total),
        precio = tonumber(precio), como = como, comoTexto = comoTexto,
        alternativas = {},
    }
    local p = esperando[tonumber(rid)]
    if p then p.info = d end
    --  🔴 SE ESPERA AL `alt` TAMBIEN PARA LAS PIEZAS (03-09-2026).
    --
    --  Aqui ponia `tipo ~= "S"`: todo lo que no fuera conjunto se pintaba de
    --  inmediato. Cuando las piezas sueltas pasaron a agruparse por familia,
    --  eso les quitaba los colores -- la ventana se pintaba antes y el `alt`
    --  que llegaba un instante despues encontraba `esperando[rid]` ya vacio y
    --  se descartaba. El sintoma: *«se agruparon pero no se puede cambiar el
    --  color como con los sets»*.
    --
    --  Ya no hay que adivinar: el servidor manda el `alt` siempre, tanto para
    --  conjuntos como para piezas, aunque solo haya un color.
    if p and p.fn and tipo ~= "S" and tipo ~= "I" then
        esperando[tonumber(rid)] = nil
        p.fn(d)
    end
end

respuestas["alt"] = function(resto)
    local rid, id, i, m, cuerpo = resto:match("^(%d+)|(%d+)|(%d+)/(%d+)|(.*)$")
    if not rid then return end
    rid = tonumber(rid)
    local p = esperando[rid]
    if not p or not p.info then return end
    --  🔴 LA RANURA VIENE EN EL MENSAJE (cuarto campo). Sin ella, pulsar
    --  una muestra de color no hacia nada -- ver la nota del servidor.
    --  El patron acepta que falte, por si llega un mensaje antiguo.
    for setid, color, hex, cat in
            cuerpo:gmatch("(%d+):([^:,]*):(%x%x%x%x%x%x):?(%d*)") do
        p.info.alternativas[#p.info.alternativas + 1] =
            { id = tonumber(setid), color = color, hex = hex,
              cat = tonumber(cat) }
    end
    if tonumber(i) < tonumber(m) then return end
    esperando[rid] = nil
    if p.fn then p.fn(p.info) end
end

--  🔑 LAS PIEZAS DE UNA PAGINA, en un solo mensaje. Se guardan en la cache,
--  asi que volver a esa pagina no pide nada. Es el equilibrio entre no pedir
--  una cosa por celda -- que desconectaba al jugador -- y no traerse el
--  catalogo entero, que no escala.
respuestas["piezasv"] = function(resto)
    local rid, i, m, cuerpo = resto:match("^(%d+)|(%d+)/(%d+)|(.*)$")
    if not rid then return end
    rid = tonumber(rid)
    --  🔴 30-09-2026: LAS PIEZAS SE GUARDAN AUNQUE LA PETICION YA NO ESTE.
    --     Antes se descartaba la respuesta si `Pedir` habia cerrado su rid
    --     por otra peticion del mismo canal. El pase repide el conjunto del
    --     nivel 100 cada medio segundo: en produccion, con lag, cada respuesta
    --     llegaba para una peticion ya cerrada, se tiraba, y el muñeco se
    --     quedaba parpadeando sin vestirse nunca (lo vio el dueño). Los datos
    --     son buenos igual: se guardan siempre.
    cache.piezas = cache.piezas or {}
    for setid, lista in cuerpo:gmatch("(%d+)=([^;]*)") do
        local piezas = {}
        for cat, id in lista:gmatch("(%d+):(%d+)") do
            piezas[#piezas + 1] = { cat = tonumber(cat), id = tonumber(id) }
        end
        if #piezas > 0 then cache.piezas[tonumber(setid)] = piezas end
    end
    local p = esperando[rid]
    if not p then return end
    if tonumber(i) < tonumber(m) then return end
    esperando[rid] = nil
    --  Avisar a las celdas que se quedaron esperando este conjunto.
    for setid, lista in pairs(esperandoPiezas) do
        local piezas = cache.piezas[setid]
        if piezas then
            esperandoPiezas[setid] = nil
            for _, fn in ipairs(lista) do pcall(fn, piezas) end
        end
    end
    PLARM.Eventos.Disparar("CATALOGO_LISTO")
    if p.fn then p.fn(cache.piezas) end
end

--  Los atuendos guardados. Llegan como `nombre=cat:id,cat:id;otro=...`
respuestas["atu"] = function(resto)
    local rid, i, m, cuerpo = resto:match("^(%d+)|(%d+)/(%d+)|(.*)$")
    if not rid then return end
    rid = tonumber(rid)
    local p = esperando[rid]
    if not p then return end
    p.acum = (tonumber(i) == 1) and {} or (p.acum or {})
    for nombre, lista in cuerpo:gmatch("([^=;]+)=([^;]*)") do
        local piezas = {}
        for cat, id in lista:gmatch("(%d+):(%d+)") do
            piezas[#piezas + 1] = { cat = tonumber(cat), id = tonumber(id) }
        end
        p.acum[#p.acum + 1] = { nombre = nombre, piezas = piezas }
    end
    if tonumber(i) < tonumber(m) then return end
    esperando[rid] = nil
    E.atuendos = p.acum
    if p.fn then p.fn(p.acum) end
end

respuestas["piezas"] = function(resto)
    local rid, setid, i, m, cuerpo = resto:match("^(%d+)|(%d+)|(%d+)/(%d+)|(.*)$")
    if not rid then return end
    rid = tonumber(rid)
    local p = esperando[rid]
    if not p then return end
    if tonumber(i) == 1 then p.acum = {} end
    p.acum = p.acum or {}
    for cat, pieza in cuerpo:gmatch("(%d+):(%d+)") do
        p.acum[#p.acum + 1] = { cat = tonumber(cat), id = tonumber(pieza) }
    end
    if tonumber(i) < tonumber(m) then return end
    esperando[rid] = nil
    if p.fn then p.fn(p.acum) end
end

respuestas["destacado"] = function(resto)
    local rid, setid = resto:match("^(%d+)|(%d+)$")
    if not rid then return end
    local p = esperando[tonumber(rid)]
    esperando[tonumber(rid)] = nil
    if p and p.fn then p.fn(tonumber(setid)) end
end

respuestas["saldo"] = function(resto)
    local cr, em = resto:match("^(%d+)|(%d+)$")
    if not cr then return end
    E.creditos, E.emblemas = tonumber(cr), tonumber(em)
    PLARM.Eventos.Disparar("ARMARIO_SALDO", E.creditos, E.emblemas)
end

respuestas["evt"] = function(resto)
    local nombre, args = resto:match("^([A-Z_]+)|?(.*)$")
    if not nombre then return end
    local partes = {}
    for a in tostring(args):gmatch("[^|]+") do partes[#partes + 1] = a end
    PLARM.Eventos.Disparar(nombre, unpack(partes))
end

respuestas["prueba"] = function(resto)
    PLARM.Eventos.Disparar("ARMARIO_PRUEBA", resto)
end

respuestas["ok"]  = function(resto) PLARM.Eventos.Disparar("ARMARIO_AVISO", resto, false) end

--  🪄 La respuesta de `.transmog aplicar` (el nucleo, cs_transmog.cpp):
--  tmog|<ranura>|<objeto>|<resultado>. Los numeros son los de TransmogStrings.
local TMOG_TEXTO = {
    [1]  = { "Transfiguracion puesta.", false },
    [9]  = { "Transfiguracion quitada.", false },
    [2]  = { "Esa ranura no se puede transfigurar.", true },
    [3]  = { "Esa apariencia no existe.", true },
    [4]  = { "No tienes esa apariencia coleccionada.", true },
    [5]  = { "No llevas nada en esa ranura: equipate algo primero.", true },
    [6]  = { "Esa apariencia no encaja con lo que llevas en esa ranura.", true },
    [7]  = { "No tienes oro suficiente para transfigurar.", true },
    [8]  = { "Te faltan fichas para transfigurar.", true },
    -- Project Jaina transfiguración dual (Oro o Token Andino)
    [90] = { "Para transfigurar tienes que estar en Ventormenta u Orgrimmar.", true },
    [91] = { "No tienes Tokens Andinos suficientes para transfigurar.", true },
}
respuestas["tmog"] = function(resto)
    local ranura, objeto, res = tostring(resto):match("^(%d+)|(%d+)|(%d+)")
    res = tonumber(res)
    if res == 10 then return end      -- «no habia nada que quitar»: no es noticia
    local t = TMOG_TEXTO[res] or { "No se pudo transfigurar (" .. tostring(res) .. ").", true }
    PLARM.Eventos.Disparar("ARMARIO_AVISO", t[1], t[2])
end
respuestas["err"] = function(resto)
    --  🪤 UN ERROR TAMBIEN ES UNA RESPUESTA. Sin esto la peticion se quedaba
    --  en la cola y a los 6 s salia "El servidor no contesta", que manda a
    --  buscar el fallo en el sitio equivocado: el servidor SI contesto.
    for rid, p in pairs(esperando) do esperando[rid] = nil end
    PLARM.Eventos.Disparar("ARMARIO_AVISO", resto, true)
end

local oyente = CreateFrame("Frame")
oyente:RegisterEvent("CHAT_MSG_ADDON")
oyente:SetScript("OnEvent", function(self, evento, prefijo, texto, _, quien)
    if prefijo ~= PREFIJO then return end
    --  🔴 SOLO MENSAJES DEL SERVIDOR (29-09-2026): el servidor nos los manda
    --     como susurro de nosotros mismos. Sin esto, OTRO jugador podia
    --     mandarnos mensajes con este prefijo y manejar el addon: abrir una
    --     web con la extension, enviar ordenes en nuestro nombre o pintar
    --     respuestas falsas.
    if quien ~= UnitName("player") then return end

    --  El eco de lo que acabamos de mandar, fuera. Se caduca a los 5 s para
    --  que la tabla no crezca durante una sesion larga.
    local cuando = eco[texto]
    if cuando then
        eco[texto] = nil
        if GetTime() - cuando < 5 then return end
    end
    PLARM_CUENTA = PLARM_CUENTA or {}
    do
        local orden = tostring(texto):match("^(%w+)")
        if orden then PLARM_CUENTA[orden] = (PLARM_CUENTA[orden] or 0) + 1 end
    end
    local orden, resto = tostring(texto):match("^(%w+)|?(.*)$")
    local fn = orden and respuestas[orden]
    if not fn then return end
    --  Un mensaje raro no puede tumbar el oyente: si esto revienta, el addon
    --  se queda sordo para siempre y sin decir por que.
    local ok, err = pcall(fn, resto or "")
    if not ok then
        print("|cffC83842[Armario]|r mensaje '" .. tostring(orden) .. "': " .. tostring(err))
    end
end)

-- ---------------------------------------------------------------------------
--  LAS FUNCIONES, con los nombres de Ascension
-- ---------------------------------------------------------------------------
C_AppearanceCollection = {}
C_Appearance           = {}
C_ItemSet              = {}
C_AppearanceOutfit     = {}

--- Los atuendos guardados de la CUENTA. Van por cuenta, no por personaje:
--- es lo que hace Ascension y lo que espera el jugador.
function C_AppearanceOutfit.GetOutfits(alListo)
    Pedir("atuendos", "atu", "lista", alListo)
end

function C_AppearanceOutfit.Save(nombre)
    PLARM.Contrato.Mandar("atu|guardar|" .. tostring(nombre))
end

function C_AppearanceOutfit.Delete(nombre)
    PLARM.Contrato.Mandar("atu|borrar|" .. tostring(nombre))
end

function C_AppearanceOutfit.Wear(nombre)
    PLARM.Contrato.Mandar("atu|poner|" .. tostring(nombre))
end
C_VanityCollection     = {}

--  Las categorias son fijas y se conocen sin preguntar: son las ranuras que
--  se ven. El nombre en espanol y el icono salen del propio cliente.
local CATEGORIAS = {
    { cat = 0,  nombre = "Cabeza",          ranura = "HeadSlot" },
    { cat = 2,  nombre = "Hombros",         ranura = "ShoulderSlot" },
    { cat = 14, nombre = "Espalda",         ranura = "BackSlot" },
    { cat = 4,  nombre = "Pecho",           ranura = "ChestSlot" },
    { cat = 3,  nombre = "Camisa",          ranura = "ShirtSlot" },
    { cat = 8,  nombre = "Munecas",         ranura = "WristSlot" },
    { cat = 9,  nombre = "Manos",           ranura = "HandsSlot" },
    { cat = 5,  nombre = "Cintura",         ranura = "WaistSlot" },
    { cat = 6,  nombre = "Piernas",         ranura = "LegsSlot" },
    { cat = 7,  nombre = "Pies",            ranura = "FeetSlot" },
    { cat = 15, nombre = "Mano principal",  ranura = "MainHandSlot" },
    { cat = 16, nombre = "Mano secundaria", ranura = "SecondaryHandSlot" },
    { cat = 17, nombre = "A distancia",     ranura = "RangedSlot" },
    --  🔴 TABARDO (17-09-2026). Faltaba, y el dueño lo destapo en pantalla:
    --  con un conjunto puesto, equiparse un tabardo **tapaba el pecho**. En
    --  WoW el tabardo se dibuja encima del torso, asi que si el armario no
    --  manda en esa ranura gana siempre el objeto real.
    --
    --  🔑 Ascension lo tiene igual: su `AppearanceCategories.dbc` lleva una
    --     categoria `Tabard` con el icono `inv_shirt_guildtabard_`.
    { cat = 18, nombre = "Tabardo",         ranura = "TabardSlot" },
}

function C_AppearanceCollection.GetAppearanceTypes()
    return { "APPEARANCE_TYPE_ITEM", "APPEARANCE_TYPE_ITEM_SET",
             "APPEARANCE_TYPE_OUTFIT", "APPEARANCE_TYPE_VANITY" }
end

function C_AppearanceCollection.GetCategoriesForType(tipo)
    if tipo == "APPEARANCE_TYPE_ITEM" then return CATEGORIAS end
    return {}
end

function C_AppearanceCollection.GetCategoryInfo(cat)
    for _, c in ipairs(CATEGORIAS) do
        if c.cat == cat then
            local _, textura = GetInventorySlotInfo(c.ranura)
            return c.nombre, textura
        end
    end
    return "", nil
end

--- Filtra y ordena. Es lo unico que fija cuantas paginas hay.
function C_AppearanceCollection.ApplyCategoryFilter(tipo, cat, texto, orden, flags, alListo)
    E.tipo, E.categoria = tipo, cat
    E.orden, E.flags, E.texto = orden or 0, flags or 0, texto or ""
    E.pagina = 1
    Pedir("filtro", "filtro", string.format("%s|%d|%d|%d|%s",
          tipo, cat, orden or 0, flags or 0, texto or ""), alListo)
end

function C_AppearanceCollection.GetCategoryMaxPages() return E.paginas end
function C_AppearanceCollection.GetCollectedCount()   return E.tengo, E.total end

--- Los elementos de una pagina. Es la funcion que usa la rejilla.
function C_AppearanceCollection.GetCategoryAppearances(pagina, alListo)
    Pedir("pagina", "pag", tostring(pagina), alListo)
end

function C_AppearanceCollection.IsAppearanceCollected(id)
    for _, e in ipairs(E.entradas) do
        if e.id == id then return e.t > 0 end
    end
    return nil          -- no lo sabemos todavia
end

-- ---------------------------------------------------------------------------
function C_Appearance.GetAppearanceDisplayInfo(id)
    local c = cache.nombres[id]
    local tipo = (id >= 2000000 and id < 3000000) and "ITEM_SET" or "ITEM"
    if c then return tipo, id, c.nombre, c.rareza, c.total, c.colores end
    if tipo == "ITEM" then
        local nombre, _, calidad = GetItemInfo(id)
        if nombre then return tipo, id, nombre, (calidad or 1) + 1, 1, 1 end
    end
    return tipo, id, nil
end

--- Pide los nombres que no tenemos. La rejilla la llama con lo de su pagina.
--- 🪤 EL CANAL SE PUEDE CAMBIAR, Y LA AUTOPRUEBA LO NECESITA.
---
--- La prueba pedia nombres y fichas por los MISMOS canales que usa la
--- rejilla. Como un canal solo admite una peticion viva -- esa es su razon de
--- ser --, la rejilla anulaba las de la prueba y esta fallaba en «nombres» y
--- «ficha y colores» con el armario funcionando perfectamente.
---
---   🎯 Un instrumento que da falsos negativos es peor que no tenerlo: manda
---      a buscar fallos donde no los hay. Paso justo eso.
function C_Appearance.PedirNombres(ids, alListo, canal)
    --  🔴 UNA ENTRADA GUARDADA DE UNA VERSION ANTERIOR NO VALE.
    --
    --  La cache vive en disco entre sesiones. Al anadir un campo nuevo
    --  -- el icono --, las entradas viejas se quedaron sin el y NUNCA se
    --  volvian a pedir, porque «ya estaban». La rejilla se quedo en blanco y
    --  seguia en blanco despues de salir y entrar.
    --
    --    🎯 Una cache tiene que saber si lo que guarda sigue sirviendo. No
    --       basta con preguntar si el dato esta: hay que preguntar si esta
    --       COMPLETO.
    local faltan = {}
    for _, id in ipairs(ids) do
        local c = cache.nombres[id]
        if not c or c.pieza == nil then faltan[#faltan + 1] = id end
    end
    if #faltan == 0 then
        if alListo then alListo(cache.nombres) end
        return
    end
    Pedir(canal or "nombres", "nom", table.concat(faltan, ","), alListo)
end

function C_Appearance.GetAppearanceDetails(id, alListo, canal)
    Pedir(canal or "info", "info", tostring(id), alListo)
end

function C_Appearance.GetAlternativeIDs(id, alListo)
    C_Appearance.GetAppearanceDetails(id, function(d)
        if alListo then alListo(d and d.alternativas or {}) end
    end)
end

function C_Appearance.GetAppearanceForCategory(cat) return E.puesto[cat] end
function C_Appearance.GetPendingAppearance(cat)     return E.pendiente[cat] end

function C_Appearance.HasPendingAppearances()
    for _ in pairs(E.pendiente) do return true end
    return false
end

function C_Appearance.SetPendingAppearance(cat, id) Mandar("pend|" .. cat .. "|" .. (id or 0)) end
function C_Appearance.ClearPendingAppearance(cat)   Mandar("pend|" .. cat .. "|0") end
function C_Appearance.ClearAllPendingAppearances()  Mandar("pendlimpiar") end
function C_Appearance.ApplyPendingAppearances()     Mandar("aplicar") end

--- Lo que Ascension NO tiene: probarse un conjunto entero de una vez.
function C_Appearance.SetPendingItemSet(setid)      Mandar("pendset|" .. setid) end

--- Probarse una pieza suelta. No hace falta decir la ranura: la sabe el
--- servidor, que es quien tiene el catalogo.
function C_Appearance.SetPendingPiece(id)          Mandar("pendpieza|" .. id) end

function C_Appearance.GetAppearanceWebURL()
    return "https://darckrovert.github.io/ProjectJaina_Web/tienda.html"
end

--  Lo que en su cliente existe y aqui no aplica. Se dejan devolviendo el
--  valor neutro a proposito: asi el codigo copiado de su addon no revienta y
--  se ve de un vistazo que no es un olvido.
function C_Appearance.GetActiveDiscount()          return nil end
function C_Appearance.IsEtherealBazaarAppearance() return false end
function C_Appearance.GetCreatureDisplayItems()    return {} end

-- ---------------------------------------------------------------------------
function C_ItemSet.GetAppearances(setid, alListo)
    --  🔴 UN CANAL POR CONJUNTO, NO UNO PARA TODOS. Con un solo canal
    --  "piezas", las 18 fichas de la rejilla se pisaban entre ellas: cada
    --  una anulaba la anterior y solo la ULTIMA llegaba a vestirse. Las
    --  otras 17 se quedaban vacias, sin ningun error.
    --
    --  El canal existe para que una peticion cancele a la que sustituye.
    --  Dos fichas distintas no se sustituyen: son peticiones paralelas.
    --  🔴 DE LA CACHE, SIN HABLAR CON EL SERVIDOR. Antes cada ficha de la
    --  rejilla pedia las suyas: 18 fichas = 18 mensajes, y con el filtro y la
    --  pagina se medieron **39 mensajes en un segundo**. El servidor corta a
    --  los 10 y el jugador acababa desconectado a los pocos minutos, sin
    --  caida del cliente y sin una linea que lo explicara.
    --
    --  Ascension no tiene este problema porque su interfaz no pregunta nada:
    --  `GetCategoryAppearances(page)` devuelve la lista en el acto. Aqui se
    --  consigue lo mismo trayendo el catalogo una vez y guardandolo.
    --
    --    🎯 La respuesta no era mandar menos mensajes: era no mandar ninguno.
    --  🔴 UNA CELDA NO MANDA MENSAJES. NUNCA.
    --
    --  Antes cada ficha pedia sus piezas: 18 celdas mas el filtro y la pagina
    --  daban 39 mensajes en un segundo, el anti-inundacion cortaba a los 10 y
    --  el jugador se desconectaba sin ninguna pista.
    --
    --  Si el dato no esta, NO se pide aqui: se apunta el interesado y se le
    --  avisa cuando llegue el lote de la pagina. Quien pide es la rejilla,
    --  una vez, para las 18. Es lo que hace Ascension -- su
    --  `GetCategoryAppearances(page)` devuelve en el acto porque el cliente ya
    --  tiene los datos.
    --
    --    🎯 Dejar la puerta abierta «por si acaso» es dejarla abierta. Si
    --       ninguna celda debe hablar con el servidor, que no pueda.
    local c = cache.piezas and cache.piezas[setid]
    if c and #c > 0 then
        if alListo then alListo(c) end
        return c
    end
    if alListo then
        esperandoPiezas[setid] = esperandoPiezas[setid] or {}
        table.insert(esperandoPiezas[setid], alListo)
    end
end

--- Trae de golpe las piezas de los conjuntos de UNA pagina.
--- La rejilla la llama una vez por pagina, antes de llenar las celdas.
function C_ItemSet.PedirPiezasDePagina(ids, alListo)
    local faltan = {}
    for _, id in ipairs(ids or {}) do
        --  Solo conjuntos, y solo los que no estan ya en la cache: pasar de
        --  pagina hacia atras no vuelve a pedir nada.
        if id >= 2000000 and id < 3000000 and not (cache.piezas and cache.piezas[id]) then
            faltan[#faltan + 1] = id
        end
    end
    if #faltan == 0 then
        if alListo then alListo(cache.piezas) end
        return
    end
    Pedir("catalogo", "piezasv", table.concat(faltan, ","), alListo)
end

function C_ItemSet.GetItemSetName(setid)
    local c = cache.nombres[setid]
    return c and c.nombre or nil
end

function C_ItemSet.GetItemSetNumCollected(setid)
    for _, e in ipairs(E.entradas) do
        if e.id == setid then
            local c = cache.nombres[setid]
            return e.t, c and c.total or 0
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
function C_VanityCollection.QueryItems(pagina, flags, texto, alListo)
    Pedir("tienda", "tienda", string.format("%d|%d|%s", pagina, flags or 0, texto or ""), alListo)
end

function C_VanityCollection.Purchase(setid) Mandar("comprar|" .. setid) end
function C_VanityCollection.GetRandomItem(alListo) Pedir("destacado", "destacado", nil, alListo) end
function C_VanityCollection.GetSaldo() return E.creditos, E.emblemas end

-- ---------------------------------------------------------------------------
--  Arranque y autoprueba
-- ---------------------------------------------------------------------------
function PLARM.Contrato.Cache() return cache.nombres end

--- 🔴 «PRESENTE»: SIN ESTO NO SE TE PINTA NADA.
---
--- El servidor guarda tu apariencia, pero solo la PINTA cuando el addon
--- saluda -- y saluda a proposito, porque es la unica forma de saber que ese
--- cliente trae nuestros parches (a quien entra con un 3.3.5a normal no se le
--- pinta, o vería cubos en su seleccion de personaje).
---
--- Lo mandaba el armario viejo. Al retirarlo dejo de mandarlo NADIE, y el
--- resultado fue exactamente lo que reporto el dueno: el conjunto aplicado
--- estaba guardado en la base, la seleccion de personaje lo mostraba -porque
--- lee una copia guardada- y en el mundo salia el equipo real.
---
---   🎯 Al retirar codigo viejo, lo que se va no son solo sus funciones: son
---      tambien los mensajes que mandaba y de los que dependia otro guion.
function PLARM.Contrato.Presente() Mandar("presente") end

function PLARM.Contrato.Saludar() Mandar("hola2") end

function PLARM.Contrato.Metrica(que, id) Mandar("metrica|" .. que .. "|" .. (id or 0)) end

--- Vuelca la cuenta de mensajes recibidos por orden. Diagnostico temporal.
function PLARM.Contrato.Diag()
    local partes = {}
    for k, v in pairs(PLARM_CUENTA or {}) do partes[#partes + 1] = k .. "=" .. v end
    if PLARM and PLARM.Diag then PLARM.Diag(table.concat(partes, "  ")) end
end

--- Se prueba sola y escribe el resultado en el chat.
--- 🎯 Existe porque durante tres dias la unica forma de saber si algo
--- funcionaba era pedirle al dueno que lo probara. Eso se acabo.
function PLARM.Contrato.Autoprueba()
    local pasos, hechos, fallos = {}, 0, {}
    --  La autoprueba es un instrumento, no un aviso para el jugador.
    local function di(t) if PLARM and PLARM.Diag then PLARM.Diag(t) end end

    local function paso(nombre, fn) pasos[#pasos + 1] = { nombre = nombre, fn = fn } end
    local i = 0
    local function siguiente()
        i = i + 1
        if not pasos[i] then
            di(string.format("autoprueba %d/%d%s", hechos, #pasos,
               #fallos > 0 and ("  FALLA: " .. table.concat(fallos, ", ")) or ""))
            return
        end
        pasos[i].fn(function(bien)
            if bien then hechos = hechos + 1 else fallos[#fallos + 1] = pasos[i].nombre end
            siguiente()
        end)
    end

    paso("saludo", function(listo)
        PLARM.Contrato.Saludar()
        local f = CreateFrame("Frame"); local t = 0
        f:SetScript("OnUpdate", function(s, e)
            t = t + e
            if E.listo then s:SetScript("OnUpdate", nil); listo(true)
            elseif t > 4 then s:SetScript("OnUpdate", nil); listo(false) end
        end)
    end)

    paso("filtro de conjuntos", function(listo)
        C_AppearanceCollection.ApplyCategoryFilter("S", 100, "", 0, 0, function(e)
            listo(e ~= nil and e.total > 0)
        end)
    end)

    paso("pagina 1", function(listo)
        C_AppearanceCollection.GetCategoryAppearances(1, function(lista)
            listo(lista ~= nil and #lista > 0)
        end)
    end)

    --  🔴 EL PASO QUE IMPORTA: se piden tres paginas seguidas y solo puede
    --  pintar la ultima. Es la prueba del fallo que costo tres dias.
    paso("una respuesta vieja no pisa a la nueva", function(listo)
        local pintadas = {}
        C_AppearanceCollection.GetCategoryAppearances(1, function() pintadas[#pintadas+1] = 1 end)
        C_AppearanceCollection.GetCategoryAppearances(2, function() pintadas[#pintadas+1] = 2 end)
        C_AppearanceCollection.GetCategoryAppearances(3, function() pintadas[#pintadas+1] = 3 end)
        local f = CreateFrame("Frame"); local t = 0
        f:SetScript("OnUpdate", function(s, e)
            t = t + e
            if t > 3 then
                s:SetScript("OnUpdate", nil)
                listo(#pintadas == 1 and pintadas[1] == 3)
            end
        end)
    end)

    --  🪤 EL PASO ANTERIOR DEJA EL ESTADO EN UNA PAGINA QUE PUEDE NO EXISTIR.
    --  Pide la 1, la 2 y la 3 a proposito para comprobar que solo pinta la
    --  ultima -- pero con 26 conjuntos solo hay 2 paginas, asi que despues
    --  `E.entradas` queda VACIO y los dos pasos siguientes fallaban con el
    --  armario funcionando perfectamente.
    --
    --    🎯 Una prueba tiene que dejar el estado como se lo encontro. Si no,
    --       ensucia a las que vienen detras y acusa a quien no ha hecho nada.
    paso("volver a la pagina 1", function(listo)
        C_AppearanceCollection.GetCategoryAppearances(1, function(lista)
            listo(lista ~= nil and #lista > 0)
        end)
    end)

    paso("nombres", function(listo)
        local ids = {}
        for _, en in ipairs(E.entradas) do ids[#ids + 1] = en.id end
        if #ids == 0 then listo(false) return end
        C_Appearance.PedirNombres(ids, function()
            listo(cache.nombres[ids[1]] ~= nil)
        end, "prueba-nombres")
    end)

    paso("ficha y colores", function(listo)
        local id = E.entradas[1] and E.entradas[1].id
        if not id then listo(false) return end
        C_Appearance.GetAppearanceDetails(id, function(d)
            listo(d ~= nil and d.nombre ~= nil)
        end, "prueba-info")
    end)

    paso("piezas del conjunto", function(listo)
        --  Solo tiene sentido en un CONJUNTO. Un arma suelta no tiene piezas
        --  y el servidor responde -bien- que ese conjunto no existe.
        local id
        for _, e in ipairs(E.entradas) do
            if e.id >= 2000000 and e.id < 3000000 then id = e.id break end
        end
        if not id then listo(true) return end
        C_ItemSet.GetAppearances(id, function(lista)
            listo(lista ~= nil and #lista > 0)
        end)
    end)

    paso("tienda", function(listo)
        C_VanityCollection.QueryItems(1, 0, "", function(lista) listo(lista ~= nil) end)
    end)

    di("autoprueba en marcha...")
    siguiente()
end

-- ---------------------------------------------------------------------------
--  Arranque
-- ---------------------------------------------------------------------------
--  🪤 EL COMANDO `/armario2` LO REGISTRA `Ventana.lua`, NO ESTE FICHERO.
--  Estuvo en los dos un rato: dos `SlashCmdList` con el mismo texto no dan
--  ningun error, simplemente gana el ultimo que se carga, y el otro deja de
--  existir sin que nada lo diga.
--  Saludar al entrar: sin esto el contrato no tiene ni version ni saldo, y la
--  ventana no sabria ni cuantas paginas hay.
local arranque = CreateFrame("Frame")
arranque:RegisterEvent("PLAYER_ENTERING_WORLD")
arranque:SetScript("OnEvent", function(self)
    --  `presente` al entrar, igual que la v1: es lo que hace que el servidor
    --  te pinte lo tuyo. Se quito durante la v2 buscando un problema de orden
    --  que resulto no ser el problema, y sin esto no se pinta nada.
    PLARM.Contrato.Presente()
    --  Al jugador no le importa que archivos cargaron: solo a quien depura.
    if PLARM and PLARM.Diag then
        PLARM.Diag("cargado:" .. tostring(PLARM_CARGADO))
    end
    local f = CreateFrame("Frame"); local t = 0
    f:SetScript("OnUpdate", function(s, e)
        t = t + e
        if t > 3 then
            s:SetScript("OnUpdate", nil)
            PLARM.Contrato.Saludar()
            --  🎯 Y SE PRUEBA SOLA, una vez por sesion. Durante tres dias la
            --  unica forma de saber si algo funcionaba era pedirselo al
            --  dueno; eso convertia cada intento en media hora suya y ponia
            --  el resultado en manos de lo que el pudiera ver. La prueba
            --  escribe en el chat, que es lo que se puede fotografiar desde
            --  fuera con `modelos/captura.ps1`.
            local g = CreateFrame("Frame"); local t2 = 0
            g:SetScript("OnUpdate", function(gg, ee)
                t2 = t2 + ee
                --  🔴 29-09-2026: solo con PLARM.DEPURAR. Con 500 personas era
                --  un filtro y cuatro paginas del catalogo entero por cada
                --  pantalla de carga de cada jugador, para nada.
                if t2 > 5 then
                    gg:SetScript("OnUpdate", nil)
                    if PLARM.DEPURAR then PLARM.Contrato.Autoprueba() end
                end
            end)
        end
    end)
end)

--  Marca de carga: si este archivo revienta, su linea NO sale y se ve al
--  instante cual es. Los errores de Lua vienen apagados de fabrica.
PLARM_CARGADO = (PLARM_CARGADO or "") .. " Contrato"
