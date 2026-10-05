extends SceneTree
var builders:Dictionary={}
var root_visual:Node3D
var detail_origin:Vector3=Vector3.ZERO
var DETAIL_SCALE:Vector3=Vector3.ONE
func _initialize()->void:call_deferred("build")
func init_builder(key:String)->void:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);builders[key]=st
func tri(key:String,a:Vector3,b:Vector3,c:Vector3,color:Color,ua:Vector2=Vector2.ZERO,ub:Vector2=Vector2.ZERO,uc:Vector2=Vector2.ZERO)->void:
 a=detail_origin+(a-detail_origin)*DETAIL_SCALE;b=detail_origin+(b-detail_origin)*DETAIL_SCALE;c=detail_origin+(c-detail_origin)*DETAIL_SCALE
 var st:SurfaceTool=builders[key];var normal:Vector3=(b-a).cross(c-a).normalized()
 for item in [[a,ua],[c,uc],[b,ub]]:
  st.set_normal(normal);st.set_color(color);st.set_uv(item[1]);st.add_vertex(item[0])
func quad(key:String,a:Vector3,b:Vector3,c:Vector3,d:Vector3,color:Color)->void:
 tri(key,a,b,c,color);tri(key,a,c,d,color)
func basis(angle:float)->Basis:
 return Basis(Vector3(sin(angle),0,-cos(angle)),Vector3.UP,Vector3(cos(angle),0,sin(angle)))
