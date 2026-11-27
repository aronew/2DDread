# DREAD — Floor and pit reference match

Floor and pit masters generated directly against your supplied screenshot.

## Contents

| File | Intended use |
|---|---|
|textures/floor_albedo.png|Flat top-down painted floor texture, one full repeat covers2x2m|
|sprites/floor_isometric.png|Shaded isolated2x2m floor tile with thin side edge|
|pits/pit_complete.png|Complete square2x2m soul-fire opening with coping and retaining faces|
|pits/pit_edge_i.png|Straight2m pit edge along ground i-axis|
|pits/pit_edge_j.png|Straight2m pit edge along perpendicular ground j-axis|
|pits/pit_inner_corner.png|Concave inside pit corner|
|pits/pit_outer_corner.png|Convex walkway corner facing the void|
|pits/bridge_crossing.png|2x4m bridge with gold meander edges and sunburst plates|

Floor direction: broad50–90cm slabs, about3across/down per2m square, muted olive
and green-black paint, chipped angular outlines, fine cracks, restrained grout.
Pit direction: narrow coping at floor level, plain masonry dropping~1.4m into
green-black depths, pointed green soul-fire low inside. No arched wall niches.

These are generated matches, not exact extractions from the screenshot. A single
scene image cannot supply hidden faces or a guaranteed seamless flat texture.
Exact game-camera projection, origins, pixel scale and modular joints remain to
be calibrated. Numeric physical sizes are design targets, not certified image
measurements. Colors are not quantized to exact hexes.

## Hand checks

1. Floor repeat seams and slab scale at one repeat per2x2m.
2. Tile diamond and module joins against the256x192px grid, yaw45deg/pitch48.6deg.
3. Pit lip at walkable floor height; retaining masonry should descend, not block
   movement above the lip. Match collision to intended geometry rather than PNG bounds.
4. Transparent margins and flame silhouettes; source shadows/light are baked into
   shaded sprites. The narrowed edge/corner sprites retain soft surrounding halos
   despite an attempted cleanup; clean their alpha before shipping. Separate
   emission masks are not included in this focused pack.

PNG integrity, native dimensions and transparency are recorded in manifest.json.
Exact image prompts are included. Original files and earlier kits are preserved.
