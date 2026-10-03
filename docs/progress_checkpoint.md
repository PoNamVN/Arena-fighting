# ARENA FIGHTING PROJECT CHECKPOINT

## Latest checkpoint — 2026-10-03: Combat spectacle for all three heroes

User requested a much stronger animation/VFX upgrade with performance kept in mind.
Implemented Knight body anticipation/C arcs/giant-sword rune-wake-impact, Archer
smooth cached two-bone bow poses/recoil/batched spiral trails and synchronized T-rex
bite effects, Wizard animated fireball/sigils/channel pose/two-layer batched lightning.
CombatSpectacle uses6 fixed burst slots,2 wave planes+24 batched sparks each;
world-fixed,0.75s lifetime, no physics/gameplay changes, idle sleeping and round cleanup.
Arrow28 segments ->1 MultiMesh; sword32 debris ->1 MultiMesh; lightning24 segments
->2 MultiMeshes. Magic/cloud/debris shadows off; physical shadows retained.
Full50/50 suites passed, then final affected Knight/Archer/Wizard suites rerun PASS.
Targeted23/23 headless and OpenGL PASS; final renderer stderr empty. Six-slot CPU microbenchmark~0.4–0.5ms,
not a full-match FPS guarantee. Runner now51 suites. See combat_spectacle.md for
complete budgets, validation logs and limitations. Models remain draft; user feel/FPS
playtest needed before further expansion.


## Previous checkpoint — 2026-10-03: Wizard presentation polish

User approved beginning visual/animation polish with performance in mind.
- Added WizardPresentation: separate visual-only arm/staff poses for charge,
  release/Counter, guard, giant staff warning/fall, hex, ice glide and storm channel.
  Exponential blend, cached6 bone indices/rests, correct imported rig axes,
  forearm continuity and wooden staff grip following actual hand endpoint.
  Stops/clears on hit, polymorph/freeze, death/reset/round lock.
- Three pre-created reusable meshes: palm rune, ice/storm ground aura, staff glow.
  Ring geometry shared; materials cached; effects hidden when unused. No spawning
  inside presentation update, no new physics queries/colliders, no gameplay tuning.
  Magical orbs, shields, runes and beams no longer cast unnecessary shadows;
  physical staff and terrain retain shadows.
- Targeted26/26 headless and OpenGL PASS; foundation44/44 headless/OpenGL,
  Z/X46/46 and C/V67/67 headless PASS; model/map isolation17/17 PASS.
  Syntax exit0 and diff clean. Final renderer after shadow cleanup26/26 PASS,
  stderr empty (scratch/wizard_polish_final_render.log).
  Presentation microbenchmark ~0.02ms/update for1000 updates on this host;
  this measures CPU presentation only, not complete-match FPS or low-end hardware.
  Full49-suite pass belongs to previous C/V milestone; runner now includes50 suites.
- Viewed actual charge, guard, staff, hex, ice and storm frames. Model remains draft;
  new casting motion/game feel needs user playtest. Next polish: Knight and Archer,
  then three-hero balancing and AI before complete-match rules.



## Previous checkpoint — 2026-10-03: Wizard C/V

User accepted foundation and Z/X; implemented the remaining Wizard skills.
V follow-up: sky/light/clouds fade in over first1s and out over last1s of the5s
channel. Original sky mode retained; targeted67/67 headless/OpenGL PASS, renderer
stderr empty (scratch/wizard_storm_fade_render.log).
- C: held aimed ice glide,15 energy start +15/s,10s cooldown,10m/s,3s maximum.
  Upward aim builds solid ice ramps up to5m above start; tiles stay fixed in world,
  expire after4s and cap at55. Release/wall/hit/depletion stops movement.
- Contact freezes enemies0.8s and stops glide; guard/i-frame prevent CC. Frozen
  actors cannot move/fight or ride caster platforms. X/C share2s expiry resistance;
  cannot chain active CC. Death/reset/round exit restores platform layers and clears ice.
- V: full100 energy, zoomed mouse selection within24m/radius7, valid ground/LOS;
  fresh LMB after camera transition confirms, Esc/hit/8s timeout cancels free aim.
  Five-second stationary dark-sky channel,20 random warned lightning strikes,
  warning0.32s/radius2/damage24/shield20, normal guard/PD and roof LOS, no energy farm.
- Spherical shield blocks all damage, shield damage, knockback and CC during channel,
  including direct HealthComponent damage. Training invulnerability stays independent.
  Camera/cursor/environment/light restored and all effects cleared on finish/round exit.
- C/V targeted62/62 headless and OpenGL Compatibility PASS; renderer stderr empty.
  Full49/49 regression suites PASS, exit0, no SCRIPT/parse errors; syntax exit0,
  diff check clean. Active scene teardown and actual practice results restore cursor.
  Viewed actual ice mountain/storm frames. Logs: scratch/wizard_cv_exit_test.log,
  wizard_cv_verified_render.log, wizard_cv_full_regression.log.
  Headless retains known dummy-renderer null-mesh teardown noise only.
  Previous foundation/Z/X playtests accepted. New C/V game feel still needs user playtest.

