"""Build reviewed-source Gandalf atlases, Godot resources and animated previews.

Run from project root. Dependencies: Pillow, numpy, scipy.
The source recipes are deliberately explicit, not a general sprite AI.
Source files are supplied in the downloadable source package.
"""
from pathlib import Path
import json
import hashlib
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import label, find_objects

ROOT = Path(__file__).resolve().parents[1]
SIZE, PIVOT = 256, (128, 208)
OUT = ROOT / 'art/characters/gandalf'
PREVIEW = ROOT / 'art/previews'
SOURCE = ROOT / 'art/source_candidates'
FRAMES = {}
RECIPES = {}


def components(name):
    image = Image.open(SOURCE / name).convert('RGBA')
    arr = np.array(image)
    labels, _ = label(arr[:, :, 3] >= 180)
    result = []
    for i, region in enumerate(find_objects(labels)):
        if region is None or np.sum(labels[region] == i + 1) < 1000:
            continue
        y, x = region
        crop = arr[region].copy()
        crop[:, :, 3] = np.where(labels[region] == i + 1, 255, 0)
        result.append({'box': [x.start, y.start, x.stop, y.stop],
                       'image': Image.fromarray(crop)})
    return result


def take_row(items, center_y, tolerance, expected):
    row = sorted([item for item in items if abs((item['box'][1] + item['box'][3]) / 2 - center_y) < tolerance],
                 key=lambda item: item['box'][0])
    if len(row) != expected:
        raise ValueError(f'Expected {expected} components near y={center_y}; found {len(row)}')
    return row


