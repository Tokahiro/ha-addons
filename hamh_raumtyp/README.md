# Matter Hub (area type test)

Test build of [Home-Assistant-Matter-Hub](https://github.com/RiDDiX/home-assistant-matter-hub) 2.0.60.

Upstream sets `areaType` of every vacuum service area to `null`. This build
patches the bundled CLI at image build time (`patch.mjs`) so each area gets an
area type from the Matter Common Area namespace, derived from the HA area.

## How the area type is chosen

1. Option `area_types`: comma-separated `area_id=Tag` pairs, for example
   `tobins_zimmer=Office,ilarias_zimmer=Bedroom`. Use `none` for no type.
   A numeric tag id also works.
2. Otherwise a keyword match on the HA area id and name (German and English),
   for example `kuche` -> Kitchen, `flur` -> Hallway, `bad` -> Bathroom.
3. No match: `null`, as upstream.

The log shows one line per area, for example
`hamh_raumtyp: Küche -> areaType Kitchen (47)`.

## Notes

- Base image: `ghcr.io/riddix/home-assistant-matter-hub-addon:2.0.60`.
- The build fails if the patch does not apply, so a changed upstream bundle is
  noticed early.
- Uses its own storage. Stop the original Matter Hub before starting this one
  if both use the same port.
