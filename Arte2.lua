-- ============================================================================
--  EL ARTE NUEVO DEL ARMARIO   ·   25-09-2026
-- ============================================================================
--  Diseño elegido por el dueño: la propuesta «premium piezas 1» (marco con las
--  esquinas redondeadas y el sol ENCIMA del borde), las pestañas de «premium
--  conjuntos 2», y SIN los cuadros de color (aún no hay variantes que dar).
--
--  Las piezas salen de `modelos/arte-armario/cortar_armario.py` y viajan en
--  patch-y (fuentes/.../PeruLandArmario/arte2/), como el arte del pase.
--
--  Aqui se SUSTITUYEN `PLARM.Boton` y `PLARM.Pestana` de Estilo.lua: todos los
--  botones del armario pasan a usar el arte nuevo sin tocar cada sitio que
--  los crea. Misma interfaz (piezas, pulsadas, etiqueta, Apagar, Marcar).
-- ============================================================================

PLARM = PLARM or {}

local A = "Interface\\AddOns\\ProjectJaina_Wardrobe\\arte2\\"
PLARM.ARTE2 = A

--  { ancho usado, alto usado, ancho lienzo, alto lienzo } de cada pieza.
--  Sale tal cual de cortar_armario.py: si se recorta de nuevo, se copia aqui.
local INFO = {
    PestanaOn    = { 512, 112, 512, 128 },
    PestanaOff   = { 512, 114, 512, 128 },
    BotonOro     = { 512, 114, 512, 128 },
    BotonOscuro  = { 512, 119, 512, 128 },
    Tarjeta      = { 256, 324, 256, 512 },
    TarjetaOn    = { 256, 321, 256, 512 },
    RanuraOff    = { 128, 117, 128, 128 },
    RanuraOn     = { 128, 119, 128, 128 },
    FlechaIzq    = { 128, 123, 128, 128 },
    FlechaDer    = { 128, 123, 128, 128 },
    Cerrar       = { 128, 123, 128, 128 },
    Buscador     = { 512, 92, 512, 128 },
    IcoConjuntos = { 46, 64, 64, 64 },
    IcoPiezas    = { 63, 64, 64, 64 },
    IcoGuardados = { 42, 64, 64, 64 },
    IcoTienda    = { 64, 54, 64, 64 },
    IcoFiltro    = { 64, 60, 64, 64 },
    IcoOrden     = { 64, 60, 64, 64 },
    --  🎨 Galeria (cortar_galeria.py)
    TarjetaG     = { 256, 306, 256, 512 },
    TarjetaGOn   = { 256, 306, 256, 512 },
    FlechaIzqG   = { 28, 28, 32, 32 },
    FlechaDerG   = { 28, 28, 32, 32 },
    Candado      = { 40, 56, 64, 64 },
    BarraFondo   = { 512, 40, 512, 64 },
    BarraLlena   = { 512, 40, 512, 64 },
    Fondo        = { 256, 328, 256, 512 },
}

--  🎨 LOS FONDOS DE AMBIENTE de las tarjetas (13, de colores distintos).
--     Cada conjunto tiene SIEMPRE el mismo: sale de su id, asi no cambia al
--     pasar de pagina ni al volver. Que se repitan entre conjuntos da igual.
PLARM.N_FONDOS = 13
function PLARM.FondoDe(id, texto)
    local n = tonumber(id) or 0
    if n == 0 and texto then
        for i = 1, #texto do n = n + texto:byte(i) * i end
    end
    return string.format("%sFondo%02d", A, (n % PLARM.N_FONDOS) + 1)
end

