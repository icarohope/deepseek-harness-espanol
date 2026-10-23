#!/bin/sh
# Genera los artefactos distribuibles en dist/:
#
#   dsh-locale-es-<versión>.tgz      paquete npm (para la página Plugins de DSH)
#   dsh-locale-es-<versión>.zip      paquete completo (carpeta con instalador)
#   Instalar Español DSH.command     instalador de un solo archivo, doble clic
#   LEER-PRIMERO.md                  instrucciones para la otra Mac
#   SHA256SUMS.txt                   sumas de verificación
#
# Uso:  sh scripts/make-dist.sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

VERSION=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' package.json | head -n 1)
[ -n "$VERSION" ] || { echo "no se pudo leer la versión de package.json" >&2; exit 1; }

NAME="dsh-locale-es-$VERSION"
DIST="$ROOT/dist"
ITEMS="package.json cordis.patch.yml README.md LICENSE NOTICE.md lib scripts translations"

echo "→ limpiando dist/"
rm -rf "$DIST"
mkdir -p "$DIST"

STAGE=$(mktemp -d "${TMPDIR:-/tmp}/dsh-locale-es-dist.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT INT TERM

echo "→ preparando $NAME"
mkdir -p "$STAGE/package"
for item in $ITEMS; do
  [ -e "$ROOT/$item" ] || continue
  cp -R "$ROOT/$item" "$STAGE/package/"
done
find "$STAGE/package" -name '.DS_Store' -delete 2>/dev/null || true
find "$STAGE/package" -name '*.bak-*' -delete 2>/dev/null || true

echo "→ empaquetando .tgz (formato npm)"
COPYFILE_DISABLE=1 tar -czf "$DIST/$NAME.tgz" -C "$STAGE" package

echo "→ empaquetando .zip"
mkdir -p "$STAGE/zip"
cp -R "$STAGE/package" "$STAGE/zip/$NAME"
( cd "$STAGE/zip" && COPYFILE_DISABLE=1 zip -r -q -X "$DIST/$NAME.zip" "$NAME" )

echo "→ generando el instalador de un solo archivo"
PAYLOAD="$STAGE/payload.tgz"
COPYFILE_DISABLE=1 tar -czf "$PAYLOAD" -C "$STAGE" package
COMMAND="$DIST/Instalar Español DSH.command"

cat > "$COMMAND" <<'HEADER'
#!/bin/sh
# Instalador de «Español (Latinoamérica)» para DeepSeek Harness.
#
# Doble clic para instalar el paquete de idioma en este Mac. No necesita
# conexión: todo el plugin viaja dentro de este archivo.
#
# Si macOS lo bloquea por provenir de otro equipo: clic derecho → Abrir, o
#   xattr -d com.apple.quarantine "Instalar Español DSH.command"
set -eu

PAYLOAD_LINE=$(awk '/^__PAYLOAD_BELOW__$/{print NR + 1; exit}' "$0")
[ -n "$PAYLOAD_LINE" ] || { echo "archivo dañado: falta el contenido" >&2; exit 1; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/dsh-locale-es.XXXXXX")
trap 'rm -rf "$WORK"' EXIT INT TERM

if printf 'aGk=' | base64 -D >/dev/null 2>&1; then
  DECODE="-D"
else
  DECODE="-d"
fi

tail -n +"$PAYLOAD_LINE" "$0" | base64 "$DECODE" | tar -xzf - -C "$WORK"

sh "$WORK/package/scripts/install.sh" "$@"
STATUS=$?

if [ -t 0 ]; then
  printf '\nPulsa Enter para cerrar esta ventana…'
  read -r _ || true
fi

exit "$STATUS"

__PAYLOAD_BELOW__
HEADER

base64 < "$PAYLOAD" >> "$COMMAND"
chmod +x "$COMMAND"

echo "→ escribiendo LEER-PRIMERO.md"
cat > "$DIST/LEER-PRIMERO.md" <<'GUIDE'
# Español (Latinoamérica) para DeepSeek Harness

Este paquete traduce toda la interfaz de DeepSeek Harness al español
latinoamericano: **63 espacios de nombres y 2 901 textos**.

## Antes de empezar

1. Instala DeepSeek Harness en esta Mac y **ábrelo una vez**. Eso crea su perfil
   en `~/.dsh/profiles/desktop`; sin ese perfil el instalador no tiene dónde
   registrar el plugin.
2. Cierra la app (opcional, pero recomendable).

## Forma 1 — instalador de un solo archivo (recomendada)

1. Copia **`Instalar Español DSH.command`** a esta Mac (AirDrop, iCloud, USB…).
2. Doble clic. Si macOS dice que no puede abrirlo porque proviene de otro
   equipo: **clic derecho → Abrir**, o abre Terminal y ejecuta:

   ```sh
   xattr -d com.apple.quarantine "Instalar Español DSH.command"
   chmod +x "Instalar Español DSH.command"
   ./"Instalar Español DSH.command"
   ```

3. Si la app estaba abierta, recarga la interfaz con **⌘R**. Si algo sigue en
   inglés, ciérrala y vuelve a abrirla.

El instalador no necesita conexión: el plugin viaja dentro del archivo.

## Forma 2 — desde la página Plugins de DSH

1. Abre **Plugins** en la barra lateral.
2. Usa la opción de instalar desde un archivo o ruta y elige
   `dsh-locale-es-<versión>.tgz` (o la carpeta descomprimida del `.zip`).
3. Actívalo y elige **Ajustes → General → Idioma → Español (Latinoamérica)**.

Esta vía deja el plugin gestionado por DSH, así que aparece en la lista de
Plugins y se puede activar o desactivar desde ahí.

## Forma 3 — manual

```sh
cd dsh-locale-es-<versión>
sh scripts/install.sh
```

## Comprobar, reparar y desinstalar

```sh
sh scripts/install.sh --check       # ¿está todo en su sitio?
sh scripts/install.sh               # instalar o reparar (idempotente)
sh scripts/install.sh --uninstall   # quitarlo y volver al inglés
```

También puedes cambiar de idioma en cualquier momento en
**Ajustes → General → Idioma**.

## ¿Se pierde al actualizar o reinstalar?

| Situación | ¿Se conserva? |
|---|---|
| Actualizar DeepSeek Harness a una versión nueva | **Sí.** El plugin vive en `~/.dsh/plugins`, fuera de la app. |
| Reiniciar la Mac o la app | **Sí.** La selección queda guardada en el perfil. |
| Desinstalar y volver a instalar DSH en la misma Mac | **Normalmente sí**, porque `~/.dsh` no se borra. Si el instalador de DSH lo eliminara, vuelve a ejecutar este instalador. |
| Borrar `~/.dsh` a mano | **No.** Vuelve a ejecutar el instalador. |
| Otra Mac, o un macOS reinstalado | **No.** Hay que ejecutar el instalador allí. |

Una actualización de DSH puede añadir textos nuevos: los que no estén
traducidos se muestran en inglés hasta que se añadan. El paquete incluye
`scripts/extract.mjs` y `scripts/check.mjs` para localizarlos y traducirlos.

## Qué toca exactamente

- Copia el plugin en `~/.dsh/plugins/dsh-locale-es`.
- Lo enlaza como dependencia y bundle del perfil `~/.dsh/profiles/desktop`.
- Fija `locale.preference: es-419` en `~/.dsh/cordis.patch.yml`.
- Respalda `package.json` y `cordis.patch.yml` del perfil antes de cambiarlos.

No modifica nada dentro de `DeepSeek Harness.app`, así que la firma de la
aplicación y sus actualizaciones siguen intactas.
GUIDE

echo "→ calculando sumas"
( cd "$DIST" && shasum -a 256 * > SHA256SUMS.txt )

echo ""
echo "✔ artefactos en $DIST"
ls -lh "$DIST"
