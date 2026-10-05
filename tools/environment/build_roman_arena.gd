extends SceneTree
var builders:Dictionary={}
var palette:Dictionary={"Stone":Color("cbbb9d"),"Trim":Color("eee0bb"),"Dark":Color("675340"),"Brick":Color("9e6c50"),"Bronze":Color("b58b40"),"Crowd":Color.WHITE}
var rng:=RandomNumberGenerator.new()
var root_visual:Node3D
func _initialize()->void:call_deferred("build")
func init_builder(key:String)->void:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);builders[key]=st
func tri(key:String,a:Vector3,b:Vector3,c:Vector3,color:Color,ua:Vector2=Vector2.ZERO,ub:Vector2=Vector2.ZERO,uc:Vector2=Vector2.ZERO)->void:
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
func ring(key:String,r1:float,r2:float,y:float,height:float,color:Color,segments:int=96)->void:
 for i in segments:
  var a:float=i*TAU/segments;var b:float=(i+1)*TAU/segments
  var tint:Color=color.darkened(rng.randf_range(0,.06))
  quad(key,position(r1,y,b),position(r1,y+height,b),position(r1,y+height,a),position(r1,y,a),tint)
  quad(key,position(r2,y,a),position(r2,y+height,a),position(r2,y+height,b),position(r2,y,b),tint)
  quad(key,position(r1,y+height,b),position(r2,y+height,b),position(r2,y+height,a),position(r1,y+height,a),tint)
