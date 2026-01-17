## Detailed Workflows

### 1. Multi-Stage Build Architecture

**File**: `Containerfile`

This template uses a **multi-stage build** following the @projectbluefin/dakota pattern.

**Stage 1: Context (ctx) - Line 39**
Combines resources from multiple OCI containers:
```dockerfile
FROM scratch AS ctx

COPY build /build
COPY custom /custom
# Import from OCI containers - Renovate updates :latest to SHA-256 digests
COPY --from=ghcr.io/ublue-os/base-main:latest /system_files /oci/base
COPY --from=ghcr.io/projectbluefin/common:latest /system_files /oci/common
COPY --from=ghcr.io/projectbluefin/branding:latest /system_files /oci/branding
COPY --from=ghcr.io/ublue-os/artwork:latest /system_files /oci/artwork
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /oci/brew
```

**Stage 2: Base Image - Line 52**
```dockerfile
FROM quay.io/gnome_infrastructure/gnome-build-meta:gnomeos-nightly  # Default (GNOME OS-based)
# OR
FROM quay.io/centos-bootc/centos-bootc:stream10  # CentOS-based
```

**Common alternative base images**:
```dockerfile
FROM quay.io/gnome_infrastructure/gnome-build-meta:gnomeos-nightly  # GNOME OS-based
FROM ghcr.io/ublue-os/bluefin:stable      # Dev, GNOME, `:stable` or `:gts`
FROM ghcr.io/ublue-os/bazzite:stable      # Gaming, Steam Deck
FROM ghcr.io/ublue-os/aurora:stable       # KDE Plasma
FROM quay.io/fedora/fedora-bootc:42       # Fedora-based
```

**Tags**: `:stable` (recommended), `:latest` (bleeding edge), `-nvidia` variants available

**Renovate**: Base image SHA and OCI container tags are auto-updated by Renovate bot every 6 hours (see `.github/renovate.json5`)

**OCI Container Resources:**
- **@ublue-os/base-main** - Base system configuration
- **@projectbluefin/common** - Desktop configuration shared with Aurora
- **@projectbluefin/branding** - Branding assets
- **@ublue-os/artwork** - Artwork shared with Aurora and Bazzite
- **@ublue-os/brew** - Homebrew integration

**File Locations in Build Scripts:**
- Local build scripts: `/ctx/build/`
- Local custom files: `/ctx/custom/`
- Base files: `/ctx/oci/base/`
- Common files: `/ctx/oci/common/`
- Branding files: `/ctx/oci/branding/`
- Artwork files: `/ctx/oci/artwork/`
- Brew files: `/ctx/oci/brew/`

### 2. OCI Containers for Additional System Files

**File**: `Containerfile` (ctx stage, lines 6-18)

Following the `@projectbluefin/dakota` pattern, you can layer in additional system files from OCI containers. These are commented out by default in the template.

**Available OCI Containers**:
```dockerfile
# Artwork and Branding from projectbluefin/common
COPY --from=ghcr.io/projectbluefin/common:latest /system_files/bluefin /files/bluefin
COPY --from=ghcr.io/projectbluefin/common:latest /system_files/shared /files/shared

# Homebrew system files from ublue-os/brew
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /files/brew
```

**What's included**:
- `projectbluefin/common:latest` - Bluefin wallpapers, themes, branding assets, ujust completions, udev rules
- `ublue-os/brew:latest` - Homebrew system integration files

**When to use**:
- You want Bluefin-specific artwork and wallpapers in your custom image
- You want additional system integration beyond what the base image provides
- You're building a Bluefin derivative and want to maintain brand consistency

**Important**: 
- These are **commented out by default** as template examples
- Uncomment only if you specifically want these additional system files
- The files are copied into the `ctx` stage and made available to your build scripts
- To use the files in your build, you'll need to copy them from `/ctx/files/*` to appropriate system locations in your build scripts

### 3. Build Scripts (`build/`)

**Pattern**: Numbered files (`10-build.sh`, `20-chrome.sh`, `30-cosmic.sh`) run in order.

**Example - `build/10-build.sh`**:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Install packages
rpm-ostree install -y vim git htop neovim

