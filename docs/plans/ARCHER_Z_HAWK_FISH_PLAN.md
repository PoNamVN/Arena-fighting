# Archer Z — Mồi cá và diều hâu khổng lồ

Ngày: 10/10/2026. Trạng thái: **ĐÃ TRIỂN KHAI P1–P3; P4 ĐÃ KIỂM TRA TỰ ĐỘNG/RENDER, CHỜ PLAYTEST CÂN BẰNG**.

Yêu cầu sửa tiếp đã triển khai: treo ngược bằng chân, FPS lật, độ cao 14 m, cooldown 24 giây, dựng lại chim. Các thông số đề xuất bên dưới thuộc bản kế hoạch đầu.

Bản triển khai và bằng chứng kiểm tra: [ARCHER_Z_HAWK_IMPLEMENTATION.md](../ARCHER_Z_HAWK_IMPLEMENTATION.md). Các phần hiện trạng bên dưới ghi nhận trước khi triển khai.

## 1. Yêu cầu đã chốt và đề xuất

Người dùng yêu cầu thay Z của Archer: một mũi tên kẹp/mang con cá bay bám mục tiêu; địch đỡ được để khắc chế; trúng trực tiếp thì diều hâu khổng lồ lao xuống gắp nạn nhân, đưa lên trời, bay một vòng rồi thả; sát thương rơi thấp vì đây là Z. Nâng cấp cả mô hình, rig, animation và VFX. Người dùng xác nhận: **đã bị bắt thì không tự thoát**.

Z chỉ thuộc Archer. Câu trả lời về nhân vật xác nhận chủ sở hữu kỹ năng, chưa xác định riêng danh sách nạn nhân. Đề xuất controller nạn nhân dùng chung cho Knight/Archer/Wizard và dummy; xác minh Archer đấu Knight trong Practice trước, sau đó đủ ba hero. Không mở rộng kit chủ động của Knight/Wizard.

Các con số dưới đây là **thông số khởi điểm để chơi thử**, chưa phải cân bằng được người dùng duyệt. Giữ X/C/V và bắn thường về cơ chế hiện tại. Không thêm escape QTE, summon có HP, AI chiến đấu riêng cho chim, ragdoll toàn thân hay cinematic pause toàn trận.

Tên hiển thị đề xuất: **Mồi cá — Diều hâu săn mồi**. ID đề xuất: `archer_hawk_fish`.

## 2. Hiện trạng được kiểm tra

- Checkout hiện tại: `C:/Users/HP VICTUS/.codex/worktrees/2e2a/Game_3D`. Các đường dẫn D: trong skill/tài liệu trước là lịch sử; triển khai vào checkout được xác minh lúc thực hiện, không xuất nhầm nơi.
- `ArcherCombat.gd`: Z hiện là `archer_rapid_volley`, 6 tên × 7 damage, 25 NL, cooldown 5 s. `start_volley`, input và `PlayerController.try_cast_ability` đang gọi đường này.
- X đã có homing, giới hạn tốc độ quay, ray sweep chống xuyên tường và trail có ngân sách. Tái sử dụng nguyên tắc, nhưng Z mới chỉ một projectile và không dùng quỹ đạo xoắn để vòng qua đỡ.
- `PlayerController.take_damage()` đang trả `void`. Đỡ vẫn có chip damage; front protection/iframe có thể từ chối hit hoàn toàn. **Không dùng HP giảm để suy ra hit không bị đỡ**.
- `is_control_impaired()` hiện chỉ gồm impact stun/polymorph/freeze; chưa có trạng thái bị chim mang đi. Có nhiều lối input, AI và chuyển động phải tích hợp.
- `ArenaPlayBounds.gd` giữ CharacterBody trong giới hạn ngang ở mọi độ cao; cần giữ nạn nhân là actor thật để tiếp tục được giới hạn.
- `PracticeArena` có ENDING/chờ presentation với watchdog. Z mới phải tham gia và không để round kết thúc treo vì chim hoặc nạn nhân.
- `VFXManager` có pool, quality và kiểm tra loại bỏ gameplay node khỏi pooled VFX. Chim/projectile/controller bắt người là gameplay; particles/trail/burst mới là VFX thuần.
- Blender MCP đọc trạng thái/scene thành công: Blender 5.2.2 LTS, add-on 1.8, scene hiện chỉ Cube/Light/Camera. Asset libraries và generators đang tắt; có thể dựng bằng bpy qua MCP, không cần dịch vụ tạo model trả phí.

## 3. Quy tắc gameplay

