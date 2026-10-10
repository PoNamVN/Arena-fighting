# Bàn giao — Hit reaction, Z hất văng và ragdoll có hồi phục

Ngày: 06/10/2026 · Trạng thái: **ĐÃ HOÀN TẤT & ĐÃ TINH CHỈNH THEO PHẢN HỒI TEST THỰC TẾ**.
Mục tiêu: Đạt 100% yêu cầu về độ bay xa lơ lửng của đòn Z, hoạt ảnh ragdoll vật lý rõ ràng không bị đè animation, thời gian nằm/đứng dậy có trọng lượng và cơ chế Wake-up Block chống chuỗi stun-lock.

## 1. Quyết định và giới hạn

**Người dùng đã chốt:**
- Z trúng trực tiếp: hất thấp khoảng 0,6–0,9 m, văng 3–4 m rồi choáng.
- Z được đỡ: giảm lực đẩy, chỉ khựng ngắn. Vỡ khiên mới choáng mạnh.
- Trong khi bị hất/choáng/hồi phục, không spam đánh lại; AI và người chơi chịu cùng quy tắc.
- Phản ứng mềm: đòn nhẹ vẫn đứng nhưng khớp có độ trễ; Z mạnh có ngã/ragdoll, rồi blend sang đứng dậy.
- Giữ phạm vi sân ở mọi độ cao; có va chạm cột, tường và mặt đất.
- Không commit nếu chưa có yêu cầu riêng. Lượt tạo tài liệu này không sửa gameplay, mesh, rig hay animation.

**Thông số khởi điểm, chưa phải quyết định cân bằng cuối:** Z bay cao 0,75 m, xa 3,5 m trong sân phẳng không vật cản; choáng sau tiếp đất 0,40 s; đứng dậy 0,6–0,9 s; blend lấy lại animation 0,15–0,25 s. Đòn thường 1/2: hit-stun 0,12–0,18 s, đẩy 0,2–0,4 m; đòn 3: 0,25–0,35 s, đẩy 0,7–1 m. Đỡ Z: khựng 0,10–0,18 s, đẩy 0,4–0,8 m. Đụng vật cản được phép đi ngắn hơn 3–4 m.

Không đổi sát thương, năng lượng, hồi chiêu, hitbox, tầm phát hiện mục tiêu, timing impact, hướng lao, bảo vệ trước của Z. Ngoại lệ được phép là **phản ứng của nạn nhân** (lực hất, stun, gián đoạn, ngã và hồi phục). Không tự mở rộng ragdoll sang X/C/V, đổi miễn khống chế của ultimate khác, thêm sát thương va tường, hoặc đổi Perfect Dodge. Không nâng phiên bản Godot/đổi physics backend để né lỗi.

## 2. Checkout, tài nguyên và hiện trạng đã kiểm tra

