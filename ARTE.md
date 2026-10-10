# Arte del armario — guía para el diseñador

> Qué imágenes hacen falta, con qué medidas, en qué formato, y **cómo verlas
> en el juego** sin depender de nadie.
>
> Escrita el 30-08-2026 a petición del dueño, que es diseñador:
> *«solo quiero usar sus archivos para ver cómo quedaría el trabajo final y con
> esa base poner mis propios artes. Necesito saber qué necesito y cómo verlo».*

---

## 1. La referencia: el arte de Ascension, ya extraído

| Carpeta | Qué hay |
|---|---|
| `D:\ascension-referencia-png\` | **1.166 imágenes en PNG**, listas para abrir |
| `D:\ascension-referencia\` | las mismas en `.blp` (el formato del juego) |

Lo interesante está en
`Interface\AddOns\AwAddons\Textures\` — sus marcos, bordes, pestañas, flechas e
ilustraciones. Las medidas que más usan:

| Medida | Cuántas | Para qué suelen usarla |
|---|---|---|
| **256×256** | 624 | ilustraciones y fondos de tarjeta |
| 64×64 | 96 | iconos y adornos pequeños |
| 512×512 | 68 | fondos grandes |
| 1024×512 | 66 | cabeceras y marcos anchos |
| 32×32 | 39 | flechas, marcas, checks |

⚠️ **Su arte es obra suya: vale como referencia para decidir el estilo, no para
publicarlo.** Lo que se reparta a los jugadores tiene que ser propio.

---

## 2. 🔑 LO QUE HAY QUE DISEÑAR: **UNA SOLA IMAGEN**

Esto se descubrió leyendo su addon, no suponiéndolo
(`Ascension_VanityCollection/VanityStore.lua:818`). Su ventana entera es:

```lua
Store:SetSize(784, 512)
Store:SetBackdrop({
    bgFile = "...Collections\StoreCollection",
    insets = { left = -120, right = -120, top = -256, bottom = -256 },
})
```

**Una imagen de 1024×1024 con TODA la ventana pintada** —marco ornamentado,
medallón de la esquina, panel de pergamino, panel oscuro, barra de abajo— y los
botones colocados encima en coordenadas fijas.

| | |
|---|---|
| Archivo | `arte/marco-completo` |
| Medida | **1024 × 1024** |
| La ventana | **784 × 512 centrada** dentro de esa imagen |
| Lo que sobra alrededor | adornos que salen del marco: el medallón, esquinas |

### 🪤 Y POR QUÉ ESTO IMPORTA TANTO

Antes de encontrarlo se intentó al revés: quince piezas sueltas, cada una
estirada sobre su zona. **Salió mal tres veces seguidas**, y no por elegir mal
las imágenes: un marco ornamentado estirado se convierte en una franja
deformada. El dueño lo resumió solo:

> *«¿Ves que si yo generaba las imágenes sin ver el resultado final, todo iba a
> salir mal?»*

Exacto. **Con el método correcto, una sola imagen da casi toda la ventana.**

### Los huecos, para pintar dentro de ellos

Coordenadas dentro de la imagen de 1024×1024 (la ventana empieza en 120,256):

| Zona | En la imagen | Qué va encima |
|---|---|---|
| Barra de título | y 260–305 | el título y el buscador |
| Cintillo izquierdo | x 137–415 · y 318–368 | nombre de la pieza |
| Pergamino grande | x 137–415 · y 393–705 | el muñeco 3D |
| Panel derecho | x 425–890 · y 318–712 | pestañas y rejilla |
| Barra inferior | y 735–760 | pestañas y el botón de aplicar |

### Las piezas pequeñas, aparte

Estas van sueltas porque se repiten muchas veces. **Todas tienen ya su hueco:
sustituir el archivo cambia esa pieza en toda la ventana, sin tocar código.**

| Archivo | Medida | Dónde se ve |
|---|---|---|
| `boton` | 128×32 | Quitar todo, Guardar conjunto |
| `boton-encima` | 128×32 | los mismos, con el ratón encima |
| `boton-principal` | 128×32 | **Aplicar al personaje** (el botón de acción) |
| `pestana` | 128×32 | Cabeza, Hombros, Espalda… y las tres de abajo |
| `pestana-activa` | 128×32 | la categoría elegida |
| `celda-fondo` | 64×64 | el hueco de cada apariencia en la rejilla |
| `celda-encima` | 64×64 | resalte al pasar el ratón por una |
| `titulo-adorno` | 256×16 | la línea ornamentada bajo cada título |
| `moneda-1` | 32×32 | contador de apariencias |
| `moneda-2` | 32×32 | contador de conjuntos completos |

🔑 **Y el borde por rareza no se diseña**: sale del color del propio objeto
(verde, azul, morado…), así que no hay nada que mantener ahí.

## 3. Formato: lo que hay que respetar

| | |
|---|---|
| **Medidas** | **potencia de dos**: 32, 64, 128, 256, 512, 1024. No tienen que ser iguales entre sí — 256×64 vale |
| **Formato para trabajar** | **TGA de 32 bits** con transparencia. Se exporta directo desde Photoshop |
| **Formato para repartir** | **BLP**, que ocupa 3-4 veces menos (una imagen de 256×64: TGA 65 KB, BLP 23 KB) |
| Transparencia | obligatoria en marcos, bordes e iconos: es lo que les da la forma |

### Convertir a BLP, cuando toque

```bash
py modelos/png_a_blp_interfaz.py mi-imagen.png
```

Genera el `.blp` con la cadena de mipmaps. **Los mipmaps no son opcionales**:
sin ellos la imagen parpadea.

---

## 4. 🔑 CÓMO VERLO EN EL JUEGO

Es lo más importante de esta guía, porque sin esto se trabaja a ciegas.

1. Deja el archivo en `Interface\AddOns\Project JainaArmario\`
   (del cliente de pruebas: `D:\Project JainaLand (Staging - Pruebas)`)
2. **Cierra el juego y ábrelo** ← ver el aviso de abajo
3. Dentro, escribe:

```
/artetest nombre-del-archivo
```

Sale la imagen en pantalla, con su transparencia, tal cual la verá un jugador.
Se puede arrastrar y se cierra con un clic.

### 🪤 LA TRAMPA QUE COSTÓ LA TARDE: `/reload` NO BASTA

**El cliente solo mira qué archivos tiene un addon AL ARRANCAR.** Si añades una
imagen con el juego abierto, para él **no existe** — ni con `/reload`.

Y no da ningún error: `SetTexture` se queda como estaba, así que parece que el
archivo está mal hecho.

Persiguiendo esto se llegó a dos conclusiones falsas seguidas:

1. *«el cliente no carga TGA»* — sí lo carga
2. *«nuestro conversor a BLP está roto»* — no lo estaba; **hasta un BLP
   auténtico de Ascension fallaba igual**

Fue justo esa prueba —sustituir el archivo propio por uno de verdad y ver que
fallaba también— la que descartó el formato y dejó la causa a la vista.

> 🎯 **Si una imagen nueva "no carga", lo primero es reiniciar el cliente.**
> Editar una que ya existía sí se ve con `/reload`; **añadir una nueva, no.**

---

## 5. La paleta que usa la ventana hoy

Por si quieres partir de ella o cambiarla (`Estilo.lua`):

| | |
|---|---|
| fondo | `#0A0B0E` |
| panel | `#14161C` |
| panel destacado | `#1B1E26` |
| borde | `#2C2F38` |
| oro (títulos) | `#E8B54D` |
| granate (acción) | `#C83842` |
| verde (completo) | `#4CAF50` |
| texto | `#F0F1F4` |