| Thuộc tính | Đề xuất ban đầu |
|---|---|
| Năng lượng | 25 NL, trừ một lần lúc bắt đầu cast hợp lệ |
| Hồi chiêu | 12 s từ cast; cân nhắc 10 s sau playtest |
| Chọn mục tiêu | Một mục tiêu sống, chọn được, có đường nhìn; tầm 24 m, cone hiện có ±55° |
| Không có mục tiêu | Không cast, không mất NL/cooldown |
| Chuẩn bị / hồi phục Archer | 0,30 s / 0,25 s; chuyển động còn 55% trong chuẩn bị |
| Projectile | Một tên kẹp cá, khoảng 22 m/s, quay tối đa khoảng 100°/s, tuổi thọ tối đa 1,5 s hoặc đi hết 24 m |
| Sát thương tên | 4 khi trúng trực tiếp |
| Sát thương rơi | Tối đa 20, tổng một cast tối đa 24 từ riêng Z |
| Đỡ thành công | 0 HP damage từ Z, mất 10 độ bền đỡ, không gọi chim |
| Phá đỡ từ hit này | Vẫn không bắt; shield-break hiện có xử lý riêng |
| Thời gian khống chế | Mục tiêu khoảng 2,2–2,5 s từ trúng đến lấy lại điều khiển; đo thực tế theo khoảng rơi |
| Độ cao mang nạn nhân | Chân nạn nhân cao khoảng 4–5 m so với mặt sàn hợp lệ |
| Một vòng bay | Một vòng 360° trên mặt phẳng ngang, bán kính khoảng 1,2–1,5 m, quanh vị trí bắt |

Projectile không tự chọn nạn nhân khác nếu mục tiêu chết/mất khả năng chọn. Đề xuất tắt dẫn hướng và cho nó đi hết quãng còn lại; khi va vào đối tượng khác thì tiêu hủy, không chuyển quyền bắt sang người đó. Không xuyên cột/tường.

Đỡ xét theo **hướng projectile thực tại impact**, không theo vị trí Archer lúc cast. Cá bật khỏi khiên/cung rồi tan biến. Đỡ, front protection hoặc iframe đều chặn gọi chim. Perfect Dodge vẫn dùng reward/counter hiện có của hit hợp lệ; không sinh reward lúc thả/rơi.

Hit trực tiếp hợp lệ, nạn nhân còn sống và nhận được CC: gắn cá lên vùng vai/ngực, khóa hành động ngay trong thời gian chim lao xuống, sau đó mang đi. Đã trúng chuỗi này không có escape giữa chừng; khóa bắt đầu tại hit để không xuất hiện cửa sổ né chim trái kỳ vọng. Death/reset/cancel là cleanup hệ thống, không phải cơ chế thoát của người chơi.

Mục tiêu đang có miễn nhiễm hiện có (ví dụ Wizard đang channel storm) giữ quy tắc từ chối hit của game; không bỏ immunity để ép bắt. Không bắt chồng vào carry/freeze/polymorph khác; policy khởi điểm là từ chối cast trên mục tiêu đang chịu các CC đó. Kiểm tra lại tại impact, không tiêu hao/refund lần hai nếu trạng thái thay đổi sau khi tên đã bắn.

Archer lấy lại điều khiển sau hồi phục bắn; vẫn được bắn thường trong lúc chim hoạt động. Không cộng damage bắn thường vào con số 24 của Z. Đây là nguồn sức mạnh combo cần playtest, đặc biệt khi kết hợp V T-rex.

## 4. Chuỗi thời gian và phản hồi

Thời gian sau projectile trúng (không tính thời gian tên bay):

| Pha | Thời gian khởi điểm | Animation / VFX |
|---|---:|---|
| Mark + Dive | 0,35 s | Cá bám vai/ngực; tiếng chim, bóng chim và vệt gió lao xuống |
| Grab + Lift | 0,35 s | Móng khép quanh hai vai, một nhịp vỗ cánh mạnh đưa người lên |
| Carry circle | 0,90 s | Chim nghiêng theo vòng bay 360°, nạn nhân treo dưới chân, tay chân đung đưa |
| Release + Fall | Khoảng 0,55–0,65 s | Móng mở, người rơi theo gravity hiện có; vòng báo điểm đáp đất |
| Landing recovery | 0,20 s | Bụi/chấn động nhỏ, pose chùng gối hoặc ngã thấp rồi phục hồi |

Không làm vòng lộn dọc: mục tiêu vẫn treo dưới chân chim, vòng bay ngang đọc rõ hơn. Không gây damage ở dive, grab, lift hoặc mỗi nhịp cánh. Damage rơi chỉ phát một lần khi tiếp đất hợp lệ.

## 5. Nạn nhân, va chạm và damage rơi

