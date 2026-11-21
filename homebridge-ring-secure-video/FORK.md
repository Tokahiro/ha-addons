# homebridge-ring-secure-video (patched)

Source of [homebridge-ring-secure-video](https://github.com/zmanuel1234/homebridge-ring-secure-video)
1.0.4 by zmanuel1234 (MIT), with two fixes and one option for Ring Intercom Video. See `CHANGELOG.md`, version
`1.0.4+fix.2`. This folder is a Homebridge plugin, not a Home Assistant add-on.

## Install

In the Homebridge terminal (Homebridge UI, menu, Terminal):

```sh
npm install --prefix /var/lib/homebridge https://github.com/Tokahiro/ha-addons/releases/download/homebridge-ring-secure-video-1.0.4-fix.2/homebridge-ring-secure-video-1.0.4-fix.2.tgz
```

Then restart Homebridge. The plugin keeps its name, so the settings and the Home pairing stay.

## Go back to the npm version

```sh
npm install --prefix /var/lib/homebridge homebridge-ring-secure-video@1.0.4
```

## Release

A push to `main` that changes this folder runs the tests, packs the plugin and makes the
GitHub release `homebridge-ring-secure-video-<version>` (with `+` written as `-`), if it does not
exist yet. Raise the version in `package.json` for a new release.

## Upstream

`git diff <import commit> -- homebridge-ring-secure-video` gives the changes against 1.0.4. To
offer them upstream, apply them in a fork of the upstream repository with
`git format-patch --relative=homebridge-ring-secure-video`.
