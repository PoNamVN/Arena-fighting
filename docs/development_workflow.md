# Workflow nâng chất lượng Game_3D

Cập nhật: 2026-10-03. Đây là quy trình và lộ trình cho các đợt phát triển tiếp theo;
những mục chưa làm bên dưới là đề xuất, không phải tính năng đã hoàn thành.
Trạng thái triển khai thực tế xem `task_tracker.md` và `AI_HANDOFF.md`.

## 1. Đích đến: một bản chơi nhỏ nhưng hoàn chỉnh

Người chơi mở game, chọn đấu, hoàn thành một trận có mục tiêu thắng rõ ràng,
hiểu vì sao trúng/né/đỡ được đòn, rồi muốn đấu lại. Knight phải có bản sắc:
kiếm và khiên, cận chiến chắc tay, ultimate kiếm khổng lồ có sức nặng.

Chất lượng được đánh giá theo năm mặt: phản hồi điều khiển, khả năng đọc trận,
âm thanh/hình ảnh, công bằng của đối thủ, và độ ổn định trên máy mục tiêu.
Mỗi đợt chọn một cải thiện người chơi có thể nhận ra và thử được.

Nền hiện có: Knight Z/X/C/V, combo/đỡ/né/Counter, map đã sửa, Đấu tập một AI,
đếm ngược và timer, F1–F4 riêng cho Arena Test, ba độ khó AI với combo/né/C.
Người dùng đã xác nhận các phần này hoạt động ổn trong trao đổi hiện tại.

## 2. Thứ tự phát triển

| Đợt | Kết quả người chơi nhận được | Nội dung chính | Điều kiện hoàn tất kỹ thuật |
| --- | --- | --- | --- |
| A — Trận đấu hoàn chỉnh | Một trận có nhiều hiệp, tỷ số và kết quả chung cuộc | Đấu thắng 2 hiệp; nghỉ giữa hiệp; bắt đầu hiệp mới; reset đúng trạng thái; đấu lại/thoát | Không cộng điểm hai lần; không damage sau hết hiệp; hiệp mới sạch camera, timer, skill và AI |
| B — Cảm giác chiến đấu | Mỗi đòn có sức nặng, dễ phân biệt đánh trúng và đỡ | Âm thanh kiếm/khiên/bước chân; animation hit/guard; chỉnh chuyển động và nhịp phản hồi | Hit feedback chỉ xuất hiện tại impact; miss không có hit sound; FPS/TPS không trôi camera |
| C — Diện mạo thống nhất | Sân và nhân vật có điểm nhấn, HUD dễ đọc | Palette, ánh sáng, tương phản nhân vật/nền, vật liệu, bụi/va chạm, bố cục HUD | Chiêu thường vẫn nhìn rõ khi có VFX; HUD không tràn; assets nằm đúng scene |
| D — Knight và AI hoàn thiện | Đối thủ dùng bộ chiêu đa dạng, có sơ hở để khai thác | AI Z, rồi X, rồi V; telegraph; đối sách; cân bằng bằng trận thực | Dùng cùng luật damage/năng lượng/cooldown; cảnh báo đúng điểm/đúng lúc; không đọc input người chơi |
| E — Nhân vật thứ hai | Hai lựa chọn tạo hai cách chơi khác nhau | Cung thủ rừng: tích lực/tự ngắm, Z loạt tên, X ba tên truy đuổi, C lướt/tàng hình, V mồi T-rex; matchup với Knight | Có điểm mạnh/yếu rõ; không chỉ đổi model; dùng chung các API chiến đấu |
| F — Bản demo để chia sẻ | Mở game và chơi mà không cần biết phòng test | Menu, hướng dẫn ngắn, âm lượng, độ nhạy, đồ họa, pause, lưu cài đặt, export Windows | Chạy bản export từ thư mục sạch; chuyển scene ổn; cài đặt được lưu; không cần editor |

Người dùng đã chọn phát triển nhân vật 2 và 3 trước luật trận nhiều hiệp.
Ưu tiên hiện tại là **E: cung thủ rừng**. Bản đầu gồm chọn nhân vật, model riêng,
giữ/thả chuột tích lực, hỗ trợ tự ngắm và tên có va chạm đã được người dùng chấp nhận.
Z loạt6 tên đã triển khai và chờ thử. Tiếp theo X (ba tên truy đuổi), C (lướt/tàng hình),
rồi V (mồi thịt + T-rex), kiểm tra từng chiêu trước khi mở rộng.

