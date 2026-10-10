# Archer Z — bản triển khai cá và diều hâu

**Main project sync 2026-10-10:** Archer Z has now been merged into `D:/Game 3D/Game_3D`, the project actually launched by Godot. See [ARCHER_Z_MAIN_SYNC.md](ARCHER_Z_MAIN_SYNC.md) for verification and restart instructions.

Ngày 10/10/2026. **Revision 2: gắp chân, treo ngược, 14 m, cooldown 24 giây và chim mới.** P1–P3 đã triển khai; P4 đã kiểm tra gameplay và renderer. Cân bằng cuối cùng cần chơi thử bằng người thật.

## Hành vi hiện tại

- Z của Archer bắn **một mũi tên kẹp cá** dẫn hướng có giới hạn tốc độ quay. Projectile ray sweep, dừng khi va tường, không chuyển sang mục tiêu khác.
- Mất **25 năng lượng**, hồi chiêu **24 giây**; chuẩn bị 0,30 giây, recovery 0,25 giây. Không có mục tiêu hợp lệ thì không mất tài nguyên.
- Đỡ đúng hướng: **0 sát thương HP**, mất 10 độ bền đỡ, cá bật ra; kể cả phá đỡ cũng không gọi chim. Né trong iframe dùng resolver/Perfect Dodge chung.
- Trúng trực tiếp: **4 sát thương**, chim lao xuống gắp hai cổ chân, lật mục tiêu ngược đầu xuống và nâng collider lên 14 m trong 1,1 giây; bay một vòng ngang bán kính 5,5 m trong 2,2 giây rồi quăng với vận tốc ngang 3,5 m/s. Nạn nhân không tự thoát, đỡ, né hoặc dùng skill khi bị bắt.
- Rơi gây **tối đa 20 sát thương**, tính theo độ cao rơi thực tế và chỉ áp dụng một lần. Tổng riêng Z tối đa 24 trong sân thoáng. Sau khi chạm đất, hero ngã ragdoll rồi tự đứng dậy; toàn bộ clip get_up 0,85 giây miễn damage HP/khiên và tác động CC. Xem ARCHER_Z_MAIN_SYNC.md cho revision 3 và kiểm tra mới. Khi rơi, nạn nhân xoay về tư thế đáp đất trong 0,45 giây; tổng damage vẫn giữ thấp dù độ cao tăng.
- Knight, Archer, Wizard và dummy dùng chung controller. Tôn trọng miễn nhiễm có sẵn; không chồng thêm freeze/polymorph lên carry.
- Collider nạn nhân vẫn là actor thật: swept movement khi nâng/bay, vật lý khi rơi, giới hạn sân mỗi bước. Gặp trần/cột/rìa sân thì kết thúc vòng sớm và rơi tại vị trí hợp lệ. Đây là phương án đơn giản hơn việc tìm lại một vòng nhỏ quanh chướng ngại vật.
- Caster/target chết, reset, đổi scene hoặc ENDING thì cleanup; không để pending landing hit tiếp tục sau kết thúc trận.

## Asset, animation và VFX

Nguồn Blender: `blender/archer_hawk_z.blend`, builder tái tạo: `blender/build_archer_hawk_z.py`. Dựng bằng Blender MCP trong scene riêng, giữ nguyên scene cũ; export chỉ active scene.

| Asset | Ngân sách và nội dung |
|---|---|
| `assets/models/forest_hawk.glb` | 2.880 triangles; một mesh có skin, 8 material surfaces, 23 deform bones và 2 grab socket bones khi import Godot |
| `assets/models/hunter_fish_arrow.glb` | 368 triangles, cá/kẹp/tên, đuôi chuyển động |
| Animation chim | `dive`, `grab`, `lift`, `carry_flap`, `release`, `exit` |
| VFX | vòng đánh dấu vai/điểm rơi, burst gió/lông, landing ring, fish trail và hai wing trails với batch 24 đoạn mỗi trail |
| Audio | Ba WAV tổng hợp nguyên bản cho tiếng chim, vỗ cánh và bật cá; không dùng thư viện bên ngoài |

Móng chim căn theo pose bone đã cập nhật khi render, bám vị trí trung bình của hai cổ chân trong lift/carry. Nạn nhân lật 180° quanh tâm thân, hai chân phía trên, tay đung đưa phía dưới; collider vẫn đứng dọc để giữ vật lý ổn định. Chim có cánh liền với blend weights ở khuỷu/cổ cánh, lông thuôn nhiều lớp, đuôi xòe, mắt và móng cong; flap có độ trễ vai–khuỷu–đầu cánh/lông. Mesh dùng palette nhỏ, không thêm texture hoặc dependency. TPS giữ camera của người chơi; FPS nạn nhân lật roll 180° và hạ điểm nhìn xuống đúng phía đầu của thân treo ngược; loại geometry cơ thể/cá/móng gần mắt bằng render layer riêng, các camera khác vẫn thấy đầy đủ. Không giành camera Archer để chạy cinematic.

