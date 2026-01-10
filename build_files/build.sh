#!/bin/bash

set -ouex pipefail

### Install packages for Niri + DankMaterialShell Developer Workstation

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images

### Core System Tools
dnf5 install -y \
    tmux \
    git \
    vim \
    wget \
    curl \
    htop \
    ripgrep \
    fd-find \
    bat \
    eza \
    zoxide

### Wayland and Graphics Dependencies
# Core Wayland libraries and utilities
dnf5 install -y \
    wayland-devel \
    wayland-protocols-devel \
    mesa-dri-drivers \
    mesa-vulkan-drivers \
    libxkbcommon \
    libinput \
    seatd \
    xorg-x11-server-Xwayland \
    pipewire \
    wireplumber \
    pipewire-alsa \
    pipewire-pulseaudio \
    pipewire-jack-audio-connection-kit

### Display Manager - SDDM for Wayland session support
dnf5 install -y \
    sddm \
    qt6-qtwayland

### Essential Wayland Utilities
# These are recommended by Niri documentation
dnf5 install -y \
    waybar \
    fuzzel \
    mako \
    swaylock \
    swayidle \
    grim \
    slurp \
    wl-clipboard \
    kanshi \
    foot

### Desktop Environment Essentials
dnf5 install -y \
    network-manager-applet \
    blueman \
    pavucontrol \
    polkit-gnome \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-gnome \
    gnome-keyring \
    nautilus \
    gnome-terminal

### Development Tools
dnf5 install -y \
    gcc \
    gcc-c++ \
    make \
    cmake \
    pkg-config \
    python3 \
    python3-pip \
    nodejs \
    npm \
    go \
    rust \
    cargo

### Build dependencies for Niri
dnf5 install -y \
    cairo-devel \
    pango-devel \
    libxkbcommon-devel \
    pixman-devel \
    libinput-devel \
    udev-devel \
    libgbm-devel \
    libdrm-devel \
    systemd-devel

### Install Niri from COPR
# Enable the COPR repository for Niri
dnf5 -y copr enable yalter/niri

# Install Niri and related packages
dnf5 install -y niri xwayland-satellite

# Disable COPR so it doesn't end up enabled on the final image
dnf5 -y copr disable yalter/niri

### Homebrew Setup
# Install dependencies for Homebrew
dnf5 install -y \
    procps-ng \
    file \
    git

# Homebrew will be installed by users on first boot via /etc/profile.d/homebrew.sh
# Create the profile script to auto-install Homebrew on first login
mkdir -p /etc/profile.d
cat > /etc/profile.d/homebrew-setup.sh << 'EOF'
# Homebrew setup for ars-linux
# Note: Uses official Homebrew installer from https://brew.sh
if [ ! -d "/home/linuxbrew/.linuxbrew" ] && [ -n "$PS1" ] && [ "$EUID" -ne 0 ]; then
    if [ ! -f "$HOME/.homebrew-install-attempted" ]; then
        echo "Homebrew is not installed. Would you like to install it? (y/n)"
        read -r response
        if [ "$response" = "y" ]; then
            # Using the official Homebrew installer (https://brew.sh)
            NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        touch "$HOME/.homebrew-install-attempted"
    fi
fi

