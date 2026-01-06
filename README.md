# Di*scroll*ess

- Basic Bluefin based on [gnomeos-nightly](`quay.io/gnome_infrastructure/gnome-build-meta:gnomeos-nightly`)
- Added PaperWM for that horizontal scrolling life
- Added some other extensions
- `:latest` image built every Thursday & Friday
- `:next` image built on pushes

```
sudo bootc switch ghcr.io/KiKaraage/discrolless:latest
```

## Included Build System
- Automated builds via GitHub Actions on every commit
- Awesome self hosted Renovate setup that keeps all your images and actions up to date.
- Automatic cleanup of old images (90+ days) to keep it tidy
- Pull request workflow - test changes before merging to main
  - PRs build and validate before merge
  - `main` branch builds `:latest` images
- Validates  files on pull requests so we should never break a build:
  - Shellcheck & Renovate config checks
- Production Grade Features
  - Container signing and SBOM Generation (not enabled yet)

## Quick Start Checklists

### 4. Customizing Image

- [x] Choosing base image in `Containerfile` (line 23)
- [ ] Add high prio extension: PaperWM as git submodule
- [ ] Add medium prio extensions as git submodules:
  - Bluetooth Battery Meter
  - Clipboard Indicator 
  - or Copyous (maybe both at first)
  - Night Theme Switcher
  - Topbar Weather
  - Transparent Top Bar (Adjustable transparency)
  - Vitals
- [ ] Add low prio extensions as git submodules:
  - Dash in Panel
  - Rounded Window Corners Reborn
  - Shutdown Dialogue
  - Window title is back
  - WSP (Window Search Provider)
  - Autohide​​​​ Battery
  - Hide Volume Indicator
- [ ] Enabling back GitHub Actions

### 5. Development Workflow

All changes should be made via pull requests:

1. Open a pull request on GitHub with desired changes
3. The PR will automatically trigger:
   - Build validation
   - Shellcheck validation
   - Test image build
4. Once checks pass, merge the PR
5. Merging triggers publishes a `:latest` image

### 6. Image Signing in the future
a. Generate signing keys
b. Add private key to GitHub Secrets
c. Replace cosign.pub contents with my public key
d. Enable signing in workflow