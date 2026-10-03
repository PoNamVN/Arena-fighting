# Khung VFX dùng chung — Task 0.2

Khung chạy bằng autoload `VFXManager`, tách riêng khỏi combat. Mỗi hiệu ứng mới là một scene tại `res://vfx/<nhân_vật>/<tên>.tscn`, root dùng `scripts/vfx/PooledVFX.gd` hoặc script kế thừa nó. Task này chưa chuyển hiệu ứng cũ sang khung mới và chưa nâng cấp hình ảnh của nhân vật.

## File của task

| File | Vai trò |
| --- | --- |
| `scripts/vfx/VFXManager.gd` | Registry theo tên, pool cố định, warm-up, chất lượng, bridge signal |
| `scripts/vfx/PooledVFX.gd` | Vòng đời hiệu ứng, tự hoàn tất, reset particle/animation/transform/tween |
| `scripts/vfx/VFXDefinition.gd` | Resource cấu hình một hiệu ứng |
| `scripts/vfx/VFXLibrary.gd` | Resource chứa danh sách definition |
| `vfx/vfx_library.tres` | Registry mặc định được nạp lúc khởi động |
| `vfx/shared/pool_probe.tscn` | Scene mẫu: 16 GPU particle, không bind combat |
| `project.godot` | Đăng ký autoload |
| `scripts/PlayerController.gd` | Chỉ thêm hai khai báo signal trình diễn còn thiếu |
| `scripts/PlayerCombat.gd` | Chỉ thêm khai báo signal impact chính xác còn thiếu |
| `run_vfx_framework_test.gd` | Kiểm tra pool, lifecycle, signal, chất lượng và giới hạn particle |
| `tools/run_regression.ps1` | Thêm suite của khung VFX vào regression |
| `docs/vfx_framework.md` | Cách sử dụng, phạm vi và kết quả kiểm tra |

## Cắm một hiệu ứng mới

1. Tạo scene riêng, root kế thừa `PooledVFX.gd`; giữ particle, mesh và animation trong scene. Màu/cường độ và tham số đặc thù dùng export var hoặc Resource của hiệu ứng.
2. Thêm `VFXDefinition` vào `vfx/vfx_library.tres`. Chọn `effect_name`, `scene`, `pool_size`, `duration` và bộ lọc `event` / `hero` / `skill`. Bộ lọc rỗng khớp mọi giá trị.
3. Manager preallocate và warm-up registry lúc load. Không tạo node mới khi cast. Definition đăng ký thêm bằng `register_definition()` cần gọi `await warm_up()` trước khi spawn.
4. Logic chỉ phát signal ở thời điểm gameplay đã xác định. Manager nghe signal và chọn scene phù hợp. Không gọi damage, đổi hitbox, FSM, cooldown hay điều khiển từ hiệu ứng.

Ví dụ API để thử một scene từ công cụ trình diễn:

```gdscript
var fx: Node3D = VFXManager.spawn(
    &"framework_probe",
    Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)),
    {"actor": actor}
)
VFXManager.quality = VFXManager.Quality.LOW
VFXManager.enabled = false
```

`spawn()` trả `null` khi tên không tồn tại, chưa warm-up, pool đầy hoặc hiệu ứng trang trí bị tắt. Pool đầy bỏ yêu cầu mới, không cắt hiệu ứng đang chạy và không tăng pool giữa combat. `spawn_rejected` cung cấp lý do cho các trường hợp tên/chưa warm-up/pool đầy.

`context.actor` gắn vòng đời với nhân vật: khi nhân vật rời scene, lease của nó được trả về pool. `context.follow` và `context.follow_offset` cho hiệu ứng bám anchor qua WeakRef. Anchor bị xóa thì hiệu ứng kết thúc.

Root có `_on_play(payload)`, `_on_update(delta)`, `_on_reset()` để kế thừa. Kết thúc bằng `finish()`, hoặc để `duration` tự kết thúc. Không `queue_free()` pooled node. Với callback bất đồng bộ, chụp `lease_id` ngay lúc play rồi gọi `finish(captured_lease)` để callback cũ không kết thúc lượt tái sử dụng mới. Mọi Tween do hiệu ứng tạo phải đăng ký bằng `track_tween(create_tween())`; `_on_reset()` chịu trách nhiệm phục hồi material, audio và trạng thái tùy chỉnh ngoài những gì lớp gốc quản lý. AnimationPlayer được dừng khi trả pool; hiệu ứng phải chủ động play animation mong muốn ở `_on_play()`.