Một effect điều khiển nạn nhân, tên dự kiến `HawkCarryEffect`, với các pha `MARKED → LIFT → CARRY → FALL → RECOVER → IDLE`. Controller Z/chim, tên dự kiến `ArcherHawkSkill`, sở hữu cast và presentation; effect sở hữu chuyển động nạn nhân. Đổi tên theo convention khi thực hiện, không xây framework summon tổng quát.

- Không reparent actor vào xương chim và không chỉ kéo mesh trong khi collider vẫn nằm dưới đất. CharacterBody thật di chuyển theo socket/đường bay bằng displacement có sweep/collision mỗi physics tick.
- Chỉ một nhánh sở hữu chuyển động: khi effect active, PlayerController chạy nhánh effect rồi return. Locomotion, knockback/dodge/counter, AI và pose thường không được ghi đè.
- Socket được chuyển sang world rồi tính vị trí actor theo offset của vai/ngực. Chân chim/IK hoặc pose hỗ trợ bám đúng vai trên từng rig; kiểm thử trang bị Knight và scale từng hero, không mặc định tên xương trái/phải là runtime giống nhau.
- Khóa input đánh, block, dodge, jump, skill và AI di chuyển/tấn công; ngắt startup chưa phát hit, combo/buffer/counter của nạn nhân. Projectile đã phát trước CC không tự bị thu hồi trừ quy tắc reset/death hiện có.
- Collider môi trường và giới hạn sân tiếp tục hoạt động. Capsule chạm cột, trần hoặc tường thì điều chỉnh cả chim lẫn vị trí socket; không giãn người khỏi móng hoặc xuyên geometry.
- Dùng ground query/sweep để chọn tâm vòng an toàn. Gần rìa/cột: giảm bán kính, đổi tâm vào sân. Nếu không thể thực hiện vòng an toàn, ưu tiên một quỹ đạo thu nhỏ; nếu vẫn bế tắc thì thả tại điểm an toàn, ghi lý do, không giả báo đã đủ 360°.
- Fall dùng gravity hiện tại, không tăng gravity toàn game; phát damage từ metadata của cast ở lần `is_on_floor`/ground contact được xác minh, không từ animation event đơn độc.
- Đề xuất fall damage = `20 × clamp(độ cao rơi thực / độ cao chuẩn, 0, 1)`; rơi thấp do vật cản không gây đủ 20. Không thêm generic fall damage cho nhảy thường và tránh tính hai lần nếu hệ thống fall damage được thêm sau này.
- Nạn nhân không block/dodge khi đang bị mang hoặc rơi. Payload fall không phát Perfect Dodge/counter/độ bền khiên; vẫn tôn trọng dead/damage rejection hiện có. Không bypass health system bằng cách sửa trực tiếp HP.
- Nạn nhân vẫn nhận damage từ người khác; death ưu tiên cao nhất, không tiếp tục vòng bay/get-up hoặc gây damage sau chết. CC mới không kéo dài vô hạn hay chiếm chuyển động khi carry đang sở hữu.
- Cancel/reset/đổi scene/mất target: clear idempotent, dừng timer/tween/audio/VFX, bỏ cá, khôi phục quyền điều khiển/pose/camera. Nếu ở trên cao, thả về physics an toàn hoặc điểm sàn đã xác minh; không teleport vào tường, không để freefall vô hạn. Có watchdog riêng cho chuỗi.
- Caster chết hoặc round kết thúc: đề xuất hủy phần còn lại, đưa nạn nhân về trạng thái an toàn, không phát damage mới. Nếu fall đã kết liễu, ENDING chỉ chờ landing presentation ngắn theo watchdog hiện có.

Trước khi code cần một kết quả hit đáng tin cậy: `accepted`, `blocked`, `dodged`, `immune`, `killed`, HP/shield outcome. Ưu tiên bổ sung kết quả từ damage resolver hiện có, giữ tương thích caller bỏ qua return. Không gọi damage hai lần hay tính lại block sau khi shield vừa vỡ. Test độc lập trường hợp blocked vẫn giảm HP ở các skill cũ để Z không vô tình bắt người đang đỡ.

## 6. Blender: cá, tên và rig diều hâu

Dựng scene làm việc riêng `Archer_Hawk_Z_Work`; giữ scene đang mở và các asset Archer/T-rex cũ. Lưu source vào `blender/archer_hawk_z.blend`, script tái tạo vào `blender/build_archer_hawk_z.py` trong checkout thực.