## Previous checkpoint — 2026-10-03: Wizard Z/X

User accepted Wizard foundation and authorized the next milestone. Z/X implemented;
C held ice glide/mountain and V immune-channel lightning storm remain unimplemented.

- Z Đại trượng:30 energy/7s, fixed facing, 12.3m x2m strip,0.8s visible outline
  and growth then0.42s fall, one38 damage/30 shield impact. Unblocked living Player
  pushed1.4m. World wall clips the warning/model length and LOS excludes targets
  behind walls. Dust/deep impact audio, shrink cleanup. Hit/Q/guard/Esc can interrupt;
  no refund. Cannot overlap basic/X/Counter; slow casting movement.
- X Hóa gà:25 energy/9s,0.22s startup, physical purple beam26m/s/radius0.12/24m.
  Visible-target autoaim at commitment or free aim; fixed trajectory afterwards.
  Front guard costs15 shield and prevents transformation; real i-frame opens PD.
  No HP damage, no basic energy reward. Hit/Q/guard/Esc cancels startup, no refund.
- PolymorphEffect attached to PlayerController and TrainingDummy:1.5s chicken,
  original visual children hidden/restored, timer label and magic puff. Movement
  remains available; attack/guard/dodge/skills/jump blocked. Cancels pending combo/
  ability/Counter/dodge and Archer/Wizard casts; keeps HP/body collider/targetability.
  Chicken can take damage. Active transform cannot refresh;2s resistance on expiry.
  Practice AI retreats, cancels queued warning before snapshot, resumes after expiry.
  Death/dummy reset/new round/scene exit clear effect and resistance.
- Chicken GLB:864 triangles, one mesh/node, original palette and editable source,
  export active selected isolated scene, no arena or third-party assets.
- Targeted initial38/38 headless and OpenGL PASS; expanded46/46 headless PASS.
  Final46/46 headless and OpenGL PASS; renderer stderr empty. Full48/48 suites PASS,
  all exit0, no SCRIPT/parse errors (scratch/wizard_zx_full_regression.log).
  Final syntax exit0/diff clean; headless has known dummy-renderer null-mesh noise only.
  Viewed actual Godot warning/fall frames; Blender asset checked clean864 triangles/1 node.
  User playtest pending for Z timing and X readability.


## Latest checkpoint — 2026-10-03: Wizard foundation

User accepted Archer and the instruction-text cleanup. Wizard kit design agreed:
elder elemental wizard with branch staff; charged autoaim fireball, giant falling
staff Z, chicken polymorph X, held aimed ice glide/mountain C, targeted 5s
random lightning V with a full-damage-immunity sphere during channeling.
Current authorized milestone implements only the character/basic/guard/Counter;
Z/X/C/V are explicitly unavailable and marked in development.

- Separate WizardCombat, selected_hero="wizard", Arena Test third selector item;
  Practice/replay/return preserve selection, opponent stays Knight.
- Charge 1.6s, 24m, 10–34 damage, 18–28m/s, swept sphere radius 0.12–0.42m.
  Slow to 55% movement; cap, release one shot; front55-degree visible live autoaim.
  Splash0–1.5m does half damage, world LOS, caster excluded, primary not hit twice;
  one15-energy award for each successful basic projectile, no skill energy farming.
- RMB75% front guard, shared100 durability/break/recovery; no immunity from normal guard.
- Q shared Perfect Dodge; fresh LMB Counter45 damage/20 shield/40m/s/24m,
  3.2m retreat in0.32s with wall collision; consumes window and prior i-frame.
- Esc/hit/guard/dodge interrupts charge; death/round reset cleans projectiles,
  particles/audio/poses. Future spells do not fall through to Knight ability logic.
- Low-poly model627 triangles/25 nodes/18 bones, idle/run/dead; staff118/2 nodes.
  Separate editable Blender source, clean selection+active-scene export, no map meshes.
- Full agreed design and milestone tuning: docs/wizard_design.md.
- Verified: full47/47 regression suites PASS, all exit0, no SCRIPT/parse errors
  (scratch/wizard_full_regression.log); Wizard44/44 headless and OpenGL PASS
  (scratch/wizard_verified_headless.log, wizard_verified_render.log), renderer stderr empty.
  Final syntax exit0; git diff --check clean apart from existing LF/CRLF notices.
  Headless retains known dummy-renderer null-mesh noise; real renderer has none.
  Initial render43/44 splash fixture failure retained in wizard_final_render.log;
  diagnostic44/44 and final44/44 pass. Charge fixture now waits actual cap and resets
  time scale between actors. User playtest remains required for feel and draft visuals.



## Checkpoint mới nhất — 2026-10-03: X tên xoắn / V mồi T-rex

- X3 tên cùng phóng, lệch120 độ, xoắn2.4 vòng/s quanh trục chung, bán kính0.95m.
  Mở vòng từ nòng cung rồi thu lại trước mục tiêu; sweep đường cong thật, trail hữu hạn.
  Giữ30 NL/8s/42 max damage, tốc độ20m/s, không đổi mục tiêu giữa đường.