Scene có CollisionObject3D/CollisionShape3D/CollisionPolygon3D bị từ chối đăng ký. Mesh không đổ bóng, OmniLight/SpotLight bị tắt shadow. Đây là lớp trình diễn; giới hạn kiểm tra cấu trúc không thể ngăn script tùy chỉnh cố tình thay đổi gameplay.

`_on_reset()` phải idempotent: lớp gốc gọi reset cả khi khởi tạo, trước play và lúc kết thúc/trả pool. Không dùng hook reset để phát damage hoặc đếm sự kiện combat.

## Resource và chất lượng

| Tham số | Mặc định / ý nghĩa |
| --- | --- |
| `effect_name`, `scene` | Tên duy nhất và PackedScene |
| `pool_size` | 8; giới hạn 1–64 instance được preallocate |
| `duration` | 0,4 giây; thời lượng trình diễn, không quyết định thời điểm damage |
| `ultimate` | false; giới hạn phát hạt mỗi instance: thường 200, ultimate 500 |
| `essential` | false; true cho telegraph cần đọc được trong PvP |
| `event`, `hero`, `skill` | Bộ lọc signal; skill dùng `AbilityData.id` |
| `warmup_context` | Payload đủ để hiệu ứng hiện mesh/shader khi render thử |
| `warmup_seconds` | 0,12 giây; điều chỉnh để trạng thái cần compile thực sự xuất hiện |

Low / Medium / High có hệ số 0,5 / 0,75 / 1,0. Mặc định Medium, bật VFX. GPU particle giữ allocation `amount` gốc và đổi `amount_ratio`; CPU particle đổi `amount` từ giá trị gốc đã cache. Không nhân lũy tiến khi đổi chất lượng nhiều lần. Giới hạn 200/500 được chia giữa emitter của cùng instance; đây là ngân sách phát hạt cấu hình, không phải phép đếm hạt còn sống trên GPU. Allocation GPU vẫn bằng amount authored, nên cần author amount hợp lý.

Chất lượng mới áp dụng cho lượt cast tiếp theo; hiệu ứng đang chạy giữ số hạt cũ để tránh nhấp nháy. Tắt VFX trả hiệu ứng trang trí đang chạy về pool. `essential=true` giữ nguyên telegraph khi Off hoặc Low. Chưa thêm menu cài đặt hay lưu tùy chọn vào đĩa.

Ngân sách trên không cộng toàn bộ instance/scene thành giới hạn chung cho một skill. Khi thiết kế skill gồm nhiều scene hoặc nhiều lượt chồng nhau, cần chia ngân sách và chọn pool_size phù hợp. Không thể bảo đảm chi phí overdraw chỉ từ số particle.

## Warm-up

Mỗi scene trong registry được mượn một instance của pool và render ở High trong SubViewport 128×128, world/camera riêng, không xuất hiện trong sân đấu. Chờ render và readback texture thực trước khi đánh dấu đã warm-up, rồi reset và trả instance. Viewport được xóa sau khi hoàn tất. `warmup_started`, `warmup_finished(rendered)` và `warmup_complete` cho bước load phía sau sử dụng.

Payload có `warmup=true`: hiệu ứng tương lai phải tránh âm thanh hoặc tác động ngoài trình diễn trong chế độ này. `warmup_context`/thời gian/camera cần phù hợp với scene; một render thử không bảo đảm compile mọi biến thể shader hay mọi pha chưa được hiển thị. Camera mặc định nhìn vùng gần gốc tọa độ: scene kích thước khổng lồ cần thiết kế trạng thái warm-up tương ứng. Warm-up chỉ bao gồm registry mới, chưa bao gồm VFX cũ. Headless bỏ render GPU và báo `warmup_rendered=false`; không dùng headless làm bằng chứng compile shader.

## Signal hiện có và còn thiếu

| Nguồn | Event manager | Phạm vi / giới hạn |
| --- | --- | --- |
| `AbilitySystem.ability_cast_started(slot, ability)` | `cast_started` | Cast đã được chấp nhận; không luôn là bắt đầu giữ tích lực hoặc wind-up |
| `PlayerCombat.hit_landed(target, damage, blocked)` | `hit` / `block` | Các đường combat đã phát signal; nguồn cũ không có skill ID để lọc theo skill, không bổ sung phát signal cho đường cũ còn thiếu |
| Actor `hit_reacted(blocked, direction)` | `received_hit` / `received_block` | Event phía người nhận riêng, tránh tự nhân đôi effect phía người đánh |
| Actor `shield_broken()` | `shield_break` | Nghe signal có sẵn |
| Actor `ability_action_finished(slot)` | `skill_finished` | Chủ yếu action Hiệp sĩ; signal cũ không phân biệt hoàn tất/hủy |
| Actor `presentation_cast_started(skill_id)` | `cast_started` | **Khai báo rỗng mới; chưa emit trong production** |
| Actor `presentation_skill_finished(skill_id, cancelled)` | `skill_finished` | **Khai báo rỗng mới; chưa emit trong production** |
| Combat `presentation_impact_frame(skill_id, position, normal)` | `impact_frame` | **Khai báo rỗng mới; chưa emit trong production** |