- Checkout thực đang dùng: `D:\Game 3D\Game_3D`; cwd của chat có thể là worktree cũ `C:\Users\HP VICTUS\.codex\worktrees\1bb6\Game_3D`. **Không sửa nhầm worktree.**
- HEAD lúc lập kế hoạch: `a1596a66d36ddb66c5e275b820094ce7f11f9847`. Có nhiều thay đổi chưa commit; không reset, checkout đè file hay chạy lại các installer cũ.
- Godot 4.3 Forward+, GTX 1650; executable `D:\Game\godot_editor\Godot_v4.3-stable_win64_console.exe`.
- `scenes/Player.tscn` dùng `assets/models/knight_k3_style3.glb`, ba mesh. Skeleton: `Visuals/CharacterModel/Gladiator_Armature/Skeleton3D`.
- 19 xương trong GLB: `root`, `hips`, `spine`, `chest`, `neck`, `head`, `crest`, `upper_arm.L`, `forearm.L`, `hand.L`, `upper_arm.R`, `forearm.R`, `hand.R`, `thigh.L`, `shin.L`, `foot.L`, `thigh.R`, `shin.R`, `foot.R`.
- Không đổi tên/thứ bậc/rest pose/scale/origin của 19 xương; không ghi đè GLB hay file Blender đang dùng. PhysicalBone là node vật lý phụ, **không phải xương mới trong rig**.
- `scripts/KnightHandedness.gd` mirror trang bị và animation lúc ready. Gameplay kiếm tay phải, khiên tay trái; **socket thực hiện tại**: SwordAttachment → `hand.L`, ShieldAttachment → `forearm.R`. Audit runtime sau ready, đo collider theo mesh đã mirror; không mặc định `.R` là tay phải.
- Gravity trong `PlayerController.gd` đã có: 24 m/s². Không tăng gravity toàn game để tạo lực đánh.
- `KnightAbilities.create_shield_charge()`: knockback 2,40 m/0,30 s. `_apply_shield_charge_impact()` gọi `take_damage`, stun 0,75 s rồi knockback.
- `apply_knockback()` ép hướng Y=0; chỉ có vận tốc ngang. `apply_hit_reaction()` cho đòn thường gọi knockback, reset combo và tween nghiêng thân; chưa có hit-stun chung.
- `apply_impact_stun()` hiện tận dụng `PolymorphEffect.cancel_actions()`. Phải thay dần bằng API ngắt hành động chung; không xây hit reaction mới phụ thuộc effect biến hình.
- `is_control_impaired()` đã chặn một số lối vào. `PracticeOpponent` có kiểm tra hàm đó. Cần audit toàn bộ lối vào, không suy ra chỉ một guard đã đủ.
- `take_damage()` phân biệt blocked/dodge/dead; phản ứng cũ bỏ qua mục tiêu sắp chết. Luồng Z hiện chỉ kiểm HP giảm để gọi stun/đẩy, **chưa có quyết định phản ứng đầy đủ theo blocked hoặc vừa vỡ khiên**.
- `AttackPayload.gd` đã có damage, thông tin đỡ/né, knockback_distance/duration; mở rộng tương thích, không tạo payload trùng.
- `ArenaPlayBounds.gd` hiện chỉ giới hạn `CharacterBody3D` theo tám mặt sân, ở mọi Y. PhysicalBone sẽ không tự được giới hạn bởi script này.
- `PracticeArena.gd` đã có ENDING: chốt HP, khóa đầu vào/AI, chờ skill kết liễu hoàn tất, settle 0,35 s, watchdog 8 s. Phải giữ sửa lỗi này.
- `UltimateCinematic` giữ lease pause toàn world; physics ragdoll không được chuyển ALWAYS để vượt qua pause.

## 3. Kiến trúc dự kiến và quyền sở hữu chuyển động

Một controller phản ứng chung, tên dự kiến `CombatHitReaction`, chứa trạng thái:
`NORMAL → HIT_STUN` cho đòn nhẹ; `NORMAL → LAUNCHED → KNOCKED_DOWN → GETTING_UP → NORMAL` cho Z mạnh; `DEAD` ưu tiên cao nhất.
Một trạng thái chỉ có một chủ sở hữu chuyển động và pose. Dùng token/generation cho mỗi phản ứng để callback/tween cũ không mở khóa một phản ứng mới.

- NORMAL/HIT_STUN: CharacterBody sở hữu chuyển động/collision. Có recoil/animation, damping; không tạo toàn thân ragdoll cho mỗi đòn nhẹ.
- LAUNCHED/KNOCKED_DOWN bản ragdoll: physical bones sở hữu pose và chuyển động cơ thể. Không đồng thời gọi move_and_slide, tween vị trí và áp impulse lên cùng nạn nhân.
- Khi physical bones hoạt động, CharacterBody làm proxy gameplay: giữ layer mục tiêu để truy vấn damage vẫn tìm đúng actor, ngừng đẩy môi trường bằng capsule; đồng bộ proxy theo pelvis theo một quy ước offset được kiểm thử. Giữ transform world của bộ ragdoll khi cập nhật proxy, tránh parent transform cộng thêm lực/teleport.
- Trong cảnh prototype có thể dùng CharacterBody + pose điều khiển để xác minh Z/stun trước; đây là bước kiểm tra gameplay, không được báo hoàn tất ragdoll.
- GETTING_UP: tìm vị trí/yaw đứng dậy hợp lệ bằng ground query và capsule sweep; chuyển proxy về đó, chụp pose vật lý, giảm ảnh hưởng physics, blend sang get-up. Sau khi ổn định mới trả collision mask và điều khiển.
- Nếu bàn giao từ physics sang animation không ổn định trên Godot 4.3: ghi log, giữ prototype riêng và báo vấn đề; không âm thầm thay bằng tween cứng rồi gọi là ragdoll hoàn chỉnh.

