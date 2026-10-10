# Archer Z đã ghép vào dự án chính
## Boundary fix — 2026-10-10

The perimeter colliders are only 5 m high while Z carries a victim to 14 m. ArenaPlayBounds previously used idle `process_priority` rather than Godot 4.3 `process_physics_priority`, and constrained only the character proxy. Reproduction measured a proxy more than 1 m outside and ragdoll bones up to 9.3 m outside; the old edge test missed the physical body.

Bounds now run after character movement/recovery and constrain every simulated ragdoll bone at all altitudes, removing outward velocity. Carry transports the ragdoll before applying bounds and keeps the ankle pins synchronized. A carry that hits the perimeter ends its circle into the fall; physical bounds remain active through landing and get-up. This also protects ordinary ragdoll knockdowns at the arena edge.

`run_archer_hawk_bounds_test.gd` checks all eight perimeter planes throughout capture, carry, fall and recovery: Knight, Archer and Wizard each passed 32/32 in separate headless processes (96/96 total, exit 0). Select a profile with `--headless --fixed-fps 60 --script run_archer_hawk_bounds_test.gd -- archer` or `-- wizard`; default is Knight. The fixture injects the real hit/capture path so map pillars do not obstruct projectile acquisition. The test is included in `tools/run_regression.ps1`.

Other headless regressions: Z 27/27, edge 16/16, throw/get-up 66/66, Knight ragdoll 13/13, Knight recovery/bounds 13/13, round finish 35/35; all exit 0, no script/parse errors. Existing headless dummy mesh cleanup errors remain. A combined 24-capture run stalled when switching rigs; the three profile checks above ran separately, so this does not verify sustained mixed-rig stress. Manual camera/animation feel near the wall still needs play testing.

Forward Plus: one full capture/carry/fall/get-up at the previously failing wall passed 4/4, exit 0, stderr empty. The eight-wall renderer attempt exceeded its 45-second budget after three completed cases; it is not counted as a full renderer pass.

Godot priority reference: https://docs.godotengine.org/en/4.3/classes/class_node.html#class-node-property-process-physics-priority

## Ragdoll từ lúc gắp cổ chân — revision 4

Khi diều hâu gắp và bắt đầu nâng, hero vào ragdoll ngay. Hai shin dùng `HawkGripBone` giữ cổ chân trong bước tích phân vật lý, còn thân/tay/đùi phản ứng bằng các joint hiện có. Móng chim căn theo điểm cổ chân của physical bodies thật: SkeletonModifier khôi phục pose animation sau render, nên không đọc pose gốc để xác định điểm gắp. Đầu luôn thấp hơn chân trong vòng bay.

Khi thả, bỏ cả hai pin và giữ nguyên simulation qua rơi/ngã; không khởi động ragdoll lần hai tại lúc chạm đất. Carry tạm giữ camera/proxy và chặn watchdog đứng dậy giữa trời; sau landing hệ ragdoll tiếp tục settle/get-up cùng miễn damage và CC hiện có. Chết/reset/hủy skill dừng simulation và giải phóng pin. Dummy vẫn không có rig humanoid. Không đổi model chim hoặc damage/cooldown.

Headless throw/get-up mới **66/66**, gồm simulation liên tục, hai pin, đầu thấp hơn cổ chân, tay có vận tốc góc thật và miễn tác động khi đứng dậy. Visual mới **33/33** trên Forward Plus (exit 0), đã xem ảnh móng giữ chân và thân treo ngược. Bằng chứng: `scratch/air_final_*.log`, `scratch/hawk_air_visual_final.log`, ảnh `D:/Game 3D/Game_3D/scratch/hawk_phase_3.png`. Backup script cũ ở `scratch/hawk_air_backup`. Chưa benchmark nhiều ragdoll cùng lúc; độ rung/đung đưa cần chơi thử.

Xác minh cuối revision 4: headless throw 66/66, edge 16/16, Knight ragdoll 13/13, kết thúc round 35/35 đều exit 0. Editor import exit 0 (`scratch/hawk_air_final_import.log`). Test throw ba hero trên Vulkan đạt 66/66 nhưng lỗi native lúc thoát, exit -1073741819 (`scratch/hawk_air_final_vulkan.log/.stdout`); hiện chưa xác định nguyên nhân và không gọi suite này là clean pass. Lỗi thoát tương tự từng xuất hiện ở lượt test revision 3. Visual suite trên Vulkan vẫn exit 0. Cần kiểm tra thao tác thoát/đổi scene khi chơi thủ công.

## Cập nhật cú quăng và đứng dậy — 10/10/2026