- V100 NL đầy: chọn đất24m bằng V/LMB, ESC hủy chưa trừ NL. Phóng mồi theo cung,
  vòng2.2m bắt1 đối thủ trong0.8s, không bắt bản thân/không qua tường.
- T-rex khổng lồ chạy tới kẻ dính mồi, gặm3×30; hụt thì chỉ ăn mồi.
  Có block/né chuẩn/thoát vùng cắn, camera mở rộng/âm thanh/bụi/chạy/hàm/cúi cắn/rời sân.
  Khôi phục FPS/TPS, con trỏ và dọn triệu hồi khi chết/kết thúc trận.
- Model riêng2084 tam giác, GLB13 nodes; mồi128 tam giác/2 nodes; giữ nguồn Blender.
- Full46/46 suite PASS (Ultimate32 lúc chạy full); Ultimate cuối37/37 headless và
  renderer thật PASS, stderr rỗng; spiral11/11 cả hai, X/C40/40. Syntax exit0/diff sạch.
- Chờ người dùng thử X/V, sau đó cân bằng matchup Knight/cung thủ.

## Checkpoint trước — 2026-10-03: Cung thủ X/C

- Người dùng chấp nhận đỡ cung/Counter; đã triển khai X truy đuổi và C lướt/tàng hình.
- X:3 tên ×14 damage,30 NL,8s cooldown;23m/s,24m range, quay110 độ/s.
  Khóa đối thủ nhìn thấy trước khi trừ NL; không đổi mục tiêu giữa đường.
  Tên bị tường/khiên chặn, mỗi tên8 độ bền khiên; không hồi NL từ skill.
- C:5m/0.25s theo WASD, đứng yên thì tiến trước;25 NL,10s cooldown.
  Tàng hình2.5s, bóng trong suốt22% và lá rừng; AI mất dấu.
  Tấn công/trúng đòn làm lộ diện; không miễn sát thương, không xuyên tường.
- Chết/kết thúc trận dọn trạng thái/khôi phục vật liệu; HUD X/C đầy đủ.
- Test X/C40/40 PASS headless và renderer thật, stderr rỗng;15 suite liên quan PASS.
  Đã xem FPS/TPS; sửa alpha vật liệu để OpenGL Compatibility hiển thị tàng hình đúng.
  Runner44 suite; chưa chạy lại toàn bộ44 (full43 trước đó thuộc đợt phòng thủ).
- Chờ người dùng thử cảm giác X/C; tiếp theo V mồi thịt + T-rex khổng lồ.

## Checkpoint trước — 2026-10-03: Đỡ cung và Counter bật lùi

- Người dùng chấp nhận Z; đã thêm giữ RMB đỡ bằng cung nằm ngang, giảm65% damage
  phía trước, độ bền100 dùng luật chung. Đòn phía sau không giảm; vỡ cung stun0.65s.
- Perfect Dodge rồi nhấp LMB mới trong0.6s: tên lớn50 damage/20 độ bền khiên,
  tốc độ38m/s, tầm24m; hướng cố định về kẻ vừa đánh, tường/khiên vẫn chặn được.
- Đồng thời bật lùi3.2m/0.32s có va chạm tường, recovery0.30s.
  Tiêu thụ cửa sổ Counter/kết thúc i-frame; tên Counter không tự hồi năng lượng.
- RMB hủy tích lực/Z; hit/né/Esc ngắt hành động; chết/kết thúc trận dọn tên/chuyển động.
  Sửa điều kiện kết thúc Counter riêng của kiếm để cung thủ trở về IDLE đúng.
- Renderer thật36/36 PASS, stderr rỗng; đã xem pose đỡ và Counter TPS/FPS.
  Toàn bộ43 suite PASS, exit0; syntax exit0, diff --check sạch.
  Chờ người dùng thử cảm giác đỡ/bật lùi.
- X/C/V chưa triển khai; tiếp theo X ba tên truy đuổi sau khi xác nhận bộ phòng thủ.

## Checkpoint trước — 2026-10-03: Cung thủ Z — Loạt tên

- Người dùng chấp nhận bắn cơ bản và yêu cầu bước tiếp theo; đã triển khai Z.
- 6 tên tuần tự, mỗi tên7 damage;25 năng lượng, cooldown5s; startup0.22s,
  khoảng cách phát0.14s, recovery0.35s. Tên tốc độ30m/s, range24m.
- Khóa hướng đầu chiêu, chỉnh nhẹ tối đa12°; không truy đuổi. Né/đỡ/tường
  theo pipeline damage thật. Mỗi tên làm mất5 khiên; skill không tự hồi năng lượng.
- Hit/Q/RMB/Esc hủy phát còn lại; chết/kết thúc trận dọn cả tên đang bay.
  HUD hiển thị Z/cooldown/cost; F1/F2 Arena Test hoạt động. X/C/V chưa làm.
- 32/32 kiểm tra Z PASS headless và renderer thật, stderr rỗng. Bắn cơ bản44/44,
  11 suite hồi quy chọn theo thay đổi đều PASS (chi tiết AI_HANDOFF); chưa chạy lại
  toàn bộ42 suite. Đã xem ảnh Z trong Đấu tập ở FPS/TPS, syntax exit0.
