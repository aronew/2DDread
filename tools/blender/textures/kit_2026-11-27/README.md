# DREAD — Reference-matched environment kit

46 separate environmental PNG masters rebuilt using your attached Soul-Fire
Temple image as the direct style reference. Open index.html locally to browse.

These are generated art masters, not exact crops or calibrated Blender renders.
Close visual matching does not guarantee exact reference pixels, exact palette
hexes, repeat seams or mathematically exact projection. No project code changed.

| Folder | Count | Contents |
|---|---:|---|
|textures|9|Worn/damaged/moss paving, gold meander, skull/laurel and sunburst inlays, ashlar/frieze wall, column wrap, emissive soul-fire strip|
|sprites|13|Amphora pair, candles, intact/broken columns, brazier, fire urn, closed/open chest, rubble, candelabra, statue, empty/active nest|
|modules|12|Frieze/pilaster wall, plain frieze wall, hooded relief, fire alcove, banner/torch wall, rock wall, secret cracked wall, door frame, bridge, balustrade, chasm fascia, altar|
|decals|4|Cracks, moss, chips, scorch|
|emission_drafts|8|Candles, brazier, urn, candelabra, nest, alcove, torch, chasm|

The reference supplied the dark fluted columns, simple round pottery, candles,
hooded relief, gold meander, sunbursts, skull/laurel and chasm treatment. Chests,
nests, altar, brazier and explosive urn extend that style using your written brief.

## Import

- textures/ is flat painted artwork for Blender materials. Soul-fire is emissive
  on black; other textures are intended as albedo. Do not use these as shaded props.
- sprites/ and modules/ are isolated shaded masters with transparent alpha.
- decals/ is top-down alpha artwork. The requested75% vertical squash has not
  been applied; account for transparent padding when setting its world size.
- emission_drafts/ contains generated black-backed masks. Source canvas sizes
  are checked, but exact shape, retained color and pixel alignment are unverified.
- Actual dimensions/alpha ranges and hashes are in manifest.json. Files retain
  native generator resolutions; they are not claimed to be2048px. The meander
  strip is3:1 rather than the requested4:1. No images were silently resized.
- Target camera: orthographic yaw45deg, pitch48.6deg,4:3 floor diamond. Generated
  edges approximate that angle. Exact grid calibration requires Blender rendering.
- Target scale:90.51px per ground-axis metre,59.87px per vertical metre. A2x2m
  floor cell should project to256x192px after calibration. These large masters
  are not yet at that scale, and their base-center origins are not calibrated.
- Opposite-facing wall modules are not included. Do not simply mirror lighting
  if an exact upper-left key and consistent shading are required.

## Design dimensions (specifications, not image measurements)

| Asset | Metres |
|---|---|
|Floor texture|2x2 per repeat|
|Wall texture/module|2wide x3tall,0.45deep for standard modules|
|Bridge tile|2x2 footprint,0.35thick|
|Chasm fascia|2long x0.5deep x1tall|
|Balustrade|2long x0.3deep x0.7tall|
|Altar|2x1 footprint,0.8tall|
|Amphorae|1.0/0.75tall, combined~1x1 footprint|
|Candles|0.1–0.6tall on0.6x0.5x0.3 block|
|Intact column|~3.2tall,0.7shaft,1x1plinth|
|Broken column|0.6shaft,1.8shaft above0.35plinth|
|Brazier|~1.1overall including0.6flame|
|Urn|~1.1tall|
|Chest|1.2long x0.7deep x0.7closed height|
|Rubble|2x2footprint, maximum0.9height|
|Candelabra|~1.3tall,0.6base|
|Statue|~1.5tall,0.9x0.9plinth|
|Nest|~1.3x1.1footprint,0.45tall before flames|
|Decals|~1.5across excluding padding|

## Checks and limits

Every PNG decodes. All25 prop/module files have alpha transparency. All8 mask
canvases match their source dimensions. A visible-pixel bright-red/pink threshold
scan passed after correcting the urn to amber; this is not exact hex quantization
or an exhaustive perceptual audit. Thresholds and results are in image_checks.json.

Floor variants and rubble were revised to remove accidental gold borders, alcoves
and fire. Rejected drafts are excluded. Source images were not modified by code;
all art generation and corrective editing used the built-in image tool. Exact
generation prompts and selected revisions are recorded in generation_prompts.json.

Check by hand before shipping:

1. Camera angle, base-center origin, real-world scale, repeat seams and module
   joints against your256x192px grid. Exact correspondence is not certified.
2. Decal alpha over actual floor. Cracks/chips/scorch retain soft surrounding haze
   despite revision; clean those alpha edges if they read as light. Never emit them.
3. Emission overlays at100% zoom: recompute from approved source pixels for exact
   final masks. Keep source and emission under the same resize/crop transform.
4. Chest/nest state overlays and silhouettes at native gameplay resolution. Matched
   canvas dimensions do not prove unchanged body/base pixels.
5. Exact palette and low floor contrast under heavy combat VFX. Colors are approximate.

Suggested light tiers:0 for primary chasm/alcove keys,1 for braziers/urns/active
nests,2 for candles/candelabra/torches. No DEFS light tuples were invented.
Wax, dull bone, pale column texture, bronze, wood and amber colors follow additions
in your individual prompts. Cool shadows stay green-teal rather than adding purple
outside the shared palette. No characters, enemies, UI or combat effects included.
