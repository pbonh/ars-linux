# ars-linux

A Universal Blue-based Linux distribution designed as a general-purpose developer workstation featuring the Niri scrollable-tiling Wayland compositor.

## Overview

ars-linux is built on Universal Blue and provides:

- **Niri Window Manager**: A modern scrollable-tiling Wayland compositor
- **Full Wayland Support**: Complete Wayland infrastructure with XWayland support
- **Developer Tools**: Pre-installed development environment (gcc, rust, go, node, python)
- **Homebrew Support**: Easy package management with Homebrew on Linux
- **Modern Utilities**: Waybar, fuzzel, mako, and more

## Features

### Niri Compositor
- Scrollable tiling workflow inspired by PaperWM
- Dynamic workspaces like in GNOME
- Built-in screenshot UI
- Monitor and window screencasting
- Touchpad and mouse gestures
- Configurable layout with gaps and borders
- Smooth animations

### Desktop Environment
- **Status Bar**: Waybar with custom configuration
- **App Launcher**: Fuzzel
- **Notifications**: Mako
- **Terminal**: Foot
- **File Manager**: Nautilus
- **Display Manager**: SDDM

### Development Tools
- Programming languages: Rust, Go, Python 3, Node.js
- Build tools: gcc, make, cmake, cargo
- Version control: git
- Modern CLI tools: ripgrep, fd, bat, exa, zoxide

### Package Management
- **dnf5**: Native Fedora package manager
- **Homebrew**: Popular package manager for additional software
- **Flatpak**: Pre-configured with Flathub (via Universal Blue)

## Installation

Follow the Universal Blue bootc installation process:

1. Build and push your image to GitHub Container Registry
2. From an existing bootc system, switch to ars-linux:
   ```bash
   sudo bootc switch ghcr.io/YOUR_USERNAME/ars-linux
   sudo systemctl reboot
   ```

## First Boot

On first login, you'll be prompted to install Homebrew. Simply answer 'y' to install it automatically.

## Configuration

### Niri Configuration
The default Niri configuration is located at `~/.config/niri/config.kdl`. Key bindings:

- `Mod+Return`: Open terminal
- `Mod+D`: Application launcher
- `Mod+Q`: Close window
- `Mod+H/J/K/L`: Navigate windows
- `Mod+1-9`: Switch workspaces
- `Mod+Shift+E`: Exit Niri
- `Mod+Shift+R`: Reload configuration

### Waybar Configuration
Waybar configuration files are at `~/.config/waybar/`. Customize `config` and `style.css` to your liking.

## Customization

This image is designed to be customized. Edit `build_files/build.sh` to add your own packages and configurations.

## About DankMaterialShell

The system is configured with a modern, material-design-friendly environment that can be themed according to DankLinux aesthetics. The foundation includes:
- Waybar for a customizable status bar
- Modern GTK applications
- Wayland-native tools
- Theming support via GTK and icon themes

## Community Resources

- [Niri Documentation](https://yalter.github.io/niri/)
- [Universal Blue](https://universal-blue.org/)
- [Niri Matrix Chat](https://matrix.to/#/#niri:matrix.org)
- [Universal Blue Discord](https://discord.gg/WEu6BdFEtp)

## License

This project follows the Universal Blue template structure. See LICENSE file for details.
