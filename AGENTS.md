# Agents Instructions for `Discrolless` bootc Image

## CRITICAL: GitHub API Usage

**ALWAYS use GitHub API for external references:**
- When researching other repositories (e.g., projectbluefin/distroless, ublue-os/bluefin)
- When checking Containerfiles, build scripts, or configuration files
- Use the `github-mcp-server-get_file_contents` tool instead of curl/wget
- This ensures consistent, authenticated access and better error handling

## CRITICAL: Pre-Commit Checklist

**Execute before EVERY commit:**
1. **Conventional Commits** - ALL commits MUST follow conventional commit format (see below)
2. **Shellcheck** - `shellcheck *.sh` on all modified shell files
3. **YAML validation** - `python3 -c "import yaml; yaml.safe_load(open('file.yml'))"` on all modified YAML
4. **Justfile syntax** - `just --list` to verify
5. **Confirm with user** - Always confirm before committing and pushing

**Never commit files with syntax errors.**

### REQUIRED: Conventional Commit Format

**ALL commits MUST use conventional commits format**

```
<type>[optional scope]: <description>
```

---

## Repository Structure

```
├── Containerfile             # Main build definition (multi-stage build with OCI imports)
├── Justfile                  # Local build automation (image name, build commands)
├── build.sh                  # Build-time scripts (10-build.sh, 20-chrome.sh, etc.)
├── iso/                      # Local testing only (no CI/CD)
│   ├── disk.toml               # VM/disk image config (QCOW2/RAW)
│   ├── iso.toml                # ISO installer config (bootc switch URL)
│   └── rclone/                 # Upload configs (Cloudflare R2, AWS S3, etc.)
├── .github/                  # GitHub configuration and CI/CD
│   ├── workflows/              # GitHub Actions workflows
│   │   ├── build.yml             # Builds :stable on main
│   │   ├── clean.yml             # Deletes images >90 days old
│   │   ├── renovate.yml          # Renovate bot updates (6h interval)
│   │   ├── validate-*.yml        # Pre-merge validation checks
│   │   └── ...
│   ├── SETUP_CHECKLIST.md      # Quick setup checklist for users
│   ├── commit-convention.md    # Conventional commits guide
│   └── renovate.json5          # Renovate configuration
├── AGENTS.md                 # THIS FILE - Instructions for Copilot
├── .pre-commit-config.yaml   # Pre-commit hooks (optional local use)
└── .gitignore                # Prevents committing secrets (cosign.key, etc.)
```

---

## Core Principles

### Multi-Stage Build Architecture
The original Finpilot template follows the **Bluefin architecture pattern** from @projectbluefin/distroless.
Instead of fully following the template, `discrolless` just added several extra GNOME Extensions on top of @projectbluefin/distroless, mainly PaperWM as a horizontal scrolling windowing mechanism.

**Architecture Layers:**
1. **Context Stage (ctx)** - Combines resources from multiple sources:
   - Local build scripts (`/build`)
   - Local custom files (`/custom`)
   - **@projectbluefin/common** - Desktop configuration shared with Aurora (`/oci/common`)
   - **@projectbluefin/branding** - Branding assets (`/oci/branding`)
   - **@ublue-os/artwork** - Artwork shared with Aurora and Bazzite (`/oci/artwork`)
   - **@ublue-os/brew** - Homebrew integration (`/oci/brew`)

2. **Base Image Options:**
    - `quay.io/gnome_infrastructure/gnome-build-meta:gnomeos-nightly` (GNOME OS-based, default)
    - `quay.io/centos-bootc/centos-bootc:stream10` (CentOS-based)

**OCI Container Resources:**
- Resources from OCI containers are copied to **distinct subdirectories** (`/oci/*`) to avoid file conflicts
- Renovate automatically updates `:latest` tags to **SHA digests** for reproducibility
- All OCI resources are mounted at build-time via the `ctx` stage

