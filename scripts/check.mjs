/**
 * Valida una o más traducciones contra el diccionario inglés de origen.
 *
 *   node scripts/check.mjs chat conversation
 *   node scripts/check.mjs --all
 *
 * Comprueba claves faltantes, claves sobrantes, marcadores {…} alterados, valores
 * vacíos y valores idénticos al inglés (aviso, no error).
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const enDir = path.join(root, 'translations', 'en')
const esDir = path.join(root, 'translations', 'es')
const PLACEHOLDER = /\{([A-Za-z0-9_.]+)\}/g
const placeholders = (value) => [...value.matchAll(PLACEHOLDER)].map((m) => m[1]).sort().join(',')

function namespaces() {
  const args = process.argv.slice(2)
  if (args.includes('--all')) return fs.readdirSync(enDir).filter((f) => f.endsWith('.json')).map((f) => f.slice(0, -5))
  return args
}

const list = namespaces()
if (list.length === 0) {
  console.error('uso: node scripts/check.mjs <espacio…> | --all')
  process.exit(2)
}

let failures = 0
for (const ns of list) {
  const enPath = path.join(enDir, `${ns}.json`)
  const esPath = path.join(esDir, `${ns}.json`)
  if (!fs.existsSync(esPath)) {
    console.log(`✗ ${ns}: falta translations/es/${ns}.json`)
    failures += 1
    continue
  }
  let en
  let es
  try {
    en = JSON.parse(fs.readFileSync(enPath, 'utf8'))
  } catch {
    console.log(`✗ ${ns}: el inglés no es JSON válido`)
    failures += 1
    continue
  }
  try {
    es = JSON.parse(fs.readFileSync(esPath, 'utf8'))
  } catch (error) {
    console.log(`✗ ${ns}: JSON inválido — ${error.message}`)
    failures += 1
    continue
  }

  const problems = []
  const enKeys = Object.keys(en)
  const esKeys = Object.keys(es)
  for (const key of enKeys) {
    if (!(key in es)) problems.push(`falta la clave «${key}»`)
    else {
      const source = en[key]
      const value = es[key]
      if (typeof value !== 'string') problems.push(`«${key}» no es una cadena`)
      else {
        if (source.trim() !== '' && value.trim() === '') problems.push(`«${key}» está vacío`)
        if (placeholders(source) !== placeholders(value)) problems.push(`«${key}» cambió los marcadores`)
      }
    }
  }
  for (const key of esKeys) if (!(key in en)) problems.push(`clave sobrante «${key}»`)

  if (problems.length > 0) {
    failures += 1
    console.log(`✗ ${ns}: ${problems.length} problema(s)`)
    for (const problem of problems.slice(0, 20)) console.log(`    - ${problem}`)
    if (problems.length > 20) console.log(`    … y ${problems.length - 20} más`)
  } else {
    console.log(`✓ ${ns}: ${enKeys.length} claves`)
  }
}

process.exit(failures === 0 ? 0 : 1)
