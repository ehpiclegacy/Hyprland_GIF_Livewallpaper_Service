#!/bin/bash

# --- PATHS (Hardcoded for reliability) ---
WALLPAPER_DIR="$HOME/Pictures/Wallpapers/GIFs"
BIN_DIR="$HOME/.local/bin/Swww"
SCRIPT_PATH="$BIN_DIR/swww-toggle"
MAIN_CONFIG="$HOME/.config/hypr/hyprland.conf"

# --- COLORS ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}:: Initializing SWWW Master Setup...${NC}"

# 1. INSTALLATION
if ! command -v swww &> /dev/null; then
    echo -e "${BLUE}:: swww not detected. Installing...${NC}"
    if command -v yay &> /dev/null; then
        yay -S swww --noconfirm
    elif command -v paru &> /dev/null; then
        paru -S swww --noconfirm
    else
        echo "!! Error: No AUR helper (yay/paru) found. Install swww manually."
        exit 1
    fi
else
    echo -e "${GREEN}:: swww is already installed.${NC}"
fi

# 2. DIRECTORY CREATION
echo -e "${BLUE}:: Verifying directories...${NC}"
mkdir -p "$WALLPAPER_DIR"
mkdir -p "$BIN_DIR"

# 3. GENERATE TOGGLE SCRIPT
echo -e "${BLUE}:: Writing logic script to $SCRIPT_PATH...${NC}"

cat <<EOT > "$SCRIPT_PATH"
#!/bin/bash
# SWWW TOGGLE LOGIC

CACHE_DIR="\$HOME/.cache/swww"
SOCK_FILE="/run/user/\$(id -u)/wayland-1-swww-daemon..sock"

if pgrep -x "swww-daemon" > /dev/null; then
    echo ":: Stopping Wallpaper Engine..."
    killall swww-daemon
    rm -rf "\$CACHE_DIR"
    rm -f "\$SOCK_FILE"
    notify-send "Live Wallpaper" "OFF"
    exit 0
fi

echo ":: Starting Wallpaper Engine..."
swww-daemon &
sleep 1
GIF=\$(find "$WALLPAPER_DIR" -type f -name "*.gif" | shuf -n 1)

if [ -n "\$GIF" ]; then
    swww img "\$GIF" --transition-type grow --transition-pos 0.5,0.5 --transition-fps 60
    notify-send "Live Wallpaper" "ON: \$(basename "\$GIF")"
else
    notify-send "Error" "No GIFs found in $WALLPAPER_DIR"
fi
EOT

chmod +x "$SCRIPT_PATH"

# 4. UPDATE HYPRLAND CONFIG
echo -e "${BLUE}:: Updating $MAIN_CONFIG...${NC}"

# Backup existing config
cp "$MAIN_CONFIG" "$MAIN_CONFIG.bak"
echo ":: Backup created at $MAIN_CONFIG.bak"

# --- DISABLE MPVPAPER CONFLICTS ---
# This block checks for mpvpaper and comments out any lines (execs or binds) containing it
if grep -q "mpvpaper" "$MAIN_CONFIG"; then
    echo -e "${BLUE}:: Conflict detected: mpvpaper found in config.${NC}"
    echo ":: Disabling mpvpaper execs and binds..."

    # sed command matches any line with 'mpvpaper' and inserts '# ' at the beginning
    sed -i '/mpvpaper/s/^/# /' "$MAIN_CONFIG"

    echo -e "${GREEN}:: Successfully commented out mpvpaper lines.${NC}"
else
    echo ":: No mpvpaper conflicts found."
fi

# Append the Keybind for SWWW
if ! grep -q "swww-toggle" "$MAIN_CONFIG"; then
    echo -e "\n# --- SWWW WALLPAPER TOGGLE ---" >> "$MAIN_CONFIG"
    echo "bind = SUPER ALT, P, exec, $SCRIPT_PATH" >> "$MAIN_CONFIG"
    echo -e "${GREEN}:: Added Keybind (SUPER+ALT+P)${NC}"
else
    echo ":: Keybind already present."
fi

# Append Auto-Start for SWWW
if ! grep -q "exec-once = $SCRIPT_PATH" "$MAIN_CONFIG"; then
    echo "exec-once = $SCRIPT_PATH" >> "$MAIN_CONFIG"
    echo -e "${GREEN}:: Added Auto-Start (exec-once) to config${NC}"
else
    echo ":: Auto-Start already present."
fi

# 5. FINISH
echo -e "${GREEN}:: SETUP COMPLETE!${NC}"
echo "------------------------------------------------"
echo "1. Place your .gif files inside: $WALLPAPER_DIR"
echo "2. Reload Hyprland now: run 'hyprctl reload'"
echo "3. Press SUPER + ALT + P to toggle the wallpaper."
echo "------------------------------------------------"
