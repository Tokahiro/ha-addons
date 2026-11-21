# @tokahiro/homebridge-ring-secure-video

Source of [homebridge-ring-secure-video](https://github.com/zmanuel1234/homebridge-ring-secure-video)
1.0.4 by zmanuel1234 (MIT), with fixes and options for Ring Intercom (Video). See `CHANGELOG.md`.
Published on npm as `@tokahiro/homebridge-ring-secure-video`. This folder is a Homebridge
plugin, not a Home Assistant add-on.

## Install

Homebridge UI, Plugins: search `@tokahiro/homebridge-ring-secure-video` and install it. Updates
then show in the UI as for any other plugin.

## Switch from homebridge-ring-secure-video

The platform name is the same ("Ring Secure Video"), so the settings block in `config.json`,
the child bridge, the cached accessories and the Home pairing stay. The config block must use
`"platform": "Ring Secure Video"` (not `"homebridge-ring-secure-video.Ring Secure Video"`).

Switch in the Homebridge terminal (Homebridge UI, menu, Terminal), so that nothing touches the
settings block:

```sh
cp /var/lib/homebridge/config.json /var/lib/homebridge/config.json.bak
npm uninstall --prefix /var/lib/homebridge homebridge-ring-secure-video
npm install --prefix /var/lib/homebridge @tokahiro/homebridge-ring-secure-video
```

Then restart Homebridge. The log shows "the plugin name changed from
'homebridge-ring-secure-video' to '@tokahiro/homebridge-ring-secure-video'" for each bridged
accessory once.

## Go back to the npm version of the original

```sh
npm uninstall --prefix /var/lib/homebridge @tokahiro/homebridge-ring-secure-video
npm install --prefix /var/lib/homebridge homebridge-ring-secure-video@1.0.4
```

Then restart Homebridge.

## Release

A push to `main` that changes this folder runs the tests and packs the plugin. If the version in
`package.json` is new, it makes the GitHub release `homebridge-ring-secure-video-<version>` and
publishes the package on npm. Raise the version in `package.json` for a new release.

npm publishing uses trusted publishing (npmjs.com, package settings, Trusted Publisher: GitHub
Actions, `Tokahiro/ha-addons`, workflow `homebridge-ring-secure-video.yml`). Until that is set, it
uses the repository secret `NPM_TOKEN`.

## Upstream

`git diff <import commit> -- homebridge-ring-secure-video` gives the changes against 1.0.4. To
offer them upstream, apply them in a fork of the upstream repository with
`git format-patch --relative=homebridge-ring-secure-video` (leave out the package name change).
