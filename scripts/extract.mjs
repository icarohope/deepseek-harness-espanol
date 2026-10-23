/**
 * Re-extrae los diccionarios ingleses de la interfaz desde una instalación de
 * DeepSeek Harness.
 *
 *   node scripts/extract.mjs
 *   node scripts/extract.mjs --asar /ruta/a/app.asar
 *
 * Recorre los paquetes `@deepseek-ai/dsh-client-*` (y los experimentales) dentro de
 * `app.asar`, localiza cada llamada `ctx.locale.register(...)` de su bundle de cliente
 * y evalúa el diccionario inglés que recibe, resolviendo constantes y objetos
 * extendidos del mismo archivo. Escribe `translations/en/<espacio>.json`.
 *
 * No modifica ninguna traducción existente: las claves nuevas quedan sin traducir y
 * `scripts/check.mjs --all` las reporta.
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const DEFAULT_ASAR = '/Applications/DeepSeek Harness.app/Contents/Resources/app.asar/dsh/node_modules/@deepseek-ai'

const args = process.argv.slice(2)
const asarIndex = args.indexOf('--asar')
const base = asarIndex >= 0 ? args[asarIndex + 1] : DEFAULT_ASAR

if (!fs.existsSync(base)) {
  console.error(`extract: no se encontró la carpeta de paquetes: ${base}`)
  console.error('Indica otra ruta con --asar <node_modules/@deepseek-ai>.')
  process.exit(1)
}

const escapeRegExp = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

/** Devuelve el índice del cierre que equilibra la apertura en `start`. */
function scanBalanced(source, start, open, close) {
  let depth = 0
  let quote = null
  let template = false
  let escaped = false
  for (let i = start; i < source.length; i += 1) {
    const char = source[i]
    if (quote) {
      if (escaped) escaped = false
      else if (char === '\\') escaped = true
      else if (char === quote) quote = null
      continue
    }
    if (template) {
      if (escaped) escaped = false
      else if (char === '\\') escaped = true
      else if (char === '`') template = false
      continue
    }
    if (char === '"' || char === "'") {
      quote = char
      continue
    }
    if (char === '`') {
      template = true
      continue
    }
    if (char === open) depth += 1
    else if (char === close) {
      depth -= 1
      if (depth === 0) return i
    }
  }
  return -1
}

/** Índice de la comilla de cierre de la cadena que empieza en `start`. */
function scanString(source, start) {
  const quote = source[start]
  for (let i = start + 1; i < source.length; i += 1) {
    if (source[i] === '\\') {
      i += 1
      continue
    }
    if (source[i] === quote) return i
  }
  return -1
}

/** Divide una lista de argumentos u objetos por comas de nivel superior. */
function splitTopLevel(source) {
  const parts = []
  let start = 0
  let depth = 0
  let quote = null
  let template = false
  let escaped = false
  for (let i = 0; i < source.length; i += 1) {
    const char = source[i]
    if (quote) {
      if (escaped) escaped = false
      else if (char === '\\') escaped = true
      else if (char === quote) quote = null
      continue
    }
    if (template) {
      if (escaped) escaped = false
      else if (char === '\\') escaped = true
      else if (char === '`') template = false
      continue
    }
    if (char === '"' || char === "'") {
      quote = char
      continue
    }
    if (char === '`') {
      template = true
      continue
    }
    if ('{[('.includes(char)) depth += 1
    else if ('}])'.includes(char)) depth -= 1
    else if (char === ',' && depth === 0) {
      parts.push(source.slice(start, i))
      start = i + 1
    }
  }
  const tail = source.slice(start)
  if (tail.trim()) parts.push(tail)
  return parts
}

