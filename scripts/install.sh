#!/bin/sh
# dsh-locale-es — instalador del paquete de idioma español (es-419) para DeepSeek Harness.
#
#   sh install.sh              instala o actualiza en el perfil de escritorio
#   sh install.sh --check      informa el estado sin tocar nada
#   sh install.sh --uninstall  desinstala y deja el perfil como estaba
#
# Opciones:
#   --app <ruta>        ruta de "DeepSeek Harness.app" (se autodetecta)
#   --dsh-home <ruta>   carpeta de datos de DSH (por defecto ~/.dsh)
#   --profile <ruta>    carpeta del perfil (por defecto <dsh-home>/profiles/desktop)
#   --no-preference     no fija el idioma; solo instala (se elige en Ajustes)
#   --yes               no pide confirmación
#   -h, --help          esta ayuda
set -eu

APP=""
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
PROFILE_ARG=""
MODE="install"
WRITE_PREFERENCE=1
ASSUME_YES=0
LOCALE_ID="es-419"
BUNDLE_ID="dsh-locale-es"

say() { printf '%s\n' "$*"; }
step() { printf '\n→ %s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --app) [ $# -ge 2 ] || fail "--app necesita una ruta"; APP="$2"; shift 2 ;;
    --dsh-home) [ $# -ge 2 ] || fail "--dsh-home necesita una ruta"; DSH_HOME="$2"; shift 2 ;;
    --profile) [ $# -ge 2 ] || fail "--profile necesita una ruta"; PROFILE_ARG="$2"; shift 2 ;;
    --check) MODE="check"; shift ;;
    --uninstall) MODE="uninstall"; shift ;;
    --no-preference) WRITE_PREFERENCE=0; shift ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "opción desconocida: $1 (usa --help)" ;;
  esac
done

[ -n "$DSH_HOME" ] || fail "DSH_HOME vacío"
case "$DSH_HOME" in
  /) fail "DSH_HOME no puede ser la raíz del sistema" ;;
esac

SRC=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PROFILE="${PROFILE_ARG:-$DSH_HOME/profiles/desktop}"
DEST="$DSH_HOME/plugins/$BUNDLE_ID"
HOME_PATCH="$DSH_HOME/cordis.patch.yml"

# ── localizar la aplicación ────────────────────────────────────────────────
find_app() {
  if [ -n "$APP" ]; then
    [ -d "$APP" ] && { printf '%s\n' "$APP"; return 0; }
    return 1
  fi
  for candidate in \
    "/Applications/DeepSeek Harness.app" \
    "$HOME/Applications/DeepSeek Harness.app"; do
    if [ -d "$candidate" ]; then printf '%s\n' "$candidate"; return 0; fi
  done
  if command -v mdfind >/dev/null 2>&1; then
    found=$(mdfind "kMDItemCFBundleIdentifier == 'com.deepseek.dsh'" 2>/dev/null | head -n 1 || true)
    if [ -n "$found" ] && [ -d "$found" ]; then printf '%s\n' "$found"; return 0; fi
  fi
  return 1
}

APP=$(find_app) || fail "No se encontró DeepSeek Harness. Indica la ruta con --app \"/Applications/DeepSeek Harness.app\""
NODE="$APP/Contents/MacOS/DeepSeek Harness"
PNPM="$APP/Contents/Resources/runtime/primary-runtime/dependencies/pnpm/bin/pnpm.cjs"
[ -x "$NODE" ] || fail "La aplicación no parece válida: $APP"

# Ejecuta Node con el binario de Electron; argv[2] es el primer argumento útil.
node_eval() {
  ELECTRON_RUN_AS_NODE=1 "$NODE" -e "$1" dsh "$2" "${3:-}"
}

APP_VERSION=$(node_eval 'try{const r=JSON.parse(require("node:fs").readFileSync(process.argv[2],"utf8"));process.stdout.write(String(r.desktopVersion||r.version||"desconocida"))}catch{process.stdout.write("desconocida")}' \
  "$APP/Contents/Resources/runtime/primary-runtime/runtime.json" 2>/dev/null || printf 'desconocida')

# ── sondas de estado ───────────────────────────────────────────────────────
plugin_installed() { [ -f "$DEST/lib/client.js" ]; }
bundle_selected() {
  [ -f "$PROFILE/package.json" ] || return 1
  node_eval '
const fs = require("node:fs");
const pkg = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const bundles = pkg?.dsh?.profile?.bundles;
process.exit(Array.isArray(bundles) && bundles.includes("dsh-locale-es") ? 0 : 1);
' "$PROFILE/package.json" >/dev/null 2>&1
}
dependency_linked() {
  [ -f "$PROFILE/package.json" ] || return 1
  node_eval '
const fs = require("node:fs");
const pkg = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
process.exit(pkg?.dependencies?.["dsh-locale-es"] ? 0 : 1);
' "$PROFILE/package.json" >/dev/null 2>&1
}
preference_set() {
  [ -f "$HOME_PATCH" ] || return 1
  grep -q "preference: *$LOCALE_ID" "$HOME_PATCH" 2>/dev/null
}