**Cá và tên:** mesh cá nhận ra rõ silhouette đầu/thân/đuôi/vây; màu bạc xanh, bụng sáng. Đầu tên có kẹp nhỏ hai bên giữ cá, không cần animation xuyên cơ thể. Cá rung nhẹ đuôi khi chuẩn bị/bay, ngừng hoặc giãy ít khi dính mục tiêu. Tổng cá+kẹp+tên mục tiêu dưới 500 triangles; tái sử dụng arrow mesh nếu phù hợp. Hai pose/model variant bay và bám vai không có collider gameplay riêng.

**Diều hâu:** body khoảng 1,5–2 m, sải cánh khoảng 4,5–5,5 m để đủ đọc là chim khổng lồ mang được một người. Style low-poly hợp forest archer: lưng nâu, ngực kem, viền lông tối, mắt vàng, mỏ và móng nổi rõ. Chọn hình dáng từ silhouette trước, giữ mesh dưới khoảng 3.000 triangles. Lông đầu cánh thành các khối rõ thay vì hàng trăm alpha cards.

Rig dự kiến 20–24 xương deform: root/body, chest, neck/head, tail, ba xương mỗi cánh và nhóm feather tips, thigh/shin/foot mỗi bên, hai nhóm móng mỗi chân. Có socket `GrabSocket.L/R` ở móng và một anchor giữa hai chân để đặt nạn nhân. Audit rest pose, local axes, weight và import trước khi chốt tên/thứ bậc.

Clip cần có: `dive`, `grab`, `lift`, `carry_flap` (loop), `release`, `exit`. Dive gập cánh; grab chân vươn/móng khép; lift vỗ mạnh; carry có wing downstroke/upstroke, đuôi điều hướng và chân giữ ổn định; release mở móng rồi chim tách khỏi hướng rơi. Animation root không đồng thời kéo vị trí gameplay; vòng bay do controller điều khiển, banking theo tiếp tuyến. Keyframe hook/event VFX chỉ phục vụ hình ảnh, hit không phụ thuộc riêng frame animation.

Xuất `assets/models/hunter_fish_arrow.glb` và `assets/models/forest_hawk.glb`, cùng source và animation clips. glTF GLB, selected collection, materials, +Y up; kiểm scale/pivot, normals, clip names/duration, sockets và shape sau import Godot. Xem viewport nhiều góc và từng pha qua Blender MCP rồi xác minh lại trong Godot. Không báo animation hoàn tất chỉ từ screenshot Blender.

Pose nạn nhân cho cả ba rig: bị bắt hai vai, chân rời đất, thân treo, đung đưa nhẹ theo gia tốc, freefall, landing. Tận dụng bone mapping/rest cache và procedural pose hiện có; rig thiếu xương có fallback mềm. Không thay GLB/skeleton hero đang dùng để làm được Z.

## 7. VFX, âm thanh và camera

- Chuẩn bị: điểm sáng nhỏ xanh bạc ở kẹp cá, bow draw/release recoil; không che tay/cá bằng vòng phép lớn.
- Projectile: trail mảnh xanh bạc có core rõ trên nền sáng, giọt/spark ít, cá vẫn nhìn thấy. Hướng tail khớp hướng bay thực. Dấu khóa nhỏ quanh mục tiêu, không dùng màu cảnh báo đồng minh lẫn địch.
- Block: cá/tên bật lệch, spark khiên và splash nhẹ tại impact; tín hiệu âm thanh khác rõ với trúng. Không có bóng chim/mark sau block.
- Mark/dive: cá bám vai; biểu tượng móng nhỏ, tiếng kêu từ trên cao, bóng silhouette chim và vệt gió thuôn theo đường dive, vài lông bay. Không cần đèn động lớn.
- Grab/lift: vòng bụi nhỏ tại nơi chân rời đất, gust theo downstroke, vài lông; hiệu ứng không che tiếp xúc móng-vai.
- Carry: vệt gió đầu cánh, banking thân/đuôi, bóng dưới đất di chuyển đúng; vòng bay nhìn được từ TPS. Không để trail tạo tường sáng kín quanh người.
- Release/fall/landing: mở móng có flash nhỏ, streak gió ngắn trên nạn nhân, marker điểm rơi đồng bộ ground query; bụi/ring nhỏ lúc tiếp đất thật. Damage number rơi xuất một lần, không làm shockwave lớn như V.
- Audio: bow/cá bay, block splash, hawk cry, dive whoosh, flap, grab, fall/landing. Spatial audio; tránh loop còn chạy sau reset. Chỉ dùng asset có quyền sử dụng rõ ràng hoặc tự tạo.
- Camera mặc định giữ quyền điều khiển Archer; không tự chuyển sang góc trên cao của V. Camera nạn nhân theo actor với smoothing/collision; hạn chế roll, không lộn camera khi người rơi. Nếu FPS bị thân/cánh che, offset/presentation ưu tiên khả năng đọc và comfort. Rung landing ngắn và nhỏ.
- Tái sử dụng VFXManager pool/quality; đánh dấu phần báo hit/mark/landing thiết yếu theo contract hiện có. Tắt VFX hoặc quality LOW không được tắt projectile, chim cần thiết để đọc hành động, damage/CC hay thay thời gian chuỗi.
- Ngân sách khởi điểm: một cá/projectile, một chim/cast, tối đa 24 trail segments, khoảng 16–24 particles cho burst, lifetime hữu hạn. Materials/meshes cache; pool phần trang trí; cleanup cả geometry/socket effects. Kiểm OpenGL Compatibility và Forward+; không phụ thuộc bloom để đọc skill.