Sau khi bộ cung thủ ổn, thử matchup với Knight và chỉnh các chênh lệch rõ ràng.
Nhân vật thứ ba sẽ được thiết kế cùng người dùng; chưa chốt kit.
Sau đó quay lại A (thắng 2 hiệp), rồi các đợt phản hồi, hình ảnh và đóng gói demo.
Quy tắc hòa cần được chốt trong phiếu A trước khi triển khai luật hiệp.

## 3. Chu trình cho mỗi đợt

### Bước 1 — Xác định cải thiện

Viết một phiếu ngắn theo mẫu ở cuối file: trải nghiệm cần cải thiện, phạm vi,
hành vi mong muốn, tiêu chí nghiệm thu và các phần cần giữ ổn định.
Đọc checkpoint và code đang chạy; tài liệu lịch sử có thể cũ hơn implementation.
Đối với lỗi, tái hiện và giữ log trước khi sửa. Nếu cải thiện thẩm mỹ, chụp cùng
một góc camera để so sánh trước/sau.

Không tự chuyển sang một mục tiêu lớn khác giữa đợt. Nếu phát hiện vấn đề liên
quan, ghi mức ảnh hưởng và xử lý phần cần thiết để tính năng đang làm hoạt động.

### Bước 2 — Làm bản nhỏ có thể chơi

Thực hiện lát cắt nhỏ nhất bao trọn trải nghiệm. Ví dụ A phải có từ kết thúc
hiệp, cộng tỷ số, reset, đếm ngược đến đánh tiếp; riêng HUD tỷ số chưa đủ.
Ví dụ âm thanh B bắt đầu với đánh trúng/đỡ/miss rồi mới mở rộng ambience.

Dùng pipeline chiến đấu hiện có cho người và AI. Damage phát sinh ở phase impact;
không gây damage bằng animation/VFX độc lập. Năng lượng, cooldown, block, dodge,
shield và death phải đi qua các API chung.

Tách quản lý trận và hiển thị khi cần để nhiều hiệp có cùng một nguồn trạng thái.
Tránh refactor rộng chưa phục vụ kết quả người chơi của đợt đang làm.

### Bước 3 — Kiểm tra đúng loại thay đổi

- Logic chiến đấu: input thật, physics frame, impact, range/occlusion, damage
  đúng một lần, cooldown/năng lượng, né/đỡ, death/cancel và cleanup.
- Luật trận: bắt đầu/kết thúc, timeout, đồng thời hạ gục, replay/thoát,
  reset giữa hiệp và không để cheat test lan sang trận.
- UI: click thật, chuột captured/visible, FPS/TPS, viewport mục tiêu,
  label dài, menu/result và đọc chữ trên nền sáng/tối.
- Model/animation: hierarchy, origin/scale, rig, FPS head mask, clip timing,
  asset import và renderer thật. Model nhân vật không được chứa map.
- Âm thanh/VFX: đánh trúng/đỡ/miss, không lặp âm hai lần, camera không tích lũy
  drift, kết thúc/hủy dọn effect, các lần dùng chiêu không tăng node vô hạn.
- Cài đặt: thay đổi có tác dụng, lưu/đọc lại đúng, giá trị mặc định hợp lệ.

Tests phải kiểm tra hành vi có ý nghĩa, không chỉ chép lại implementation.
Chỉnh một màu/label không cần thêm suite gameplay. Test chờ diễn biến thật bằng
physics hoặc signal có giới hạn; không ép phase để tạo kết quả mong muốn.

Chạy suite liên quan trước. Với thay đổi vào combat, player, luật trận hoặc
chuyển scene chung, chạy hồi quy đầy đủ trước bàn giao. Nếu chỉ sửa fixture sau
một lần chạy đầy đủ, có thể chạy lại suite bị ảnh hưởng và ghi rõ kết quả từng
lần; không biến báo cáo full run trước đó thành một báo cáo all-green giả.

### Bước 4 — Chơi và tinh chỉnh

Dùng các lượt chơi tập trung sau, ghi vấn đề quan sát được:

1. Arena Test: một skill/lần; dùng F1–F4 để tái hiện nhanh.
2. Đấu tập Dễ: có hiểu đòn và né/đỡ chủ động được không?
3. Đấu tập Thường: có lý do dùng combo, block, dodge, Counter và skill không?
4. Đấu tập Khó: khó do quyết định và nhịp đánh hay do thiếu cảnh báo?
5. FPS/TPS: cùng một tình huống; ngắm V, thoát, chết và chơi lại.

Mỗi vòng chỉ chỉnh một nhóm biến: nhịp đòn, mức phản hồi hoặc tương phản.
Giữ nguyên nhóm còn lại để biết thay đổi nào tạo khác biệt. Cảm nhận hay/dở và
độ khó cần người dùng chơi thật; kết quả headless không chứng minh được điều đó.

Ghi trạng thái “đã kiểm tra kỹ thuật, chờ đánh giá cảm giác” khi phù hợp.
Có thể tiếp tục công việc độc lập đã được giao; không đặt thêm bước xin phép
cho những thao tác đã được người dùng cho phép.

### Bước 5 — Bàn giao và cập nhật

Báo ngắn: thay đổi gì, cách vào thử, kiểm tra nào đã qua, giới hạn còn lại.
Cập nhật `task_tracker.md`, `progress_checkpoint.md`, `AI_HANDOFF.md`.
Phân biệt rõ đề xuất / đã triển khai / đã kiểm tra / người dùng đã chấp nhận.
Giữ log của lỗi và lần chạy lại; không che FAIL bằng danh sách ngoại lệ.

Giữ nguyên thay đổi có sẵn trong workspace. Tạo branch theo `codex/<mô-tả>`
khi công việc cần branch; không chuyển checkout làm mất công việc hiện có.
Commit/push chỉ khi người dùng yêu cầu hoặc đã cho phép rõ trong phiên làm việc;
nghiệm thu bằng lời không tự động đồng nghĩa với quyền commit/push.

## 4. Chuẩn chất lượng đề xuất

Các con số dưới đây là **mục tiêu cần đo**, không phải benchmark đã đạt.

| Mặt chất lượng | Mục tiêu và cách đánh giá |
| --- | --- |
| Hiệu năng | Hướng đến 60 FPS ở 1080p trên GTX1650/4GB; ghi cấu hình renderer, FPS và frame-time trong combat thường và V |
| Độ ổn định | Chơi lại/chuyển phòng 10 lần; node/effect không tăng liên tục; bộ nhớ ổn định sau khi tài nguyên đã warm up |
| Khả năng đọc trận | Người chơi nhận ra mục tiêu, hướng đánh, vùng nguy hiểm và kết quả đỡ/né ngay trong combat |
| VFX | Chiêu thường nhìn rõ, ultimate nổi bật; không phủ hết nhân vật/HUD; có tùy chọn giảm shake/flash ở giai đoạn cài đặt |
| Âm thanh | Phân biệt hit/block/miss; âm lượng được cân bằng; giữ nguồn và giấy phép nếu dùng asset bên ngoài |
| Art | Nhân vật dưới 3.000 tris, props dưới 500 tris theo ngân sách hiện tại; scale/rig/scene đúng, palette và vật liệu nhất quán |
| Công bằng AI | Phản ứng có độ trễ, dùng năng lượng/cooldown thật, có cơ hội bị trừng phạt khi đánh hụt hoặc recovery |
| Bản export | Khởi động, vào trận, chơi lại, đổi cài đặt và thoát hoạt động từ thư mục export sạch |

Nếu mục tiêu không đạt, ghi số đo và nút thắt cụ thể; tối ưu sau profiling.
Ưu tiên tái sử dụng effect và giảm tài nguyên thừa trước khi giảm độ rõ của combat.

## 5. Cách chạy kiểm tra hiện có

Từ thư mục gốc dự án, PowerShell:

```powershell
# Parse một script có thay đổi
& 'D:\Game\godot_editor\Godot_v4.3-stable_win64_console.exe' --path 'D:\Game 3D\Game_3D' --headless --check-only -s scripts/PracticeArena.gd

# Suite liên quan: ví dụ AI
& 'D:\Game\godot_editor\Godot_v4.3-stable_win64_console.exe' --path 'D:\Game 3D\Game_3D' --headless -s run_practice_ai_upgrade_test.gd

# Hồi quy đầy đủ
& ./tools/run_regression.ps1

# Kiểm tra whitespace
git diff --check
```