---

## Documentos relacionados
 
- [README](README.md) — el armario y las apariencias (arquitectura y uso)
- [API](API.md) — especificación técnica y protocolos de red

## La ficha de la colección — las 7 ranuras

**Está montada con la geometría exacta de Ascension**, así que cada archivo que
dejes aquí cae en su sitio sin tocar una línea de código.

Su arte lleva **el marco y la chapa del nombre dentro de la imagen de fondo**.
Por eso el código no dibuja ningún borde propio: si lo hiciera, se vería doble
en cuanto pusieras el tuyo.

| Archivo | Tamaño | Centro | Qué es |
|---|---|---|---|
| `celda-fondo` | **256×128** | `(0, 0)` | **la tarjeta entera**: marco, fondo y la chapa del nombre |
| `celda-escudo` | 92×92 | `(0, +10)` | **el blasón dorado** — es lo que hace que la ficha se reconozca a un metro |
| `celda-brillo` | 128×64 | `(0, +10)` | el resplandor de detrás del icono |
| `celda-aro` | 64×64 | `(0, +10)` | el aro que rodea al icono |
| `celda-grupo` | 40×40 | `(0, −10)` | el emblema de categoría (armadura, montura, mascota…) |
| `celda-encima` | 256×128 | `(0, 0)` | ratón por encima — **se suma**, así que va oscura con los brillos claros |
| `celda-elegida` | 256×128 | `(0, 0)` | la pieza que está puesta |

Y lo que el código pone encima, en posiciones fijas que **no** debes tapar:

| | Tamaño | Centro |
|---|---|---|
| el icono del objeto, recortado en círculo | 40×40 | `(0, +11)` |
| el nombre (`GameFontHighlight`, sombra 1 px) | 120×22 | `(0, −30)` |

## La cabecera izquierda — 1 ranura más

| Archivo | Tamaño | Dónde | Qué es |
|---|---|---|---|
| `cabecera-brillo` | 140×140 | `LEFT(-39, 0)` | **gira 360° cada 20 s** en modo `ADD`. Va oscura con los brillos claros, porque se suma |

El resplandor 3D que la acompaña no es una imagen: es un modelo que ya trae el
cliente (`quirajglow.m2`), así que no hay nada que diseñar ahí.

### 🪤 Los márgenes de `celda-fondo` van transparentes

La imagen mide 256×128 pero **las fichas se colocan cada 150×106**. La tarjeta
dibujada tiene que caber en unos **140×100 centrados**; lo que sobresalga se
solapa con la ficha de al lado. Ascension lo usa a propósito para meter brillos
que se salen del marco.

### 🔴 Formato: TGA de 32 bits, de ABAJO ARRIBA

```bash
py modelos/png_a_tga.py mi-imagen.png "D:/Project JainaLand (Staging - Pruebas)/Interface/AddOns/Project JainaArmario/arte/celda-fondo.tga"
```

Los lados tienen que ser **potencia de dos** (32, 64, 128, 256, 1024…).

Y dos cosas que costaron una tarde entera:

* **La orientación va de abajo arriba.** El formato permite marcarla al revés
  con un bit; el cargador de WoW **no lo respeta** y entonces la textura
  simplemente no carga — sin error, sin aviso, igual que si no existiera.
  `png_a_tga.py` ya lo hace bien.
* **Los `.blp`/`.tga` nuevos no los ve un `/reload`**: hay que cerrar y volver a
  abrir el juego.

### Sin arte, qué se ve

La tarjeta sale **roja**, a propósito. Un respaldo que se parece al arte bueno
no deja saber si el archivo está cargando; uno que canta responde solo.

