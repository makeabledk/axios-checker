#!/bin/bash

BAD="^(1\.14\.1|0\.30\.4)$"

checked=0
hits=0

echo "Scanning projects changed in last 48h..."
echo ""

while IFS= read -r -d '' f; do
  d=$(dirname "$f")
  checked=$((checked+1))

  echo "Checking: $d"

  found=0

  # lockfile check
  if [ -f "$d/package-lock.json" ]; then
    v=$(jq -r '.packages["node_modules/axios"].version // .dependencies.axios.version // empty' "$d/package-lock.json" 2>/dev/null)
    if [[ $v =~ $BAD ]]; then
      echo "  LOCKFILE HIT: axios@$v"
      found=1
    fi
  fi

  # installed check
  if [ -d "$d/node_modules" ]; then
    if (cd "$d" && npm ls axios 2>/dev/null | grep -E 'axios@(1\.14\.1|0\.30\.4)\b' >/dev/null); then
      echo "  INSTALLED HIT"
      found=1
    fi
  fi

  # malware check
  if [ -d "$d/node_modules/plain-crypto-js" ]; then
    echo "  MALWARE FOUND"
    found=1
  fi

  if [ $found -eq 1 ]; then
    hits=$((hits+1))
  fi

done < <(find . -type f -mtime -2 \( -name package.json -o -name package-lock.json \) -not -path "*/node_modules/*" -print0)

echo ""
echo "===== REPORT ====="
echo "Projects checked: $checked"
echo "Projects with hits: $hits"

if [ "$hits" -eq 0 ]; then
  echo "Status: CLEAN"
else
  echo "Status: ATTENTION NEEDED"
fi