- Chờ người dùng thử Z; tiếp theo X — ba tên truy đuổi.



## Checkpoint trước — 2026-10-03: Cung thủ rừng, bắn cơ bản

- Theo lựa chọn của người dùng: phát triển nhân vật2/3 trước luật trận nhiều hiệp.
- Đã triển khai chọn Knight/Cung thủ trong Arena Test, model cung thủ riêng với
  cung/ống tên/mũ trùm/áo choàng; giữ/thả LMB tích lực và hỗ trợ tự ngắm.
- Tên bay thật, chặn bởi tường/khiên và có thể né; không homing sau khi thả.
  Tạm chỉnh12→36 damage,18→32m/s, charge1.2s, range24m, recovery0.4s.
- RMB/Esc/né/bị đánh hủy tích lực; chết/kết thúc trận dọn tên; FPS/TPS hoạt động.
- Đấu tập giữ chọn nhân vật khi đấu lại/quay về, AI vẫn là Knight; giữ countdown.
- Z/X/C/V chưa triển khai cho cung thủ; HUD ghi rõ, không dùng nhầm chiêu Knight.
- Kiểm tra cung thủ44/44 PASS bằng renderer thật, stderr rỗng; syntax exit0.
  Coverage hồi quy41 suite PASS qua lượt đầy đủ37PASS/4 lỗi import audio
  và lượt chạy lại4/4 sạch sau import; giữ log lỗi gốc. Chi tiết ở AI_HANDOFF.
- Chờ người dùng thử cảm giác bắn. Tiếp theo Z loạt tên, X ba tên truy đuổi,
  C lướt/tàng hình, V mồi thịt + T-rex; hoàn thiện từng đợt.


## Checkpoint trước — 2026-10-03: AI ba độ khó, combo/né/C

- User chấp nhận Đấu tập cơ bản và yêu cầu phát triển bước tiếp theo.
- Thêm chọn Dễ/Thường/Khó dưới nút Đấu tập. Mặc định Thường; giữ lựa chọn
  khi Đấu lại/quay về. HUD hiển thị độ khó và năng lượng AI, panel test có nền tối.
- Dễ: combo1, phản ứng0.32s, tốc độ3.6, đánh cách1.7s. Thường: combo2,
  phản ứng0.22s, tốc độ4.4, đánh cách1.25s, biết đỡ/né/C. Khó: combo3,
  phản ứng0.16s, tốc độ5, đánh cách1.05s. Giữ 200 HP/basic25 ở cả ba mức.
- Combo dùng cửa sổ đánh thật, giữ hướng trong swing, không nối khi mục tiêu
  ra khỏi tầm. Né qua hệ thống cooldown/i-frame thật; không đọc phím người chơi.
- AI Thường/Khó dùng C khi đủ30 năng lượng/cooldown5s và ở gần; vòng cam3m
  cảnh báo0.55s trước startup0.15s. Vỡ khiên/kết thúc trận dọn cảnh báo;
  không gây damage/trừ năng lượng sớm, C gây30 damage qua pipeline chung.
- Sửa nguồn hướng né/locomotion/release block cho external actor; WASD của
  người chơi không kéo hướng né AI. Đường input nhân vật người chơi giữ nguyên.
- Test AI mới27/27; phòng Đấu tập27/27; điều hướng11/11 có kiểm tra chọn Khó
  và giữ mức khi replay. Đã xem ảnh renderer thật, không lỗi preview/parse.
- Hồi quy40 suite lần đầu39 PASS/1 FAIL (test khiên14 kiểm tra IDLE sớm khi
  recoil chưa ổn định). Chỉ sửa test chờ physics hữu hạn, không sửa gameplay;
  chạy lại suite khiên15/15 PASS. 39 suite khác giữ kết quả PASS, không chạy
  lại sau sửa fixture. Tổng coverage cuối: 40 suite qua full run + rerun.
  Giữ log `practice_ai_full_regression.log` và `practice_ai_shield_stable.log`
  trong tools/regression_output; không ghi full run ban đầu là all-green.
- Chạy renderer thật lần cuối: điều hướng11/11, test khiên đã sửa15/15,
  không lỗi stderr.
- Nâng cấp AI mới chờ user test cảm giác/độ khó; các phần đã chấp nhận vẫn giữ.


## Checkpoint trước — 2026-10-03: Đấu tập và hỗ trợ Arena Test

- Thêm nút ĐẤU TẬP ở góc phải Arena Test (Esc để dùng chuột).
  Sân mới chỉ có bạn + một AI màu đỏ; không dummy. Hai bên 200 HP,
  năng lượng ban đầu 0, tích bằng đánh trúng/Perfect Dodge.
- Đếm ngược 3–2–1 khóa combat, sau đó trận 90 giây. AI di chuyển tiếp cận,
  đánh và đôi lúc đỡ sau thời gian phản ứng. Hết giờ so HP; bằng nhau hòa.
  Hạ gục kết thúc sớm; có kết quả, Đấu lại và Về Arena Test.