print_state() {
  say "DeepSeek Harness   $APP (versión $APP_VERSION)"
  say "Datos de DSH       $DSH_HOME"
  say "Perfil             $PROFILE"
  say ""
  if [ -d "$PROFILE" ]; then printf '  ✔ perfil encontrado\n'; else printf '  ✖ perfil no encontrado (abre la app una vez)\n'; fi
  if plugin_installed; then printf '  ✔ plugin instalado en %s\n' "$DEST"; else printf '  ✖ plugin no instalado\n'; fi
  if dependency_linked; then printf '  ✔ dependencia declarada en el perfil\n'; else printf '  ✖ dependencia ausente\n'; fi
  if bundle_selected; then printf '  ✔ bundle seleccionado en dsh.profile.bundles\n'; else printf '  ✖ bundle no seleccionado\n'; fi
  if preference_set; then printf '  ✔ idioma fijado: %s\n' "$LOCALE_ID"; else printf '  ✖ idioma no fijado (se elige en Ajustes → General → Idioma)\n'; fi
}

# ── --check ────────────────────────────────────────────────────────────────
if [ "$MODE" = "check" ]; then
  print_state
  if [ -d "$PROFILE" ] && plugin_installed && dependency_linked && bundle_selected; then
    say ""
    say "Todo en orden."
    exit 0
  fi
  say ""
  say "Falta algo: ejecuta  sh install.sh  para instalarlo o repararlo."
  exit 1
fi

# ── --uninstall ────────────────────────────────────────────────────────────
if [ "$MODE" = "uninstall" ]; then
  [ -d "$PROFILE" ] || fail "No existe el perfil: $PROFILE"
  if [ "$ASSUME_YES" -eq 0 ]; then
    printf '¿Desinstalar %s de %s? [s/N] ' "$BUNDLE_ID" "$PROFILE"
    answer=""
    read -r answer || true
    case "$answer" in s|S|si|sí|y|Y) ;; *) say "cancelado"; exit 0 ;; esac
  fi

  step "quitando el bundle de dsh.profile.bundles"
  node_eval '
const fs = require("node:fs");
const file = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(file, "utf8"));
if (Array.isArray(pkg?.dsh?.profile?.bundles)) {
  pkg.dsh.profile.bundles = pkg.dsh.profile.bundles.filter((name) => name !== "dsh-locale-es");
  fs.writeFileSync(file, JSON.stringify(pkg, null, 2) + "\n");
}
' "$PROFILE/package.json"

  step "eliminando la dependencia del perfil"
  if [ -f "$PNPM" ]; then
    ( cd "$PROFILE" && ELECTRON_RUN_AS_NODE=1 "$NODE" "$PNPM" remove "$BUNDLE_ID" --ignore-scripts >/dev/null 2>&1 ) || true
  fi
  node_eval '
const fs = require("node:fs");
const file = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(file, "utf8"));
if (pkg?.dependencies?.["dsh-locale-es"]) {
  delete pkg.dependencies["dsh-locale-es"];
  fs.writeFileSync(file, JSON.stringify(pkg, null, 2) + "\n");
}
' "$PROFILE/package.json"

  step "quitando la preferencia de idioma"
  if [ -f "$HOME_PATCH" ]; then
    node_eval '
const fs = require("node:fs");
const file = process.argv[2];
const text = fs.readFileSync(file, "utf8");
const blocks = text.split(/\n(?=- id: )/u);
const kept = blocks.filter((block) => !/^- id: *locale\b/mu.test(block) || !/preference: *es-419/u.test(block));
const next = kept.join("\n");
if (next !== text) fs.writeFileSync(file, next.endsWith("\n") ? next : `${next}\n`);
' "$HOME_PATCH"
  fi

  step "borrando los archivos instalados"
  case "$DEST" in
    "$DSH_HOME"/plugins/"$BUNDLE_ID") rm -rf "$DEST" ;;
    *) fail "ruta inesperada: $DEST" ;;
  esac

  say ""
  say "✔ desinstalado. Recarga la interfaz (⌘R) para volver al inglés."
  exit 0
fi

# ── instalación ────────────────────────────────────────────────────────────
[ -d "$PROFILE" ] || fail "No existe el perfil: $PROFILE
Abre DeepSeek Harness una vez (para que cree su perfil) y vuelve a ejecutar este instalador."
[ -f "$PROFILE/package.json" ] || fail "El perfil no tiene package.json: $PROFILE"

say "DeepSeek Harness $APP_VERSION"
say "Destino: $DEST"

