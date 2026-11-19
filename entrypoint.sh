#!/bin/sh
# EaglercraftX Browser Server entrypoint
# - seeds /data from the image's pre-patched seed on first boot (marker-guarded,
#   never re-fires after the first boot: plugin configs and worlds persist on the volume)
# - computes the JVM heap from the container cgroup memory limit:
#     heap = clamp(1/2 x cgroup limit, floor 512M, cap 4096M), -Xms256m, NO AlwaysPreTouch
# - prints the Eaglercraft join banner, then execs Paper 1.12.2 (EaglerXServer injected)

set -eu

cd /data

# ---- one-time seed (first boot only) ----
if [ ! -f /data/.seed-complete ]; then
    echo "[entrypoint] first boot: seeding /data from the pre-patched image seed"
    cp -a /opt/seed/. /data/
    touch /data/.seed-complete
else
    echo "[entrypoint] seed already present: keeping existing world, plugins, and configs"
fi

# ---- cgroup-aware heap ----
read_mem_max() {
    # cgroup v2, then v1; "max" (v2) and 9223372036854775807 (v1) mean unlimited
    if [ -r /sys/fs/cgroup/memory.max ]; then
        M=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo 0)
    elif [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
        M=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo 0)
    else
        M=0
    fi
    case "$M" in
        ''|max|*[!0-9]*) M=0 ;;
    esac
    if [ "$M" -gt 9000000000000000 ]; then M=0; fi
    echo "$M"
}

MEM_LIMIT=$(read_mem_max)
if [ "$MEM_LIMIT" -le 0 ]; then
    # unknown limit (local run outside a cgroup): assume a 4 GB cap
    MEM_LIMIT=$((4 * 1000 * 1000 * 1000))
    echo "[entrypoint] no cgroup limit found: assuming 4 GB cap"
fi

HALF=$((MEM_LIMIT / 2))
FLOOR=$((512 * 1024 * 1024))
CAP=$((4096 * 1024 * 1024))

HEAP=$HALF
if [ "$HEAP" -lt "$FLOOR" ]; then HEAP=$FLOOR; fi
if [ "$HEAP" -gt "$CAP" ]; then HEAP=$CAP; fi
HEAP_MB=$((HEAP / 1024 / 1024))

MEM_LIMIT_MB=$((MEM_LIMIT / 1024 / 1024))
echo "[entrypoint] container memory limit: ${MEM_LIMIT_MB}MB -> JVM heap: -Xms256m -Xmx${HEAP_MB}M (no AlwaysPreTouch)"

# ---- join banner (K5) ----
DOMAIN="${RAILWAY_PUBLIC_DOMAIN:-}"
if [ -n "$DOMAIN" ]; then
    echo ""
    echo "=============================================================="
    echo "  EAGLERCRAFT JOIN URL: wss://$DOMAIN"
    echo "=============================================================="
    echo ""
    echo "  Browser players:"
    echo "    1. Open https://eaglercraft.com and grab the Eaglercraft 1.12.2 client"
    echo "    2. Direct Connect to:  wss://$DOMAIN"
    echo "    3. In game, run:  /register <password> <password>"
    echo "       (choose your own password - you are the first player here,"
    echo "        this account is yours: change-it-now is the whole point)"
    echo ""
    echo "  Java Edition players (any version 1.8 - latest via ViaVersion):"
    TCPD="${RAILWAY_TCP_PROXY_DOMAIN:-}"
    TCPP="${RAILWAY_TCP_PROXY_PORT:-}"
    if [ -n "$TCPD" ] && [ -n "$TCPP" ]; then
        echo "    Connect to the TCP proxy host:port from your Variables tab:"
        echo "      $TCPD:$TCPP"
    else
        echo "    TCP proxy host:port appear in the Variables tab as"
        echo "    RAILWAY_TCP_PROXY_DOMAIN and RAILWAY_TCP_PROXY_PORT"
    fi
    echo ""
else
    echo "=============================================================="
    echo "  EAGLERCRAFT JOIN URL: (RAILWAY_PUBLIC_DOMAIN not set yet)"
    echo "  Railway generates the domain on first deploy - redeploy once"
    echo "  or check the Settings > Networking tab for your public domain."
    echo "=============================================================="
fi

# ---- exec Paper (nogui flags; heap above; JAVA_ARGS override optional) ----
JAVA_ARGS_EXTRA="${JAVA_ARGS:-}"
exec java -Xms256m -Xmx${HEAP_MB}M \
    -XX:+UseG1GC -XX:+ParallelRefProcEnabled \
    -XX:+UnlockExperimentalVMOptions \
    -XX:MaxGCPauseMillis=200 \
    -XX:+DisableExplicitGC \
    -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 \
    -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 \
    -XX:InitiatingHeapOccupancyPercent=15 \
    -Dsun.jnu.encoding=UTF-8 -Dfile.encoding=UTF-8 \
    -Dcom.mojang.eula.agree=true \
    -DPaper.IgnoreJavaVersion=true \
    $JAVA_ARGS_EXTRA \
    -jar /data/server.jar nogui