API dự kiến (có thể đổi tên cho hợp convention repo):
`receive_hit(reaction_profile, outcome, direction)`; `is_control_locked()`; `is_presentation_busy()`; `cancel(reason)`/`reset()` idempotent. Profile là Resource tái dùng, không cấp phát mỗi frame.

Kết quả hit cần có `accepted`, `dodged`, `blocked`, `shield_broken_now`, `killed`, HP/shield trước-sau. Trả hoặc lấy metadata tại lần xử lý damage gốc; không tính lại góc đỡ sau khi pose đã đổi, không gọi take_damage lần hai. Giữ tương thích những caller bỏ qua giá trị trả về.

## 4. Ragdoll, collision và trang bị

Godot 4.3: `PhysicalBoneSimulator3D` dưới Skeleton3D, `PhysicalBone3D` dưới simulator; start/stop qua simulator. Không dùng API cũ trên Skeleton làm đường triển khai chính. API cần xác nhận bằng prototype trên executable thật, nhất là partial simulation và influence.

Prototype bắt đầu khoảng 11 body: hips, chest, head, hai upper_arm, hai forearm, hai thigh, hai shin. Hands/feet nối theo chuỗi hiện có; chỉ thêm body cho chúng nếu clipping đáng kể (tối đa khoảng 15). Không tạo body cho root/crest và mọi xương nhỏ chỉ vì tool hỗ trợ.

- Capsule/box đơn giản, đo từ rest pose và mesh runtime. Gối/khuỷu dùng hinge với trục đo thật; vai/hông/cổ dùng cone hoặc joint phù hợp. Không đoán trục từ tên xương.
- Mass tương đối: torso/pelvis nặng hơn tay/chân, đầu nhỏ hơn torso; damping vừa đủ, bounce thấp. Giới hạn xoắn/gập để giáp không lộn qua nhau.
- PhysicalBone gravity lấy từ project gravity × gravity_scale: phải đo để đạt gia tốc tương đương actor 24 m/s²; đừng mặc định project cũng là 24. Không áp gravity hai lần.
- Tạo collision exceptions giữa các body cùng nhân vật và capsule proxy; không tự va giật tung người. Physics ragdoll chỉ va môi trường; damage vẫn qua proxy/receiver cũ, không biến 11 body thành 11 mục tiêu nhận cùng hit.
- Kiếm/khiên giữ skin/socket như hiện tại, không rơi vũ khí. Thêm collider đơn giản kinematic theo trang bị chỉ sau khi body ổn định, tránh cạnh kiếm/khiên mắc vào người hoặc tạo lực phản hồi ngoài ý muốn.
- Collider chi tiết giáp không thuộc scope; kiểm clipping hình ảnh theo góc, ưu tiên giới hạn khớp và bố trí tay.
- Có bảo vệ giới hạn sân **cho pelvis và bộ body**, không chỉ proxy. Đề xuất controller correction đồng bộ một translation cho toàn bộ ragdoll, triệt vận tốc ra ngoài; prototype đo kỹ để không kéo từng body phá joint. Không mở rộng cột/tường vô hình chặn camera V.

## 5. Tác động của hit, gián đoạn và chống stun-lock

- Perfect Dodge / i-frame / hit bị từ chối: không damage, không launch, không stun mới.
- Đỡ Z mà khiên còn: lực đẩy nhỏ, animation shield recoil/guard, không ragdoll hay khóa dài; không mất shield hai lần.
- Vừa vỡ khiên vì Z: dùng phản ứng mạnh; hợp nhất stun shield-break và knockdown bằng ưu tiên/max, không cộng hai timer vô nghĩa.
- Z trúng trực tiếp, còn sống: hất văng và ngã; post-land stun tính từ lần tiếp đất/ổn định hợp lệ, không hết khi vẫn đang bay. Giới hạn chờ tiếp đất để tránh treo khi kẹt vật cản.
- Đòn nhẹ: ngắt startup/đòn chưa impact, xóa combo/buffer/queued counter, chặn đánh/né/skill mới trong stun. Damage đã phát trước hit không bị thu hồi.
- Không nối dài stun vô hạn: dùng max thời gian còn lại với profile mới và giới hạn ngân sách CC của một chuỗi. Đòn nhiều hit chỉ gây phản ứng chính một lần cho cùng cast; không liên tục reset get-up bởi damage tick nhẹ.
- Sau hồi phục cần một cửa sổ bảo vệ CC ngắn, có tham số, đề xuất 0,15–0,25 s; chưa chốt số. Không miễn damage mặc định. Đòn đủ mạnh khác có thể chuyển trạng thái theo quy tắc được test.
- Các ultimate đang có immunity/channeling giữ nguyên trong đợt đầu. Ghi rõ ngoại lệ thay vì bỏ chúng để đạt cảm giác hất tất cả.
- Hit chết: không hồi sinh/get-up. Death ragdoll nếu làm chỉ là presentation; không thay damage/death event hay chặn kết thúc trận mãi. Theo dõi is_presentation_busy có timeout khi tích hợp ENDING.

