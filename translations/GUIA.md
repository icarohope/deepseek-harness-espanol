# Guía de traducción — dsh-locale-es

Traducción de la interfaz de **DeepSeek Harness** al **español latinoamericano (es-419)**.

## Voz y tono

- Español neutro de Latinoamérica. Nada de «vosotros», «ordenador», «fichero», «pulsar»,
  «móvil» ni «contraseña» cuando el contexto sea técnico.
- Trato de **tú**, informal pero profesional: «Elige un modelo», «No se pudo guardar».
- Frases cortas, en **modo imperativo** para botones y acciones («Guardar», «Reintentar»,
  «Abrir en la barra lateral»). Sin punto final en etiquetas de botón ni en títulos.
- Los mensajes de estado y de error sí llevan punto final y voz pasiva refleja o
  impersonal: «No se pudo cargar el catálogo.», «El archivo cambió mientras se leía.».
- Puntos suspensivos con el carácter `…` (nunca `...`) cuando el original los use.
- Comillas angulares «» solo si el original usa comillas; conserva el resto de la
  puntuación y los signos de apertura `¿` `¡` cuando corresponda.

## Reglas obligatorias

1. **Mismas claves, mismo orden.** Copia exactamente las claves del archivo inglés, sin
   agregar, quitar ni renombrar ninguna.
2. **Marcadores intactos.** `{name}`, `{count}`, `{message}`, `{command}`… deben aparecer
   igual, con las mismas llaves y el mismo nombre. No los traduzcas ni los muevas de
   sitio si eso cambia el sentido; puedes reordenarlos dentro de la frase.
3. **No traduzcas**:
   - nombres de producto: `DeepSeek`, `DeepSeek Harness`, `DSH`, `DeepSeek Account`;
   - identificadores y tokens literales: valores de claves `token.*`, rutas, comandos
     (`/goal`, `/plan`, `/export`), nombres de herramientas (`bash`, `read`, `write`),
     extensiones de archivo, `JSON`, `Markdown`, `HTML`, `PDF`, `ZIP`, `Cron`, `Git`,
     `TOML`, `YAML`, `URL`, `API`, `SDK`, `MCP`, `PTC`, `token`;
   - nombres de modelos y proveedores (`deepseek-flash`, `deepseek-account`…);
   - unidades de versión y sufijos como `K`/`M` en `{value}K`.
4. **Valores vacíos o solo espacios** (separadores como `""` o `" "`): déjalos igual que
   en inglés.
5. **Singular y plural.** El inglés separa `*.one` y `*.other`; en español usa singular
   real en `*.one` y plural en `*.other` («{count} tarea» / «{count} tareas»).
6. **Formato**: JSON válido, UTF-8, sangría de 2 espacios, una clave por línea, sin coma
   final. No agregues comentarios (JSON no los admite).
7. Si el original está en MAYÚSCULAS o en Title Case para una etiqueta, en español usa
   mayúscula inicial y minúsculas en el resto, salvo nombres propios.

## Glosario (usar siempre estos términos)

| Inglés | Español |
|---|---|
| Session | Sesión |
| Workspace | Espacio de trabajo |
| Agent | Agente |
| Subagent | Subagente |
| Agent Team | Equipo de agentes |
| Tool / tool call | Herramienta / llamada a herramienta |
| Skill | Habilidad |
| Goal | Objetivo |
| Plan / plan mode | Plan / modo plan |
| Trajectory | Trayectoria |
| Queue | Cola |
| Steer | Guiar |
| Queue / Steer action | acción Cola / Guiar |
| Approval | Aprobación |
| Permission / permission preset | Permiso / preajuste de permisos |
| Sandbox | entorno aislado (sandbox) |
| Read Only | Solo lectura |
| Workspace Write | Escritura en el espacio de trabajo |
| Full access | Acceso total |
| Auto review | Revisión automática |
| Settings | Ajustes |
| Model | Modelo |
| Provider | Proveedor |
| Plugin / Plugins | Plugin / Plugins (nombre del producto) |
| Bundle | Paquete |
| Built-in | Integrado |
| Background job | Tarea en segundo plano |
| Deliverable | Entregable |
| Attachment | Archivo adjunto |
| Sidebar | Barra lateral |
| Panel | Panel |
| Tab | Pestaña |
| Browser | Navegador |
| Terminal | Terminal |
| File / Folder | Archivo / Carpeta |
| Command | Comando |
| Shortcut | Atajo |
| Language | Idioma |
| Theme / Appearance | Tema / Apariencia |
| Account / Sign in / Sign out | Cuenta / Iniciar sesión / Cerrar sesión |
| Usage | Consumo |
| Context | Contexto |
| Compaction / Compact | Compactación / Compactar |
| Checkpoint | Punto de control |
| Handoff | Transferencia |
| Review | Revisión |
| Turn | Turno |
| Approval policy | Política de aprobación |
| Reasoning effort | Esfuerzo de razonamiento |
| Token | Token |
| Streaming | Transmisión |
| Retry | Reintentar |
| Copy / Copied | Copiar / Copiado |
| Close / Cancel / Save / Delete / Edit | Cerrar / Cancelar / Guardar / Eliminar / Editar |
| Loading… | Cargando… |
| Search | Buscar |
| New | Nuevo |
| More | Más |
| Expand / Collapse | Expandir / Contraer |
| Back | Atrás |
| Next / Previous | Siguiente / Anterior |
| Skip | Omitir |

## Ejemplos

| Inglés | Correcto | Incorrecto |
|---|---|---|
| `Open plan in sidebar` | `Abrir el plan en la barra lateral` | `Abrir plan en barra lateral` (suena telegráfico, pero se acepta en etiquetas cortas) |
| `{count} background jobs running` | `{count} tareas en segundo plano en ejecución` | `{count} jobs de fondo corriendo` |
| `Could not load plan` | `No se pudo cargar el plan` | `No podría cargar el plan` |
| `Enable Full access?` | `¿Activar el acceso total?` | `¿Habilitar Full access?` |
| `Press a shortcut` | `Presiona un atajo` | `Pulsa un atajo` |
| `This session is already in use…` | `Esta sesión ya está en uso…` | `Esta sesión ya está siendo usada…` |

## Validación

Cada archivo se valida con:

```sh
node scripts/check.mjs <espacio-de-nombres>
```

El validador comprueba claves faltantes o sobrantes, marcadores `{…}` alterados y
valores vacíos. No debe quedar ningún problema.