Xem exit code, số assertion và cả SCRIPT ERROR/parse error. Renderer headless
có thông báo teardown cũ; phải phân biệt với lỗi script và kiểm tra phần hiển thị
bằng renderer thật. Lưu báo cáo trong `tools/regression_output/`.
Không lặp toàn bộ kiểm tra đã qua nếu không có thay đổi/lỗi/nghi ngờ mới.

## 6. Phiếu triển khai dùng lại

```text
Đợt / mục tiêu:
Trải nghiệm người chơi cần tốt hơn:
Phạm vi thay đổi:
Hành vi mong muốn và các nhánh kết thúc:
Phần đã chấp nhận cần giữ ổn định:
Quyết định thiết kế / giả định:
Tiêu chí nghiệm thu (3–5 ý quan sát được):
Các kiểm tra cần chạy:
Cảnh chơi/screenshot so sánh:
Kết quả đo / kết quả test / log:
Đã kiểm tra kỹ thuật:
Đánh giá chơi thật của người dùng:
Vấn đề còn lại và bước kế tiếp:
```

Ví dụ đợt A: “Hoàn thành trận thắng 2 hiệp”. Nghiệm thu tối thiểu: tỷ số chính
xác; không cộng điểm lặp; hai nhân vật sạch trạng thái khi vào hiệp mới; trận có
kết quả chung cuộc; replay và thoát hoạt động ở mọi màn kết quả.


### Cập nhật cung thủ 2026-10-03

Bắn cơ bản, Z và đỡ/Counter đã được người dùng chấp nhận. X ba tên truy đuổi
và C lướt/tàng hình đã triển khai, đang chờ playtest cảm giác/cân bằng. Đợt
tiếp theo là V mồi thịt/T-rex; sau bộ cung thủ mới cân bằng matchup Knight.


### Cập nhật X/V cung thủ 2026-10-03

Người dùng chấp nhận X/C, yêu cầu X bay xoắn và triển khai V ngay sau đó.
X xoắn ba tên và V mồi/T-rex đã triển khai, chờ playtest hình ảnh/cân bằng.
Đợt tiếp theo: cân bằng matchup Knight/cung thủ, rồi quyết định nhân vật3 hoặc luật trận.

## 2026-10-03 — Wizard character milestone
Archer accepted including X/V and hidden control instructions. User chose a
third hero before further complete-match work. Wizard design is locked in
wizard_design.md; first milestone is model/select/charged fireball/guard/Counter.
Next milestone: giant staff Z and chicken polymorph X, then held ice C and storm V.
Gameplay, shared-defense integration and cleanup must pass before expanding kit.

## 2026-10-03 — Wizard Z/X milestone
Foundation accepted by user. Giant staff Z and chicken polymorph X now implemented.
Shared PolymorphEffect owns duration/resistance and visual restoration; actor APIs
gate combat while retaining movement and targetability. Practice AI cancels its
telegraph before snapshot and retreats while transformed. Next: ice glide C, then
immune-channel lightning V; both still unimplemented.

## 2026-10-03 — Wizard C/V milestone
Z/X accepted. Held ice glide C and five-second immune-channel lightning V are now
implemented; see wizard_design.md for controls, parameters and cleanup rules.
Next: user playtest of C steering/mountain and V camera/strike readability, then
balance the three heroes and improve their animation/VFX before complete-match rules.

## 2026-10-03 — Wizard visual polish milestone
Visual-only cached procedural poses and three reusable casting effects implemented.
Actual rig axes/grip fixed, magic-mesh shadows removed. Gameplay parameters preserved.
Next: user playtest, then equivalent Knight/Archer presentation improvements before
balancing and AI. CPU microbenchmark is not a complete-match FPS guarantee.

## 2026-10-03 — Combat spectacle milestone
User wanted much stronger animation/VFX. All three heroes received visual upgrades
with fixed pooling, shared shaders and MultiMesh batches; see combat_spectacle.md.
Next: user playtest of spectacle/readability/FPS, then HUD or matchup tuning.
Visual quality remains constrained by draft low-poly models; no60FPS claim without profiling.