## 6. Animation, camera, VFX

- Bổ sung clip nếu thiếu: recoil nhẹ theo hướng, mất thăng bằng, get_up_back và get_up_front. Thử procedural trước; không bắt buộc dựng Blender trước khi kiểm gameplay.
- Nếu cần Blender, làm trên bản sao mới, giữ các clip cũ và rig; xuất GLB animation bổ sung theo pipeline cũ, không thay model đang dùng. Xác minh clip hiện có và runtime mirror trước authoring.
- Tay/đầu có độ trễ; khi bị hất tay chân mềm nhưng không xoắn 180° vô lý. Crest dùng chuyển động nhẹ, không physical body riêng.
- TPS bám pelvis/proxy có smoothing, collision tránh cột; FPS theo đầu nhưng lọc roll/pitch tần số cao do ragdoll. Không đem thay đổi này sang camera dash/X/V hoặc sửa cutscene V.
- Người dùng trước đó thích camera theo xoay/lộn của skill chủ động. Không suy ra camera phải nhận mọi rung solver khi **bị đánh**: nếu cần rolling FPS mạnh thì hỏi ở cổng duyệt camera.
- VFX tái dùng pool hiện có: tia lửa tại khiên khi trúng, bụi ở chân lúc bật/văng, bụi nhỏ tại tiếp đất. Không nâng số hạt hay thêm magie để che lỗi pose.

## 7. Thứ tự triển khai và cổng nghiệm thu

### P0 — Baseline và tái hiện (không sửa)
1. Xác nhận checkout/HEAD/status; backup từng file sẽ sửa và ghi diff trước đó. Dùng runtime actual PracticeArena, không chỉ dummy.
2. Tái hiện Z trực tiếp/đỡ/vỡ khiên ở FPS/TPS. Log source/cast id, outcome, state, velocity, displacement, stun; kiểm chỗ force bị ghi đè, thứ tự cancel/reset/knockback, vật cản và AI.
3. Chạy suite liên quan làm baseline; lưu số FAIL/allowlist **thực tế hiện tại**, không đoán mọi suite đang PASS.
**Gate:** chỉ ra nguyên nhân Z thiếu lực với log; chưa chữa bằng tăng giá trị mù.

### P1 — Phản ứng chung + Z gameplay
1. Tạo controller/profile và hit outcome; tận dụng payload cũ, receiver dùng một lần.
2. Chặn đủ input/FSM/AI, hủy startup/buffer đúng cách, giữ death/Perfect Dodge/shield rules.
3. Prototype quỹ đạo Z và post-land stun bằng CharacterBody, ghi rõ chưa phải ragdoll.
**Gate:** sân phẳng hất 0,6–0,9 m / 3–4 m, đỡ giảm lực, phá khiên mạnh; không đánh lại trong CC; damage/cost/cooldown/impact giữ nguyên.

### P2 — Prototype ragdoll riêng
Tạo `test/knight_hit_reaction_test.tscn`: Knight và receiver thật, sàn/cột/tường, nút trúng nhẹ/Z/block/break/recover, debug state/pose/collision. Dựng 11 body, giới hạn joint, start từ pose hiện tại, chuyển ownership an toàn, không spawn/free khi mỗi hit.
**Gate:** ngã tự nhiên, không bung body/joint, không trôi root, không tự va, start/stop/reset 100 lần không rò node/connection; partial/influence và gravity của Godot 4.3 đã kiểm.

### P3 — Ngã → hồi phục
Tích hợp full ragdoll launch/landing, front/back get-up, đứng dậy sát vật cản, giới hạn map và camera bị đánh. So thông số với P1; đo lại thay vì mặc định quỹ đạo physics khớp kinematic.
**Gate:** không xuyên đất/cột, không bay ra map; không pop pose/teleport rõ; pelvis/proxy lệch trong ngưỡng đo và tự về chuẩn khi xong; không mở input trước khi đứng ổn.

