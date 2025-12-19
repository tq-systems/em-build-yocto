# Energy Manager Yocto Build System

## Description

This project provides a complete Yocto-based build system for the TQ-Systems Energy Manager (EM400) project. It manages the build infrastructure for creating:

- **Core Images**: Energy Manager Operating System (EMOS) for multiple target architectures
- **Cross-compiler Toolchains**: SDK for application development
- **Docker Build Environment**: Containerized build system for reproducible builds

The build system supports multiple machine architectures (`em310`, `em-aarch64`) and includes automated CI/CD pipelines for continuous integration and deployment.

## Prerequisites

### System Requirements
- **Docker** and **docker-compose** for containerized builds
- **Make** for build orchestration
- **Git** for source code management
- **Linux host system** (tested on Ubuntu/Debian)

### Hardware Requirements
- **Minimum 32GB RAM** for Yocto builds
- **at least 100GB free disk space** for build artifacts and caches
- **Multi-core CPU** (8+ cores recommended for faster builds)

## Quick Start

### 1. Clone and Prepare
```bash
git clone <repository-url>
cd em-build-yocto
```

### 2. Build Everything (Docker)
```bash
# Build core image and toolchain for all machines
make all

# Or build specific targets
make build TARGET=core-image
make build TARGET=toolchain
```

### 3. Deploy Artifacts
```bash
# Deploy to local workspace
make deploy
```

## Build Targets

### Available Make Targets

| Target                  | Description                             |
|-------------------------|-----------------------------------------|
| `all`                   | Build both core image and toolchain     |
| `prepare`               | Fetch and prepare em-build repository   |
| `build TARGET=<target>` | Build specific target                   |
| `deploy`                | Deploy artifacts to configured location |
| `clean-build`           | Clean build directory only              |
| `clean`                 | Full clean (removes em-build)           |

### Build Target Types

| Target          | Description          | Output Location                       |
|-----------------|----------------------|---------------------------------------|
| `core-image`    | EMOS root filesystem | `artifacts/core-image/<machine>/`     |
| `toolchain`     | Cross-compiler SDK   | `artifacts/toolchain/<architecture>/` |
| `<recipe-name>` | Any Yocto recipe     | Standard Yocto deploy paths           |

### Supported Machine Architectures

| Machine      | Architecture  | Description                   |
|--------------|---------------|-------------------------------|
| `em310`      | ARM Cortex-A7 | EM310 energy manager          |
| `em-aarch64` | ARM64         | EM4xx/EM-CB30 energy managers |

## Configuration

### Environment Variables

#### Build Configuration
```bash
# Target machines (default: em-aarch64)
export TQEM_MACHINES="em310 em-aarch64"

# Specific em-aarch64 variant (em4xx or em-cb30)
export TQEM_EM_AARCH64_MACHINE="em4xx"

# em-build reference (branch/tag)
export TQEM_EM_BUILD_REF="v1.2.3"

# Clean mode before build
export CLEAN_MODE="build"  # or "full"
```

#### Deployment Paths
```bash
# Base deployment directory
export TQEM_BASE_DEPLOY_PATH="$HOME/workspace/tqem/deploy"

# Local Yocto configuration
export PATH_LOCAL_YOCTO_CONF="$HOME/.yocto"
```

### Local Layer Configuration
The local layer configuration is a file that provides an additional set of Yocto layers
that is appended to the internal static set of em-layers.conf.

#### Method 1: Configuration File
Create a local layer configuration file:

```bash
# Create configuration file
cat > adapt-em-layers.conf << EOF
LAYERS += meta-custom

meta-custom_repo = ssh://git@git.example.com/meta-custom.git
meta-custom_branch = master
# meta-custom_commit = abc123
# meta-custom_subdirs = meta-layer1 meta-layer2
EOF

# Set environment variable
export ADD_LAYER_CONF_FILE="adapt-em-layers.conf"
```

#### Method 2: Override (Existing) Configuration via Environment Variable
```bash
export OVERRIDE_LAYER_CONF_VAR="LAYERS += meta-custom
meta-custom_repo = https://github.com/example/meta-custom.git
meta-custom_branch = main"
```

