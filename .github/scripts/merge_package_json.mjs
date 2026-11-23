// Three-way merge of package.json: node merge_package_json.mjs <base> <ours> <theirs>
// Writes the result to <ours>. Keys that make the fork its own package stay ours.
// Exits 1 and lists the keys when both sides changed the same value differently.
import { readFileSync, writeFileSync } from 'node:fs'

const [basePath, oursPath, theirsPath] = process.argv.slice(2)
const read = (p) => JSON.parse(readFileSync(p, 'utf8'))
const keepOurs = new Set(['name', 'version', 'description', 'repository', 'bugs', 'homepage', 'publishConfig'])
const eq = (a, b) => JSON.stringify(a) === JSON.stringify(b)
const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)
const conflicts = []

function merge(base, ours, theirs, path) {
  if (eq(theirs, base) || eq(ours, theirs)) return ours
  if (eq(ours, base)) return theirs
  if (isObj(ours) && isObj(theirs) && (base === undefined || isObj(base))) {
    const b = base ?? {}
    const out = {}
    for (const k of new Set([...Object.keys(ours), ...Object.keys(theirs)])) {
      const v = path === '' && keepOurs.has(k) ? ours[k] : merge(b[k], ours[k], theirs[k], `${path}${path ? '.' : ''}${k}`)
      if (v !== undefined) out[k] = v
    }
    return out
  }
  conflicts.push(path)
  return ours
}

const result = merge(read(basePath), read(oursPath), read(theirsPath), '')
writeFileSync(oursPath, `${JSON.stringify(result, null, 2)}\n`)
if (conflicts.length > 0) {
  console.log(conflicts.join('\n'))
  process.exit(1)
}