--- Pone un fondo en una textura con el recorte que pide su marco: la imagen
--- es 256x328 y el marco puede ser mas ancho o mas estrecho. Se recorta el
--- sobrante por los lados (o por arriba), nunca se deforma.
function PLARM.PonerFondo(tex, ruta, ancho, alto)
    tex:SetTexture(ruta)
    --  336x432 dentro de un lienzo 512x512 (fondos_galeria.py)
    local fw, fh = 336, 432
    local u1, v1 = fw / 512, fh / 512
    local ar, af = ancho / alto, fw / fh
    if ar < af then            -- marco mas estrecho: se recortan los lados
        local sobra = u1 * (1 - ar / af) / 2
        tex:SetTexCoord(sobra, u1 - sobra, 0, v1)
    else                       -- mas ancho: se recorta arriba (el suelo se queda)
        local usar = af / ar
        tex:SetTexCoord(0, u1, v1 * (1 - usar), v1)
    end
end
PLARM.ARTE2_INFO = INFO

--- Una pieza entera, estirada al tamaño del marco (tarjetas, ranuras).
function PLARM.Pieza(marco, nombre, capa)
    local i = INFO[nombre]
    local t = marco:CreateTexture(nil, capa or "BACKGROUND")
    t:SetTexture(A .. nombre)
    t:SetTexCoord(0, i[1] / i[3], 0, i[2] / i[4])
    t:SetAllPoints(marco)
    return t
end

--- En TRES trozos: los extremos conservan su bisel y solo se estira el medio.
--- 🪤 El ancho de los extremos se saca del ALTO del marco, que tiene que estar
---    puesto antes de llamar (todos los botones se crean con su tamaño).
function PLARM.Tres(marco, nombre, capa, fraccion)
    local i = INFO[nombre]
    local u, v = i[1] / i[3], i[2] / i[4]
    fraccion = fraccion or 0.07          -- lo que ocupa cada extremo en la pieza
    local cu = u * fraccion
    local ancho = math.max(6, (marco:GetHeight() or 20) * (i[1] * fraccion) / i[2])

    local izq = marco:CreateTexture(nil, capa)
    izq:SetPoint("TOPLEFT"); izq:SetPoint("BOTTOMLEFT"); izq:SetWidth(ancho)
    izq:SetTexture(A .. nombre); izq:SetTexCoord(0, cu, 0, v)

    local der = marco:CreateTexture(nil, capa)
    der:SetPoint("TOPRIGHT"); der:SetPoint("BOTTOMRIGHT"); der:SetWidth(ancho)
    der:SetTexture(A .. nombre); der:SetTexCoord(u - cu, u, 0, v)

    local med = marco:CreateTexture(nil, capa)
    med:SetPoint("TOPLEFT", izq, "TOPRIGHT")
    med:SetPoint("BOTTOMRIGHT", der, "BOTTOMLEFT")
    med:SetTexture(A .. nombre); med:SetTexCoord(cu, u - cu, 0, v)

    return { izq, med, der }
end

local function Tenir(lista, r, g, b, a)
    for _, x in ipairs(lista) do x:SetVertexColor(r, g, b); if a then x:SetAlpha(a) end end
end

--  Los botones que son un simbolo y no llevan texto.
--  Las flechas son las redondas de la propuesta «Carrusel» (lo pidio el dueño).
local SIMBOLO = { ["<"] = "FlechaIzqG", [">"] = "FlechaDerG", ["X"] = "GCerrar" }