- F1 vô hạn năng lượng, F2 bỏ cooldown, F3 bất tử HP, F4 làm mới toàn bộ
  phòng và tắt hỗ trợ. Chỉ Arena Test nhận phím; mặc định tắt, không mang
  sang Đấu tập. F2 vẫn giữ animation/recovery; F3 vẫn có khiên/knockback.
- Sửa BLOCK -> LMB không đánh, và lỗi giảm damage/trừ khiên hai lần khi
  basic attack trúng nhân vật PlayerController (AI cũng dùng hệ thống này).
- Sửa/đồng bộ bốn nhóm KNOWN: dùng physics frame cho test TPS/RMB,
  tách attack cũ khỏi case RMB tiếp theo, sửa test shield theo luật không
  đánh khi khiên vỡ. Không nới lockout shield để làm test qua.
- Test mới Đấu tập 27/27, điều hướng/phím/click 11/11; đã chạy renderer thật
  và xem ảnh countdown/kết quả. V vẫn 60/60. Hồi quy đầy đủ 39/39 suite PASS,
  0 KNOWN / 0 FAIL, exit 0; log `tools/regression_output/practice_full_regression.log`.
  Không lỗi script/parse; thông báo teardown renderer headless cũ vẫn còn.
- User đã test và chấp nhận Đấu tập/F1–F4, cho phép phát triển tiếp; không commit/push.


## Checkpoint trước — 2026-10-03: cập nhật test ability cũ

- User đã chấp nhận V mới và cho phép cập nhật test. Chỉ sửa test 5.15E/5.15F
  và tài liệu, không thay gameplay/asset/input hay danh sách KNOWN; không commit/push.
- 5.15E dùng cấu hình Knight và lifecycle thật: Z charge hit, X LMB/tiếp đất,
  C ACTIVE, V chọn đất bằng MouseButton và chờ kiếm đáp/recovery. Giữ kiểm tra
  stamina/cooldown/lockout/no early damage/death. Targeted 28/28 PASS.
- 5.15F giữ toàn bộ 44 assertion cũ và thêm 5 kiểm tra lifecycle Z -> V:
  không chồng chiêu, không chi stamina khi bị chặn, chờ hồi phục, click V không
  mở combo và trả camera/input. Targeted 49/49 PASS.
- Fixture headless dùng viewport 1152x720 để HUD không chặn LMB, dừng attacker
  không liên quan trong arena; không giả lập confirm flag hoặc ép phase/hit.
- Godot parse/diff check PASS. Hồi quy 37 suite: 33 PASS / 4 KNOWN / 0 FAIL,
  runner exit 0. E 28/28, F 49/49, Z 27/27, X 63/63, C 52/52, V 60/60, map 17/17.
  Không lỗi script/parse; renderer headless vẫn có thông báo teardown cũ. Log
  `tools/regression_output/knight_ability_reconciliation_final.log`.
- Các KNOWN của TPS/FSM/RMB/shield break vẫn là việc theo dõi riêng.

## Checkpoint trước — 2026-10-02: V chọn điểm, kiếm đặc siêu lớn

- User yêu cầu sửa V: zoom camera ra xa, chọn điểm rơi bằng LMB, kiếm bình
  thường siêu lớn đi xuyên mây, rơi mạnh xuống rồi tan biến. Thay prototype cũ.
- V mở ngắm với con trỏ/vòng vùng AOE, giữ timeline tới click mới; camera zoom
  0.45s. Chọn mặt đất trong 24m, không nhận tường/click ngoài vùng.
- LMB chốt điểm rơi và bắt đầu rơi 1.40s; 90 damage / AOE 4.5m, active 0.20s,
  recovery 2.0s. Không chuyển click sang basic attack. ESC trong aim trả stamina;
  sau click không refund. Chết/hủy/hoàn tất dọn camera/cursor/VFX/audio.
- Kiếm Blender mới cao 24.5m, 104 triangle, thép/đồng/da OPAQUE; rơi từ 60m,
  xuyên cụm mây 34m. Có slam audio thật, camera shake, bụi/sóng xung kích và
  dissolve sau impact. Không spawn node mỗi lần. Không sửa character/map.
- Camera riêng giữ nguyên FPS/TPS ban đầu, tạm hiện head khi zoom rồi phục hồi.
- Test V 60/60, Godot parse/diff check PASS. Ảnh renderer thật đã kiểm tra trong
  `scratch/colossal_*.png`, không lỗi script/shader; camera/cursor trả về đúng.
- Hồi quy 37 suite: 31 PASS / 4 KNOWN / 2 FAIL cũ (5.15E/5.15F giống baseline).
  V 60/60, C 52/52, X 63/63, Z 27/27, map 17/17; không assertion lỗi mới.
  Log `tools/regression_output/colossal_ultimate_regression_final.log`.
  User đã test V mới và báo ổn (2026-10-02): milestone được chấp nhận.

## Checkpoint trước — 2026-10-02: Knight V — Giant Sword Ultimate

- User đã test C và báo ổn, tiếp tục V. Ghi chú C chờ acceptance bên dưới
  là lịch sử. Không commit/push.
