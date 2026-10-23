# dsh-locale-es

Traducción al **español latinoamericano (es-419)** de toda la interfaz de
[DeepSeek Harness](https://harness.deepseek.com). Es un plugin de cliente: registra un
paquete de idioma y un diccionario por cada espacio de nombres de la interfaz, de modo
que el selector de idioma de DSH lo trata como un idioma más.

- **63 espacios de nombres** y **2 901 textos** traducidos (barra lateral, chat,
  trayectoria, ajustes, plugins, tareas programadas, vista previa de documentos, atajos,
  entrada de voz, mercado de plugins, etc.).
- El idioma aparece en **Ajustes → General → Idioma** como «Español (Latinoamérica)».
- Cualquier texto que el paquete no cubra cae automáticamente al inglés, nunca a una
  clave cruda.
- La preferencia se guarda en el perfil (`locale.preference`), así que sobrevive a
  reinicios y afecta a todas las ventanas de esta instalación.

## Requisitos

- **DeepSeek Harness 0.2.x en macOS** (probado en Apple Silicon con 0.2.1-rc.2). El
  instalador `Instalar-Espanol-DSH.command` y `scripts/install.sh` usan rutas y comandos
  de macOS.
- El **plugin en sí es multiplataforma**: funciona en cualquier sistema donde corra DSH,
  porque solo registra un idioma en el navegador. En Windows o Linux instala
  `dsh-locale-es-1.0.0.tgz` desde **Plugins**.
- No requiere permisos de administrador ni modifica `DeepSeek Harness.app`.

## Descargar

[Última versión](https://github.com/icarohope/deepseek-harness-espanol/releases/latest) · [Repositorio](https://github.com/icarohope/deepseek-harness-espanol)

## Instalación

### La forma rápida (macOS, un solo archivo)

`dist/Instalar-Espanol-DSH.command` contiene el plugin completo. Cópialo a la Mac de
destino, doble clic y listo: no necesita conexión ni permisos de administrador. Si macOS
lo bloquea por venir de otro equipo, clic derecho → **Abrir**.

### Desde la página Plugins de DSH

Arrastra `dist/dsh-locale-es-1.0.0.tgz` (o la carpeta del `.zip`) en **Plugins** y actívalo.
Así queda gestionado por DSH y aparece en la lista de plugins.

### A mano, desde el código

```sh
cd dsh-locale-es
sh scripts/install.sh
```

El instalador:

1. copia el paquete a `~/.dsh/plugins/dsh-locale-es`;
2. lo enlaza como dependencia del perfil de escritorio (`pnpm link:`, o un enlace manual
   si pnpm no está disponible);
3. lo agrega a `dsh.profile.bundles`;
4. fija `locale.preference: es-419` en `~/.dsh/cordis.patch.yml`;
5. respalda `package.json` y `cordis.patch.yml` del perfil antes de tocar nada;
6. si la app está abierta, desmonta y vuelve a montar la fila para que relea el bundle.

Es idempotente: puedes ejecutarlo las veces que quieras para instalar, reparar o
actualizar. Después recarga la interfaz con **⌘R**.

```sh
sh scripts/install.sh --check       # informa el estado sin tocar nada
sh scripts/install.sh --uninstall   # lo quita y deja el perfil como estaba
sh scripts/install.sh --help        # todas las opciones
```

Si prefieres elegir el idioma a mano, abre **Ajustes → General → Idioma** y selecciona
«Español (Latinoamérica)».

## Llevarlo a otra Mac

```sh
sh scripts/make-dist.sh
```

Genera en `dist/`:

| Archivo | Para qué |
|---|---|
| `Instalar-Espanol-DSH.command` | instalador de un solo archivo, doble clic |
| `dsh-locale-es-1.0.0.tgz` | paquete npm para la página Plugins |
| `dsh-locale-es-1.0.0.zip` | carpeta completa, para instalar con `sh scripts/install.sh` |
| `LEER-PRIMERO.md` | instrucciones para la Mac de destino |
| `SHA256SUMS.txt` | sumas de verificación |

Requisito en la Mac de destino: tener DeepSeek Harness instalado y **abierto al menos una
vez**, porque el instalador registra el plugin en `~/.dsh/profiles/desktop`, que la app
crea en su primer arranque.

## Volver al inglés

**Ajustes → General → Idioma → English**. La elección se guarda sola y el plugin sigue
instalado (puedes volver al español cuando quieras).

## ¿Se pierde al actualizar?

| Situación | ¿Se conserva? |
|---|---|
| Actualizar DeepSeek Harness a una versión nueva | **Sí.** El plugin vive en `~/.dsh/plugins`, fuera de la app firmada. |
| Reiniciar la app o la Mac | **Sí.** El idioma queda guardado en el perfil. |
| Reinstalar DSH en la misma Mac | **Normalmente sí** (`~/.dsh` no se borra). Si desapareciera, ejecuta `--check` y vuelve a instalar. |
| Borrar `~/.dsh` a mano | **No.** Vuelve a ejecutar el instalador. |
| Otra Mac u otro usuario de macOS | **No.** Ejecuta el instalador allí. |

Tras una actualización de DSH pueden aparecer textos nuevos: se muestran en inglés hasta
traducirlos (`scripts/extract.mjs` + `scripts/check.mjs` los localizan). Si una versión
cambiara la API de idiomas, el plugin dejaría de cargar y la interfaz seguiría en inglés,
sin romper nada.

## Desinstalar

```sh
sh scripts/install.sh --uninstall
```

Quita el bundle, la dependencia y la preferencia de idioma, y deja el perfil como estaba.

## Cómo está hecho

```
package.json          manifiesto con dsh.bundle.patch y dsh.client
cordis.patch.yml      capa de bundle: inserta la fila `locale-es`
lib/index.js          mitad host: no hace nada (la traducción es del navegador)
lib/client.js         bundle de cliente generado: registra el idioma y los diccionarios
translations/en/*.json  diccionarios originales extraídos de la app
translations/es/*.json  traducciones
scripts/build.mjs     valida y genera lib/client.js
scripts/check.mjs     validador de un diccionario suelto
scripts/extract.mjs   re-extrae los diccionarios ingleses de una instalación de DSH
scripts/qa.mjs        informe de calidad de las traducciones
scripts/install.sh    instalador, verificador y desinstalador
scripts/make-dist.sh  genera dist/ (tgz, zip, instalador de un archivo)
```

El bundle de cliente usa el formato que sirve `dsh-client-modules`:

```js
window.__ModuleLoader__.load({
  id: 'dsh-locale-es',
  factory: (require) => { /* … exports.apply, exports.inject … */ },
})
```

`apply(ctx)` registra, como efectos del plugin:

```js
ctx.locale.addLanguage({ id: 'es-419', label: 'Español (Latinoamérica)', fallback: 'en' })
ctx.locale.register('chat', 'es-419', { /* … */ })
```

Como el idioma declara `fallback: 'en'`, una clave ausente se resuelve en inglés antes
de mostrar la clave.

## Editar una traducción

1. Cambia el valor en `translations/es/<espacio>.json` (misma clave, mismos marcadores
   `{…}`).
2. Regenera el bundle:

   ```sh
   node scripts/build.mjs
   ```

   El script falla si falta una clave, sobra una o cambió un marcador.
3. Copia el bundle a la instalación:

   ```sh
   sh scripts/install.sh
   ```

   El instalador vuelve a copiar los archivos y desmonta/monta la fila del plugin para que
   la aplicación en ejecución relea `lib/client.js` sin reiniciarse. Después recarga la
   interfaz con **⌘R**.

El host guarda en memoria el bundle que sirvió al componer el perfil: editar
`~/.dsh/plugins/dsh-locale-es/lib/client.js` a mano no basta, porque HMR solo vigila el
manifiesto y los parches del perfil, no los módulos del plugin. Reinstalar (o reiniciar
la app) es lo que hace visible el cambio.

## Mantenimiento tras actualizar DeepSeek Harness

Cada versión de DSH puede agregar textos nuevos. Para regenerar los diccionarios base:

```sh
node scripts/extract.mjs            # reescribe translations/en/*.json
node scripts/check.mjs --all        # muestra qué claves faltan traducir
```

`extract.mjs` lee los bundles de la app instalada
(`/Applications/DeepSeek Harness.app/Contents/Resources/app.asar`) sin descomprimirla.
Las claves nuevas aparecen como faltantes en `check.mjs`; hasta que se traduzcan, la
interfaz las muestra en inglés.

En macOS, `node` no está en el `PATH`: usa el binario que trae la app.

```sh
export ELECTRON_RUN_AS_NODE=1
NODE="/Applications/DeepSeek Harness.app/Contents/MacOS/DeepSeek Harness"
"$NODE" scripts/build.mjs
```

## Alcance y límites conocidos

- **Se traduce la interfaz**, no el contenido: los mensajes del agente, los títulos de
  sesión generados por el modelo, la salida de comandos y el contenido de los archivos
  siguen en su idioma original.
- Los **diagnósticos del host** (pnpm, el cargador de plugins, errores de red) llegan del
  proceso principal y se muestran tal cual, en inglés.
- Los textos que un plugin registra **antes** de que el idioma esté activo conservan el
  idioma de registro hasta que se vuelvan a registrar (limitación documentada por
  `dsh-client-locale`); recargar la página lo resuelve.
- El plugin fija el idioma por perfil. Otras instalaciones o perfiles no se ven afectados.

## Licencia y créditos

Este paquete se publica bajo licencia **MIT** (ver [LICENSE](LICENSE)).

Los diccionarios de `translations/en/` son los textos de la interfaz de **DeepSeek
Harness**, extraídos de la instalación local y reproducidos aquí para que la build sea
reproducible; DeepSeek Harness también se distribuye bajo MIT (Copyright © 2026 DeepSeek,
<https://github.com/deepseek-ai/deepseek-harness>). Los detalles están en
[NOTICE.md](NOTICE.md).

Es un paquete de idioma **no oficial**, hecho por la comunidad: no está publicado ni
respaldado por DeepSeek.