# Enable services
systemctl enable podman.socket

# Download binaries
curl -L https://example.com/tool -o /usr/local/bin/tool
chmod +x /usr/local/bin/tool
```

**Example - Third-party RPM repository** (see `build/20-chrome.sh`):
```bash
#!/usr/bin/env bash
set -euo pipefail

# Chrome
cat > /etc/yum.repos.d/google-chrome.repo << 'EOF'
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF

rpm-ostree install -y google-chrome-stable

# Clean up
rm -f /etc/yum.repos.d/google-chrome.repo
```

**Example - Desktop swap** (see `build/30-cosmic.sh`):
```bash
#!/usr/bin/env bash
set -euo pipefail

# Remove GNOME, install COSMIC
rpm-ostree remove -y gnome-shell
rpm-ostree install -y cosmic-desktop
systemctl set-default graphical.target
```

**Example scripts**: See `build/20-chrome.sh.example` and `build/30-cosmic-desktop.sh.example` for complete working examples.

### 4. Homebrew (`custom/brew/`)

**Files**: `*.Brewfile` (Ruby syntax)

**Example - `custom/brew/default.Brewfile`**:
```ruby
# CLI tools
brew "bat"        # Better cat
brew "eza"        # Better ls
brew "ripgrep"    # Better grep
brew "fd"         # Better find

# Dev tools
tap "homebrew/cask"
brew "node"
brew "python"
```

**Users install via**: `ujust install-default-apps` (create shortcut in `custom/ujust/`)

### 5. ujust Commands (`custom/ujust/`)

**Files**: `*.just` (all auto-consolidated)

**Example - `custom/ujust/apps.just`**:
```just
[group('Apps')]
install-default-apps:
    #!/usr/bin/env bash
    brew bundle --file /usr/share/ublue-os/homebrew/default.Brewfile

[group('Apps')]
install-dev-tools:
    #!/usr/bin/env bash
    brew bundle --file /usr/share/ublue-os/homebrew/development.Brewfile
```

**RULES**:
- **NEVER** use package managers in ujust files - only Brewfile/Flatpak shortcuts
- Use `[group('Category')]` for organization
- All `.just` files merged during build

### 6. Flatpaks (`custom/flatpaks/`)

**Files**: `*.preinstall` (INI format, installed after first boot)

**Example - `custom/flatpaks/default.preinstall`**:
```ini
[Flatpak Preinstall org.mozilla.firefox]
Branch=stable

[Flatpak Preinstall org.gnome.Calculator]
Branch=stable