Burst và marker dùng `VFXManager`/pool hiện có. LOW/OFF không thay đổi capture hoặc sát thương; cảnh báo thiết yếu vẫn tồn tại. Chim, collider và controller gameplay nằm ngoài pool trang trí.

## Kiểm tra revision 2

Import Godot exit 0, không có Script/Parse Error. `run_archer_volley_test.gd`: 27/27, gồm cooldown 24 giây và không thể cast lại sau khi chuỗi kết thúc. `run_archer_hawk_edge_test.gd`: 16/16, gồm caster chết khi nạn nhân đang ở độ cao 14 m và cleanup trở về sàn.

Visual suite revision 2: Forward Plus 34/34; OpenGL 34/34 sau sửa fade trail. Sáu suite gameplay liên quan (Z, edge, basic, defense, X/C, Practice) đạt tổng 190/190 assertions trên revision 2. Có kiểm tra pose cánh thay đổi, móng bám cổ chân, collider đạt 14 m, body/FPS treo ngược, restore camera và ba cast không giữ node/effect leases. Logs mới: `scratch/hawk_v2_final_import.log`, `scratch/hawk_v2_visual_forward.log`, `scratch/hawk_v2_visual_gl_final.log`, `scratch/v2_run_archer_*.log`.

## Kiểm tra bản đầu (lịch sử)

Godot **4.3 stable**, GPU **GTX 1650**. Không đo benchmark FPS.

| Nhóm | Kết quả |
|---|---|
| 12 suite Archer/Wizard/spectacle/Practice/VFX liên quan | 627/627 assertions, tất cả exit 0 |
| 10 suite resolver, shield, iframe, counter, Knight, dummy, AI, map bounds | 280/280 assertions, tất cả exit 0 |
| `run_archer_hawk_edge_test.gd` | 16/16: homing mục tiêu di chuyển, tường sau launch, trần thấp, giảm damage rơi thấp, chết/xóa actor, miễn CC khác, Perfect Dodge, giới hạn sân, dummy |
| `run_archer_hawk_visual_test.gd`, OpenGL Compatibility | 31/31: warmup renderer thật, rig/6 clip, đồng bộ móng, các pha, ba cast, LOW/OFF, TPS/FPS, restore camera và trả geometry/effect leases về sạch |
| Cùng visual suite, Forward Plus/Vulkan | 29/29 trước khi thêm hai assertion cleanup; cùng implementation gameplay/render |
| Chạy lại bản cuối | Z, edge, basic, defense và X/C được chạy lại sau sửa rebound/camera |

Tổng **24 suite khác nhau** đã chạy. Không chạy toàn bộ runner của repo. Một số suite headless có cảnh báo dummy renderer `Parameter "m" is null` lúc giải phóng mesh đã gặp ở baseline; không có Script/Parse Error trong các lượt đạt. Hai lượt visual cuối không có cảnh báo này.

Bằng chứng: `scratch/hawk_targeted_results.json`, `scratch/hawk_core_results.json`, `scratch/final_run_archer_*.log`, `scratch/hawk_visual_final_gl.log`, `scratch/hawk_visual_final_forward.log`.

Ảnh renderer: [chim mang nạn nhân](../scratch/hawk_phase_3.png), [góc nhìn Archer](../scratch/hawk_gameplay_tps.png), [FPS nạn nhân](../scratch/hawk_victim_fps.png).

Để kiểm tra lại hình ảnh, chạy Godot với `--path . --rendering-method gl_compatibility -s run_archer_hawk_visual_test.gd` hoặc `--rendering-method forward_plus`. `tools/run_regression.ps1` đã dùng đúng checkout hiện tại và timeout từng suite; suite edge được thêm vào runner, visual suite chạy riêng vì cần renderer thật.

## Còn cần chơi thử

Chưa chốt độ mạnh của khóa điều khiển hoặc combo Z + V, chưa benchmark trên máy yếu, chưa kiểm thử mạng/multiplayer hoặc stress nhiều chim đồng thời. Kiểm tra tự động ba cast và hồi trả pool không thay thế benchmark tải. Pause/resume, replay và sàn có hình học phức tạp nên được người chơi kiểm tra thêm. Revision 3 thêm ragdoll cho hero theo yêu cầu mới; không thêm QTE thoát hoặc AI/HP riêng cho chim.
