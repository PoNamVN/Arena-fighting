# ARENA FIGHTING PROJECT CHECKPOINT

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