[Flatpak Preinstall com.visualstudio.code]
Branch=stable
```

**Important**: Not in ISO/container. Installed post-first-boot. Requires internet. Find IDs at https://flathub.org/

### 7. ISO/Disk Images (`iso/`)

**For local testing only. No CI/CD.**

**Files**:
- `iso/disk.toml` - VM images (QCOW2/RAW): `just build-qcow2`
- `iso/iso.toml` - Installer ISO: `just build-iso`

**CRITICAL** - Update bootc switch URL in `iso/iso.toml`:
```toml
[customizations.installer.kickstart]
contents = """
%post
bootc switch --mutate-in-place --transport registry ghcr.io/USERNAME/REPO:stable
%end
"""
```

**Upload**: Use `iso/rclone/` configs (Cloudflare R2, AWS S3, Backblaze B2, SFTP)

### 8. Release Workflow

**Branches**:
- `main` - Production only. Builds `:latest` images. Never push directly.

**Workflows**:
- `build.yml` - Builds `:latest` or `:next` on main
- `renovate.yml` - Monitors base image updates (every 6 hours)
- `clean.yml` - Deletes images >90 days (weekly)
- `validate-*.yml` - Pre-merge validation (shellcheck, Brewfile, Flatpak, etc.)

**Image Tags**:
- `:latest` - Latest stable release from main branch
- `:stable.YYYYMMDD` - Datestamped stable release
- `:YYYYMMDD` - Date only
- `:pr-123` - Pull request builds (for testing)
- `:sha-abc123` - Git commit SHA (short)

**Renovate Bot**: 
- Automatically updates base image SHAs in `Containerfile`
- Runs every 6 hours (configured in `.github/renovate.json5`)
- Creates PRs for updates - review and merge to keep images current

### 8. Understanding the Multi-Stage Build Architecture

This template implements a **multi-stage build pattern** following @projectbluefin/dakota.

**Why Multi-Stage?**
- **Modularity**: Combine resources from multiple OCI containers
- **Reusability**: Share common components across different images
- **Maintainability**: Update shared components independently
- **Reproducibility**: Renovate updates OCI container tags to SHA digests

**Stage Breakdown:**

**Stage 1: Context (ctx)**
```dockerfile
FROM scratch AS ctx
COPY build /build                    # Local build scripts
COPY custom /custom                  # Local customizations
COPY --from=ghcr.io/projectbluefin/common:latest /system_files /oci/common
COPY --from=ghcr.io/projectbluefin/branding:latest /system_files /oci/branding
COPY --from=ghcr.io/ublue-os/artwork:latest /system_files /oci/artwork
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /oci/brew
```

This stage combines:
- **Local resources** (build scripts, custom files)
- **OCI container resources** from upstream projects
- Resources are copied to **distinct subdirectories** to avoid conflicts

**Stage 2: Final Image**
```dockerfile
FROM quay.io/gnome_infrastructure/gnome-build-meta:gnomeos-nightly

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/build/10-build.sh
```

The final stage:
- Starts from base image
- Mounts the `ctx` stage at `/ctx`
- Runs build scripts with access to all resources

**Accessing OCI Resources in Build Scripts:**

Build scripts can access files from OCI containers:
```bash
#!/usr/bin/env bash
# Example: Copy branding files
cp -r /ctx/oci/branding/* /usr/share/branding/

# Example: Copy common desktop config
cp /ctx/oci/common/config.yaml /etc/myapp/

# Example: Use brew files
cp /ctx/oci/brew/*.sh /usr/local/bin/
```

**Renovate Integration:**
- Renovate monitors OCI container tags (`:latest`)
- Automatically updates to SHA digests for reproducibility
- Example: `:latest` → `@sha256:abc123...`
- Ensures builds are reproducible and verifiable

**Reference:** See [Bluefin Contributing Guide](https://docs.projectbluefin.io/contributing/) for architecture diagram

### 9. Image Signing (Optional, Recommended for Production)

**Default**: DISABLED (commented out in workflows) to allow first builds.
```bash
# Generate keys
COSIGN_PASSWORD="" cosign generate-key-pair
# Creates: cosign.key (SECRET), cosign.pub (COMMIT)

# Add to GitHub
# Settings → Secrets and Variables → Actions → New secret
# Name: SIGNING_SECRET
# Value: <paste entire contents of cosign.key>

# Uncomment signing sections in:
# - .github/workflows/build.yml
# - .github/workflows/build-testing.yml
```

**NEVER commit `cosign.key`**. Already in `.gitignore`.

---

## Critical Rules (Enforced)

1. **ALWAYS** use Conventional Commits format for ALL commits (required for Release Please)
   - Format: `<type>[scope]: <description>`
   - Valid types: `feat:`, `fix:`, `docs:`, `chore:`, `build:`, `ci:`, `refactor:`, `test:`
   - Breaking changes: Add `!` or `BREAKING CHANGE:` in footer
   - See `.github/commit-convention.md` for examples
2. **NEVER** commit `cosign.key` to repository
3. **ALWAYS** use `rpm-ostree install` for bootc images
4. **ALWAYS** use `-y` flag for non-interactive installs
5. **NEVER** use package managers in ujust files - only Brewfile/Flatpak shortcuts
7. **ALWAYS** work on testing branch for development
8. **ALWAYS** let Release Please handle testing→main merges
9. **NEVER** push directly to main (only via Release Please)
10. **ALWAYS** confirm with user before deviating from @ublue-os/bluefin patterns
11. **ALWAYS** run shellcheck/YAML validation before committing
12. **ALWAYS** update bootc switch URL in `iso/iso.toml` to match user's repo
13. **ALWAYS** follow numbered script convention: `10-*.sh`, `20-*.sh`, `30-*.sh`
14. **ALWAYS** check example scripts before creating new patterns (`.example` files in `build/`)
15. **ALWAYS** validate that new Flatpak IDs exist on Flathub before adding
16. **NEVER** modify validation workflows without understanding impact on PR checks
---

## Troubleshooting

| Symptom | Cause | Solution |
|---------|-------|----------|
| Build fails: "permission denied" | Signing misconfigured | Verify signing commented out OR `SIGNING_SECRET` set |
| Build fails: "package not found" | Typo or unavailable | Check spelling, verify on RPMfusion, add COPR if needed |
| Build fails: "base image not found" | Invalid FROM line | Check syntax in `Containerfile` line 24 |
| Build fails: "shellcheck error" | Script syntax error | Run `shellcheck build/*.sh` locally, fix errors |
| PR validation fails: Brewfile | Invalid Brewfile syntax | Check Ruby syntax, ensure packages exist |
| PR validation fails: Flatpak | Invalid app ID | Verify app ID exists on https://flathub.org/ |
| PR validation fails: justfile | Invalid just syntax | Run `just --list` locally to test |
| Changes not in production | Wrong workflow | Push to main (via PR) to trigger stable builds |
| ISO missing customizations | Wrong bootc URL | Update `iso/iso.toml` bootc switch URL to match repo |
| COPR packages missing after boot | COPR not disabled | COPRs persist if not disabled - use `copr_install_isolated` |
| ujust commands not working | Wrong install location | Files must be in `custom/ujust/` and copied to `/usr/share/ublue-os/just/` |
| Flatpaks not installed | Expected behavior | Flatpaks install post-first-boot, not in ISO/container |
| Local build fails | Wrong environment | Must run on bootc-based system or have podman installed |
| Renovate not creating PRs | Configuration issue | Check `.github/renovate.json5` syntax |
| Third-party repo not working | Repo file persists | Remove repo file at end of script (see examples) |

---

## Common Patterns & Examples

### Pattern 1: Enabling System Services

**Location**: `build/10-build.sh`

```bash
# Enable service
systemctl enable podman.socket

# Mask unwanted service
systemctl mask unwanted-service

# Set default target
systemctl set-default graphical.target
```

### Pattern 2: Creating Custom ujust Commands

**Location**: `custom/ujust/*.just`

**Example structure**:
```just
# vim: set ft=make :

# Install development tools
[group('Apps')]
install-dev-tools:
    #!/usr/bin/env bash
    echo "Installing development tools..."
    brew bundle --file /usr/share/ublue-os/homebrew/development.Brewfile

# Custom system command
[group('System')]
my-custom-command:
    #!/usr/bin/env bash
    echo "Running custom command..."
    # Your logic here (NO package manager!)
```

### Pattern 3: Local Testing Workflow

**Complete local testing cycle**:
```bash
# 1. Build container image
just build

# 2. Build QCOW2 disk image
just build-qcow2

# 3. Run in VM
just run-vm-qcow2

# Or combine all steps
just build && just build-qcow2 && just run-vm-qcow2
```

**Alternative**: Build ISO for installation testing
```bash
just build
just build-iso
just run-vm-iso
```

### Pattern 4: Pre-commit Validation (Optional)

**Setup pre-commit hooks locally**:
```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

**Note**: Pre-commit config exists (`.pre-commit-config.yaml`) but is optional. CI validation runs automatically on PRs.

---

## Advanced Topics

### /opt Immutability
Some packages (Chrome, Docker Desktop) write to `/opt`. On Fedora, it's symlinked to `/var/opt` (mutable). To make immutable:

Uncomment `Containerfile` line 20:
```dockerfile
RUN rm /opt && mkdir /opt
```

### Multi-Architecture
- Local `just` commands support your platform
- Most UBlue images support amd64/arm64
- Add `-arm64` suffix if needed: `bluefin-arm64:stable`
- Cross-platform builds require additional setup

### Custom Build Functions
See `build/copr-install-functions.sh` for reusable patterns:
- `copr_install_isolated` - Enable COPR, install packages, disable COPR
- Follow @ublue-os/bluefin conventions exactly



---

## Understanding the Build Process

### Container Build Flow

1. **Base Image** - Pulls base image specified in `Containerfile` FROM line
2. **Context Stage** - Mounts `build/` and `custom/` directories
3. **Build Scripts** - Runs scripts in `build/` directory in numerical order:
   - `10-build.sh` - Always runs first (copies custom files, installs packages)
   - `20-*.sh` - Additional scripts (if present and not .example)
   - `30-*.sh` - More scripts (if present and not .example)
4. **Container Lint** - Validates final image with `bootc container lint`
5. **Push to Registry** - Uploads to GitHub Container Registry (ghcr.io)

### What Gets Included in the Image

**Build-time (baked into image)**:
- System packages from `dnf5 install`
- Enabled systemd services
- Custom files copied from `/ctx/custom/` to standard locations:
  - Brewfiles → `/usr/share/ublue-os/homebrew/`
  - ujust files → `/usr/share/ublue-os/just/60-custom.just`
  - Flatpak preinstall → `/etc/flatpak/preinstall.d/`

**Runtime (installed after deployment)**:
- Homebrew packages (user runs `ujust install-*`)
- Flatpak applications (installed on first boot, requires internet)

### Local vs CI Builds

**Local builds** (with `just build`):
- Uses your local podman
- Faster for testing
- No signing
- No automatic push to registry

**CI builds** (GitHub Actions):
- Uses GitHub runners
- Automatic on push/PR
- Includes validation steps
- Can include signing
- Automatic push to ghcr.io

### Image Layers and Caching

**Efficient layering**:
- Each `RUN` command creates a new layer
- Layers are cached between builds
- Changes near end of Containerfile = faster rebuilds
- Use `--mount=type=cache` for package managers

**Best practices**:
- Group related `rpm-ostree install` commands together
- Don't install and remove in same layer
- Clean up in same RUN command as install

---

## Image Tags Reference

**Main branch** (production releases):
- `stable` - Latest stable release (recommended)
- `stable.20250129` - Datestamped stable release
- `20250129` - Date only
- `v1.0.0` - Version from Release Please

**PR builds**:
- `pr-123` - Pull request number
- `sha-abc123` - Git commit SHA (short)

---

## File Modification Priority

When user requests customization, check in this order:

1. **`build/10-build.sh`** (50%) - Build-time packages, services, system configs
2. **`custom/brew/`** (20%) - Runtime CLI tools, dev environments
3. **`custom/ujust/`** (15%) - User convenience commands
4. **`custom/flatpaks/`** (5%) - GUI applications
5. **`Containerfile`** (5%) - Base image, /opt config, advanced builds
6. **`Justfile`** (2%) - Image name, build parameters
7. **`iso/*.toml`** (2%) - ISO/disk customization for testing
8. **`.github/workflows/`** (1%) - Metadata, triggers, workflow config

### Files to AVOID Modifying

**Do NOT modify unless specifically requested or necessary**:
- `.github/renovate.json5` - Renovate configuration (auto-updates)
- `.github/workflows/validate-*.yml` - Validation workflows
- `.gitignore` - Prevents committing secrets
- `build/copr-helpers.sh` - Helper functions (stable patterns)
- `LICENSE` - Repository license
- `cosign.pub` - Public signing key (regenerate if changing keys)

**Modify with extreme caution**:
- `.github/workflows/build.yml` - Core build workflow
- `.github/workflows/clean.yml` - Image cleanup
- `Justfile` - Local build automation (users rely on these commands)

---

## Debugging Tips

### Local Debugging

**Build failures**:
```bash
# Build with verbose output
podman build --log-level=debug .

# Check build script syntax
shellcheck build/*.sh

# Test specific script in container
podman run --rm -it ghcr.io/ublue-os/bluefin:stable bash
# Then run your script commands manually
```

**Brewfile issues**:
```bash
# Validate Brewfile syntax
brew bundle check --file custom/brew/default.Brewfile

# List what would be installed
brew bundle list --file custom/brew/default.Brewfile
```

**Just file issues**:
```bash
# Check syntax
just --list

# Check specific file
just --unstable --fmt --check -f custom/ujust/custom-apps.just

# Run specific command with debug
just --verbose install-default-apps
```