### P4 — Tích hợp game thật và cân phản ứng
Áp cho Knight người chơi và AI trước; sau đó hit-stun nhẹ dùng chung cho Archer/Wizard mà không clone rig Knight. Nếu muốn ragdoll hai hero khác phải audit rig riêng và lập mapping riêng; không thuộc hoàn tất P4.
Sửa ENDING để chờ reaction/get-up có giới hạn khi cần, giữ skill kết liễu không bị cancel; dead không có get-up. Đồng bộ VFX/camera/pause, anti-stun-lock.
**Gate:** manual test trước, suite mới PASS, suite liên quan PASS; regression đầy đủ một lần có timeout 120 s/suite, không nới tolerance vô nghĩa/allowlist.

### P5 — Bàn giao/duyệt
Video FPS/TPS so trước/sau (Z trực tiếp, bị đỡ, phá khiên, gần cột, gần mép), bảng đo quãng hất/đỉnh/stun, FPS/physics frame time với hai ragdoll. Báo file sửa, phần chưa đạt, backup. Dừng chờ duyệt, không commit.

## 8. File dự kiến, kiểm thử và hiệu năng

**Đọc/sửa khi triển khai:** `scripts/PlayerController.gd`, `PlayerCombat.gd`, `AttackPayload.gd`, `KnightAbilities.gd`, `PracticeOpponent.gd`, `ArenaPlayBounds.gd`, `PracticeArena.gd`, `scenes/Player.tscn`; thêm controller/profile/ragdoll scene/test scene và các test chuyên biệt. Chỉ sửa `PolymorphEffect` nếu thật sự cần tách API cancel chung, phải giữ test biến hình. `KnightHandedness`, camera/vũ khí/cloth là integration cần audit, không tự rewrite.

Test dự kiến: `run_hit_reaction_state_test.gd`, `run_knight_z_launch_test.gd`, `run_knight_ragdoll_lifecycle_test.gd`. Phải bao gồm:
1. HP, cost, cooldown, hit count và impact timestamp trước/sau bằng nhau.
2. Đỉnh/quãng hất trong môi trường trống; blocked/break/dodge đúng nhánh, mỗi hiệu ứng chỉ một lần.
3. Input spam LMB/Z/X/C/V/Q/đỡ/counter trong mọi phase không phá CC; input trước hit được xóa.
4. Landing chỉ bắt đầu post-land stun một lần; airborne collider/contact đủ xác thực, không chỉ chân ray chạm sớm.
5. Combo/multi-hit không CC vô hạn; stronger hit không làm callback cũ mở khóa mới.
6. Cột, tường, corner, độ cao 30/200 m, proxy/body không vượt ranh; test thật physics, không chỉ check flag.
7. PhysicalBone không trở thành nhiều receiver/damage target; hit khi đang ngã chỉ tính một lần.
8. Death trong bay/choáng/get-up, reset/replay/đổi hero/scene exit đều cleanup idempotent; không get-up người chết.
9. V pause giữa ragdoll đóng băng physics/timer và tiếp tục không impulse thứ hai; ENDING giữ kỹ năng kết liễu/camera đúng, không kẹt watchdog.
10. FPS/TPS, socket kiếm/khiên, giáp/tabard/crest không bung hoặc bị giữ tại pose cũ.

Suite liên quan hiện có: `run_task_knight_shield_charge_test.gd`, `run_knight_z_ram_test.gd`, `run_knight_z_upgrade_test.gd`, `run_knight_z_vfx_test.gd`, `run_task5_15c_a_iframe_test.gd`, `run_task5_15c_counter_test.gd`, `run_task5_14_attack_combo_test.gd`, `run_practice_ai_upgrade_test.gd`, `run_practice_arena_test.gd`, `run_practice_round_finish_test.gd`, `run_knight_v_cinematic_test.gd`, `run_knight_v_camera_wall_test.gd`, tests freeze/polymorph và Archer/Wizard tương ứng. Tìm lại tên thực tế nếu file không tồn tại; không đoán PASS. Regression runner `tools/run_regression.ps1` hiện phải audit timeout hỗ trợ, không chạy suite treo vô hạn.

