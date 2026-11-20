// Patches the bundled Matter Hub CLI so ServiceArea areas get a Matter
// areaType (AreaTypeTag, Common Area namespace tag id) instead of null.
// Usage: node patch.mjs <path to dist/backend/cli.js>
import { readFileSync, writeFileSync } from "node:fs";

const file = process.argv[2];
let src = readFileSync(file, "utf8");

const helper = `
// --- hamh_raumtyp patch: areaType from the HA area ---
const HAMH_AREA_TAGS = {
  Bathroom: 6, Bedroom: 7, Corridor: 16, Dining: 21, Entrance: 27,
  GuestBathroom: 38, GuestBedroom: 39, GuestRoom: 41, Hallway: 43,
  KidsRoom: 45, KidsBedroom: 46, Kitchen: 47, LaundryRoom: 49,
  LivingRoom: 52, Office: 58, PrimaryBathroom: 68, PrimaryBedroom: 69,
  StorageRoom: 86, Study: 88, Toilet: 95,
};
const HAMH_AREA_KEYWORDS = [
  [/kuche|kueche|küche|kitchen/, "Kitchen"],
  [/wohnzimmer|living/, "LivingRoom"],
  [/schlafzimmer|bedroom/, "Bedroom"],
  [/kleines_bad|gaste_?bad|gaeste_?bad|gäste_?bad|guest_bath/, "GuestBathroom"],
  [/bad|bathroom/, "Bathroom"],
  [/wc|toilet/, "Toilet"],
  [/flur|diele|gang|hallway|corridor/, "Hallway"],
  [/esszimmer|esstisch|dining/, "Dining"],
  [/kinderzimmer|kids/, "KidsRoom"],
  [/arbeitszimmer|buro|buero|büro|office/, "Office"],
];
let hamhAreaOverrides;
function hamhAreaType(room) {
  if (hamhAreaOverrides === undefined) {
    hamhAreaOverrides = {};
    for (const pair of String(process.env.AREA_TYPE_OVERRIDES ?? "").split(",")) {
      const [key, tag] = pair.split("=").map((s) => s.trim());
      if (key && tag) hamhAreaOverrides[key.toLowerCase()] = tag;
    }
  }
  const keys = [room.haAreaId, room.id, room.name]
    .filter((k) => k !== undefined && k !== null)
    .map((k) => String(k).toLowerCase());
  let tag;
  for (const k of keys) {
    if (hamhAreaOverrides[k] !== undefined) { tag = hamhAreaOverrides[k]; break; }
  }
  if (tag === undefined) {
    const text = keys.join(" ").replace(/\\s+/g, "_");
    tag = HAMH_AREA_KEYWORDS.find(([re]) => re.test(text))?.[1];
  }
  if (tag === undefined || tag === "" || tag === "none") return null;
  const id = /^\\d+$/.test(tag) ? Number(tag) : HAMH_AREA_TAGS[tag];
  if (id === undefined) {
    logger260.warn(\`hamh_raumtyp: unknown area type "\${tag}" for \${room.name}\`);
    return null;
  }
  logger260.info(\`hamh_raumtyp: \${room.name} -> areaType \${tag} (\${id})\`);
  // areaType is a plain uint8: the tag id from the Common Area namespace.
  return id;
}
// --- end hamh_raumtyp patch ---
`;

function patchFunction(name) {
  const start = src.indexOf(`\nfunction ${name}(`);
  if (start < 0) throw new Error(`function ${name} not found`);
  const end = src.indexOf("\n}\n", start);
  const body = src.slice(start, end);
  const count = body.split("areaType: null").length - 1;
  if (count !== 1) throw new Error(`${name}: expected 1 "areaType: null", found ${count}`);
  src =
    src.slice(0, start) +
    body.replace("areaType: null", "areaType: hamhAreaType(room)") +
    src.slice(end);
}

if (src.includes("hamh_raumtyp patch")) {
  console.log("already patched");
  process.exit(0);
}
if (!src.includes("var logger260 = Logger.get(\"VacuumServiceAreaServer\")") &&
    !/logger260 = Logger\.get\("VacuumServiceAreaServer"\)/.test(src)) {
  throw new Error("logger260 is not the VacuumServiceAreaServer logger, check the bundle");
}
patchFunction("createCleanAreaServiceAreaServer");
patchFunction("roomsToAreas");
const anchor = src.indexOf("\nfunction roomsToAreas(");
src = src.slice(0, anchor) + "\n" + helper + src.slice(anchor);
writeFileSync(file, src);
console.log("patched", file);
