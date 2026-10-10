from PIL import Image, ImageDraw, ImageFont
import os

f1 = r'd:\Game 3D\Game_3D\scratch\elf_archer_front.png'
f2 = r'd:\Game 3D\Game_3D\scratch\elf_archer_back_capped.png'
f3 = r'd:\Game 3D\Game_3D\scratch\elf_archer_34.png'
f4 = r'd:\Game 3D\Game_3D\scratch\archer_godot_real_ingame.png'

out_path = r'd:\Game 3D\Game_3D\scratch\elf_archer_master_showcase.png'

target_w, target_h = 800, 800
canvas = Image.new('RGB', (target_w * 2, target_h * 2), (35, 39, 46))

images = [
    (Image.open(f1), 0, 0, "1. Front View"),
    (Image.open(f2), target_w, 0, "2. Back View (Capped Hood)"),
    (Image.open(f3), 0, target_h, "3. 3/4 Perspective View"),
    (Image.open(f4), target_w, target_h, "4. Real Godot 4.3 Vulkan")
]

draw = ImageDraw.Draw(canvas)

for img, x, y, label in images:
    # Resize keeping aspect ratio or fit target
    img_resized = img.convert('RGBA').resize((target_w, target_h), Image.Resampling.LANCZOS)
    canvas.paste(img_resized, (x, y), img_resized)
    # Draw label box
    draw.rectangle([x + 20, y + 20, x + 380, y + 55], fill=(20, 24, 30, 200))
    draw.text((x + 30, y + 26), label, fill=(240, 245, 250))

canvas.save(out_path, format='PNG')
print("Successfully generated:", out_path)
