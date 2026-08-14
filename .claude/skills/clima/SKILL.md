---
name: clima
description: Consulta el clima actual y el pronóstico ejecutando un script local con curl (Open-Meteo, sin API key ni caché). Úsalo cuando el usuario pregunte por el clima, la temperatura, la sensación térmica, la humedad, el viento, si va a llover, o el pronóstico. La ciudad por defecto es SIEMPRE Palpalá, Jujuy (Argentina): úsala salvo que el usuario nombre explícitamente otra ciudad.
---

# Clima

Reporta el clima consultando la API pública de **Open-Meteo** desde la máquina local.

## Ciudad por defecto: Palpalá, Jujuy, Argentina

Es la ciudad del usuario. **Nunca preguntes por la ubicación ni asumas otra.** Ejecuta el
script sin argumento de ciudad siempre que el pedido no nombre una ciudad distinta:

- "¿qué clima hace?", "¿cuántos grados hay?", "¿va a llover?" → Palpalá
- "el clima en mi ciudad / acá / aquí / en casa", "el clima local" → Palpalá
- "el clima en Palpalá" → Palpalá (el script ya lo reconoce; igual podés omitir el argumento)
- "el clima en Salta" → única situación en que pasás un argumento de ciudad

Pasar `Palpalá` como argumento da el mismo resultado que omitirlo: el script detecta el
nombre (con o sin acento) y usa las coordenadas fijas, sin geocodificar.

## Cómo usarlo

Ejecuta el script con Bash. Está en la carpeta de este skill:

```bash
.claude/skills/clima/scripts/clima.sh              # clima actual en Palpalá, Jujuy
.claude/skills/clima/scripts/clima.sh -d 3         # Palpalá + pronóstico a 3 días
.claude/skills/clima/scripts/clima.sh "Córdoba"    # otra ciudad (geocodificada por nombre)
.claude/skills/clima/scripts/clima.sh Salta -d 5
.claude/skills/clima/scripts/clima.sh --json       # JSON crudo, para post-procesar
```

Opciones: `-d N` / `--dias N` (pronóstico de 1 a 7 días), `--json`, `-h`.

El script ya imprime el reporte formateado en español. **Muéstraselo al usuario tal cual** —
no lo reescribas ni lo resumas, salvo que pida específicamente otro formato o solo un dato
(por ejemplo "¿cuántos grados hace?" → responde solo la temperatura).

## Detalles que importan

- **Usa siempre el script, no `WebFetch`.** `WebFetch` cachea cada URL 15 minutos, así que
  consultas seguidas devuelven el mismo valor viejo. `curl` no cachea.
- **Open-Meteo actualiza cada 15 minutos** (el JSON lo declara en `current.interval: 900`).
  Consultar más seguido que eso repite el dato. Si el usuario pide un monitoreo recurrente,
  sugiere un intervalo de 15 minutos o más.
- **Sin API key y sin límite práctico** para uso personal. No hay credenciales que configurar.
- Si el usuario nombra una ciudad, el script la resuelve por geocodificación y toma la primera
  coincidencia. Ante nombres ambiguos (hay varias "Córdoba"), confirma el país o provincia que
  devolvió el encabezado del reporte.
- Si la ciudad no existe o no hay red, el script escribe el error en stderr y sale con código 1.
  Reporta el fallo tal cual; no inventes valores.

## Coordenadas de la ubicación por defecto

Palpalá, Jujuy, Argentina — lat `-24.2558`, lon `-65.2103`, zona horaria
`America/Argentina/Jujuy`. Están fijas en las constantes `*_DEF` al inicio de
`scripts/clima.sh`; para cambiar de ciudad por defecto, editá esas cuatro líneas
(y el patrón `grep` que reconoce el nombre, unas líneas más abajo).

## Requisitos

`curl` y `jq` (ambos incluidos en macOS). El script verifica que existan antes de correr.