#### Method 3: Append To Existing Local Layer Configuration via Environment Variable
```bash
export APPEND_LAYER_CONF_VAR="LAYERS += meta-additional
meta-additional_repo = https://github.com/additional-layer/meta-additional.git
meta-additional_branch = custom"
```

### Site Configuration
Create `~/.yocto/site.conf` for persistent local settings:

```bash
mkdir -p ~/.yocto
cat > ~/.yocto/site.conf << EOF
# Parallel build settings
BB_NUMBER_THREADS = "8"
PARALLEL_MAKE = "-j 8"

# Download directory (shared cache)
DL_DIR = "/var/cache/yocto/downloads"

# Shared state cache
SSTATE_DIR = "/var/cache/yocto/sstate"
EOF
```

## Docker Build Environment

### Building Docker Images
```bash
# Build yocto build image
make -f docker.mk all

# Push to registry (for CI/CD)
make -f docker.mk push

# Clean up
make -f docker.mk clean
```

### Docker Environment Variables
```bash
# Docker registry settings
export YOCTO_REGISTRY="registry.example.com/em"
export BASE_REGISTRY="registry.example.com/em/base"
export BASE_TAG="latest"
export BUILD_TAG="v1.0.0"
```

## Advanced Usage

### Custom Recipe Development

1. **Add Custom Layer**:
   ```bash
   export OVERRIDE_LOCAL_CONF="LAYERS += meta-custom
   meta-custom_repo = /path/to/local/meta-custom
   meta-custom_branch = HEAD"
   ```

2. **Build Custom Recipe**:
   ```bash
   make build TARGET=my-custom-recipe
   ```

### Multi-Architecture Builds

Build for specific architectures:
```bash
# Build for EM310 only
export TQEM_MACHINES="em310"
make all

# Build for specific em-aarch64 variant
export TQEM_MACHINES="em-aarch64"
export TQEM_EM_AARCH64_MACHINE="em4xx"
make all
```

### Incremental Builds

```bash
# Prepare once
make prepare

# Build incrementally
make build TARGET=core-image
make build TARGET=toolchain
make build TARGET=my-package
```

### Development Workflow

```bash
# Full development build
export CLEAN_MODE="full"
export LOCAL_LAYER_CONF="my-layers.conf"
make all

# Deploy for testing
make deploy

# Incremental changes
export CLEAN_MODE=""  # No cleaning
make build TARGET=modified-recipe
```

## Output Artifacts

### Core Image Artifacts
```
artifacts/core-image/<machine>/
├── em-image-core-<machine>.tar          # Root filesystem
└── em-image-core-<machine>.bootloader.tar  # Bootloader files
```

### Toolchain Artifacts
```
artifacts/toolchain/<architecture>/
└── emos-x86_64-<arch>-toolchain.sh     # SDK installer
```

### Deployment Structure
```
$TQEM_BASE_DEPLOY_PATH/
└── snapshots/emos/<ref>/
    ├── core-image/
    └── toolchain/
```

## Troubleshooting

### Common Issues

1. **Build Failures**:
   ```bash
   # Clean and retry
   export CLEAN_MODE="full"
   make prepare
   make build TARGET=<failed-target>
   ```

2. **Disk Space Issues**:
   ```bash
   # Clean build artifacts
   make clean-build

   # Full clean
   make clean
   ```

3. **Layer Conflicts**:
   ```bash
   # Check layer configuration
   make prepare
   cd em-build && cat local/em-layers.conf
   ```

4. **Docker Issues**:
   ```bash
   # Rebuild docker image
   make -f docker.mk clean
   make -f docker.mk all
   ```

### Debug Mode

Enable verbose logging:
```bash
# Set debug environment
export BB_VERBOSE_LOGS="1"
export BITBAKE_UI="knotty"

# Run with debug
make build TARGET=core-image
```

## License Information

All files in this project are classified as product-specific software and bound to the use with the TQ-Systems GmbH product: EM400

    SPDX-License-Identifier: LicenseRef-TQSPSLA-1.0.3

## Support and Resources

- **em-build Repository**: https://github.com/tq-systems/em-build.git
- **TQ-Systems**: https://www.tq-group.com/
- **Yocto Project**: https://www.yoctoproject.org/

For technical support, please contact TQ-Systems GmbH or refer to the project's issue tracker.
