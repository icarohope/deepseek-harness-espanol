/**
 * Informe de calidad de las traducciones.
 *
 *   node scripts/qa.mjs
 *
 * Señala lo que el validador estructural no ve: valores idénticos al inglés que
 * parecen frases (no términos técnicos), restos de palabras inglesas frecuentes,
 * comillas o signos desbalanceados y textos sospechosamente largos o cortos.
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const enDir = path.join(root, 'translations', 'en')
const esDir = path.join(root, 'translations', 'es')

const ENGLISH_HINTS = /\b(the|and|with|from|this|that|your|you|please|failed|cannot|could not|unable|loading|search|settings|session|workspace|agent|file|folder|open|close|save|delete|cancel|retry|more|less|show|hide|enable|disable|choose|select|remove|add|new|edit|copy|download|upload|running|waiting|error|warning)\b/iu
const TECHNICAL = /^(?:JSON|Markdown|HTML|PDF|ZIP|Cron|Git|Office|DSH|API|SDK|MCP|PTC|Token|URL|TCP|HTTP|HTTPS|UTF-8|OK|ON|OFF)$/u

const identical = []
const suspicious = []
const unbalanced = []
let total = 0

for (const file of fs.readdirSync(enDir).filter((name) => name.endsWith('.json')).sort()) {
  const namespace = file.slice(0, -5)
  const enPath = path.join(enDir, file)
  const esPath = path.join(esDir, file)
  if (!fs.existsSync(esPath)) continue
  const en = JSON.parse(fs.readFileSync(enPath, 'utf8'))
  const es = JSON.parse(fs.readFileSync(esPath, 'utf8'))
  for (const key of Object.keys(en)) {
    if (!(key in es)) continue
    total += 1
    const source = en[key]
    const value = es[key]
    if (typeof source !== 'string' || typeof value !== 'string') continue
    if (source === value) {
      if (!TECHNICAL.test(source) && /[A-Za-z]{3,}/u.test(source) && !/^\{[^}]*\}$/u.test(source)) {
        identical.push(`${namespace}/${key}: «${source}»`)
      }
      continue
    }
    if (ENGLISH_HINTS.test(value.replace(/\{[^}]*\}/gu, ''))) suspicious.push(`${namespace}/${key}: «${value}»`)
    const pairs = [['(', ')'], ['[', ']'], ['«', '»'], ['¿', '?'], ['¡', '!']]
    for (const [open, close] of pairs) {
      const opens = value.split(open).length - 1
      const closes = value.split(close).length - 1
      if (opens !== closes) unbalanced.push(`${namespace}/${key}: «${value}»`)
    }
  }
}

const report = (title, rows) => {
  console.log(`\n${title}: ${rows.length}`)
  for (const row of rows.slice(0, 40)) console.log(`  - ${row}`)
  if (rows.length > 40) console.log(`  … y ${rows.length - 40} más`)
}

console.log(`qa: ${total} textos revisados`)
report('Idénticos al inglés que parecen frases', identical)
report('Restos de inglés', suspicious)
report('Signos desbalanceados', unbalanced)

const problems = identical.length + suspicious.length + unbalanced.length
process.exit(problems === 0 ? 0 : 1)
