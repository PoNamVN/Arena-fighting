# Phù thủy nguyên tố

Thiết kế đã chốt với người dùng ngày 2026-10-03. Nhân vật thứ ba: lão phù thủy,
trượng gỗ dạng cành cây, đánh xa và cấu rỉa. Hình ảnh hiện tại là bản nháp low-poly.

## Đợt 1: nền chiến đấu đã triển khai

- Chọn Phù thủy trong Arena Test; giữ lựa chọn khi vào đấu tập, chơi lại và quay về.
- Chuột trái: giữ tích lực tối đa 1,6 giây, tự ngắm đối thủ như cung thủ.
  Thả để bắn một cầu lửa vật lý, tầm 24 m, tốc độ 18–28 m/s,
  sát thương 10–34, bán kính va chạm 0,12–0,42 m, hồi động tác 0,5 giây.
  Tích lực còn 55% tốc độ di chuyển. Không tự bắn khi đạt tối đa.
- Nổ lan tối đa 1,5 m, gây 50% sát thương cho đối thủ phụ có đường nhìn thông;
  không đánh lại mục tiêu trực tiếp, không gây sát thương lên người bắn.
  Mỗi cầu lửa trúng chỉ nhận một lần 15 năng lượng, không tăng theo số đối thủ.
- Chuột phải: khiên phép phía trước giảm 75% sát thương, độ bền 100;
  đòn phía sau bỏ qua khiên. Phá khiên và hồi khiên dùng quy tắc chung.
- Q dùng Dodge/Perfect Dodge chung. Chuột trái mới sau Perfect Dodge bắn tia
  Counter 45 sát thương, 20 sát thương khiên, 40 m/s, tầm 24 m, bật lùi 3,2 m
  trong 0,32 giây. Tường chặn quãng lùi; Counter không cấp miễn sát thương mới.
- Tường chặn cầu lửa/tia phép, mục tiêu chết hoặc bị xóa mất khóa ngắm.
  Esc/đỡ/né/bị đánh hủy tích lực; chết/kết thúc trận dọn phép và hiệu ứng.
- Z/X/C/V đều đã trang bị, dùng bộ chiêu riêng của Phù thủy.

Các thông số trên là cân chỉnh ban đầu, cần người dùng test cảm giác chiến đấu.

## Đợt 2: Z/X đã triển khai

- Z: 30 NL / 7 giây hồi, bản sao trượng gỗ khổng lồ dựng lên rồi đổ theo hướng
  đã ngắm. Dải đánh dài 12,3 m, rộng 2 m; outline/growth 0,8 giây, đổ 0,42 giây.
  Một đòn 38 sát thương / 30 độ bền khiên, hất lùi 1,4 m nếu không đỡ.
  Tường giới hạn chiều dài và đường nhìn; giữ trượng trên tay, bụi/âm thanh/thu nhỏ.
- X: 25 NL / 9 giây hồi, niệm 0,22 giây, tia tím vật lý 26 m/s, tầm 24 m.
  Tự ngắm khi niệm rồi giữ hướng bay, không bám mục tiêu; tường/khiên/i-frame chặn.
  Hóa gà 1,5 giây, vẫn chạy và nhận sát thương nhưng không đánh/đỡ/né/nhảy/dùng skill.
  Hủy đòn đang niệm; không gây HP damage, không hồi NL. Kháng biến hình 2 giây sau đó.
  Model gà riêng và đồng hồ; hết hạn/chết/kết thúc trận trả hình dạng và điều khiển.

## Đợt 3: C/V đã triển khai

- C — Lướt băng: 15 NL khởi động / hồi 10 giây, giữ C để lướt tối đa 3 giây
  với tốc độ 10 m/s, hao thêm 15 NL/giây. Chuột điều hướng; ngắm lên tạo dốc
  băng có va chạm, nâng nhân vật tối đa 5 m so với điểm xuất phát.
  Thả C, hết NL, gặp tường, bị đánh hoặc chạm đóng băng đối thủ sẽ dừng lướt.
- Băng cố định trong thế giới, hết sau 4 giây, giới hạn 55 khối; chết/reset/kết
  thúc trận dọn toàn bộ. Chạm đối thủ đóng băng 0,8 giây, không gây HP damage.
  Khiên phía trước và i-frame chặn được; đóng băng dừng di chuyển và hành động.
  X/C không nối khống chế trực tiếp; hết hạn có 2 giây kháng khống chế chung.
- V — Bão sét: cần đủ 100 NL; camera zoom ra và chuột trái chọn vùng trong 24 m,
  bán kính 7 m. Chưa xác nhận chưa tiêu hao/miễn sát thương; Esc, bị đánh hoặc
  quá 8 giây hủy chọn. Click mới sau khi camera chuyển xong mới xác nhận.
- Khi xác nhận: tiêu hao 100 NL, đứng yên niệm 5 giây, mây đen và 20 tia sét
  ngẫu nhiên phân bố trong vùng. Mỗi điểm cảnh báo trước 0,32 giây, bán kính
  đánh 2 m, 24 sát thương / 20 độ bền khiên; tường/mái che, đỡ, i-frame và
  Perfect Dodge dùng kiểm tra chung. Không gây sát thương bản thân, không hồi NL.
