#! /usr/bin/python3

import argparse
import json
import sys

parser = argparse.ArgumentParser('STAC json transformer')
parser.add_argument('-u', '--url', type=str, required=True,
                    help='URL to the product zip')
args = parser.parse_args()

f = json.load(sys.stdin)
f['assets'] = {
    'safe-archive': {
        'href': args.url,
        'type': 'application/zip',
        'roles': [
          'metadata',
        ],
    },
}

print('%s' % json.dumps(f, indent=2))
