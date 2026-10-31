"""Structural regression checks for shipped art, independent of source artwork."""
import hashlib
import json
import re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {'idle','walk','run','jump','fall','staff_strike','heavy_staff','lightning','fireball','magic_push','hurt','knockback','defeat','victory'}


def verify():
    base = ROOT/'art/characters/gandalf'
    data = json.loads((base/'manifest.json').read_text())
    assert set(data['animations']) == EXPECTED, 'Animation contract mismatch'
    w,h = data['cell_size']
    checked = 0
    for name, animation in data['animations'].items():
        path = base/animation['texture']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == animation['sha256'], f'{name}: checksum mismatch'
        with Image.open(path) as original:
            image = original.convert('RGBA')
            assert image.size == (w*animation['frame_count'],h), f'{name}: dimensions'
            assert animation['fps'] > 0
            assert len(animation['frames']) == animation['frame_count']
            distinct = set()
            for i in range(animation['frame_count']):
                frame = image.crop((i*w,0,(i+1)*w,h))
                distinct.add(hashlib.sha256(frame.tobytes()).digest())
                alpha = frame.getchannel('A')
                bounds = alpha.getbbox()
                assert bounds is not None, f'{name}/{i}: empty'
                assert bounds[0] > 0 and bounds[1] > 0 and bounds[2] < w and bounds[3] < h, f'{name}/{i}: clipping'
                assert sum(alpha.histogram()[1:255]) == 0, f'{name}/{i}: alpha fringe'
                checked += 1
            assert len(distinct) > 1, f'{name}: no frame-to-frame changes'
    for path in [ROOT/'scenes/art_preview.tscn',*(ROOT/'scripts/presentation').glob('*.gd'),base/'animations.tres',base/'idle.tres']:
        for resource in re.findall(r'res://[^"\s]+',path.read_text()):
            assert (ROOT/resource.removeprefix('res://')).is_file(), f'{path}: missing {resource}'
    resource = (base/'animations.tres').read_text()
    assert len(re.findall(r'\[sub_resource type="AtlasTexture"',resource)) == checked
    assert set(re.findall(r'"name": &"([^"]+)"',resource)) == EXPECTED
    vader = json.loads((ROOT/'art/characters/vader/manifest.json').read_text())
    assert vader['status'] == 'blocked_missing_art'
    assert all(a['frame_count']==0 and a['texture'] is None for a in vader['animations'].values())
    report = {'structural_pass':True,'gandalf_animations':len(EXPECTED),'playback_frames':checked,
              'unique_source_poses':sum(a.get('unique_source_poses',a['frame_count']) for a in data['animations'].values()),
              'gandalf_png_bytes':sum(p.stat().st_size for p in base.glob('*.png')),
              'vader_art':'missing; generation blocked','engine_parse':'not run; Godot unavailable',
              'live_playback':'not run','gameplay_integration':'pending Claude gameplay branch'}
    (ROOT/'docs/art_validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))


if __name__=='__main__':
    verify()