def assemble(animation, items, pivots, scale, source, fps=10, loop=False, issues=None):
    output, records = [], []
    for item, pivot in zip(items, pivots, strict=True):
        box, image = item['box'], item['image']
        resized = image.resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))), Image.Resampling.NEAREST)
        offset = (PIVOT[0] + round((box[0] - pivot[0]) * scale), PIVOT[1] + round((box[1] - pivot[1]) * scale))
        if min(offset) < 0 or offset[0] + resized.width > SIZE or offset[1] + resized.height > SIZE:
            raise ValueError(f'{animation} clips at {offset}')
        frame = Image.new('RGBA', (SIZE, SIZE))
        frame.alpha_composite(resized, offset)
        output.append(frame)
        records.append({'source_box': box, 'source_pivot': list(pivot), 'scale': scale})
    FRAMES[animation] = output
    RECIPES[animation] = {'fps': fps, 'loop': loop, 'source': source, 'frames': records,
                          'status': 'review_candidate', 'known_issues': issues or []}


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    source = 'gandalf_idle_v01.png'
    all_items = components(source)
    idle = take_row(all_items, 325, 100, 4) + take_row(all_items, 950, 100, 4)
    assemble('idle', idle, [(157 + round(i % 4 * 1254 / 4), 582 + i // 4 * 627) for i in range(8)], 112 / 510, source, 8, True)

    source = 'gandalf_movement_v01.png'
    items = components(source)
    configs = [
        ('walk', 170, [190, 500, 812, 1128], 322, 10, True),
        ('run', 480, [200, 516, 831, 1144], 617, 14, True),
        ('jump', 780, [191, 518, 830, 1143], 925, 12, False),
        ('fall', 1080, [191, 518, 830, 1143], 1230, 9, False)]
    for name, center, xs, base, fps, loop in configs:
        assemble(name, take_row(items, center, 115, 4), [(x, base) for x in xs], 112 / 301, source, fps, loop)

    source = 'gandalf_staff_v01.png'
    items = take_row(components(source), 285, 100, 6)
    assemble('staff_strike', items, [(x, 474) for x in [130, 367, 632, 923, 1210, 1435]], 112 / 378, source, 18)

    source = 'gandalf_heavy_v02.png'
    items = components(source)
    heavy = take_row(items, 355, 120, 3) + take_row(items, 955, 120, 3)
    assemble('heavy_staff', heavy, [(x, y) for x, y in [(240,616),(650,616),(1040,616),(230,1182),(655,1182),(1080,1182)]],
             112 / 492, source, 12)

    source = 'gandalf_specials_v01.png'
    items = components(source)
    for name, center, baseline in [('lightning', 245, 431), ('fireball', 640, 809), ('magic_push', 1030, 1198)]:
        row = take_row(items, center, 90, 6)
        pivots = [(x, baseline) for x in [112,305,509,720,952,1165]]
        # Reject poses that drop the prop. Hold a valid pose instead of shipping it.
        order = {'lightning':[0,1,2,3,3,5], 'fireball':[0,1,1,3,3,5]}.get(name,list(range(6)))
        assemble(name, [row[i] for i in order], [pivots[i] for i in order],
                 112 / 339, source, 12)
        RECIPES[name]['source_pose_order'] = order
        RECIPES[name]['unique_source_poses'] = len(set(order))

    source = 'gandalf_reactions_v01.png'
    items = components(source)
    for name, center, xs, base, fps in [
        ('hurt',175,[195,491,797,1116],325,14),
        ('knockback',480,[200,508,814,1127],623,10),
        ('defeat',775,[161,472,786,1104],897,5),
        ('victory',1080,[160,487,800,1128],1235,6)]:
        assemble(name, take_row(items, center, 110, 4), [(x,base) for x in xs],112 / 317,source,fps)

    # Quantize all poses together so the character uses one stable palette.
    all_frames = [f for frames in FRAMES.values() for f in frames]
    palette_sheet = Image.new('RGBA', (SIZE * 8, SIZE * ((len(all_frames) + 7) // 8)))
    for index, frame in enumerate(all_frames):
        palette_sheet.alpha_composite(frame, (index % 8 * SIZE, index // 8 * SIZE))
    palette_sheet = palette_sheet.quantize(colors=128, method=Image.Quantize.FASTOCTREE,
                                          dither=Image.Dither.NONE).convert('RGBA')
    cursor = 0
    for animation, frames in FRAMES.items():
        for i in range(len(frames)):
            frames[i] = palette_sheet.crop((cursor % 8 * SIZE, cursor // 8 * SIZE,
                                           (cursor % 8 + 1) * SIZE, (cursor // 8 + 1) * SIZE))
            cursor += 1
        atlas = Image.new('RGBA', (SIZE * len(frames), SIZE))
        for i, frame in enumerate(frames):
            atlas.alpha_composite(frame, (i * SIZE, 0))
        atlas.quantize(colors=128, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(OUT / f'{animation}.png', optimize=True)
        previews = []
        for frame in frames:
            canvas = Image.new('RGBA', (SIZE, SIZE), (23, 31, 47, 255))
            draw = ImageDraw.Draw(canvas)
            draw.line((0, PIVOT[1], SIZE, PIVOT[1]), fill=(55, 75, 100))
            canvas.alpha_composite(frame)
            previews.append(canvas.convert('RGB'))
        previews[0].save(PREVIEW / f'gandalf_{animation}.gif', save_all=True, append_images=previews[1:],
                         duration=round(1000/RECIPES[animation]['fps']), loop=0, disposal=2)
    manifest = {'schema': 1, 'character_id': 'gandalf', 'cell_size': [SIZE,SIZE], 'pivot': list(PIVOT),
                'alpha_cutoff': 180, 'palette_colors': 128, 'animations': {}, 'engine_verified': False}
    ext, subs, anims = [], [], []
    for n, (name, frames) in enumerate(FRAMES.items()):
        ext.append(f'[ext_resource type="Texture2D" path="res://art/characters/gandalf/{name}.png" id="{n+1}"]')
        sequence = []
        for i in range(len(frames)):
            key = f'{name}_{i}'
            subs.append(f'[sub_resource type="AtlasTexture" id="{key}"]\natlas = ExtResource("{n+1}")\nregion = Rect2({i*SIZE}, 0, {SIZE}, {SIZE})')
            sequence.append('{"duration": 1.0, "texture": SubResource("'+key+'")}')
        record = RECIPES[name]
        anims.append('{"frames": ['+', '.join(sequence)+'], "loop": '+str(record['loop']).lower()+', "name": &"'+name+'", "speed": '+str(float(record['fps']))+'}')
        manifest['animations'][name] = {**record, 'texture': f'{name}.png', 'frame_count': len(frames),
                                       'sha256': hashlib.sha256((OUT/f'{name}.png').read_bytes()).hexdigest()}
    header = f'[gd_resource type="SpriteFrames" load_steps={len(ext)+len(subs)+1} format=3]'
    resource_text = '\n\n'.join([header, '\n'.join(ext), '\n\n'.join(subs), '[resource]\nanimations = ['+',\n'.join(anims)+']'])+'\n'
    (OUT / 'animations.tres').write_text(resource_text)
    (OUT / 'idle.tres').write_text(resource_text)
    (OUT / 'idle.json').write_text(json.dumps({'status':'review_candidate','animation_id':'idle','columns':8,'rows':1,'cell':[SIZE,SIZE],'pivot':list(PIVOT),'fps':8,'loop':True},indent=2)+'\n')
    (OUT / 'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    portrait = Image.new('RGBA',(128,128))
    head = FRAMES['idle'][0].crop((97,94,161,168)).resize((110,128),Image.Resampling.NEAREST)
    portrait.alpha_composite(head,(9,0))
    portrait.save(OUT/'portrait.png')
    # Animated overview. Finite states hold last pose before the four-second reset.
    names = list(FRAMES)
    montage = []
    for tick in range(40):
        canvas = Image.new('RGBA',(7*192,2*220),(23,31,47,255))
        draw = ImageDraw.Draw(canvas)
        for i,name in enumerate(names):
            record, frames = RECIPES[name], FRAMES[name]
            index = int(tick * .1 * record['fps'])
            index = index % len(frames) if record['loop'] else min(index,len(frames)-1)
            x,y = i%7*192,i//7*220
            draw.text((x+10,y+7),name,fill=(220,230,245))
            canvas.alpha_composite(frames[index].resize((192,192),Image.Resampling.NEAREST),(x,y+24))
        montage.append(canvas.convert('RGB'))
    montage[0].save(PREVIEW/'gandalf_all_states.gif',save_all=True,append_images=montage[1:],duration=100,loop=0,disposal=2)
    montage[3].save(PREVIEW/'gandalf_all_states.png')
    print(json.dumps({'animations':len(FRAMES),'playback_frames':sum(map(len,FRAMES.values())),
                      'unique_source_poses':sum(record.get('unique_source_poses',len(record['frames'])) for record in RECIPES.values()),
                      'manifest':str(OUT/'manifest.json')}))


if __name__ == '__main__':
    build()
