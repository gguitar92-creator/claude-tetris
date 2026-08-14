#!/usr/bin/env bash
# Consulta el clima actual y el pronóstico desde Open-Meteo.
# API pública, sin clave y sin caché: cada ejecución trae el dato más reciente.
# Dependencias: curl y jq (ambos vienen con macOS).

set -euo pipefail

# --- Ciudad por defecto: Palpalá, Jujuy, Argentina ----------------------------
# Es la ciudad del usuario. Se usa siempre que no se pase otra ciudad, y también
# cuando se nombra a Palpalá explícitamente (así no dependemos del geocodificador,
# que devuelve coordenadas algo distintas y el nombre sin acento).
NOMBRE_DEF="Palpalá, Jujuy (AR)"
LAT_DEF="-24.2558"
LON_DEF="-65.2103"
TZ_DEF="America/Argentina/Jujuy"

GEO_API="https://geocoding-api.open-meteo.com/v1/search"
CLIMA_API="https://api.open-meteo.com/v1/forecast"

dias=0
crudo=0
ciudad=""

uso() {
  cat <<'EOF'
Uso: clima.sh [ciudad] [-d N] [--json]

  ciudad    Nombre de la ciudad a consultar. Si se omite, usa Palpalá, Jujuy.
  -d, --dias N   Agrega el pronóstico de los próximos N días (1-7).
      --json     Imprime el JSON crudo en vez del reporte formateado.
  -h, --help     Muestra esta ayuda.

Ejemplos:
  clima.sh                      # clima actual en Palpalá
  clima.sh -d 3                 # Palpalá + pronóstico a 3 días
  clima.sh "San Salvador de Jujuy"
  clima.sh Córdoba --json
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dias)  dias="${2:-0}"; shift 2 ;;
    --json)     crudo=1; shift ;;
    -h|--help)  uso; exit 0 ;;
    -*)         echo "Opción desconocida: $1" >&2; uso >&2; exit 2 ;;
    *)          ciudad="${ciudad:+$ciudad }$1"; shift ;;
  esac
done

for bin in curl jq; do
  command -v "$bin" >/dev/null 2>&1 || { echo "Falta '$bin' en el sistema." >&2; exit 1; }
done

[[ "$dias" =~ ^[0-7]$ ]] || { echo "--dias debe ser un número entre 0 y 7." >&2; exit 2; }

# --- Resolver coordenadas -----------------------------------------------------
# Cualquier forma de nombrar a Palpalá (con o sin acento, con o sin provincia/país)
# se resuelve con las constantes de arriba, no por geocodificación.
if printf '%s' "$ciudad" | grep -qiE '^palpal(a|á)([[:space:],].*)?$'; then
  ciudad=""
fi