- Khiên cầu bao quanh miễn toàn bộ HP damage, sát thương khiên, knockback và
  khống chế trong 5 giây; bảo vệ cả lời gọi trực tiếp HealthComponent. Không
  dùng hành động khác khi niệm. F3 test độc lập với miễn sát thương của V.
- Bầu trời/ánh sáng và mây chuyển dần: tối trong 1 giây đầu, sáng trong 1 giây
  cuối của bão. Giữ nguyên loại sky gốc và chỉ chỉnh bản environment riêng; không
  đổi đột ngột sang nền màu phẳng. Dọn phòng vẫn trả ngay tài nguyên gốc.
- Kết thúc hoặc chuyển phòng trả camera, chuột, ánh sáng và environment gốc;
  dọn cảnh báo/sét/mây/khiên và cờ miễn sát thương. Mây không đổ bóng đặc xuống sân.

## Nguồn asset

- `blender/build_elemental_wizard.py`: tạo model riêng trên rig nền của dự án,
  chỉ giữ idle/run/dead, bỏ vũ khí Knight, áo choàng xanh, mũ và râu bạc.
- `tools/blender_sources/elemental_wizard.blend`: nguồn editable riêng.
- Model 627 tam giác, 25 nodes, 18 bones, 3 animation; trượng 118 tam giác, 2 nodes.
- Export selection + active scene; không có mesh đấu trường hoặc scene khác.
- Hai âm thanh phép tự tổng hợp; không dùng asset bên thứ ba.


## Kiểm chứng đợt 1
47/47 bộ hồi quy đạt, exit0, không lỗi SCRIPT/parse. Riêng phù thủy44/44 trên
headless và OpenGL Compatibility, stderr renderer rỗng, đã xem ảnh trong Godot.
Test gồm tích lực, va chạm/tường/nổ lan, khiên trước/sau/phá khiên, Perfect Dodge,
Counter/quãng lùi/tường, Esc/chết/respawn/kết thúc trận, chọn hero và đếm ngược.
Log: scratch/wizard_full_regression.log, wizard_verified_headless.log,
wizard_verified_render.log. Người dùng chưa test cảm giác/model của phù thủy.


## Kiểm chứng đợt 2
Z/X46/46 headless và OpenGL Compatibility; stderr renderer rỗng. Full48/48 bộ
hồi quy đạt, exit0, không lỗi SCRIPT/parse; syntax và diff sạch. Đã xem khung hình
trượng đang lớn/đổ và model gà. Log scratch/wizard_zx_extended.log,
wizard_zx_final_render.log, wizard_zx_full_regression.log. Chờ người dùng test.

## Kiểm chứng đợt 3
C/V62/62 headless và OpenGL Compatibility; stderr renderer rỗng. Full49/49 bộ
hồi quy đạt, exit0, không lỗi SCRIPT/parse; syntax exit0 và diff sạch.
Đã xem dốc băng và bão sét trong renderer thật. Test gồm năng lượng/F1/giới hạn
địa hình, tường/đóng băng/kháng CC, chọn vùng bằng chuột, Perfect Dodge, miễn
sát thương trực tiếp, 20 tia trong 5 giây, camera FPS, kết thúc trận và thoát
scene khi V đang chạy. Headless có nhiễu null-mesh của dummy renderer như trước.
Log: scratch/wizard_cv_exit_test.log, wizard_cv_verified_render.log,
wizard_cv_full_regression.log. Cảm giác điều hướng/camera/cân bằng chờ người dùng test.

### Điều chỉnh V: ánh sáng chuyển dần
Bầu trời, ánh sáng sân và mây tối dần trong 1 giây đầu, sáng dần trong 1 giây
cuối của bão; giữ nguyên thời gian sát thương/khiên 5 giây. Giữ loại sky gốc,
chỉnh environment riêng và khôi phục tài nguyên gốc khi dọn phòng.
Kiểm chứng C/V67/67 headless và OpenGL Compatibility, stderr renderer rỗng;
syntax exit0 và diff sạch. Log scratch/wizard_storm_fade_headless.log và
wizard_storm_fade_render.log. Full49 bộ của đợt trước; lần chỉnh này chạy bộ C/V.

## Đợt 4: động tác và hiệu ứng tối ưu
Tư thế tay/trượng riêng cho tích cầu lửa, phóng phép/Counter, đỡ, Z dựng/đổ,
X, C và V; chuyển động nội suy mượt trên rig hiện có. Trượng bám tay thật,
sửa trục R/L và trước/sau của rig nhập. Không đổi thông số hay thời điểm đánh.
Ba mesh phụ tái sử dụng: vòng phép bàn tay, hào quang chân C/V, đốm sáng đầu
trượng. Cache xương/material, chia sẻ mesh vòng; không tạo node trong update.
Tắt bóng của mesh phép, giữ bóng trượng vật lý và địa hình. Bị đánh/khống chế,
chết/reset dọn tư thế/hiệu ứng; không chặn animation chết.
Kiểm tra mới26/26 headless/OpenGL; nền44/44, Z/X46/46, C/V67/67 và cô lập map17/17
đạt. Syntax exit0. CPU riêng presentation khoảng0,02ms/update trên máy này,
chưa đại diện FPS cả trận hoặc máy yếu. Log scratch/wizard_presentation_verified_headless.log,
wizard_polish_final_render.log, wizard_presentation_foundation.log,
wizard_presentation_zx.log và wizard_presentation_cv.log. Cần người dùng test cảm giác.