- V giữ cấu hình: cần/tiêu thụ 100 stamina, 90 damage / AOE 4.5m, cooldown 0;
  startup 0.70s, active 0.20s, recovery 0.80s. Hit một lần khi vào ACTIVE.
- Vòng báo và impact cố định ở vị trí bắt đầu niệm, kể cả bị knockback.
  Dùng chung damage/block/shield/i-frame/Perfect Dodge/Counter và wall checks.
- Animation niệm từ Blender và kiếm low-poly riêng (40 triangle); chỉ thêm clip
  vào rig hiện có. Kiếm rơi từ 8m, chạm đất cùng hit, mờ dần trong recovery.
  Khóa WASD/chiêu khác khi niệm; hủy/chết dọn hiệu ứng, không refund hoặc hit muộn.
- Sửa signal audio ultimate phát trùng; presentation chỉ một lần mỗi cast.
- Targeted V 36/36 PASS, Godot parse PASS; ảnh runtime renderer thật đã kiểm tra
  tại `scratch/ultimate_runtime_screenshot.png`. Hồi quy 37 suite: 31 PASS / 4 KNOWN / 2 FAIL cũ (5.15E/5.15F).
  Z 27/27, X 63/63, C 52/52, map 17/17; không có assertion lỗi mới.
  Log `tools/regression_output/ultimate_regression_final.log`.
- Chờ user test V: đủ 100 stamina, mục tiêu trong 4.5m, bấm V; hit 90 sau 0.70s,
  stamina về 0. Kiểm tra FPS/TPS và LMB/RMB/Q trở lại sau recovery.

## Checkpoint trước — 2026-10-02: Knight C — Whirling Blade

- User đã test map và báo ổn. Tiếp tục C theo thứ tự Z -> X -> C -> V.
- C dùng cấu hình hiện có: 30 damage / 3m / 30 stamina / cooldown 5s;
  startup 0.15s, active 0.45s, recovery 0.30s. Hit chỉ tại đầu ACTIVE,
  một lần/mục tiêu, không xuyên tường, không hoàn stamina như basic attack.
- Animation xoay riêng từ Blender, nạp vào AnimationPlayer hiện có; không sửa
  GLB nhân vật gốc hoặc map. Có nguồn `.blend` và clip `.tres` độc lập.
- Khóa WASD khi C chạy, vẫn nhận recoil; block/i-frame/Perfect Dodge dùng
  pipeline cũ. Hủy/chết dọn animation/VFX và phục hồi input.
- Test C 52/52 PASS, gồm chuyển từ block/attack, pose cổ tay và head mask FPS.
  Giữ track pose nghỉ khi import C để không lưu pose từ đòn đánh trước;
  loại riêng scale track để bảo toàn head mask. Godot validation PASS.
  Regression 36 suite ghi log tại `tools/regression_output/whirling_regression_final.log`.
- Hồi quy cuối: 30 PASS, 4 KNOWN, 2 FAIL; hai suite FAIL vẫn là 5.15E/5.15F
  đã có từ trước. C 52/52, Z 27/27, X 63/63, map 17/17; không còn assertion
  thất bại mới trong lượt cuối. Chưa coi toàn bộ regression là xanh.
- C chờ test cảm giác chơi/hình ảnh và user acceptance; không commit/push.

## Checkpoint mới nhất — 2026-10-02: map nhân bản/dính nhân vật

- Nguyên nhân: `player_character.glb` có cả 42 mesh `Arena_*`, nên map thừa
  nằm dưới `Player/Visuals/CharacterModel` và di chuyển cùng nhân vật.
- Đã loại node/mesh đấu trường khỏi GLB nhân vật, remap index scene/skin/animation;
  giữ nguyên binary buffer, rig 18 xương và 9 animation. Không sửa Blender/map chính.
- Test tái hiện trước sửa: 12/16; sau sửa: 17/17 (thêm kiểm tra skin binding).
  Main scene có đúng một bộ
  42 mesh đấu trường và map đứng yên khi nhân vật di chuyển/xoay.
- Godot import/validation PASS; bộ regression 35 suite ghi kết quả vào
  `tools/regression_output/map_fix_report.log`.
- X 63/63; Z đo lại trên đường trống bằng physics frame thật đạt 27/27.
  Lần full regression có 29 PASS, 3 KNOWN, 3 FAIL: hai suite ability cũ và
  phép đo movement Z không ổn định. Đã sửa riêng fixture Z, giữ log full run;
  không chạy lại toàn bộ sau sửa test. Không có thay đổi gameplay Z/X.
- Cần dừng game đang chạy rồi chạy lại sau khi Godot import model để kiểm tra
  hình ảnh. Chưa có user acceptance; không commit/push.

## Checkpoint mới nhất — 2026-10-02: kiểm tra Z/X

- Đã sửa X chưa gây sát thương khi tiếp đất: gọi pipeline ability hiện có
  trước khi chuyển ACTIVE -> RECOVERY, 35 damage / AOE range 3.5.