Vòng bay có bán kính 5,5 m, kéo dài 2,2 giây ở độ cao 14 m. Chim quăng nạn nhân với vận tốc ngang 3,5 m/s. Khi chạm đất, nhân vật chuyển từ carry sang ragdoll vật lý 11 xương, ngã rồi tự đứng dậy bằng `get_up` (0,85 giây). Không dùng block để bỏ qua chuỗi này. Knight, Archer và Wizard đều hỗ trợ; dummy không có rig nên chỉ mô phỏng bay/rơi.

Trong toàn bộ animation đứng dậy, damage HP/khiên, freeze, polymorph, stun, knockback và ragdoll mới đều bị từ chối. Camera trở lại offset trước khi bị bắt. Khi đứng dậy xong sẽ nhận damage bình thường; CC grace 0,30 giây của hệ ragdoll hiện có vẫn áp dụng. Sát thương Z tối đa 24, năng lượng 25 và cooldown 24 giây.

Kiểm tra trên dự án chính: throw/get-up cả ba nhân vật **48/48**, headless exit 0 và Forward Plus exit 0; visual/camera/rig **33/33**, Forward Plus exit 0; Z **27/27**, edge **16/16**, Knight get-up **5/5**, ragdoll lifecycle **13/13**, combat integration **8/8**, kết thúc round **35/35**. Headless vẫn có cảnh báo mesh null của dummy renderer đã có từ baseline. Test visual đưa mục tiêu về vị trí ban đầu giữa các cast vì cú quăng đổi vị trí thật; test throw chờ VFX warmup hoàn tất để tránh lỗi native khi renderer thoát giữa warmup.

Logs: `scratch/hawk_throw_final_headless.log`, `scratch/hawk_throw_final_vulkan.log`, `scratch/hawk_throw_visual.log`, `scratch/throw_*.log` trong worktree Codex. Chưa benchmark FPS hoặc chốt cân bằng bằng chơi thử. Backup bảy file ban đầu của lượt này: `scratch/hawk_throw_backup`.

Xác minh cuối: `scratch/final_throw_*.log` đạt throw 48/48, Knight get-up 5/5 và combat integration 8/8, tất cả exit 0. Editor import retry exit 0, không Script/Parse Error (`scratch/hawk_throw_import_retry.log`); lượt import ngay trước đó gặp Resource Busy khi tải Player rồi lỗi thoát native, không lặp lại ở lượt kiểm tra sau.

Ngày 10/10/2026. Dự án Godot đang được người dùng chạy: `D:/Game 3D/Game_3D`. Bản triển khai trước nằm trong worktree Codex, nên chưa xuất hiện trong phiên game của dự án chính.

Đã ghép 39 file có liên quan vào dự án chính, giữ thay đổi hiện có về Archer model/bow/pose/cape/dash/shader và Knight ragdoll. Không đổi project.godot, Player.tscn hoặc model Archer hiện có. Các file đích cũ được sao lưu tại `scratch/hawk_sync_backup` trong worktree Codex; quá trình ghi kiểm tra SHA256 để không ghi đè file vừa thay đổi.

Đã cập nhật cả HUD Z của bản chính: Diều Hâu, icon một cá/chim, cooldown 24 giây. Payload của fish bỏ ordinary hit reaction để hit stun mới trong bản chính không từ chối capture của chính skill; các hit khác giữ mặc định. Ragdoll không được giành movement khi đã bị chim bắt.

## Kiểm tra tại đúng dự án chính

- Import editor: exit 0, không Script/Parse Error.
- Scene chính `CombatTestArena.tscn`, chọn Archer, phím Z vật lý: **6/6** trên Forward Plus. Test chỉ bỏ dummy tự đánh khỏi fixture để không cản đường projectile; code game vẫn giữ nó.
- Z gameplay: **27/27**; edge: **16/16**.
- Visual rig/animation/camera/móng/collider cao 14 m: **34/34** trên Forward Plus.
- Archer dash: tất cả đạt; Knight ragdoll lifecycle: **13/13**.
- Bộ UI/VFX cũ chưa chạy xong: fixture gắn script StaticBody3D vào Node3D và đọc `combat.reticle_hud` không tồn tại cả trong file trước khi ghép. Không sửa các lỗi độc lập này trong lượt ghép Z. Không gọi toàn bộ regression là đạt.

Bằng chứng log trong `scratch/hawk_main_import.log`, `scratch/hawk_main_scene_verified.log`, `scratch/hawk_main_visual.log`, `scratch/main_run_archer_*.log`, `scratch/main_run_knight_ragdoll_lifecycle_test.gd.log` ở worktree Codex.

Để test thủ công, dừng phiên game đang mở rồi chạy lại `D:/Game 3D/Game_3D/project.godot`. Trong Godot editor dùng F8 để dừng, F5 để chạy toàn bộ dự án; chọn Archer và nhắm một mục tiêu hợp lệ trước khi bấm Z. Nếu mở game độc lập thì đóng cửa sổ game cũ và chạy lại từ editor. Không cần mở worktree Codex để nhận bản Z mới nữa.
