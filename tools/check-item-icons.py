#!/usr/bin/env python3
"""Fails when an ox_inventory item resolves to an icon file that does not exist.

Items that were already missing an icon when this check was added are listed in
tools/item-icons-baseline.txt, so only a NEW missing icon fails. Delete a line
from the baseline when its icon is added; a stale line is reported, not failed.
"""
import os
import re
import sys

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
inv = os.path.join(root, 'txData/FiveMBasicServerCFXDefault_3A7DA0.base/resources/[standalone]/ox_inventory')
images = set(os.listdir(os.path.join(inv, 'web/images')))
items = open(os.path.join(inv, 'data/items.lua'), encoding='utf-8', errors='ignore').read()

baseline_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'item-icons-baseline.txt')
baseline = {l.strip() for l in open(baseline_path) if l.strip() and not l.startswith('#')}

missing = set()
for name, body in re.findall(r"\n\t\['([A-Za-z0-9_\-]+)'\]\s*=\s*\{(.*?)\n\t\},", items, re.S):
    image = re.search(r"image\s*=\s*'([^']+)'", body)
    if (image.group(1) if image else name + '.png') not in images:
        missing.add(name)

new = sorted(missing - baseline)
stale = sorted(baseline - missing)

for name in stale:
    print(f'note: {name} now has an icon, remove it from tools/item-icons-baseline.txt')

if new:
    print('items with no inventory icon file: ' + ', '.join(new))
    print('add the icon to ox_inventory/web/images, or point the item at an existing one')
    sys.exit(1)

print(f'item icons ok ({len(missing)} known gaps in the baseline)')