func arch(r:float,base:float,angle:float,width:float=3.2,depth:float=1.1)->void:
 var rot:Basis=basis(angle);var origin:Vector3=position(r,base,angle)
 var inner:float=width*.5;var outer:float=inner+.46
 for j in 11:
  var a:float=j*PI/11;var b:float=(j+1)*PI/11
  var p:Array[Vector3]=[]
  for z in [-depth*.5,depth*.5]:
   for q in [Vector2(cos(a)*inner,sin(a)*inner+3.5),Vector2(cos(b)*inner,sin(b)*inner+3.5),Vector2(cos(b)*outer,sin(b)*outer+3.5),Vector2(cos(a)*outer,sin(a)*outer+3.5)]:p.append(origin+rot*Vector3(q.x,q.y,z))
  var color:Color=palette.Trim.darkened(rng.randf_range(.02,.16))
  for f in [[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[0,1,5,4],[3,7,6,2]]:quad("Stone",p[f[3]],p[f[2]],p[f[1]],p[f[0]],color)
 for x in [-inner-.25,inner+.25]:
  box("Stone",Vector3(.50,3.5,depth),origin+rot*Vector3(x,1.75,0),rot,palette.Stone)
  box("Trim",Vector3(.73,.20,depth+.12),origin+rot*Vector3(x,3.43,0),rot,palette.Trim)
func column(r:float,base:float,angle:float,height:float)->void:
 var rot:Basis=basis(angle);var p:Vector3=position(r,base,angle)
 box("Trim",Vector3(.9,.25,.9),p+Vector3.UP*.125,rot,palette.Trim)
 box("Trim",Vector3(.65,height,.65),p+Vector3.UP*(height*.5+.25),rot,palette.Trim)
 box("Trim",Vector3(.96,.26,.96),p+Vector3.UP*(height+.35),rot,palette.Trim)
func banner(r:float,top:float,angle:float,width:float,height:float)->void:
 var rot:Basis=basis(angle);var origin:Vector3=position(r,top,angle)
 for x in 4:
  for y in 6:
   var p:Array[Vector3]=[];var uv:Array[Vector2]=[]
   for ij in [[x,y],[x+1,y],[x+1,y+1],[x,y+1]]:
    var u:float=ij[0]/4.0;var v:float=ij[1]/6.0
    var shape:=Vector3((u-.5)*width,-v*height+pow(v,6)*.18*sin(u*PI),sin(u*PI*4)*.10)
    p.append(origin+rot*shape);uv.append(Vector2(u,v))
   var color:=Color("952d36").darkened(.08 if x%2 else 0)
   tri("Banners",p[0],p[1],p[2],color,uv[0],uv[1],uv[2]);tri("Banners",p[0],p[2],p[3],color,uv[0],uv[2],uv[3])
 # Gold hem and a simple raised diamond, no letters or spell sigils.
 box("Bronze",Vector3(width+.16,.10,.12),origin+rot*Vector3(0,.07,0),rot,palette.Bronze)
 var emblem:Vector3=origin+rot*Vector3(0,-height*.45,-.14)
 # Abstract legion eagle: angular wings, raised body and head.
 for sign_value in [-1.0,1.0]:
  var wing:Array[Vector3]=[]
  for q in [Vector2(0,.12),Vector2(sign_value*.58,.32),Vector2(sign_value*.43,-.12),Vector2(sign_value*.13,-.24)]:wing.append(emblem+rot*Vector3(q.x,q.y,0))
  quad("Bronze",wing[0],wing[1],wing[2],wing[3],palette.Bronze)
 box("Bronze",Vector3(.15,.52,.05),emblem+rot*Vector3(0,-.06,0),rot,palette.Bronze)
 box("Bronze",Vector3(.18,.15,.05),emblem+rot*Vector3(.07,.27,0),rot,palette.Bronze)

func spectator(r:float,y:float,angle:float)->void:
 var p:Vector3=position(r,y,angle);var rot:Basis=basis(angle)
 var clothes:Array[Color]=[Color("694747"),Color("ad8565"),Color("eee0bd"),Color("687563"),Color("4d5260")]
 box("Crowd",Vector3(.43,.63,.29),p+Vector3.UP*.43,rot,clothes[rng.randi_range(0,4)])
 box("Crowd",Vector3(.28,.29,.27),p+Vector3.UP*.90,rot,Color("b99271").darkened(rng.randf_range(0,.18)))
func build()->void:
 rng.seed=10973
 for key in ["Stone","Trim","Dark","Brick","Bronze","Crowd","Banners","Sand"]:init_builder(key)
 root_visual=Node3D.new();root_visual.name="RomanArenaVisual";root.add_child(root_visual)
 # A flat sand fighting floor; the existing octagonal collision stays authoritative.
 for i in 8:tri("Sand",Vector3.ZERO,position(23.08,.004,(i+1)*TAU/8),position(23.08,.004,i*TAU/8),Color.WHITE)
 ring("Dark",23.0,160,-.10,.04,Color("8b795b"),96)
 # Distant faceted hills give the colosseum a setting rather than a floating stage.
 for hill in 9:
  var a:float=hill*TAU/9.0;var center:Vector3=position(205+(hill%3)*26,0,a)
  var radial:Array[float]=[1.0,.80,.52,.23,.035]
  var rise:Array[float]=[0,.32,.67,.93,1]
  var height:float=16+(hill%3)*5
  for band in 4:
   for face in 16:
    var points:Array[Vector3]=[]
    for ij in [[face,band],[face+1,band],[face+1,band+1],[face,band+1]]:
     var theta:float=ij[0]*TAU/16.0
     var r:float=(80+(hill%3)*9)*radial[ij[1]]*(1.0+.08*sin(theta*3+hill))
     points.append(center+Vector3(cos(theta)*r+rise[ij[1]]*8,rise[ij[1]]*height-.08,sin(theta)*r*.82))
    quad("Dark",points[3],points[2],points[1],points[0],Color("96937a").darkened(.012*(face%3)))
 # Eight bronze guardian statues above the podium corners.
 for corner in 8:
  var a:float=corner*TAU/8;var rot:Basis=basis(a);var p:Vector3=position(24.0,5.05,a)
  box("Trim",Vector3(1.45,.65,1.35),p+Vector3.UP*.325,rot,palette.Trim)
  for leg in [-.23,.23]:box("Bronze",Vector3(.30,.90,.35),p+rot*Vector3(leg,1.10,0),rot,palette.Bronze.darkened(.12))
  box("Bronze",Vector3(.90,.90,.50),p+Vector3.UP*1.98,rot,palette.Bronze)
  box("Bronze",Vector3(.52,.57,.50),p+Vector3.UP*2.74,rot,palette.Bronze)
  box("Bronze",Vector3(.70,.14,.66),p+Vector3.UP*2.99,rot,palette.Bronze)
  box("Brick",Vector3(.08,.24,.52),p+Vector3.UP*3.14,rot,Color("7b3231"))
  box("Bronze",Vector3(.63,1.20,.10),p+rot*Vector3(-.62,1.88,-.23),rot,palette.Bronze.darkened(.12))
  box("Bronze",Vector3(.10,2.66,.10),p+rot*Vector3(.63,2.1,0),rot,palette.Bronze)
 # Block courses follow the existing eight walls, preserving the 5m obstruction.
 for wall in 8:
  var a:float=(wall+.5)*TAU/8
  for row in 5:
   for brick in 12:
    if wall%2==0 and brick in [4,5,6,7]:continue
    var local:Vector3=Vector3((brick-5.5)*1.57,.46+row*.94,0)
    box("Stone",Vector3(1.54,.90,1.8),position(22.17,0,a)+basis(a)*local,basis(a),palette.Stone.darkened(rng.randf_range(0,.12)))
  if wall%2==0:
   for x in [-6.2,6.2]:box("Trim",Vector3(6.3,.32,2.15),position(22.17,4.84,a)+basis(a)*Vector3(x,0,0),basis(a),palette.Trim)
  else:box("Trim",Vector3(18.7,.32,2.15),position(22.17,4.84,a),basis(a),palette.Trim)
  box("Dark",Vector3(18.7,.19,.14),position(21.19,.40,a),basis(a),palette.Dark)
 # Seating ramps and aisle stairs form a bowl above the podium.
 for step in 12:
  ring("Stone",23.3+step*1.06,24.36+step*1.06,4.6+step*.67,.67,palette.Stone,96)
  ring("Brick",23.45+step*1.06,24.10+step*1.06,5.29+step*.67,.08,Color("b08368"),96)
 for aisle in 16:
  var a:float=aisle*TAU/16
  for step in 24:box("Trim",Vector3(.95,.18,.53),position(23.7+step*.52,4.96+step*.335,a),basis(a),palette.Trim)
 # Three rhythmic arcade levels around the entire circumference.
 for tier in 3:
  var base:float=tier*6.2
  for bay in 48:
   var a:float=bay*TAU/48
   arch(38.4,base,a,3.35,1.35)
   column(39.25,base-.08,a+PI/48,5.45)
   if tier==0:box("Dark",Vector3(3.15,3.7,.22),position(39.15,1.8,a),basis(a),palette.Dark.darkened(.22))
  ring("Trim",37.8,39.9,base+5.85,.43,palette.Trim,96)
  ring("Brick",38.0,39.6,base+5.52,.18,palette.Brick,96)
 ring("Stone",38.0,39.3,18.7,.75,palette.Stone,96)
 ring("Trim",37.9,39.7,19.45,.24,palette.Trim,96)
 # Segmented linen velarium over the back rows; fighting floor remains open.
 for panel in 24:
  if panel%4==0:continue
  var begin:float=panel*TAU/24.0+.018
  var finish:float=(panel+1)*TAU/24.0-.018
  for radial_step in 4:
   for lateral_step in 4:
    var points:Array[Vector3]=[];var tex:Array[Vector2]=[]
    for ij in [[lateral_step,radial_step],[lateral_step+1,radial_step],[lateral_step+1,radial_step+1],[lateral_step,radial_step+1]]:
     var u:float=ij[0]/4.0;var v:float=ij[1]/4.0
     points.append(position(lerpf(40,33.4,v),lerpf(21.0,18.8,v)-sin(u*PI)*.24,lerpf(begin,finish,u)))
     tex.append(Vector2(u,v))
    var linen:Color=Color("e7cf9d") if panel%3 else Color("ae6048")
    tri("Banners",points[0],points[1],points[2],linen,tex[0],tex[1],tex[2]);tri("Banners",points[0],points[2],points[3],linen,tex[0],tex[2],tex[3])
  box("Dark",Vector3(.16,2.8,.16),position(39.8,20.8,begin),basis(begin),palette.Dark)
 # Gate monuments, closed decorative doors keep the existing boundary honest.
 for gate in 4:
  var a:float=(gate*2+.5)*TAU/8;var rot:Basis=basis(a)
  arch(21.48,.20,a,4.4,.32)
  box("Dark",Vector3(4.30,6.0,.10),position(21.57,3.0,a),rot,palette.Dark)
  box("Dark",Vector3(4.28,4.6,.18),position(21.44,2.34,a),rot,Color("513b29"))
  for plank in 9:box("Brick",Vector3(.40,4.25,.035),position(21.32,2.28,a)+rot*Vector3((plank-4)*.46,0,0),rot,Color("795137"))
  for y in [1.0,3.3]:box("Bronze",Vector3(4.16,.12,.10),position(21.32,y,a),rot,palette.Bronze)
  column(22.0,0,a-.13,5.7);column(22.0,0,a+.13,5.7)
  banner(21.52,9.6,a,2.25,3.8)
 for i in 24:
  var a:float=i*TAU/24
  if i%3==0:banner(36.9,17.0,a,1.65,3.0)
 # Imperial viewing pavilion above the north gate.
 var royal_angle:float=-PI/2;var royal_rot:Basis=basis(royal_angle)
 var royal:Vector3=position(31.8,10.7,royal_angle)
 box("Trim",Vector3(10,.55,4.5),royal,royal_rot,palette.Trim)
 for x in [-4.2,-2.8,2.8,4.2]:
  box("Trim",Vector3(.46,3.4,.46),royal+royal_rot*Vector3(x,1.95,-1.9),royal_rot,palette.Trim)
 box("Trim",Vector3(10.4,.34,4.9),royal+Vector3.UP*3.75,royal_rot,palette.Trim)
 var roof:Array[Vector3]=[]
 for v in [Vector3(-5.4,3.94,-2.6),Vector3(5.4,3.94,-2.6),Vector3(0,5.55,-2.6),Vector3(-5.4,3.94,2.6),Vector3(5.4,3.94,2.6),Vector3(0,5.55,2.6)]:roof.append(royal+royal_rot*v)
 tri("Trim",roof[0],roof[2],roof[1],palette.Trim);tri("Trim",roof[3],roof[4],roof[5],palette.Trim)
 quad("Brick",roof[0],roof[3],roof[5],roof[2],Color("a0573b"))
 quad("Brick",roof[2],roof[5],roof[4],roof[1],Color("a0573b"))
 banner(33.3,14.2,royal_angle,2.4,3.0)
 # One merged static crowd surface: atmosphere only, no AI or hurtboxes.
 for row in [2,5,8,10]:
  for seat in 64:
   if rng.randf()<.18 or seat%8==0:continue
   spectator(23.95+row*1.06,5.27+row*.67,seat*TAU/64+rng.randf_range(-.013,.013))
 var total:int=0
 for key in builders:
  var mesh:ArrayMesh=builders[key].commit();mesh.surface_set_name(0,key)
  var material:Material
  if key=="Sand":
   material=ShaderMaterial.new();material.shader=load("res://assets/shaders/roman_arena_sand.gdshader")
  elif key=="Banners":
   material=ShaderMaterial.new();material.shader=load("res://assets/shaders/roman_arena_banner.gdshader")
  elif key in ["Stone","Trim"]:
   material=ShaderMaterial.new();material.shader=load("res://assets/shaders/arena_weathered_stone.gdshader")
  else:
   var standard:=StandardMaterial3D.new();standard.vertex_color_use_as_albedo=true;standard.roughness=.86;standard.cull_mode=BaseMaterial3D.CULL_DISABLED
   if key=="Bronze":standard.metallic=.65;standard.roughness=.48
   material=standard
  mesh.surface_set_material(0,material)
  var saved:String="res://assets/environment/roman/"+key.to_lower()+".res"
  ResourceSaver.save(mesh,saved)
  var instance:=MeshInstance3D.new();instance.name="Roman"+key;instance.mesh=load(saved)
  if key in ["Sand","Crowd","Banners"]:instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  root_visual.add_child(instance);instance.owner=root_visual
  total+=mesh.surface_get_array_len(0)/3
 root_visual.set_meta("arena_theme","roman_colosseum")
 root_visual.set_script(load("res://scripts/RomanArenaAmbience.gd"))
 var packed:=PackedScene.new();packed.pack(root_visual);ResourceSaver.save(packed,"res://scenes/environments/RomanArenaVisual.tscn")
 print("ROMAN BAKE surfaces=",builders.size()," triangles=",total)
 quit()