-- ---------------------------------------------------------------------------
--  Boton
-- ---------------------------------------------------------------------------
function PLARM.Boton(padre, texto, ancho, alto, principal)
    local b = CreateFrame("Button", nil, padre)
    b:SetSize(ancho or 100, alto or 22)

    local simbolo = SIMBOLO[texto]
    if simbolo then
        --  Cuadrado: el lado es el alto, para que la flecha no se deforme.
        b:SetWidth(b:GetHeight())
        b.piezas = { PLARM.Pieza(b, simbolo, "BACKGROUND") }
        local enc = PLARM.Pieza(b, simbolo, "HIGHLIGHT")
        enc:SetBlendMode("ADD"); enc:SetAlpha(0.35)
    else
        local tex = principal and "BotonOro" or "BotonOscuro"
        b.piezas = PLARM.Tres(b, tex, "BACKGROUND")
        local enc = PLARM.Tres(b, tex, "HIGHLIGHT")
        for _, x in ipairs(enc) do x:SetBlendMode("ADD"); x:SetAlpha(0.3) end
    end
    b.pulsadas = {}

    local colTexto = principal and { 1, 0.95, 0.84 } or { 0.95, 0.84, 0.62 }
    local et = PLARM.Texto(b, 12, colTexto)
    et:SetPoint("CENTER", 0, 1)
    et:SetShadowOffset(1, -1); et:SetShadowColor(0, 0, 0, 1)
    et:SetText(simbolo and "" or texto)
    b.etiqueta = et

    b:SetScript("OnMouseDown", function(self)
        if self.apagado then return end
        Tenir(self.piezas, 0.78, 0.78, 0.78)
        et:SetPoint("CENTER", 1, 0)
    end)
    b:SetScript("OnMouseUp", function(self)
        if self.apagado then return end
        Tenir(self.piezas, 1, 1, 1)
        et:SetPoint("CENTER", 0, 1)
    end)

    function b:Apagar(si, motivo)
        self.apagado = si
        Tenir(self.piezas, si and 0.45 or 1, si and 0.45 or 1, si and 0.45 or 1)
        et:SetTextColor(unpack(si and PLARM.color.textoTenue or colTexto))
        self.motivo = motivo
    end

    return b
end

-- ---------------------------------------------------------------------------
--  Pestana: dos juegos de trozos (encendida y apagada) y se enseña uno.
-- ---------------------------------------------------------------------------
function PLARM.Pestana(padre, texto, ancho, alto)
    local b = CreateFrame("Button", nil, padre)
    b:SetSize(ancho or 100, alto or 22)

    b.on  = PLARM.Tres(b, "PestanaOn",  "BACKGROUND")
    b.off = PLARM.Tres(b, "PestanaOff", "BACKGROUND")
    b.piezas = b.off
    local enc = PLARM.Tres(b, "PestanaOff", "HIGHLIGHT")
    for _, x in ipairs(enc) do x:SetBlendMode("ADD"); x:SetAlpha(0.25) end

    b.etiqueta = PLARM.Texto(b, 12, PLARM.color.textoSuave)
    b.etiqueta:SetPoint("CENTER", 8, 1)
    b.etiqueta:SetShadowOffset(1, -1); b.etiqueta:SetShadowColor(0, 0, 0, 1)
    b.etiqueta:SetText(texto or "")

    --- El icono va a la izquierda del texto, y el conjunto queda centrado.
    function b:PonerIcono(nombre)
        local i = INFO[nombre]
        local t = self:CreateTexture(nil, "ARTWORK")
        local h = 15
        t:SetSize(h * i[1] / i[2], h)
        t:SetTexture(A .. nombre)
        t:SetTexCoord(0, i[1] / i[3], 0, i[2] / i[4])
        t:SetPoint("RIGHT", self.etiqueta, "LEFT", -6, 0)
        self.icono = t
        self:Marcar(self.elegida)
    end

    function b:Marcar(si)
        self.elegida = si
        for _, x in ipairs(self.on)  do if si then x:Show() else x:Hide() end end
        for _, x in ipairs(self.off) do if si then x:Hide() else x:Show() end end
        self.etiqueta:SetTextColor(unpack(si and { 1, 0.9, 0.65 } or PLARM.color.textoSuave))
        if self.icono then self.icono:SetVertexColor(si and 1 or 0.7, si and 1 or 0.7, si and 1 or 0.7) end
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
--  Borde de ARTE que se usa como el borde de lineas viejo
-- ---------------------------------------------------------------------------
--  Ficha.lua y Coleccion.lua marcan el estado pintando `f.borde[1..4]` con
--  `SetVertexColor`. En vez de tocar cada sitio, se les da cuatro «lineas»
--  falsas: si el color es el neutro se ve la pieza apagada; si es otro, la
--  encendida teñida de ese color (dorado = puesto/encima, morado = elegido).
function PLARM.BordeArte(marco, apagada, encendida)
    local off = PLARM.Pieza(marco, apagada, "BACKGROUND")
    local on  = PLARM.Pieza(marco, encendida, "BORDER")
    on:Hide()
    local neutro = PLARM.color.borde
    local falso = {
        SetVertexColor = function(_, r, g, b)
            if math.abs(r - neutro[1]) < 0.01 and math.abs(g - neutro[2]) < 0.01
               and math.abs(b - neutro[3]) < 0.01 then
                on:Hide()
            else
                --  🎨 Siempre el dorado natural de la pieza: teñirla de morado
                --     (lo «elegido» del codigo viejo) sobre un arte dorado
                --     casi no se veia -- medido en el juego, 25-09-2026.
                on:SetVertexColor(1, 1, 1)
                on:Show()
            end
        end,
        Hide = function() end, Show = function() end, SetAlpha = function() end,
    }
    return { falso, falso, falso, falso }, off, on