Ngân sách: hai Knight đang ragdoll, khoảng 22–30 physical bodies; simulator tắt hoàn toàn khi idle. Không phát sinh node mới mỗi hit, không solver body cho từng mảnh giáp. Mục tiêu 1080p MSAA2×: ≥100 FPS trong tình huống nặng (hai ragdoll + VFX Z), physics P99 < ngân sách tick 16,67 ms; ghi baseline và chênh lệch, không cam kết số trước khi đo. Giữ apps khác thì ghi FPS tham khảo, không đóng ứng dụng của người dùng.

## 9. Bàn giao giữa các AI

Trước mỗi pha: đọc tài liệu này và status repo, kiểm file hiện tại, không chạy installer lịch sử trong thư mục artifacts vì có thể ghi đè bản mới. Sau pha: cập nhật checklist dưới đây, file đã sửa/backup, câu lệnh và đường dẫn log, số đo, điểm chưa đạt và lệnh tiếp theo. Phân biệt DONE, PARTIAL, BLOCKED; không đánh dấu hoàn tất dựa trên chỉ parse thành công.

| Pha | Trạng thái hiện tại | Bằng chứng |
|---|---|---|
| P0 baseline/tái hiện | **DONE** | Chạy `Godot_v4.3-stable_win64_console.exe` suite `run_task5_7_hit_reaction_test.gd` PASS 22/22. Đã xác định: `apply_hit_reaction` chưa set `_impact_stun_timer`; Z impact đang ép Y=0; block đã có cờ `was_blocked`. |
| P1 hit reaction/Z | **DONE** | Cập nhật `apply_hit_reaction` trong `PlayerController.gd`: unblocked -> ngắt đòn đang xuất chiêu về IDLE + combo reset + impact stun 0.16s; blocked -> miễn nhiễm impact stun, chỉ knockback khiên nhẹ; bảo toàn super armor cho shield charge/ultimates. Bảo toàn `velocity.y` khi có lực hất dọc (`velocity.y > 0`). Suite `run_task5_7_hit_reaction_test.gd` PASS 25/25; `run_task_knight_shield_charge_test.gd` PASS 61/61; `run_task5_14_attack_combo_test.gd` PASS 14/14; `run_rmb_lifecycle_test.gd` PASS 15/15; `run_knight_z_upgrade_test.gd` PASS 34/34. |
| P2 ragdoll prototype | **DONE** | Tạo [`scripts/KnightRagdoll.gd`](file:///d:/Game%203D/Game_3D/scripts/KnightRagdoll.gd) chuẩn Godot 4.3 với `PhysicalBoneSimulator3D` và 11 `PhysicalBone3D` (hips, chest, head, 2 upper_arm, 2 forearm, 2 thigh, 2 shin). Thiết lập joint limits (Hinge khuỷu/gối, Cone vai/hông/cổ/ngực), gravity scale 2.45 (~24 m/s²), collision exceptions với proxy capsule. Tạo test scene [`test/knight_hit_reaction_test.tscn`](file:///d:/Game%203D/Game_3D/test/knight_hit_reaction_test.tscn) và controller [`test/KnightHitReactionTestController.gd`](file:///d:/Game%203D/Game_3D/test/KnightHitReactionTestController.gd). Chạy suite [`run_knight_ragdoll_lifecycle_test.gd`](file:///d:/Game%203D/Game_3D/run_knight_ragdoll_lifecycle_test.gd) PASS 13/13 (bao gồm 100 chu kỳ start/stop/reset không rò rỉ, rơi ổn định trên sàn). |
| P3 recovery/camera/bounds | **DONE** | Bổ sung vào [`scripts/KnightRagdoll.gd`](file:///d:/Game%203D/Game_3D/scripts/KnightRagdoll.gd) cỗ máy trạng thái (LAUNCHED -> SETTLING -> RECOVERING -> INACTIVE), phát hiện tư thế nằm `is_supine()` (ngửa lưng vs úp mặt) và hướng đứng dậy `get_lying_heading()` từ xương `hips`, landing detection, raycast tìm cao độ sàn, snap CharacterBody proxy tới vị trí pelvis và xoay theo hướng nằm, giới hạn biên sân `_clamp_to_bounds` (radius 22m), camera tracking theo pelvis Y khi ragdoll, cửa sổ miễn nhiễm CC grace 0.20s sau khi đứng dậy. Tích hợp tự động vào [`scripts/PlayerController.gd`](file:///d:/Game%203D/Game_3D/scripts/PlayerController.gd) (`is_control_impaired()`). Chạy suite [`run_knight_recovery_bounds_test.gd`](file:///d:/Game%203D/Game_3D/run_knight_recovery_bounds_test.gd) PASS 13/13; [`run_knight_ragdoll_lifecycle_test.gd`](file:///d:/Game%203D/Game_3D/run_knight_ragdoll_lifecycle_test.gd) PASS 13/13; [`run_task5_7_hit_reaction_test.gd`](file:///d:/Game%203D/Game_3D/run_task5_7_hit_reaction_test.gd) PASS 25/25; [`run_task_knight_shield_charge_test.gd`](file:///d:/Game%203D/Game_3D/run_task_knight_shield_charge_test.gd) PASS 61/61. |
| P4 tích hợp/regression | **DONE** | Đã tích hợp đầy đủ phản ứng ragdoll vào combat thực tế: (1) Đòn Z trực diện unblocked hoặc làm vỡ khiên kích hoạt launch ragdoll và đứng dậy (recovery); (2) Đòn đỡ sạch sẽ (clean block) chỉ giật lùi nhẹ (block recoil), không kích hoạt ragdoll; (3) Đòn kết liễu fatal hit chuyển sang `CombatState.DEAD`, ngắt ragdoll ngay lập tức và không get-up; (4) Đồng bộ `PracticeOpponent` AI và `PracticeArena` round ending (`_finishing_presentation_busy` chờ ragdoll ổn định). Chạy PASS toàn bộ 11 test suites: `run_task_phase4_ragdoll_combat_integration_test.gd` (8/8), `run_task5_7_hit_reaction_test.gd` (25/25), `run_task_knight_shield_charge_test.gd` (61/61), `run_knight_z_upgrade_test.gd` (34/34), `run_knight_z_ram_test.gd` (21/21), `run_knight_ragdoll_lifecycle_test.gd` (13/13), `run_knight_recovery_bounds_test.gd` (13/13), `run_task5_14_attack_combo_test.gd` (14/14), `run_practice_round_finish_test.gd` (35/35), `run_practice_arena_test.gd` (27/27), `run_practice_ai_upgrade_test.gd` (27/27). |
| P5 video/bàn giao | **DONE** | Hoàn thành bộ đo benchmark và telemetry Pha 5 (`run_task_phase5_ragdoll_benchmarks.gd` PASS 6/6): Đỉnh hất Y: 1.04m, Thời gian ổn định (settle): 0.97s, Toàn bộ chu kỳ đứng dậy (full get-up): 2.43s, Đỡ đòn giật lùi (block recoil): 0.120m (tiêu chuẩn <=0.6m), Hấp thụ độ bền khiên: 15.0 HP, An toàn va đập cột/tường (không xuyên vật cản), Tải physics frame time khi 2 Knight cùng ragdoll (22 bones): trung bình 7.753ms (đạt ngân sách < 16.67ms tick), Chi phí mô phỏng idle: 0ms (PhysicalBoneSimulator3D tắt hoàn toàn khi đứng yên). Bổ sung HUD trực quan thời gian thực vào [`test/knight_hit_reaction_test.tscn`](file:///d:/Game%203D/Game_3D/test/knight_hit_reaction_test.tscn). Sẵn sàng bàn giao toàn diện. |

**Quy tắc chống treo tiến trình:**
- **TUYỆT ĐỐI KHÔNG** gọi trực tiếp `Godot.exe` qua background task (vì là GUI exe sẽ bị treo handle).
- **LUÔN DÙNG:** `& "D:\Game\godot_editor\Godot_v4.3-stable_win64_console.exe" --headless -s <test_suite.gd>`

## 10. Tài liệu API đã đối chiếu

- Godot 4.3 PhysicalBoneSimulator3D: https://docs.godotengine.org/en/4.3/classes/class_physicalbonesimulator3d.html (parent simulator và start/stop simulation).
- Godot 4.3 PhysicalBone3D: https://docs.godotengine.org/en/4.3/classes/class_physicalbone3d.html (joint, impulse, gravity_scale, damping).

Các trang API hỗ trợ chọn cơ chế; không thay thế prototype/version check và không chứng minh ragdoll của rig này đã hoạt động.
