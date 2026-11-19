#!/bin/bash
# Applies the offline/privacy config patches to a generated seed directory.
# Usage: apply.sh <seed-dir>
# Formats verified against the generated seed (Paper 1.12.2 + EaglerXServer 1.1.1 +
# EaglerWeb 1.0.1 + AuthMe + Via*): YAML for EaglercraftXServer/bStats/Via*/AuthMe,
# JSON for EaglerWeb. Run at BUILD time, after the seed boot.
set -eu

SEED="${1:?usage: apply.sh <seed-dir>}"

echo "[patch] seed dir: $SEED"

# --- 1) server.properties: port 8080, offline mode (Eagler protocol), sane MOTD ---
SP="$SEED/server.properties"
if [ -f "$SP" ]; then
  sed -i \
    -e 's/^server-port=.*/server-port=8080/' \
    -e 's/^online-mode=.*/online-mode=false/' \
    -e 's/^motd=.*/motd=EaglercraftX Browser Server on Railway/' \
    -e 's/^max-players=.*/max-players=50/' \
    -e 's/^view-distance=.*/view-distance=6/' \
    -e 's/^prevent-proxy-connections=.*/prevent-proxy-connections=false/' \
    "$SP"
  echo "[patch] server.properties: port 8080, online-mode=false"
  grep -E "^server-port=|^online-mode=" "$SP"
else
  echo "[patch] WARNING: server.properties not found"
fi

# --- 2) EaglercraftXServer settings.yml: update checker OFF, cert downloads OFF ---
EX="$SEED/plugins/EaglercraftXServer/settings.yml"
if [ -f "$EX" ]; then
  sed -i \
    -e 's/^  download_latest_certs: true/  download_latest_certs: false/' \
    -e 's/^  enable_update_checker: true/  enable_update_checker: false/' \
    "$EX"
  echo "[patch] EaglercraftXServer settings.yml: update fetches OFF"
  grep -E "download_latest_certs|enable_update_checker" "$EX" || true
else
  echo "[patch] WARNING: plugins/EaglercraftXServer/settings.yml not found"
fi

# --- 3) EaglerWeb: landing-page webroot (document_root "web") ---
EW="$SEED/plugins/EaglerWeb"
if [ -f "$EW/settings.json" ]; then
  mkdir -p "$EW/web"
  echo "[patch] EaglerWeb webroot ready at plugins/EaglerWeb/web"
else
  echo "[patch] WARNING: plugins/EaglerWeb/settings.json not found"
fi

# --- 4) bStats: metrics OFF (privacy + zero boot network calls) ---
BS="$SEED/plugins/bStats/config.yml"
if [ -f "$BS" ]; then
  sed -i -e 's/^enabled: true/enabled: false/' "$BS"
  echo "[patch] bStats metrics disabled"
  grep -E "^enabled:" "$BS" || true
fi

# --- 5) AuthMe: disable the GeoIP database download (the rival's boot-time fetch) ---
AC="$SEED/plugins/AuthMe/config.yml"
if [ -f "$AC" ]; then
  echo "[patch] AuthMe config.yml found; GeoIP-related keys before patch:"
  grep -nE "PerformHealthCheck|enableProtection|geoIpDatabase" "$AC" | head -8 || true
  # flip geoIpDatabase.enabled (the key under the geoIpDatabase: block)
  sed -i '/geoIpDatabase:/,/licenseKey:/ s/^        enabled: true/        enabled: false/' "$AC"
  echo "[patch] AuthMe GeoIP keys after patch:"
  grep -nE -A1 "geoIpDatabase:" "$AC" | head -4 || true
else
  echo "[patch] WARNING: plugins/AuthMe/config.yml not found (AuthMe may have failed to load)"
fi

echo "[patch] done"