func position(r:float,y:float,angle:float)->Vector3:return Vector3(cos(angle)*r,y,sin(angle)*r)
func box(key:String,size:Vector3,origin:Vector3,rotation:Basis=Basis.IDENTITY,color:Color=Color.WHITE)->void:
 var h:=size*.5
 var points:Array[Vector3]=[]
 for p in [Vector3(-h.x,-h.y,-h.z),Vector3(h.x,-h.y,-h.z),Vector3(h.x,h.y,-h.z),Vector3(-h.x,h.y,-h.z),Vector3(-h.x,-h.y,h.z),Vector3(h.x,-h.y,h.z),Vector3(h.x,h.y,h.z),Vector3(-h.x,h.y,h.z)]:points.append(origin+rotation*p)
 for f in [[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[0,1,5,4],[3,7,6,2]]:quad(key,points[f[0]],points[f[1]],points[f[2]],points[f[3]],color)

func solid_box(size:Vector3,at:Vector3,rot:Basis,label:String)->void:
 var shape:=BoxShape3D.new();shape.size=size
 collider(shape,at,rot,label)
func collider(shape:Shape3D,at:Vector3,rot:Basis,label:String)->void:
 var body:=StaticBody3D.new();body.name=label;body.collision_layer=1;body.collision_mask=0
 root_visual.add_child(body);body.owner=root_visual;body.transform=Transform3D(rot,detail_origin+(at-detail_origin)*DETAIL_SCALE);body.scale=DETAIL_SCALE
 var collision:=CollisionShape3D.new();collision.name="Shape";collision.shape=shape
 body.add_child(collision);collision.owner=root_visual
func pillar(at:Vector3,height:float,rot:Basis,label:String,broken:bool)->void:
 var cream:=Color("c8c2ad");var trim:=Color("ded4b9")
 box("Trim",Vector3(1.12,.20,1.12),at+Vector3.UP*.10,rot,trim)
 solid_box(Vector3(1.12,.20,1.12),at+Vector3.UP*.10,rot,label+"Base")
 box("Stone",Vector3(.94,.14,.94),at+Vector3.UP*.27,rot,cream)
 solid_box(Vector3(.94,.14,.94),at+Vector3.UP*.27,rot,label+"Step")
 var bottom:float=.34;var top:float=height-.30 if not broken else height
 # Alternating facets cut eight shallow flutes; capped ends avoid holes.
 for i in 32:
  var t:float=i*TAU/32;var u:float=(i+1)*TAU/32
  var r:float=.43 if i%4 in [0,3] else .385
  var s:float=.43 if (i+1)%4 in [0,3] else .385
  var v:=Vector3(cos(t)*r,0,sin(t)*r);var w:=Vector3(cos(u)*s,0,sin(u)*s)
  var y:float=top+(.055*sin(t*3) if broken else 0)
  var z:float=top+(.055*sin(u*3) if broken else 0)
  quad("Stone",at+v+Vector3.UP*bottom,at+v+Vector3.UP*y,at+w+Vector3.UP*z,at+w+Vector3.UP*bottom,cream.darkened(.06 if i%4 in [1,2] else 0))
  tri("Stone",at+Vector3.UP*top,at+w+Vector3.UP*z,at+v+Vector3.UP*y,cream)
 var shaft:=CylinderShape3D.new();shaft.radius=.43;shaft.height=top-bottom
 collider(shaft,at+Vector3.UP*(top+bottom)*.5,Basis.IDENTITY,label+"Shaft")
 if not broken:
  box("Trim",Vector3(.96,.16,.96),at+Vector3.UP*(height-.22),rot,trim)
  box("Trim",Vector3(1.16,.14,1.16),at+Vector3.UP*(height-.07),rot,trim)
  solid_box(Vector3(.96,.16,.96),at+Vector3.UP*(height-.22),rot,label+"CapitalLower")
  solid_box(Vector3(1.16,.14,1.16),at+Vector3.UP*(height-.07),rot,label+"CapitalUpper")
func build()->void:
 init_builder("Stone");init_builder("Trim")
 root_visual=Node3D.new();root_visual.name="GreekArenaRuins";root.add_child(root_visual)
 for cluster in 4:
  var angle:float=PI/4+cluster*PI/2+(.18 if cluster==1 else 0.0);var rot:Basis=basis(angle);var origin:Vector3=position(15.8,0,angle)
  detail_origin=origin
  DETAIL_SCALE=[Vector3(2.1,2.85,2.1),Vector3(2.45,2.15,2.45),Vector3(1.9,3.1,1.9),Vector3(2.3,2.55,2.3)][cluster]
  pillar(origin+rot*Vector3(-1.85,0,0),3.35,rot,"Cluster%dTall"%cluster,false)
  DETAIL_SCALE.y*=.85 if cluster%2 else 1.1
  pillar(origin+rot*Vector3(1.85,0,0),1.40,rot,"Cluster%dBroken"%cluster,true)
  DETAIL_SCALE.y=[1.65,2.1,1.45,1.85][cluster]
  # Three courses, staggered joints, broad coping and a restrained Greek-key frieze.
  for row in 3:
   for brick in 3:
    box("Stone",Vector3(.94,.29,.68),origin+rot*Vector3((brick-1)*.96,.16+row*.30,0),rot,Color("b8b099").darkened(.025*((row+brick)%3)))
  solid_box(Vector3(2.86,.91,.68),origin+Vector3.UP*.455,rot,"Cluster%dWall"%cluster)
  box("Trim",Vector3(3.04,.17,.82),origin+Vector3.UP*.995,rot,Color("ded4b9"))
  solid_box(Vector3(3.04,.17,.82),origin+Vector3.UP*.995,rot,"Cluster%dCoping"%cluster)
  for side in [-1,1]:
   for repeat in 5:
    var x:float=(repeat-2)*.56
    for part in [Vector4(x,.78,.32,.045),Vector4(x-.14,.70,.045,.16),Vector4(x-.02,.63,.25,.045)]:
     box("Trim",Vector3(part.z,part.w,.018),origin+rot*Vector3(part.x,part.y,side*.349),rot,Color("dfd5bb"))
 # Smaller ruin accents sit between the main groups, close to the outer edge.
 for accent in 4:
  var angle:float=accent*PI/2+.14;var rot:Basis=basis(angle);var origin:Vector3=position(18.5,0,angle)
  detail_origin=origin
  DETAIL_SCALE=[Vector3(1.8,2.6,1.8),Vector3(1.6,3.1,1.6),Vector3(1.9,2.1,1.9),Vector3(1.7,2.8,1.7)][accent]
  pillar(origin,1.05,rot,"Accent%dDrum"%accent,true)
  var stone_rot:Basis=rot*Basis(Vector3.UP,.24)
  var fallen:Vector3=origin+rot*Vector3(1.45,.38,.15)
  box("Stone",Vector3(1.35,.76,.68),fallen,stone_rot,Color("b8b099"))
  solid_box(Vector3(1.35,.76,.68),fallen,stone_rot,"Accent%dFallen"%accent)
  box("Trim",Vector3(1.42,.11,.75),fallen+Vector3.UP*.31,stone_rot,Color("ded4b9"))
  for stripe in 3:
   box("Trim",Vector3(.16,.38,.025),fallen+stone_rot*Vector3((stripe-1)*.32,0,-.351),stone_rot,Color("dfd5bb"))
 var total:int=0
 DirAccess.make_dir_recursive_absolute("res://assets/environment/greek")
 for key in builders:
  var mesh:ArrayMesh=builders[key].commit();mesh.surface_set_name(0,"Greek"+key)
  var mat:=ShaderMaterial.new();mat.shader=load("res://assets/shaders/arena_weathered_stone.gdshader")
  mesh.surface_set_material(0,mat)
  var path:String="res://assets/environment/greek/"+key.to_lower()+".res"
  ResourceSaver.save(mesh,path)
  var visual:=MeshInstance3D.new();visual.name=key;visual.mesh=load(path);root_visual.add_child(visual);visual.owner=root_visual
  total+=mesh.surface_get_array_len(0)/3
 root_visual.set_meta("triangles",total);root_visual.set_meta("clear_center_radius",10.0)
 var packed:=PackedScene.new();packed.pack(root_visual);ResourceSaver.save(packed,"res://scenes/environments/GreekArenaRuins.tscn")
 print("GREEK BAKE triangles=",total," surfaces=2 colliders=56");quit()

