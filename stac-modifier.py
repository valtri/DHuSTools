#! /usr/bin/python3

import argparse
import json
import sys

parser = argparse.ArgumentParser('STAC json transformer')
parser.add_argument('-u', '--url', type=str, required=True,
                    help='URL to the product zip')
args = parser.parse_args()

f = json.load(sys.stdin)
if 'assets' in f:
    f.pop('assets')
links = f.setdefault('links', [])
for link in links:
    if 'rel' in link and link['rel'] == 'self':
        link['type'] = 'application/zip'
        # a = urlparse(link['href'])
        # link['href'] = args.url + os.path.basename(a.path)
        link['href'] = args.url
print('%s' % json.dumps(f, indent=2))