Các điểm còn thiếu để task sau nối đúng pha: bắt đầu giữ tích lực/wind-up, impact chính xác từng skill/projectile, kết thúc/hủy custom skill Cung thủ và Phù thủy, một số contact bespoke Hiệp sĩ. Vị trí hit/block/shield hiện là vị trí thân nhân vật gần đúng; chỉ hook impact mới có vị trí/pháp tuyến chính xác. Không suy đoán impact từ timer VFX. Khi nối reserved hook sau này, chọn một nguồn cast/end tương ứng để tránh phát hai lần cùng một sự kiện.

## Đo hiệu năng và kiểm tra

Đo trước/sau bằng Godot 4.3 Forward+, GPU NVIDIA GTX 1650, viewport 1920×1080, VSync tắt. Fixture là CombatTestArena, tắt tự đánh của dummy, cùng camera, chờ ổn định rồi lấy mẫu idle 5 giây. Cửa sổ chạy ẩn/ngoài màn hình; số liệu là benchmark tự động trên renderer thực, chưa thay thế playtest tương tác toàn màn hình.

| Mẫu | FPS trung bình | P99 frame (ms) | Frame chậm nhất (ms) |
| --- | ---: | ---: | ---: |
| Idle trước khung mới | 292,05 | 3,783 | 9,926 |
| Idle sau khung mới | 288,07 | 3,788 | 9,908 |
| Spawn 1–50 | 274,60 | 3,942 | 4,249 |
| Spawn 51–100 | 278,89 | 3,856 | 4,017 |

100 lượt cách nhau 4 physics frame, lifetime 0,4 giây, High, tự trả pool: 100/100 được nhận, dùng lại 7 trong 8 instance, node giữ 271 → 271, kết thúc active=0 và available=8. Draw call peak của hai nửa: 601 / 590; warm-up sample gửi 1 draw call thật. Tổng Object của toàn arena 2109 → 2117, vì vậy kết quả này chứng minh không tăng node, không khẳng định mọi Resource toàn game không tăng. Mức giảm idle khoảng 1,4% có thể nằm trong biến động mẫu; chưa đủ để kết luận chi phí cố định chính xác của manager.

Suite riêng: 58/58 headless, 59/59 Forward+ (có thêm assert draw warm-up). Bao gồm 100 vòng reuse, 100 yêu cầu đồng thời (chỉ nhận 8, bỏ 92), tự hoàn tất, stale lease/double return, CPU/GPU quality, budget 200/500, Off/essential, follow/actor bị xóa, collision rejection, bridge signal và một cast thật có kiểm tra năng lượng/HP.

`tools/run_regression.ps1`: **52/52 suite PASS**, exit 0. Check-only suite VFX cùng các script preload: không có lỗi parse/script. `git diff --check` đạt; có cảnh báo chuyển LF/CRLF ở các file đã có thay đổi từ trước task. So hash 128 file của bản đầu task: chỉ bốn file cũ thay đổi (`project.godot`, hai script thêm signal, regression runner); strip các khai báo signal mới thì hai script combat giống nguyên bản đầu task. Không commit/push.

Log benchmark, JSON số đo, harness và log regression được lưu tại [thư mục bằng chứng](<C:/Users/HP VICTUS/.codex/visualizations/2026/10/02/01a0fb78-a0a2-79f3-b140-30494a041d08/vfx_framework_0_2>). Kết quả phản ánh phiên đo ngày 03/10/2026, không phải bảo đảm FPS cho hiệu ứng chưa được thiết kế.

Headless có thông báo null mesh từ dummy renderer khi teardown các scene combat có sẵn; Forward+ không có thông báo này. Không có lỗi script/parse ở suite đã xác nhận. Chưa test thủ công bằng bàn phím/chuột hoặc chứng minh ≥60 FPS cho toàn bộ 12 skill cũ; không có thay đổi số gameplay/timing/FSM/input. Task dừng ở khung dùng chung.
