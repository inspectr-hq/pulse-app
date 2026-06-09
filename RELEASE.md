# Release Process

This repository currently releases from git tag pushes.

## Trigger

The release workflow is defined in `.github/workflows/release.yaml`.

It runs when a tag matching `v*` is pushed:

```yaml
on:
  push:
    tags:
      - "v*"
```

That means the workflow starts as soon as a version tag such as `v1.2.3` is pushed.

## What The Workflow Does

1. Checks out the repository.
2. Selects the full Xcode install.
3. Reads the version from `GITHUB_REF_NAME` and strips the leading `v` for `MARKETING_VERSION`.
4. Builds `Pulse.app` from `app/Pulse.xcodeproj` using the `Pulse` scheme in `Release` configuration.
5. Disables code signing for the build.
6. Ad-hoc signs the built app to reduce Gatekeeper false positives on unsigned distributions.
7. Packages the app as:
   - `Pulse-<tag>.zip`
   - `Pulse-<tag>.dmg`
8. Uploads both assets to a GitHub Release with generated release notes.

## Expected Tag Format

The workflow expects tags like:

- `v1.2.3`
- `v1.3.0`

The uploaded assets keep the full tag in the filename:

- `Pulse-v1.2.3.zip`
- `Pulse-v1.2.3.dmg`

## How The DMG Is Built

The DMG is assembled directly in the workflow.

### Staging layout

The workflow creates a temporary folder:

- `app/build/dmg-stage`

It then copies:

- `Pulse.app`
- an `Applications` symlink pointing to `/Applications`

This gives the standard drag-to-install DMG layout.

### DMG creation command

The workflow runs:

```bash
hdiutil create \
  -volname "Pulse ${GITHUB_REF_NAME}" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  "dist/Pulse-${GITHUB_REF_NAME}.dmg"
```

Important details:

- `UDZO` means a compressed read-only DMG
- the mounted volume name includes the full tag
- there is no custom Finder background or icon positioning

## How To Cut A Release

1. Make sure the intended release commit is pushed.
2. Create a tag, for example:

```bash
git tag v1.2.3
git push origin v1.2.3
```

3. Wait for the GitHub Actions release workflow to finish.
4. Verify that the GitHub Release contains both:
   - ZIP
   - DMG

## Current Constraints

- release artifacts are not fully signed/notarized distribution builds
- Brew support is not automated yet in this repo
- any future Brew automation will depend on an external tap repository and token

## Brew Setup

Pulse does not have Brew automation in this repo yet. To add it, you need both a Homebrew tap repository and a cask that installs from the GitHub Release DMG.

### 1. Create or choose a tap repository

Typical layout:

- `your-org/homebrew-tap`

The tap repo should contain:

- `Casks/pulse.rb`

### 2. Create the cask

The cask must point at the GitHub Release DMG URL pattern produced by this repo.

Example shape:

```ruby
cask "pulse" do
  version "1.2.3"
  sha256 "REPLACE_ME"

  url "https://github.com/inspectr-hq/pulse-app/releases/download/v#{version}/Pulse-v#{version}.dmg"
  name "Pulse"
  desc "macOS menu bar uptime checker"
  homepage "https://github.com/inspectr-hq/pulse-app"

  app "Pulse.app"
end
```

Important detail:

- this workflow names assets with the full tag, so the URL currently needs `Pulse-v#{version}.dmg`, not `Pulse-#{version}.dmg`

### 3. Required release data for the cask

For each release, the cask needs:

- `version`
- `sha256` of the DMG
- `url` of the DMG on the GitHub Release page

### 4. Manual Brew update flow

If you keep it manual at first, the process is:

1. Push release tag.
2. Wait for the workflow to upload the DMG.
3. Download the DMG or compute its SHA256 from the release artifact.
4. Update `Casks/pulse.rb` with:
   - new version
   - new SHA256
   - new DMG URL
5. Commit and push the tap change.

### 5. Automating the Brew update later

If you want to automate Brew like TypePaste does, you would add a second GitHub Actions job that:

1. Downloads the just-published DMG from the GitHub Release.
2. Computes its SHA256.
3. Checks out the tap repo.
4. Rewrites `Casks/pulse.rb`.
5. Commits and pushes the tap update.

That job would need a token secret with access to the tap repo, for example:

- `HOMEBREW_TAP_TOKEN`

### 6. What must stay in sync

If you port the Brew automation from TypePaste, these values must match exactly across the workflow and the cask:

- app name: `Pulse.app`
- release asset name: `Pulse-v<version>.dmg`
- release repository: `inspectr-hq/pulse-app`
- cask token: likely `pulse`
- tap cask path: for example `Casks/pulse.rb`