- Đã bỏ gán trực tiếp vị trí trong impact của Z; giữ vị trí sau `move_and_slide()`.
- Test mục tiêu: Z 27/27, X core 63/63; headless editor validation PASS.
- Bộ regression đã thêm Z và X core (34 suite). Kết quả toàn bộ được ghi trong
  `tools/regression_output/zx_review_report.log`.
- Regression: 28 PASS, 4 KNOWN, 2 FAIL. Hai suite 5.15E/5.15F vẫn lỗi tương
  tự khi tạm gỡ đúng hai sửa đổi của phiên này (9/22 và 42/44); đã khôi phục
  bản sửa. Không có thất bại mới do patch Z/X, nhưng toàn bộ suite chưa xanh.
- Chưa kiểm tra cảm giác chơi/hình ảnh bằng tay, chưa có user acceptance.
- Có lỗi renderer headless `mesh_get_surface_count` khi teardown mesh đã xuất
  hiện trước bản sửa; không coi log runtime là sạch lỗi.
- Không sửa Blender, không commit/push; giữ các thay đổi đang có trong working tree.
- Tham khảo checkpoint mới ở `docs/AI_HANDOFF.md`; các mục lịch sử bên dưới
  chưa phản ánh đầy đủ Dodge/Counter/stamina/Knight abilities hiện tại.

> **Lưu ý**: Tài liệu này lưu trữ toàn bộ trạng thái hiện tại của dự án để đảm bảo liền mạch cho các phiên làm việc tiếp theo.

---

## 1. Trạng thái tổng quan (Overview State)
- **Engine**: Godot 4.3 Stable (Forward+ Vulkan).
- **Mô hình & Rigging**: Blender 5.2 MCP (127.0.0.1:9876).
- **Thư mục dự án**: `D:\Game 3D\Game_3D`.
- **Scene chính**: `scenes/Arena.tscn`.
- **Nhân vật**: Đấu sĩ La Mã low-poly (`assets/models/player_character.glb`) có kiếm (tay phải) và khiên (tay trái).

---

## 2. Các giai đoạn đã hoàn thành & Khóa logic (Completed & Locked Phases)

### Phase 1: FPS Camera Overhaul [LOCKED]
- CameraPivot đặt tại `(0, 1.62, 0)` thẳng hàng với trục xương sống nhân vật.
- Triệt tiêu hoàn toàn độ lệch quỹ đạo khi xoay 360° yaw: độ lệch đo được là `0.0000 m`.
- Near clipping trong FPS đặt `near = 0.08` để tránh xuyên mesh tay/vũ khí.
- Thu nhỏ xương đầu/cổ (`scale = 0.0001`) trong FPS để không bị chắn tầm nhìn; khôi phục hoàn chỉnh (`scale = 1.0`) trong TPS (nhấn `V` để chuyển đổi).
- Đồng bộ hướng ngắm chém theo cả Yaw và Pitch trong FPS.
- Test script: `run_phase1_runtime_test.gd` (4/4 tests PASS).

### Phase 2: Melee Attack & Damage Timing [LOCKED]
- Animation `attack` gồm 3 phase rõ ràng (Wind-Up -> Slash Apex -> Recovery), độ dài 18 frames (0.750s).
- Sát thương được đồng bộ chính xác tại mốc va chạm (Apex Frame) tại $t = 0.35\text{s}$ (`ATTACK_IMPACT_TIMESTAMP = 0.35`).
- Cơ chế `single-hit guarantee` (`_damage_applied_this_swing`) đảm bảo mỗi nhát chém chỉ gây sát thương 1 lần duy nhất, không gây sát thương sớm ở giai đoạn vung kiếm (wind-up).
- Tốc độ di chuyển giảm 50% trong lúc đang chém kiếm (`target_speed *= 0.5`).
- Test script: `run_phase2_runtime_test.gd` (5/5 tests PASS).

### Phase 3: Shield Block & Directional Defense [LOCKED]
- Animation phòng thủ gồm các track riêng biệt: `block_start` (0.208s, tốc độ 1.4x), `block_hold` (0.417s, loopable), `block_release` (0.208s, tốc độ 1.4x).
- Chuột phải (RMB): Nhấn -> `block_start`, Giữ -> `block_hold` (ổn định, không loop restart mỗi frame), Thả -> `block_release` -> `idle`.
- Hình nón phòng thủ 120° phía trước (`cos(60°) = 0.50`), giảm 85% sát thương khi đỡ trúng hướng tấn công (`block_damage_reduction = 0.85`). Đòn đánh từ sau lưng hoặc hai bên sườn (ngoài nón 120°) bỏ qua khiên và nhận 100% sát thương.
- Loại trừ tương hỗ: Không thể đồng thời vừa chém vừa đỡ; khi đang chém thì nhấn đỡ sẽ bị từ chối; khi đang đỡ mà bấm chém sẽ hạ khiên dứt khoát và chém ngay.
- Tốc độ di chuyển giảm 45% khi đang giơ khiên (`target_speed *= 0.45`).
- Test script: `run_phase3_runtime_test.gd` (10/10 tests PASS).