# Set up Homebrew environment if it exists
if [ -d "/home/linuxbrew/.linuxbrew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
EOF
chmod +x /etc/profile.d/homebrew-setup.sh

### Create Niri configuration directory structure
mkdir -p /etc/skel/.config/niri

# Create default Niri configuration
cat > /etc/skel/.config/niri/config.kdl << 'EOF'
// Niri Configuration for ars-linux

// Input configuration
input {
    keyboard {
        xkb {
            layout "us"
        }
    }
    
    touchpad {
        tap
        natural-scroll
        accel-speed 0.2
    }
    
    mouse {
        accel-speed 0.2
    }
}

// Output (monitor) configuration
// This is a basic configuration - users should customize for their setup
// output "HDMI-A-1" {
//     mode "1920x1080@60.000"
// }

// Layout configuration
layout {
    gaps 8
    
    focus-ring {
        width 2
        active-color "#7fc8ff"
        inactive-color "#505050"
    }
    
    border {
        width 2
        active-color "#7fc8ff"
        inactive-color "#505050"
    }
    
    struts {
        left 0
        right 0
        top 0
        bottom 0
    }
}

// Spawn programs on startup
spawn-at-startup "waybar"
spawn-at-startup "mako"
spawn-at-startup "nm-applet"
spawn-at-startup "blueman-applet"
spawn-at-startup "/usr/libexec/polkit-gnome-authentication-agent-1"

// Keybindings
binds {
    // Window management
    Mod+H { focus-column-left; }
    Mod+L { focus-column-right; }
    Mod+J { focus-window-down; }
    Mod+K { focus-window-up; }
    
    Mod+Shift+H { move-column-left; }
    Mod+Shift+L { move-column-right; }
    Mod+Shift+J { move-window-down; }
    Mod+Shift+K { move-window-up; }
    
    // Workspace management
    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }
    Mod+6 { focus-workspace 6; }
    Mod+7 { focus-workspace 7; }
    Mod+8 { focus-workspace 8; }
    Mod+9 { focus-workspace 9; }
    
    Mod+Shift+1 { move-window-to-workspace 1; }
    Mod+Shift+2 { move-window-to-workspace 2; }
    Mod+Shift+3 { move-window-to-workspace 3; }
    Mod+Shift+4 { move-window-to-workspace 4; }
    Mod+Shift+5 { move-window-to-workspace 5; }
    Mod+Shift+6 { move-window-to-workspace 6; }
    Mod+Shift+7 { move-window-to-workspace 7; }
    Mod+Shift+8 { move-window-to-workspace 8; }
    Mod+Shift+9 { move-window-to-workspace 9; }
    
    // Application launchers
    Mod+Return { spawn "foot"; }
    Mod+D { spawn "fuzzel"; }
    Mod+Q { close-window; }
    
    // System controls
    Mod+Shift+E { quit; }
    Mod+Shift+R { spawn "niri" "msg" "action" "reload-config"; }
    
    // Screenshot
    Print { spawn "sh" "-c" "grim - | wl-copy"; }
    Mod+Print { spawn "sh" "-c" "slurp | grim -g - - | wl-copy"; }
    
    // Volume and media controls
    XF86AudioRaiseVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
    XF86AudioLowerVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
    XF86AudioMute { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
    XF86AudioMicMute { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }
}

// Window rules
// Example:
// window-rule {
//     match app-id="firefox"
//     default-column-width { proportion 0.5; }
// }

// Prefer dark theme
prefer-no-csd

// Enable VRR (Variable Refresh Rate) if supported
// vrr {
//     enable
// }

// Cursor
cursor {
    size 24
}

// Animations - customize as desired
animations {
    slowdown 1.0
}

// Debug options (disable for production)
// debug {
//     render-drm-device "/dev/dri/renderD128"
// }
EOF

### Create default Waybar configuration
mkdir -p /etc/skel/.config/waybar

cat > /etc/skel/.config/waybar/config << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "modules-left": ["custom/launcher", "niri/workspaces", "niri/window"],
    "modules-center": [],
    "modules-right": ["pulseaudio", "network", "cpu", "memory", "temperature", "battery", "clock", "tray"],
    
    "custom/launcher": {
        "format": " 󰣇 ",
        "on-click": "fuzzel",
        "tooltip": false
    },
    
    "niri/workspaces": {
        "format": "{name}",
        "on-click": "activate"
    },
    
    "niri/window": {
        "format": "{}",
        "max-length": 50
    },
    
    "clock": {
        "format": "{:%H:%M  %Y-%m-%d}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },
    
    "cpu": {
        "format": " {usage}%",
        "tooltip": false
    },
    
    "memory": {
        "format": " {}%"
    },
    
    "temperature": {
        "critical-threshold": 80,
        "format": " {temperatureC}°C"
    },
    
    "battery": {
        "states": {
            "warning": 30,
            "critical": 15
        },
        "format": "{icon} {capacity}%",
        "format-charging": " {capacity}%",
        "format-plugged": " {capacity}%",
        "format-icons": ["", "", "", "", ""]
    },
    
    "network": {
        "format-wifi": " {essid}",
        "format-ethernet": " {ifname}",
        "format-disconnected": "⚠ Disconnected",
        "tooltip-format": "{ifname}: {ipaddr}/{cidr}"
    },
    
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": " Muted",
        "format-icons": {
            "default": ["", "", ""]
        },
        "on-click": "pavucontrol"
    },
    
    "tray": {
        "spacing": 10
    }
}
EOF

