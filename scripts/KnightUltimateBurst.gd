extends Node3D
## One reusable local bank of common effects, warmed at ready. These instances
## keep running inside the ultimate's paused world without waking other VFX.
const Puff=preload("res://vfx/common/DustPuff.tscn")
const Ring=preload("res://vfx/common/DustRing.tscn")
const Debris=preload("res://vfx/common/Debris.tscn")
const Sparks=preload("res://vfx/common/Sparks.tscn")
var effects: Array[Node3D]=[]
var manager: Node
var ground_color: Color=Color("c9b48a")
var ground_y: float=0
var query: PhysicsRayQueryParameters3D
var _warmed: bool=false

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 manager=get_node_or_null("/root/VFXManager")
 for scene in [Puff,Puff,Puff,Puff,Puff,Puff,Puff,Puff,Puff,Puff,Puff,Puff,Ring,Debris,Debris,Sparks,Sparks]:
  var effect: Node3D=scene.instantiate();add_child(effect);effects.append(effect);effect.process_mode=Node.PROCESS_MODE_ALWAYS
 query=PhysicsRayQueryParameters3D.new();query.collision_mask=1
 call_deferred("warmup")

func warmup() -> void:
 if _warmed or DisplayServer.get_name()=="headless":return
 _warmed=true
 var viewport: SubViewport=SubViewport.new();viewport.size=Vector2i(64,64);viewport.own_world_3d=true;viewport.msaa_3d=get_viewport().msaa_3d;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
 var camera: Camera3D=Camera3D.new();viewport.add_child(camera);camera.position=Vector3(0,12,32);camera.look_at(Vector3(0,12,0));camera.current=true
 var source: Node3D=get_parent()
 var environment: WorldEnvironment=WorldEnvironment.new();environment.environment=get_world_3d().environment;viewport.add_child(environment)
 var sun: DirectionalLight3D=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-30,0);sun.shadow_enabled=true;viewport.add_child(sun)
 for mesh: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
  if mesh==source._sigil:continue
  var prime: MeshInstance3D=MeshInstance3D.new();prime.mesh=mesh.mesh;prime.material_override=mesh.material_override
  prime.transform=source.global_transform.affine_inverse()*mesh.global_transform;viewport.add_child(prime)
 for effect in effects:
  effect.reparent(viewport,false);effect.configure(.2,64);effect.apply_quality(1.2);effect.play({"color":ground_color})
 for i in 6:await RenderingServer.frame_post_draw
 viewport.get_texture().get_image()
 for effect in effects:effect.reset();effect.reparent(self,false)
 viewport.queue_free()

func sample_ground(origin: Vector3) -> void:
 ground_y=origin.y;query.from=origin+Vector3.UP*2;query.to=origin-Vector3.UP*4
 var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
 if hit.is_empty():return
 ground_y=hit.position.y
 var body: Node=hit.collider
 if body.has_meta("ground_color"):ground_color=body.get_meta("ground_color");return
 var meshes: Array[Node]=body.find_children("*","MeshInstance3D",true,false)
 if meshes.is_empty() and body.get_parent():meshes=body.get_parent().find_children("*","MeshInstance3D",true,false)
 var area: float=-1
 for mesh: MeshInstance3D in meshes:
  if not mesh.mesh:continue
  var bounds: AABB=mesh.global_transform*mesh.mesh.get_aabb()
  if not bounds.grow(.05).has_point(hit.position) or bounds.size.x*bounds.size.z<=area:continue
  var material: Material=mesh.material_override if mesh.material_override else mesh.get_active_material(0)
  if material is StandardMaterial3D:ground_color=material.albedo_color;area=bounds.size.x*bounds.size.z

func impact(origin: Vector3,radius: float) -> void:
 stop()
 if manager and not manager.enabled:return
 var multiplier: float=[.5,1.0,1.2][manager.quality if manager else 1]
 for i in effects.size():
  var at: Vector3=origin;at.y=ground_y
  var params: Dictionary={"color":ground_color,"ground_y":ground_y}
  if i<8:
   var angle: float=TAU*i/8.0;var outward: Vector3=Vector3(cos(angle),.15,sin(angle)).normalized()
   at+=Vector3(cos(angle),0,sin(angle))*radius*.35
   params.merge({"scale":1.8,"amount_scale":.85,"particle_lifetime":1.5,"direction":outward,"spread":16.0,"speed_min":16.0,"speed_max":24.0})
  elif i<12:
   var angle: float=TAU*(i-8)/4;at+=Vector3(cos(angle),0,sin(angle))*.7
   params.merge({"scale":3.0,"amount_scale":.6,"particle_lifetime":1.6,"direction":Vector3.UP,"speed_min":3.0,"speed_max":5.5})
  elif i==12:params.merge({"radius":radius*1.8,"amount_scale":1.0,"particle_lifetime":1.35})
  elif i<15:params.merge({"scale":1.5,"amount_scale":1.0,"particle_lifetime":1.8,"speed_min":3.5,"speed_max":7.5})
  else:
   at.y+=.7;params.merge({"color":Color(1,.83,.57),"amount_scale":.9,"direction":Vector3(i-15.5,.7,0).normalized(),"speed_min":6.0,"speed_max":11.0})
  effects[i].global_transform=Transform3D(Basis.IDENTITY,at)
  effects[i].configure(2.0,64);effects[i].apply_quality(multiplier);effects[i].play(params)
  var particle: GPUParticles3D=effects[i].particles
  particle.process_mode=Node.PROCESS_MODE_ALWAYS
  particle.lifetime=params.get("particle_lifetime",particle.lifetime)
  var motion: ParticleProcessMaterial=effects[i].motion
  motion.direction=params.get("direction",Vector3.UP)
  motion.spread=params.get("spread",65.0)
  if i<8:motion.scale_min=.55;motion.scale_max=1.15
  motion.initial_velocity_min=params.get("speed_min",motion.initial_velocity_min)
  motion.initial_velocity_max=params.get("speed_max",motion.initial_velocity_max)
  particle.restart();particle.emitting=true

func stop() -> void:
 for effect in effects:effect.reset()

func active_particles() -> int:
 var count: int=0
 for effect in effects:
  if effect.active:count+=effect.effective_particles()
 return count