### Phase 4: Combat FSM Matrix [COMPLETED]
- Kiến trúc máy trạng thái hữu hạn tập trung:
  ```gdscript
  enum CombatState {
      IDLE,
      RUN,
      ATTACK,
      BLOCK,
      DEAD
  }
  var combat_state: CombatState = CombatState.IDLE
  ```
- Khử hoàn toàn các boolean rời rạc gây mâu thuẫn trạng thái; các getter tương thích (`is_attacking`, `is_blocking`, `is_dead`) ánh xạ trực tiếp từ `combat_state`.
- **Trạng thái `DEAD` có độ ưu tiên cao nhất**: Khi HP $\le 0$, cưỡng bức chuyển sang `DEAD` từ bất kỳ trạng thái nào (`IDLE`, `RUN`, `ATTACK`, `BLOCK`).
- Khóa toàn bộ input khi chết: vận tốc ngang triệt tiêu hoàn toàn (`velocity.x = 0, velocity.z = 0`), từ chối input di chuyển, tấn công (LMB), phòng thủ (RMB). Không cho phép chuyển ngược lại trạng thái sống.
- Animation `dead` được tạo trong Blender (24 frames, 1.000s, không loop), nhân vật ngã gục tự nhiên về phía sau, chân co gập, tay buông thõng sát sàn cát ($Z \ge 0.0$m), không lún xuyên nền đá và giữ nguyên tại vị trí hy sinh khi hết animation.
- Test script: `run_phase4_fsm_runtime_test.gd` (18/18 tests PASS).
- **Bugfix (RMB Block Stuck / Character Freezes - Root Cause Investigation)**:
  - **Root Cause**: Trong `_on_animation_finished("attack")`, kiểm tra `if Input.is_action_pressed("block"): transition_to(CombatState.BLOCK)` được gọi khi `combat_state` vẫn đang là `CombatState.ATTACK`. Do `transition_to(CombatState.BLOCK)` từ chối chuyển trạng thái khi đang `ATTACK` (trả về `false`), luồng code không rơi vào nhánh `IDLE`/`RUN`, khiến nhân vật bị kẹt vĩnh viễn ở `CombatState.ATTACK` mà không có animation nào chạy (frozen in attack).
  - **Khắc phục**:
    1. Chuẩn hóa `_on_animation_finished("attack")`: Kết thúc đòn đánh luôn chuyển dứt khoát về `RUN` hoặc `IDLE`, không tự ý tái kích hoạt `BLOCK`.
    2. Trong `transition_to(CombatState.ATTACK)`: Đảm bảo luôn dọn sạch `_block_transition = ""` khi vào trạng thái chém.
    3. Đơn giản hóa guard của `_release_block()`: Kiểm tra trực tiếp `if combat_state != CombatState.BLOCK: return`.
    4. Thêm cơ chế giải phóng block an toàn trong `_set_mouse_captured(false)` khi mất focus hoặc mở UI.
  - Test script: `run_rmb_lifecycle_test.gd` (15/15 tests PASS, gồm toàn bộ Sequence A-G và 10 chu kỳ RMB+WASD liên tiếp).

---

## 3. Giai đoạn tiếp theo (Next Step)
- **Phase 5: Gameplay Polish & Visual Verification Gate**:
  - Tinh chỉnh hiệu ứng hình ảnh (VFX chém, tia lửa đỡ đòn, phản hồi âm thanh/camera shake nhẹ).
  - Tối ưu hóa UI thanh máu đấu trường và HUD.
  - Tổng duyệt toàn bộ gameplay vòng lặp chiến đấu hoàn chỉnh.

---

## 4. Lệnh kiểm tra tự động nhanh (Quick Verification Commands)
Khi cần chạy kiểm tra toàn bộ hệ thống trong PowerShell:
```powershell
# Chạy Phase 1 Camera test (4 tests)
& "D:\Game\godot_editor\Godot_v4.3-stable_win64_console.exe" --headless -s run_phase1_runtime_test.gd

# Chạy Phase 2 Attack test (5 tests)
& "D:\Game\godot_editor\Godot_v4.3-stable_win64_console.exe" --headless -s run_phase2_runtime_test.gd

# Chạy Phase 3 Block test (10 tests)
& "D:\Game\godot_editor\Godot_v4.3-stable_win64_console.exe" -s run_phase3_runtime_test.gd

# Chạy Phase 4 FSM test (18 tests)
& "D:\Game\godot_editor\Godot_v4.3-stable_win64_console.exe" -s run_phase4_fsm_runtime_test.gd

# Chạy RMB Block Lifecycle & Locomotion test (11 tests)
& "D:\Game\godot_editor\Godot_v4.3-stable_win64_console.exe" -s run_rmb_lifecycle_test.gd
```

---

## 5. Nguyên tắc bắt buộc (Critical Guidelines)
1. **Không commit hoặc push Git** khi chưa có sự đồng ý trực tiếp của người dùng.
2. Giữ nguyên toàn bộ logic Camera Phase 1, Timing tấn công Phase 2 ($t=0.35$s), và Logic khiên đỡ Phase 3 ($120^\circ$, 85%).
3. Mọi tính năng mới đều phải được kiểm chứng bằng test tự động thực thi trên GPU/Engine.