## 8. Các phần phải cập nhật

- `ArcherCombat.gd`: equip Z mới, input, interrupt/reset, pose/HUD marker; thay đường Z cũ, giữ helpers trail Counter/X vẫn dùng.
- `PlayerController.gd`: dispatch skill_1, movement/CC guard, damage outcome, victim pose/locomotion priority. `PracticeOpponent.gd`: AI tôn trọng carry lock và warning cleanup.
- Script/scene mới cho cast/chim và effect nạn nhân; integration dummy nếu dùng cho test. Không đặt capture logic vào pooled VFX.
- `CombatSpectacle.gd`: loại tham chiếu volley đã bỏ khỏi pose và thêm release Z theo pha. Không phá pose bắn thường/X/Counter.
- `CombatTestHUD.gd`, `PracticeArena.gd`: tên/giá/cooldown mới, reset, presentation busy và ENDING cleanup. VFX definitions/library cho phần trang trí.
- Tests đang expect `archer_rapid_volley` hoặc 6 tên phải cập nhật/đổi mục đích; đặc biệt basic, volley, defense, X/C, spiral, ultimate, spectacle và runner regression. File test X/C/spiral/ultimate hiện kế thừa volley test: kiểm helper trước khi đổi/xóa base.
- Tài liệu checkpoint/handoff chỉ cập nhật khi có implementation được kiểm chứng; lượt này chỉ thêm kế hoạch.

## 9. Lộ trình và tiêu chí hoàn tất

**P1 — Gameplay prototype:** cá/chim proxy đơn giản, hit outcome, một projectile homing, block/iframe, carry physics + vòng 360° + landing damage. Hoàn tất khi người thật/AI/dummy không xuyên sân, không double damage, không kẹt input. Không gọi proxy là visual hoàn chỉnh.

**P2 — Blender asset/animation:** cá+kẹp, diều hâu rigged và sáu clip; source/export/import, socket theo rig nạn nhân. Hoàn tất khi key poses đọc rõ, wing weights không gãy, móng giữ đúng vai, loop nối mượt.

**P3 — VFX/audio/camera:** từng phase theo event, pool/quality, TPS/FPS và integration combat spectacle. Hoàn tất khi trúng/đỡ/trượt đọc được, camera không giành điều khiển Archer, landing đồng bộ thật.

**P4 — Regression/playtest/cân bằng:** test runtime và renderer thật, review screenshot/video các pha; đo vòng bay, tổng khóa, damage, cooldown, số node sau spam/replay. Chỉ đổi thông số sau dữ liệu và cảm nhận playtest.

Các tình huống bắt buộc: no target/thiếu NL/cooldown; chuẩn bị bị ngắt; đỡ trước/sau lưng/vỡ đỡ; front protection; Perfect Dodge; target chết/ẩn sau cast; projectile đụng tường; từng hero và AI bị bắt không dùng được skill/né; miễn nhiễm channel storm; trần/cột/rìa sân/sàn cao; vòng đủ 360° khi sân thoáng; rơi thấp giảm damage; landing chỉ một hit; caster/target chết giữa chuỗi; pause/resume; ENDING, replay, đổi hero/scene, camera FPS/TPS; VFX LOW/OFF; nhiều cast liên tục không tăng node/particles vô hạn. X/C/V/bắn thường và Counter giữ hành vi cũ.

Lượt lập kế hoạch chưa chạy test; kết quả triển khai mới được ghi trong tài liệu bàn giao. Chưa benchmark FPS hoặc chốt cân bằng bằng playtest người thật. Rủi ro chính: CC khoảng 2,5 s có thể mạnh hơn con số damage gợi ý, combo V có thể quá khó đối phó; điều khiển nạn nhân và camera/va chạm là phần cần prototype trước khi đánh bóng asset.
