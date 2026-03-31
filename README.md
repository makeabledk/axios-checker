# axios-checker

On March 29, 2025, compromised versions of axios were published to npm (`1.14.1` and `0.30.4`). They include a malicious dependency (`plain-crypto-js`) that drops a remote access trojan on your machine.

This script checks if any of your local projects are affected.

More info: https://www.stepsecurity.io/blog/axios-compromised-on-npm-malicious-versions-drop-remote-access-trojan

## Usage

Run from the root of your projects folder (e.g. `~/projects`):

```bash
cd ~/projects && curl -sL https://raw.githubusercontent.com/makeabledk/axios-checker/main/checker.sh | bash
```

## What it checks

### System-level (runs once)
- **Persistence files** — checks for malware artifacts dropped on disk:
  - macOS: `/Library/Caches/com.apple.act.mond`
  - Linux: `/tmp/ld.py`
- **C2 domain** — checks if the command-and-control server `sfrclak.com` resolves via DNS

### Project-level (per project modified after 2025-03-29)
- **package-lock.json** — checks if the resolved axios version is `1.14.1` or `0.30.4`
- **yarn.lock** — same check for yarn-based projects
- **npm ls** — checks actually installed axios version in `node_modules`
- **Malware package** — checks for presence of `node_modules/plain-crypto-js`

## What to do if something is found

1. Treat the machine as **compromised**
2. **Rotate all credentials** — npm tokens, AWS keys, SSH keys, CI/CD secrets
3. Remove the malware: `rm -rf node_modules/plain-crypto-js`
4. Downgrade axios: `npm install axios@1.14.0`
5. Block C2: `sudo sh -c 'echo "0.0.0.0 sfrclak.com" >> /etc/hosts'`
6. Consider rebuilding the machine from a known-good state

## Requirements

- `bash`
- `jq`
- `npm`