/** Texto del inicializador de `const <name> = …`, sin envoltorios como Object.freeze. */
function initializerText(source, name) {
  const match = new RegExp(`(?:const|let|var)\\s+${escapeRegExp(name)}\\s*=\\s*`).exec(source)
  if (!match) return null
  let index = match.index + match[0].length
  for (let i = 0; i < 6; i += 1) {
    const wrapper = /^(?:Object\.(?:freeze|assign|seal)\(\s*|\(\s*)/.exec(source.slice(index))
    if (!wrapper) break
    index += wrapper[0].length
  }
  const char = source[index]
  if (char === '{' || char === '[') {
    const end = scanBalanced(source, index, char, char === '{' ? '}' : ']')
    return end < 0 ? null : source.slice(index, end + 1)
  }
  if (char === '"' || char === "'" || char === '`') {
    const end = scanString(source, index)
    return end < 0 ? null : source.slice(index, end + 1)
  }
  const rest = /^[^\n;]+/.exec(source.slice(index))
  return rest ? rest[0].trim() : null
}

/** Evalúa una expresión resolviendo, bajo demanda, los identificadores que le faltan. */
function evaluate(source, text, cache, depth = 0) {
  const params = {}
  for (let attempt = 0; attempt < 80; attempt += 1) {
    try {
      const names = Object.keys(params)
      const fn = new Function(...names, `return (${text})`)
      return { value: fn(...names.map((name) => params[name])) }
    } catch (error) {
      const missing = /^([A-Za-z_$][\w$]*) is not defined$/u.exec(error.message)
      if (!missing) return { error: error.message }
      const name = missing[1]
      if (name in params) return { error: `ciclo en ${name}` }
      const value = resolve(source, name, cache, depth + 1)
      if (value === undefined) return { error: `${name} no se pudo resolver` }
      params[name] = value
    }
  }
  return { error: 'demasiadas referencias' }
}

function resolve(source, name, cache, depth = 0) {
  if (cache.has(name)) return cache.get(name)
  if (depth > 12) return undefined
  const text = initializerText(source, name)
  if (!text) return undefined
  const result = evaluate(source, text, cache, depth + 1)
  if (result.error) return undefined
  cache.set(name, result.value)
  return result.value
}

const found = new Map()
const problems = []

for (const packageName of fs.readdirSync(base).sort()) {
  const packageDir = path.join(base, packageName)
  if (!fs.statSync(packageDir).isDirectory()) continue
  const entry = path.join(packageDir, 'lib/client.js')
  if (!fs.existsSync(entry)) continue
  const source = fs.readFileSync(entry, 'utf8')
  if (!source.includes('locale.register')) continue
  const cache = new Map()

  const call = /locale\.register\(/g
  let match
  while ((match = call.exec(source))) {
    const open = match.index + 'locale.register('.length
    let depth = 1
    let i = open
    let quote = null
    let template = false
    let escaped = false
    for (; i < source.length; i += 1) {
      const char = source[i]
      if (quote) {
        if (escaped) escaped = false
        else if (char === '\\') escaped = true
        else if (char === quote) quote = null
        continue
      }
      if (template) {
        if (escaped) escaped = false
        else if (char === '\\') escaped = true
        else if (char === '`') template = false
        continue
      }
      if (char === '"' || char === "'") {
        quote = char
        continue
      }
      if (char === '`') {
        template = true
        continue
      }
      if (char === '(') depth += 1
      else if (char === ')') {
        depth -= 1
        if (depth === 0) break
      }
    }

    const callArgs = splitTopLevel(source.slice(open, i))
    const namespaceRaw = callArgs[0]?.trim()
    let namespace = null
    if (namespaceRaw && /^["']/u.test(namespaceRaw)) namespace = namespaceRaw.slice(1, -1)
    else {
      const literal = initializerText(source, namespaceRaw)
      if (literal && /^["']/u.test(literal.trim())) namespace = literal.trim().slice(1, -1)
    }

    let english = null
    if (callArgs.length === 2) {
      const value = callArgs[1].trim()
      if (value.startsWith('{')) {
        const properties = splitTopLevel(value.slice(1, -1)).map((part) => part.trim()).filter(Boolean)
        if (properties.length > 0 && properties.every((part) => /^[A-Za-z_$][\w$]*$/u.test(part))) {
          const englishProperty = properties.find((part) => /^en/u.test(part))
          if (englishProperty) english = initializerText(source, englishProperty)
        } else english = value
      } else english = initializerText(source, value)
    } else if (callArgs.length >= 3) {
      const languageRaw = callArgs[1].trim()
      let language = /^["']/u.test(languageRaw) ? languageRaw.slice(1, -1) : null
      if (language === null) {
        const literal = new RegExp(`\\[\\s*["']([\\w-]+)["']\\s*,\\s*${escapeRegExp(languageRaw)}\\s*\\]`).exec(source)
        language = literal ? literal[1] : null
      }
      if (language === 'en') {
        const value = callArgs[2].trim()
        english = value.startsWith('{') ? value : initializerText(source, value)
      }
    }
    if (english === null && callArgs[1] && callArgs[1].trim().startsWith('[')) {
      const pairs = splitTopLevel(callArgs[1].trim().slice(1, -1))
      for (const pair of pairs) {
        const pairMatch = /^\[\s*["']en["']\s*,\s*/u.exec(pair.trim())
        if (pairMatch) {
          english = pair.trim().slice(pairMatch[0].length).replace(/\]\s*$/u, '')
          break
        }
      }
    }
    if (english === null) {
      const fallback = /\[\s*["']en["']\s*,\s*\{/u.exec(source)
      if (fallback) {
        const brace = fallback.index + fallback[0].length - 1
        const end = scanBalanced(source, brace, '{', '}')
        if (end > 0) english = source.slice(brace, end + 1)
      }
    }
    if (english === null) {
      problems.push(`${packageName}: no se localizó el diccionario inglés de ${namespace ?? '(sin nombre)'}`)
      continue
    }

    const result = evaluate(source, english, cache)
    if (result.error) {
      problems.push(`${packageName}/${namespace}: ${result.error}`)
      continue
    }
    let dictionary = result.value
    if (dictionary && typeof dictionary === 'object' && Object.keys(dictionary).length === 2 && dictionary.zh && dictionary.en) {
      dictionary = dictionary.en
    }
    if (namespace === null) {
      problems.push(`${packageName}: diccionario sin espacio de nombres`)
      continue
    }
    if (found.has(namespace)) problems.push(`${namespace}: registrado por dos paquetes (${packageName})`)
    found.set(namespace, { packageName, dictionary })
  }
}

const target = path.join(root, 'translations', 'en')
fs.mkdirSync(target, { recursive: true })
for (const [namespace, { dictionary }] of found) {
  fs.writeFileSync(path.join(target, `${namespace}.json`), `${JSON.stringify(dictionary, null, 2)}\n`)
}

const keys = [...found.values()].reduce((sum, entry) => sum + Object.keys(entry.dictionary).length, 0)
console.log(`extract: ${found.size} espacios de nombres, ${keys} claves → translations/en`)
for (const problem of problems) console.error(`  aviso: ${problem}`)