end


-- ============================================================================
--  GALERIA IGUAL QUE LA MAQUETA (25-09-2026, segunda vuelta)
-- ============================================================================
--  El dueño: «tiene que quedar exactamente igual que la ultima», con las
--  secciones en la BARRA DE LA IZQUIERDA. Las medidas salen de la maqueta
--  (1280x720) pasadas a la ventana (1062x600) con PLARM.MX / PLARM.MY.
-- ============================================================================
PLARM.MX = function(v) return math.floor(v * 1062 / 1280 + 0.5) end
PLARM.MY = function(v) return math.floor(v * 600 / 720 + 0.5) end

local G = {
    GTarjeta     = { 256, 442, 256, 512 },
    GTarjetaOn   = { 256, 442, 256, 512 },
    GChip        = { 64, 30, 64, 32 },
    GCaja        = { 512, 78, 512, 128 },
    GBarra       = { 512, 12, 512, 16 },
    GBarraLlena  = { 512, 12, 512, 16 },
    GActiva      = { 256, 128, 256, 128 },
    GFundido     = { 64, 128, 64, 128 },
    GPieTarjeta  = { 64, 128, 64, 128 },
    GBotonOro    = { 512, 114, 512, 128 },
    GBotonOscuro = { 512, 82, 512, 128 },
    GCerrar      = { 19, 19, 32, 32 },
}
for k, v in pairs(G) do INFO[k] = v end

--  🪤 ICONOS AL TAMAÑO EXACTO EN PANTALLA (iconos_exactos.py): una TGA no
--     lleva mipmaps y, reducida en el juego, sale pixelada (el dueño). Cada
--     icono se guarda a los pixeles con los que se pinta: { lado, lienzo }.
PLARM.ICONOS_PX = {
    GMoneda        = { 29, 32 },
    GIcoConjuntos  = { 39, 64 },
    GIcoPiezas     = { 39, 64 },
    GIcoGuardados  = { 39, 64 },
    GIcoTienda     = { 39, 64 },
    GIcoPase       = { 35, 64 },
    GLupa          = { 20, 32 },
    GEmbudo        = { 20, 32 },
    GOrden         = { 20, 32 },
    GCerrar        = { 19, 32 },
    GMarcador      = { 22, 32 },
    GSolito        = { 26, 32 },
    GCandadoT      = { 17, 32 },
    GEngranaje     = { 21, 32 },
    GAyuda         = { 21, 32 },
    FlechaIzqG     = { 28, 32 },
    FlechaDerG     = { 28, 32 },
}

--  🎨 UN SOLO COLOR para todos los iconos (salen en blanco de
--     iconos_exactos.py y se tiñen aqui): dorado el activo, el resto crema.
PLARM.TINTE_ACTIVO = { 0.96, 0.76, 0.34 }
PLARM.TINTE_ICONO  = { 0.84, 0.80, 0.72 }

--- Una textura de icono cuadrado de arte2.
function PLARM.Icono(padre, nombre, lado, capa)
    local t = padre:CreateTexture(nil, capa or "ARTWORK")
    t:SetTexture(A .. nombre)
    local px = PLARM.ICONOS_PX[nombre]
    if px then
        t:SetTexCoord(0, px[1] / px[2], 0, px[1] / px[2])
        --  el tamaño en unidades que da justo esos pixeles
        lado = px[1] / (1760 / 1517)
    end
    t:SetSize(lado, lado)
    return t