if [[ -n "$ciudad" ]]; then
  geo=$(curl -fsS -G "$GEO_API" \
          --data-urlencode "name=$ciudad" \
          --data-urlencode "count=1" \
          --data-urlencode "language=es" \
          --data-urlencode "format=json") \
    || { echo "No se pudo contactar la API de geocodificación." >&2; exit 1; }

  if [[ "$(jq -r '.results // [] | length' <<<"$geo")" == "0" ]]; then
    echo "No se encontró la ciudad: $ciudad" >&2
    exit 1
  fi

  lat=$(jq -r '.results[0].latitude'  <<<"$geo")
  lon=$(jq -r '.results[0].longitude' <<<"$geo")
  tz=$(jq  -r '.results[0].timezone'  <<<"$geo")
  nombre=$(jq -r '[.results[0].name,
                   (.results[0].admin1 // empty),
                   (.results[0].country_code // empty)]
                  | map(select(. != "" and . != null))
                  | "\(.[0])\(if length > 1 then ", " + .[1] else "" end)\(if length > 2 then " (" + .[2] + ")" else "" end)"' \
                 <<<"$geo")
else
  lat="$LAT_DEF"; lon="$LON_DEF"; tz="$TZ_DEF"; nombre="$NOMBRE_DEF"
fi

# --- Consultar el clima -------------------------------------------------------
args=(-fsS -G "$CLIMA_API"
      --data-urlencode "latitude=$lat"
      --data-urlencode "longitude=$lon"
      --data-urlencode "timezone=$tz"
      --data-urlencode "current=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,wind_direction_10m,is_day")

if [[ "$dias" -gt 0 ]]; then
  args+=(--data-urlencode "daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
         --data-urlencode "forecast_days=$dias")
else
  args+=(--data-urlencode "daily=temperature_2m_max,temperature_2m_min,sunrise,sunset"
         --data-urlencode "forecast_days=1")
fi

datos=$(curl "${args[@]}") \
  || { echo "No se pudo contactar la API del clima." >&2; exit 1; }

if [[ "$crudo" -eq 1 ]]; then
  jq --arg lugar "$nombre" '. + {lugar: $lugar}' <<<"$datos"
  exit 0
fi

# --- Formatear el reporte -----------------------------------------------------
jq -r --arg lugar "$nombre" --argjson dias "$dias" '
  def condicion($c):
    {"0":"Despejado","1":"Mayormente despejado","2":"Parcialmente nublado","3":"Nublado",
     "45":"Niebla","48":"Niebla con escarcha",
     "51":"Llovizna ligera","53":"Llovizna moderada","55":"Llovizna densa",
     "56":"Llovizna helada ligera","57":"Llovizna helada densa",
     "61":"Lluvia ligera","63":"Lluvia moderada","65":"Lluvia fuerte",
     "66":"Lluvia helada ligera","67":"Lluvia helada fuerte",
     "71":"Nevada ligera","73":"Nevada moderada","75":"Nevada fuerte","77":"Granos de nieve",
     "80":"Chubascos ligeros","81":"Chubascos moderados","82":"Chubascos violentos",
     "85":"Chubascos de nieve ligeros","86":"Chubascos de nieve fuertes",
     "95":"Tormenta eléctrica","96":"Tormenta con granizo ligero","99":"Tormenta con granizo fuerte"}
    [$c|tostring] // "Condición desconocida (\($c))";

  def icono($c; $dia):
    if   $c == 0            then (if $dia == 1 then "☀️" else "🌙" end)
    elif $c <= 2            then "🌤️"
    elif $c == 3            then "☁️"
    elif $c <= 48           then "🌫️"
    elif $c <= 67           then "🌧️"
    elif $c <= 77           then "❄️"
    elif $c <= 86           then "🌦️"
    else                         "⛈️" end;

  def rumbo($d):
    ["N","NNE","NE","ENE","E","ESE","SE","SSE",
     "S","SSO","SO","OSO","O","ONO","NO","NNO"][((($d + 11.25) / 22.5) | floor) % 16];

  def hhmm: split("T")[1];

  .current as $a | .current_units as $u | .daily as $d |
  "\($lugar) — \($a.time | sub("T"; " "))  (hora local)",
  "  \(icono($a.weather_code; $a.is_day))  \(condicion($a.weather_code))",
  "  🌡  \($a.temperature_2m) \($u.temperature_2m)   (sensación \($a.apparent_temperature) \($u.apparent_temperature))",
  "  💧 Humedad \($a.relative_humidity_2m)\($u.relative_humidity_2m)   ·   🌬  Viento \($a.wind_speed_10m) \($u.wind_speed_10m) \(rumbo($a.wind_direction_10m))   ·   ☔ Precipitación \($a.precipitation) \($u.precipitation)",
  "  ⬆️  Máx \($d.temperature_2m_max[0]) °C   ·   ⬇️  Mín \($d.temperature_2m_min[0]) °C   ·   🌅 \($d.sunrise[0] | hhmm)   🌇 \($d.sunset[0] | hhmm)",
  (if $dias > 0 then
     "", "  Pronóstico:",
     ( [range(0; ($d.time | length))]
       | map("    \($d.time[.])  \(icono($d.weather_code[.]; 1))  \($d.temperature_2m_min[.]) / \($d.temperature_2m_max[.]) °C   lluvia \($d.precipitation_probability_max[.] // 0)%   \(condicion($d.weather_code[.]))")
       | .[] )
   else empty end)
' <<<"$datos"
