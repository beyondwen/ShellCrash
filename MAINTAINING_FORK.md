# Maintaining Fork

This repository is intended to be maintained as a custom ShellCrash fork with local Hysteria2 single-node import support for sing-box.

## Branch Strategy

- Keep `master` close to upstream when possible.
- Use a dedicated deployment branch such as `hy2-openwrt` for router installation and updates.
- Put each customization in a separate commit so upstream merges are easier to review.

## Suggested Remotes

```bash
git remote rename origin upstream
git remote add origin https://github.com/<your-user>/ShellCrash.git
```

## Suggested Release Flow

```bash
git checkout -b hy2-openwrt upstream/master
git add scripts/libs/hy2_uri.sh scripts/menus/6_core_config.sh scripts/lang/chs/6_core_config.lang scripts/lang/en/6_core_config.lang MAINTAINING_FORK.md CUSTOM_CHANGELOG.md
git commit -m "feat: support local Hysteria2 single-node import for sing-box"
git push -u origin hy2-openwrt
```

## Syncing Upstream

```bash
git fetch upstream
git checkout hy2-openwrt
git merge upstream/master
```

After merging:

- review changes in `scripts/menus/6_core_config.sh`
- review changes in `scripts/lang/chs/6_core_config.lang`
- review changes in `scripts/lang/en/6_core_config.lang`
- verify that `scripts/libs/hy2_uri.sh` is still sourced and reachable

## OpenWrt Install Source

Point installation and updates to your own branch instead of the official repository:

```sh
export url='https://testingcf.jsdelivr.net/gh/<your-user>/ShellCrash@hy2-openwrt'
```

## Update Policy

- Do not update routers from the official ShellCrash source.
- Update from your fork only after you merge and validate upstream changes locally.
- Keep a short changelog entry for every custom change so future merges are easier to reason about.