end

--- Convierte un boton ya hecho en una CAJA como las de la maqueta (buscador,
--- Filtro, Ordenar): fondo oscuro con borde fino, icono a la izquierda,
--- texto en mayusculas pequeño y, si se pide, la flechita de desplegable.
function PLARM.EstiloCaja(b, icono, flechita)
    for _, x in ipairs(b.piezas or {}) do x:Hide() end
    for _, r in ipairs({ b:GetRegions() }) do
        if r.GetDrawLayer and r:GetDrawLayer() == "HIGHLIGHT" then r:Hide() end
    end
    b.piezas = PLARM.Tres(b, "GCaja", "BACKGROUND", 0.04)
    local enc = PLARM.Tres(b, "GCaja", "HIGHLIGHT", 0.04)
    for _, x in ipairs(enc) do x:SetBlendMode("ADD"); x:SetAlpha(0.18) end
    if b.etiqueta then
        b.etiqueta:SetFont("Fonts" .. string.char(92) .. "FRIZQT__.TTF", 9, "")
        b.etiqueta:SetTextColor(0.86, 0.84, 0.78)
        b.etiqueta:SetText(string.upper(b.etiqueta:GetText() or ""))
        b.etiqueta:ClearAllPoints()
        b.etiqueta:SetPoint("CENTER", icono and 4 or 0, 0)
    end
    if icono then
        local i = PLARM.Icono(b, icono, 15)
        i:SetPoint("RIGHT", b.etiqueta, "LEFT", -7, 0)
        i:SetVertexColor(unpack(PLARM.TINTE_ICONO))
    end
    if flechita then
        local f = b:CreateTexture(nil, "ARTWORK")
        f:SetTexture(A .. "GFlechita"); f:SetTexCoord(0, 1, 0, 10 / 16)
        f:SetSize(8, 5)
        f:SetPoint("LEFT", b.etiqueta, "RIGHT", 8, 0)
    end
end

--- Boton grande de la maqueta: oro (Aplicar) u oscuro, texto en mayusculas
--- espaciado e icono a la izquierda.
function PLARM.BotonG(padre, texto, ancho, alto, oro, icono)
    local b = CreateFrame("Button", nil, padre)
    b:SetSize(ancho, alto)
    local tex = oro and "GBotonOro" or "GBotonOscuro"
    b.piezas = PLARM.Tres(b, tex, "BACKGROUND", oro and 0.12 or 0.04)
    local enc = PLARM.Tres(b, tex, "HIGHLIGHT", oro and 0.12 or 0.04)
    for _, x in ipairs(enc) do x:SetBlendMode("ADD"); x:SetAlpha(0.22) end
    b.pulsadas = {}
    local col = oro and { 1, 0.97, 0.9 } or { 0.84, 0.8, 0.72 }
    local et = PLARM.Texto(b, oro and 13 or 10, col)
    et:SetShadowOffset(1, -1); et:SetShadowColor(0, 0, 0, 0.9)
    et:SetText(string.upper(texto))
    et:SetPoint("CENTER", icono and 8 or 0, 0)
    b.etiqueta = et
    if icono then
        --  🎨 El sol de «Aplicar» es dorado claro y grande, sin teñir (el dueño).
        local i = PLARM.Icono(b, icono, oro and 22 or 19)
        i:SetPoint("RIGHT", et, "LEFT", -10, 0)
        b.icono = i
    end
    b:SetScript("OnMouseDown", function(s) if not s.apagado then Tenir(s.piezas, 0.8, 0.8, 0.8) end end)
    b:SetScript("OnMouseUp", function(s) if not s.apagado then Tenir(s.piezas, 1, 1, 1) end end)
    function b:Apagar(si, motivo)
        self.apagado = si
        Tenir(self.piezas, si and 0.45 or 1, si and 0.45 or 1, si and 0.45 or 1)
        et:SetTextColor(unpack(si and PLARM.color.textoTenue or col))
        self.motivo = motivo
    end
    return b