**Reference:** See [Bluefin Contributing Guide](https://docs.projectbluefin.io/contributing/) for architecture diagram

### Build-time vs Runtime
- **Build-time** (`build/`): Baked into container. Services, configs, system packages.
- **Runtime** (`custom/`): User installs after deployment. Use Brewfiles, Flatpaks. CLI tools, GUI apps, dev environments.

### Bluefin Convention Compliance
- **ALWAYS follow @ublue-os/bluefin and @projectbluefin/distroless patterns. Confirm before deviating.**
- Check @bootc-dev for container best practices

### Branch Strategy
- **main** = Production releases ONLY. Never push directly. Builds `:latest` images.
- Push/PR will trigger `:next` images.
- **Conventional Commits** = REQUIRED. `feat:`, `fix:`, `chore:`, etc.
- **Workflows** = All validation happens on PRs. Merging to main triggers stable builds.

### Validation Workflows
The repository includes automated validation on pull requests:
- **validate-shellcheck.yml** - Runs shellcheck on all `build/*.sh` scripts
- **validate-brewfiles.yml** - Validates Homebrew Brewfile syntax
- **validate-flatpaks.yml** - Checks Flatpak app IDs exist on Flathub
- **validate-justfiles.yml** - Validates just file syntax
- **validate-renovate.yml** - Validates Renovate configuration

**When adding files**: These validations run automatically on PRs. Fix any errors before merge.

---

## GNOME Shell Extensions

Extensions are installed at build-time via git submodules in `files/usr/share/gnome-shell/extensions/`.

### Adding a New Extension

**Step 1: Add as git submodule**
```bash
git submodule add https://github.com/AUTHOR/extension-name.git files/usr/share/gnome-shell/extensions/UUID@domain
git submodule update --init --recursive
```

**Step 2: Add to `.gitmodules` with branch**
```ini
[submodule "files/usr/share/gnome-shell/extensions/UUID@domain"]
    path = files/usr/share/gnome-shell/extensions/UUID@domain
    url = https://github.com/AUTHOR/extension-name.git
    branch = vXX  # or master, main, etc.
```

**Step 3: Handle special treatments in `build.sh`**
```bash
# Schema compilation (for all extensions with schemas/)
for schema_dir in /usr/share/gnome-shell/extensions/*/schemas; do
    if [ -d "${schema_dir}" ]; then
        glib-compile-schemas --strict "${schema_dir}"
    fi
done

# Helper binaries (e.g., Logo Menu)
install -Dpm0755 -t /usr/bin /usr/share/gnome-shell/extensions/UUID@domain/distroshelf-helper

# Nested directory moves (e.g., Caffeine)
if [ -d /usr/share/gnome-shell/extensions/tmp/caffeine/caffeine@patapon.info ]; then
    mv /usr/share/gnome-shell/extensions/tmp/caffeine/caffeine@patapon.info /usr/share/gnome-shell/extensions/
fi
```

### Extension Complexity Tiers

| Tier | Build Requirements | Examples |
|------|-------------------|----------|
| **Simple** | `cp` + `glib-compile-schemas` | Dash in Panel, Window title is back, Autohide Battery, Hide Volume Indicator |
| **Medium** | + gettext (`msgfmt`) | PaperWM, Bluetooth Battery Meter, Clipboard Indicator, Shutdown Dialogue, WSP |
| **Complex** | npm/pnpm/TypeScript or Meson | Copyous, Night Theme Switcher, Rounded Window Corners |
| **Runtime deps** | System libraries | Vitals (libgtop2-devel, lm_sensors) |

### Files to Inspect in Extension Repos

| File | Purpose |
|------|---------|
| `metadata.json` | UUID, gettext domain, shell version |
| `Makefile` | Build targets (schema, locale, install) |
| `package.json` / `meson.build` | Build system and dependencies |
| `schemas/` | GSettings schemas (.xml → .compiled) |
| `po/` or `locale/` | Translations (.po → .mo via `msgfmt`) |
| `helpers/` or `bin/` | Executables for `/usr/bin` |
| `resources/` | `.gresource` files (needs `glib-compile-resources`) |

### Quick Heuristics

- **Has `schemas/`** → Needs `glib-compile-schemas`
- **Has `po/` or `locale/`** → Needs gettext (`msgfmt`)
- **Has `helpers/` or `bin/`** → Needs binary installation to `/usr/bin`
- **Has `resources/*.gresource`** → Needs `glib-compile-resources`
- **Uses Meson/npm/pnpm** → Complex build-time compilation
- **Flat structure, no schemas** → Simple copy-only

### Homebrew Packages (Brew - Runtime)

**Location**: `custom/brew/*.Brewfile`

Homebrew packages are installed by users after deployment. Best for CLI tools and development environments.

**Files**:
- `custom/brew/default.Brewfile` - General purpose CLI tools
- `custom/brew/development.Brewfile` - Development tools and environments
- `custom/brew/fonts.Brewfile` - Font packages
- Create custom `*.Brewfile` as needed

**Example**:
```ruby
# In custom/brew/default.Brewfile
brew "bat"        # cat with syntax highlighting
brew "eza"        # Modern replacement for ls
brew "ripgrep"    # Faster grep
brew "fd"         # Simple alternative to find
```

**When to use**:
- CLI tools and utilities
- Development tools (node, python, go, etc.)
- User-specific tools that don't need to be in the base image
- Tools that update frequently

**Important**:
- Brewfiles use Ruby syntax
- Users install via `ujust` commands (e.g., `ujust install-default-apps`)
- Not installed in ISO/container - users install after deployment

### Flatpak Applications (GUI Apps - Runtime)

**Location**: `custom/flatpaks/*.preinstall`

Flatpak applications are GUI apps installed after first boot. Use INI format.

**Files**:
- `custom/flatpaks/default.preinstall` - Default GUI applications
- Create custom `*.preinstall` files as needed

**Example**:
```ini
# In custom/flatpaks/default.preinstall
[Flatpak Preinstall org.mozilla.firefox]
Branch=stable

[Flatpak Preinstall com.visualstudio.code]
Branch=stable

[Flatpak Preinstall org.gnome.Calculator]
Branch=stable
```

**When to use**:
- GUI applications
- Desktop apps (browsers, editors, media players)
- Apps that users expect to have immediately available
- Apps from Flathub (https://flathub.org/)

**Important**:
- Installed post-first-boot (not in ISO/container)
- Requires internet connection
- Find app IDs at https://flathub.org/
- Use INI format with `[Flatpak Preinstall APP_ID]` sections
- Always specify `Branch=stable` (or another branch)

---

## Quick Reference: Common User Requests

| Request | Action | Location |
|---------|--------|----------|
| Add package (runtime) | `brew "pkg"` | `custom/brew/default.Brewfile` |
| Add GUI app | `[Flatpak Preinstall org.app.id]` | `custom/flatpaks/default.preinstall` |
| Add user command | Create shortcut (NO package manager) | `custom/ujust/*.just` |
| Switch base image | Update FROM line | `Containerfile` |
| Add OCI containers | Uncomment COPY --from= lines | `Containerfile` lines 13-18 (ctx stage) |
| Deploy (production) | `sudo bootc switch ghcr.io/user/repo:stable` | Terminal |
| Enable service | `systemctl enable service.name` | `build.sh` |
| Validate changes | Automatic on PR | `.github/workflows/validate-*.yml` |

---

### CI Debugging

**Check workflow logs**:
1. Go to Actions tab in GitHub
2. Click on failed workflow run
3. Expand failed step
4. Look for error messages

**Common CI failures**:
- Shellcheck errors: Fix script syntax
- Brewfile validation: Check package names exist
- Flatpak validation: Verify app IDs on Flathub
- Image pull failures: Check base image SHA/tag

**Test PR before merge**:
```bash
# PR builds are tagged as :pr-NUMBER
podman pull ghcr.io/YOUR_USERNAME/YOUR_REPO:pr-123
podman run --rm -it ghcr.io/YOUR_USERNAME/YOUR_REPO:pr-123 bash
```

### Runtime Debugging

**After deployment**:
```bash
# Check system info
bootc status

# Check running services
systemctl list-units --failed

# Check logs
journalctl -b -p err

# Check ujust commands available
ujust --list

# Check Brewfiles location
ls -la /usr/share/ublue-os/homebrew/

# Check Flatpak preinstall
ls -la /etc/flatpak/preinstall.d/
```

**Flatpak debugging**:
```bash
# Check Flatpak remotes
flatpak remotes

# Check installed Flatpaks
flatpak list

# Install Flatpak manually
flatpak install -y flathub org.mozilla.firefox
```

**Homebrew debugging**:
```bash
# Check Homebrew status
brew doctor

# Check Brewfile
cat /usr/share/ublue-os/homebrew/default.Brewfile

# Install manually
brew install package-name
```

---

## Resources & Documentation

- **Bluefin patterns**: https://github.com/ublue-os/bluefin
- **bootc documentation**: https://github.com/containers/bootc
- **Conventional Commits**: https://www.conventionalcommits.org/
- **RPMfusion packages**: https://mirrors.rpmfusion.org/
- **Flatpak IDs**: https://flathub.org/
- **Homebrew**: https://brew.sh/
- **Universal Blue**: https://universal-blue.org/
- **Renovate**: https://docs.renovatebot.com/
- **GitHub Actions**: https://docs.github.com/en/actions
- **Podman**: https://podman.io/
- **Justfile**: https://just.systems/

---

## Other Rules that are Important to the Maintainers

- Ensure that [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/#specification) are used and enforced for every commit and pull request title.
- Always be surgical with the least amount of code, the project strives to be easy to maintain.

## Attribution Requirements

AI agents must disclose what tool and model they are using in the "Assisted-by" commit footer:

```text
Assisted-by: [Model Name] via [Tool Name]
```

Example:

```text
Assisted-by: Claude 3.5 Sonnet via GitHub Copilot
```

---

**Last Updated**: 2025-11-14  
**Template Version**: finpilot (Enhanced with comprehensive Copilot instructions)  
**Maintainer**: Universal Blue Community
