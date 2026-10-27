"""Read-only pixel/AX measurements of 2x native screenshots. Requires Pillow."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).parent

def box(path, area, predicate):
    image_path = ROOT / path
    if not image_path.exists() and path == 'natural-settings.png':
        image_path = ROOT / 'failed-natural-settings.png'
    image = Image.open(image_path).convert('RGB')
    x0, y0, x1, y1 = area
    points = [(x, y) for y in range(y0, min(y1, image.height))
              for x in range(x0, min(x1, image.width)) if predicate(*image.getpixel((x, y)))]
    if not points:
        raise ValueError(f'No pixels found in {path}: {area}')
    return [min(x for x,y in points), min(y for x,y in points),
            max(x for x,y in points), max(y for x,y in points)]

def menu(path):
    icon = box(path, (0, 0, 60, 48), lambda r,g,b: g > 100 and g > r*1.5 and g > b*1.4)
    han = box(path, (62, 0, 91, 48), lambda r,g,b: min(r,g,b) > 140 and max(r,g,b)-min(r,g,b) < 20)
    icon_y, han_y = (icon[1]+icon[3])/2, (han[1]+han[3])/2
    return dict(icon_bbox_px=icon, han_bbox_px=han, icon_center_y_px=icon_y,
                han_center_y_px=han_y, icon_below_han_px=icon_y-han_y,
                icon_below_han_pt=(icon_y-han_y)/2)

def settings(stem):
    ax = json.loads((ROOT / f'{stem}.json').read_text())
    window = ax['windows'][0]
    expected_right_px = int((window['size'][0]-20)*2)-1
    green = box(f'{stem}.png', (300,115,650,170), lambda r,g,b: g>110 and g>r*1.2 and g>b*1.2)
    groups = [dict(role=e['role'], label=e.get('description'), position=e.get('position'), size=e.get('size'))
              for e in window['elements'] if e.get('role') in ('AXRadioGroup','AXRadioButton')]
    extra = {}
    if stem == 'delivery-appearance':
        bezel = box(f'{stem}.png', (600,390,650,438), lambda r,g,b: r>50 and max(r,g,b)-min(r,g,b)<15)
        extra = dict(appearance_right_inclusive_px=bezel[2], appearance_right_error_px=bezel[2]-expected_right_px)
    return dict(**extra, window_size_pt=window['size'], content_right_inclusive_px=expected_right_px,
                reminder_selected_bbox_px=green, reminder_right_error_px=green[2]-expected_right_px,
                reminder_right_error_pt=(green[2]-expected_right_px)/2, ax_groups=groups)

if __name__ == '__main__':
    result = {'scale':2, 'coordinate_convention':'inclusive pixel bounds, y down',
              'menu_before':menu('before-menubar.png'),
              'menu_after':menu('after-menubar.png'),
              'settings_natural_failed':settings('natural-settings'),
              'settings_final':settings('delivery-settings'),
              'settings_expanded':settings('delivery-appearance')}
    (ROOT / 'measurements.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(result,ensure_ascii=False,indent=2))