end

--- Una seccion de la barra lateral: icono grande arriba, nombre debajo.
--- Tiene la misma interfaz que PLARM.Pestana (Marcar, PonerIcono, etiqueta).
function PLARM.SeccionLateral(padre, texto, ancho, alto)
    local b = CreateFrame("Button", nil, padre)
    b:SetSize(ancho, alto)
    b.activa = b:CreateTexture(nil, "BACKGROUND")
    --  🎨 Recortada de la maqueta (activa_galeria.py): barra dorada con muesca,
    --     brillo y lineas finas arriba y abajo.
    b.activa:SetTexture(A .. "GActivaM")
    b.activa:SetTexCoord(0, 1, 0, 224 / 256)
    b.activa:SetPoint("TOPLEFT", -6, 2); b.activa:SetPoint("BOTTOMRIGHT", 0, -2)
    b.barra = b:CreateTexture(nil, "BORDER")
    b.barra:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.barra:SetVertexColor(0.95, 0.72, 0.28)
    b.barra:SetPoint("TOPLEFT", -4, -4); b.barra:SetPoint("BOTTOMLEFT", -4, 4)
    b.barra:SetWidth(3)
    local enc = b:CreateTexture(nil, "HIGHLIGHT")
    enc:SetTexture(A .. "GActiva"); enc:SetAllPoints(b); enc:SetAlpha(0.4)

    b.etiqueta = PLARM.Texto(b, 9, PLARM.color.textoSuave)
    b.etiqueta:SetPoint("BOTTOM", 0, math.floor(alto * 0.2))
    --  🪤 Sin espaciado entre letras: el espacio fino (U+200A) NO esta en la
    --     fuente del juego y sale como «?» (medido en el juego).
    b.etiqueta:SetText(string.upper(texto or ""))
    b.piezas = {}
    b.lineas = {}
    for _, lado in ipairs({ "TOP", "BOTTOM" }) do
        local l = b:CreateTexture(nil, "BORDER")
        l:SetTexture("Interface\\Buttons\\WHITE8X8")
        l:SetGradientAlpha("HORIZONTAL", 0.8, 0.62, 0.3, 0.7, 0.8, 0.62, 0.3, 0)
        l:SetHeight(1)
        l:SetPoint(lado .. "LEFT", -4, 0); l:SetPoint(lado .. "RIGHT", 0, 0)
        b.lineas[#b.lineas + 1] = l
    end

    function b:PonerIcono(nombre)
        local t = PLARM.Icono(self, nombre, math.floor(alto * 0.44))
        t:SetPoint("BOTTOM", self.etiqueta, "TOP", 0, 6)
        self.icono = t
        self:Marcar(self.elegida)
    end
    function b:Marcar(si)
        self.elegida = si
        if si then self.activa:Show() else self.activa:Hide() end
        self.barra:Hide()
        for _, l in ipairs(self.lineas) do l:Hide() end
        self.etiqueta:SetTextColor(unpack(si and { 0.95, 0.74, 0.32 } or { 0.72, 0.70, 0.66 }))
        if self.icono then
            self.icono:SetVertexColor(unpack(si and PLARM.TINTE_ACTIVO or PLARM.TINTE_ICONO))
        end
    end
    b:Marcar(false)
    return b
end


--- «LEGENDARIO» en su color, como en la maqueta.
local NOMBRES_RAREZA = { [1] = "COM\195\154N", [2] = "RARO", [3] = "\195\137PICO", [4] = "LEGENDARIO" }
function PLARM.RarezaTexto(r)
    local x = PLARM.RAREZAS[r or 1] or PLARM.RAREZAS[1]
    local cr, cg, cb = unpack(x.color)
    return string.format("|cff%02x%02x%02x%s|r", cr * 255, cg * 255, cb * 255, NOMBRES_RAREZA[r or 1] or "")
end