step "copiando el paquete"
case "$DEST" in
  "$DSH_HOME"/plugins/"$BUNDLE_ID") rm -rf "$DEST" ;;
  *) fail "ruta inesperada: $DEST" ;;
esac
mkdir -p "$DEST"
for item in package.json cordis.patch.yml README.md lib scripts translations; do
  [ -e "$SRC/$item" ] || continue
  cp -R "$SRC/$item" "$DEST/"
done
find "$DEST" -name '.DS_Store' -delete 2>/dev/null || true
[ -f "$DEST/lib/client.js" ] || fail "el paquete no incluye lib/client.js"

step "enlazando el paquete como dependencia del perfil"
node_eval '
const fs = require("node:fs");
const file = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(file, "utf8"));
pkg.dependencies ??= {};
pkg.dependencies["dsh-locale-es"] = "link:../../plugins/dsh-locale-es";
fs.writeFileSync(file, JSON.stringify(pkg, null, 2) + "\n");
' "$PROFILE/package.json"

LINKED=0
if [ -f "$PNPM" ]; then
  if ( cd "$PROFILE" && ELECTRON_RUN_AS_NODE=1 "$NODE" "$PNPM" add "link:../../plugins/dsh-locale-es" --ignore-scripts >/dev/null 2>&1 ); then
    LINKED=1
  fi
fi
if [ "$LINKED" -eq 0 ]; then
  say "  (pnpm no disponible; enlazando node_modules a mano)"
  mkdir -p "$PROFILE/node_modules"
  ln -sfn "../../plugins/dsh-locale-es" "$PROFILE/node_modules/dsh-locale-es"
fi

step "seleccionando el bundle en el perfil"
node_eval '
const fs = require("node:fs");
const file = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(file, "utf8"));
pkg.dsh ??= {};
pkg.dsh.profile ??= {};
pkg.dsh.profile.bundles ??= [];
if (!pkg.dsh.profile.bundles.includes("dsh-locale-es")) pkg.dsh.profile.bundles.push("dsh-locale-es");
fs.writeFileSync(file, JSON.stringify(pkg, null, 2) + "\n");
' "$PROFILE/package.json"

if [ "$WRITE_PREFERENCE" -eq 1 ]; then
  step "fijando el idioma activo ($LOCALE_ID)"
  if [ ! -f "$HOME_PATCH" ]; then
    cat > "$HOME_PATCH" <<'YAML'
# Capa de parches del usuario para todos los perfiles de esta instalación.
- id: locale
  name: '@deepseek-ai/dsh-client-locale'
  config:
    preference: es-419
YAML
  elif ! grep -q '^ *- id: *locale *$' "$HOME_PATCH"; then
    printf '\n' >> "$HOME_PATCH"
    cat >> "$HOME_PATCH" <<'YAML'
- id: locale
  name: '@deepseek-ai/dsh-client-locale'
  config:
    preference: es-419
YAML
  elif ! preference_set; then
    say "  Ya hay una entrada «locale» con otro idioma en $HOME_PATCH."
    say "  Se respeta tu elección; cámbiala en Ajustes → General → Idioma."
  fi
fi

# El host guarda en memoria el bundle que sirvió al componer el perfil y solo lo
# relee cuando la fila se desmonta y vuelve a montarse. Si la app está abierta,
# quitar y reponer el bundle fuerza esa relectura sin reiniciarla.
APP_RUNNING=0
if command -v pgrep >/dev/null 2>&1 && pgrep -f "Contents/MacOS/DeepSeek Harness" >/dev/null 2>&1; then
  APP_RUNNING=1
fi

if [ "$APP_RUNNING" -eq 1 ]; then
  step "recargando el plugin en la aplicación abierta"
  node_eval '
const fs = require("node:fs");
const file = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(file, "utf8"));
pkg.dsh.profile.bundles = pkg.dsh.profile.bundles.filter((name) => name !== "dsh-locale-es");
fs.writeFileSync(file, JSON.stringify(pkg, null, 2) + "\n");
' "$PROFILE/package.json"
  sleep 3
  node_eval '
const fs = require("node:fs");
const file = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(file, "utf8"));
pkg.dsh.profile.bundles.push("dsh-locale-es");
fs.writeFileSync(file, JSON.stringify(pkg, null, 2) + "\n");
' "$PROFILE/package.json"
  sleep 2
fi

say ""
say "✔ instalado."
if [ "$APP_RUNNING" -eq 1 ]; then
  say "  Recarga la interfaz con ⌘R. Si algo sigue en inglés, cierra y vuelve a abrir la app."
else
  say "  Abre DeepSeek Harness: la interfaz aparecerá en español."
fi
say "  Para volver al inglés: Ajustes → General → Idioma → English."
say "  Estado en cualquier momento:  sh install.sh --check"
