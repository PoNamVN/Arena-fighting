# Knight V0 common visual library

Uses the existing `/root/VFXManager`; there is no duplicate VFXRoot.

```gdscript
VFXManager.spawn(&"DustPuff", world_position, {
    "scale": 1.0, "amount_scale": 1.0, "color": ground_albedo,
    "ground_y": ground_y, "radius": 1.5, "ground_layer": 8
})
await VFXManager.warmup() # normally performed automatically at startup
VFXManager.camera_recoil(actor, 0) # existing actor hit/block/break recoil (0/1/2)
VFXManager.hit_stop_enabled = false # default; never enable on gameplay animation
VFXManager.hit_stop(preview_animation_player, 0.06) # visual-preview only, 40–80 ms
```

Names: DustPuff, DustRing, Debris, Sparks, Shockwave, GroundDecal.
`spawn` also accepts the legacy Transform3D signature. Default common budget is
300 allocated live particles, `ultimate: true` raises it to 600. Rejected requests
emit `spawn_rejected` (unknown_name, pool_full, not_warmed, particle_budget).
No new effect is bound to gameplay events. Existing effect quality is unchanged.
Common Low/Med/High multipliers are 0.5/1.0/1.2. GPUParticles buffers are fixed
at High capacity; amount_scale is capped by that capacity, not resized per cast.
Dust `color` means ground albedo (desaturated and multiplied by 0.85 internally),
debris uses 0.7; sparks accepts a direct white-orange tint. Dust is unshaded alpha
blend, never emissive, no depth sampling/writing. No soft particles or SSR.

GroundDecal has six leases, a generated deterministic 128px crack texture,
a shallow 4.5cm projection volume, upward-normal rejection, and dedicated
receiver mask `ground_layer` (default render layer 4 / value 8). Tag only ground
meshes with that layer in future integration; V0 does not modify game floors.
Debris collision uses a per-instance GPU collision box with top at ground_y.
It is a rendering collision, never a gameplay physics body. Bounds cover 20m.
Ring is a dust-colored opaque-edge alpha mesh, not a glowing magical aura.
Effect scale is uniform. A timer lease returns after the final particle lifetime.
The manager warms actual instances in an isolated 128px viewport for two rendered
frames; headless reports the rendering warm-up as skipped.

Camera recoil is intentionally reused, retaining its existing intensity/duration
presets. The new optional visual hold never pauses SceneTree or Engine.time_scale;
it is not connected to skills/impact timing. Run `res://test/vfx_gallery.tscn`.
Stress sends five effects together three times, at 100ms intervals. The displayed
particle budget is a conservative count until lifetime expiry, not a GPU readback.
