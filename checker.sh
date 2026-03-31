#!/bin/bash
VERSION="1.0.0"

BAD="^(1\.14\.1|0\.30\.4)$"
AFTER="2026-03-29"
C2_DOMAIN="sfrclak.com"
C2_IP="142.11.206.73"

# Check requirements
missing=0

if ! command -v jq &>/dev/null; then
  echo "Missing: jq"
  echo "  macOS:  brew install jq"
  echo "  Linux:  sudo apt install jq"
  echo ""
  missing=1
fi

if ! command -v npm &>/dev/null; then
  echo "Missing: npm"
  echo "  Install Node.js from https://nodejs.org"
  echo ""
  missing=1
fi

if [ $missing -eq 1 ]; then
  echo "Install the above and try again."
  exit 1
fi

checked=0
hits=0
system_compromised=0

echo "=== Axios Compromise Checker v$VERSION ==="
echo "Scanning projects changed after $AFTER..."
echo ""

# --- System-level checks (run once) ---

echo "[System checks]"

# Persistence file check
case "$(uname)" in
  Darwin)
    if [ -f "/Library/Caches/com.apple.act.mond" ]; then
      echo "  ⚠️  PERSISTENCE FILE FOUND: /Library/Caches/com.apple.act.mond"
      system_compromised=1
    fi
    ;;
  Linux)
    if [ -f "/tmp/ld.py" ]; then
      echo "  ⚠️  PERSISTENCE FILE FOUND: /tmp/ld.py"
      system_compromised=1
    fi
    ;;
esac

# Check for active connections to C2
if command -v lsof &>/dev/null; then
  if lsof -i -n 2>/dev/null | grep -qE "$C2_IP|8000" && lsof -i -n 2>/dev/null | grep -q "$C2_IP"; then
    echo "  ⚠️  ACTIVE CONNECTION TO C2: $C2_IP ($C2_DOMAIN)"
    system_compromised=1
  fi
elif command -v ss &>/dev/null; then
  if ss -tn 2>/dev/null | grep -q "$C2_IP"; then
    echo "  ⚠️  ACTIVE CONNECTION TO C2: $C2_IP ($C2_DOMAIN)"
    system_compromised=1
  fi
elif command -v netstat &>/dev/null; then
  if netstat -an 2>/dev/null | grep -q "$C2_IP"; then
    echo "  ⚠️  ACTIVE CONNECTION TO C2: $C2_IP ($C2_DOMAIN)"
    system_compromised=1
  fi
fi

# Check /etc/hosts for C2 (if already blocked, that's good)
if [ -f /etc/hosts ] && grep -q "$C2_DOMAIN" /etc/hosts; then
  echo "  ✓  C2 domain already blocked in /etc/hosts"
fi

if [ $system_compromised -eq 0 ]; then
  echo "  ✓  No system-level indicators found"
fi

echo ""
echo "[Project checks]"

# --- Project-level checks ---

while IFS= read -r -d '' f; do
  d=$(dirname "$f")

  # Deduplicate: skip if we already checked this directory
  if [ "$d" = "$prev_d" ]; then
    continue
  fi
  prev_d="$d"

  checked=$((checked+1))

  echo "Checking: $d"

  found=0

  # lockfile check (package-lock.json)
  if [ -f "$d/package-lock.json" ]; then
    v=$(jq -r '.packages["node_modules/axios"].version // .dependencies.axios.version // empty' "$d/package-lock.json" 2>/dev/null)
    if [[ $v =~ $BAD ]]; then
      echo "  ⚠️  LOCKFILE HIT: axios@$v (package-lock.json)"
      found=1
    fi
  fi

  # lockfile check (yarn.lock)
  if [ -f "$d/yarn.lock" ]; then
    if grep -qE 'axios@.*:' "$d/yarn.lock" && grep -qE '^\s+version "(1\.14\.1|0\.30\.4)"' "$d/yarn.lock"; then
      echo "  ⚠️  LOCKFILE HIT: compromised axios in yarn.lock"
      found=1
    fi
  fi

  # installed check (via package.json in node_modules, avoids slow npm ls)
  if [ -f "$d/node_modules/axios/package.json" ]; then
    v=$(jq -r '.version // empty' "$d/node_modules/axios/package.json" 2>/dev/null)
    if [[ $v =~ $BAD ]]; then
      echo "  ⚠️  INSTALLED HIT: axios@$v in node_modules"
      found=1
    fi
  fi

  # malware package check
  if [ -d "$d/node_modules/plain-crypto-js" ]; then
    echo "  🚨 MALWARE FOUND: plain-crypto-js is present"
    found=1
  fi

  if [ $found -eq 1 ]; then
    hits=$((hits+1))
  fi

done < <(find . -type f -newermt "$AFTER" \( -name package.json -o -name package-lock.json -o -name yarn.lock \) -not -path "*/node_modules/*" -print0 | sort -z)

echo ""
echo "===== REPORT ====="
echo "Projects checked: $checked"
echo "Projects with hits: $hits"
echo ""

if [ $system_compromised -eq 1 ] || [ "$hits" -gt 0 ]; then
  echo "Status: ⚠️  ATTENTION NEEDED"
  echo ""
  echo "If malware was found or persistence files exist:"
  echo "  1. Treat this machine as COMPROMISED"
  echo "  2. Rotate ALL credentials (npm tokens, AWS keys, SSH keys, CI/CD secrets)"
  echo "  3. Remove plain-crypto-js: rm -rf node_modules/plain-crypto-js"
  echo "  4. Downgrade axios: npm install axios@1.14.0"
  echo "  5. Block C2: sudo sh -c 'echo \"0.0.0.0 sfrclak.com\" >> /etc/hosts'"
  echo "  6. Consider rebuilding machine from known-good state"
  echo ""
  echo "More info: https://www.stepsecurity.io/blog/axios-compromised-on-npm-malicious-versions-drop-remote-access-trojan"
else
  echo "Status: ✅ CLEAN"
fi