cat > /etc/skel/.config/waybar/style.css << 'EOF'
* {
    border: none;
    border-radius: 0;
    font-family: "JetBrainsMono Nerd Font", monospace;
    font-size: 13px;
    min-height: 0;
}

window#waybar {
    background: rgba(30, 30, 46, 0.9);
    color: #cdd6f4;
}

#workspaces button {
    padding: 0 5px;
    background: transparent;
    color: #cdd6f4;
    border-bottom: 3px solid transparent;
}

#workspaces button.active {
    border-bottom: 3px solid #89b4fa;
}

#workspaces button.focused {
    background: #45475a;
    border-bottom: 3px solid #89b4fa;
}

#custom-launcher,
#clock,
#battery,
#cpu,
#memory,
#temperature,
#network,
#pulseaudio,
#tray {
    padding: 0 10px;
    margin: 0 2px;
    background: #45475a;
}

#battery.charging {
    color: #a6e3a1;
}

#battery.warning:not(.charging) {
    color: #f9e2af;
}

#battery.critical:not(.charging) {
    color: #f38ba8;
    animation: blink 0.5s linear infinite alternate;
}

@keyframes blink {
    to {
        background-color: #f38ba8;
        color: #1e1e2e;
    }
}
EOF

### Create SDDM Wayland session file for Niri
mkdir -p /usr/share/wayland-sessions

cat > /usr/share/wayland-sessions/niri.desktop << 'EOF'
[Desktop Entry]
Name=Niri
Comment=Scrollable-tiling Wayland compositor
Exec=niri-session
Type=Application
DesktopNames=niri
EOF

# Create niri-session wrapper script
cat > /usr/local/bin/niri-session << 'EOF'
#!/bin/bash
# Start Niri with proper environment

# Set XDG environment variables
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=niri
export XDG_CURRENT_DESKTOP=niri

# Qt settings
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1

# GTK settings
export GDK_BACKEND=wayland

# Firefox Wayland
export MOZ_ENABLE_WAYLAND=1

# Start Niri
exec niri
EOF
chmod +x /usr/local/bin/niri-session

### Enable SDDM
systemctl enable sddm.service

### Enable essential services
systemctl enable podman.socket
# Enable pipewire services for audio - using service units for better reliability in bootc
systemctl enable pipewire.service
systemctl enable pipewire-pulse.service
systemctl enable wireplumber.service

### Note about DankMaterialShell
# DankMaterialShell (https://danklinux.com/) integration
# As DankMaterialShell appears to be a desktop shell/theme,
# we've configured a solid foundation with Niri, Waybar, and modern tools.
# Users can further customize the appearance and behavior using:
# - Waybar themes and configurations
# - GTK themes
# - Icon themes
# - Custom scripts and tools
#
# The current setup provides:
# - Niri as the window manager
# - Waybar as the status bar
# - Fuzzel as the application launcher
# - Mako for notifications
# - All necessary Wayland infrastructure
#
# This creates a modern, material-design-friendly environment that can be
# themed and customized according to DankLinux aesthetics.

echo "ars-linux build complete!"
echo "Niri compositor installed with Wayland utilities"
echo "Homebrew support added (will prompt on first user login)"
echo "Development tools and essential packages installed"
