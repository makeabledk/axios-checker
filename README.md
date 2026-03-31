# axios-checker

Checks your local projects for compromised axios versions (`1.14.1`, `0.30.4`) and the `plain-crypto-js` malware package.

## Usage

Run from the root of your projects folder (e.g. `~/projects`):

```bash
cd ~/projects && curl -sL https://raw.githubusercontent.com/makeabledk/axios-checker/main/checker.sh | bash
```

The script scans all `package.json` and `package-lock.json` files modified in the last 48 hours.

## What it checks

- **Lockfile** — axios version in `package-lock.json`
- **Installed packages** — axios version via `npm ls`
- **Malware** — presence of `node_modules/plain-crypto-js`

## Requirements

- `bash`
- `jq`
- `npm`
