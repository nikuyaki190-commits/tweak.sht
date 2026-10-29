
#!/data/data/com.termux/files/usr/bin/bash

# Android Root Tweaker | Android 10 | Multi-device
# No auto reboot | No settings backup

set -u

CURL="/data/data/com.termux/files/usr/bin/curl"
WORK="/data/local/tmp/android-root-tweaker"
TARGET_DP=960

APK_URLS=(
  "https://files.zetsu.lol/f/137a6350-3255-4882-8127-6ba19329010e"
  "https://files.zetsu.lol/f/21a077e7-0551-4ed7-a817-d61ef6220fb6"
  "https://files.zetsu.lol/f/a293aa85-1b6b-4054-8498-2f92cb816688"
)

log() { echo "[Tweaker] $*"; }

if [ "$(id -u)" -ne 0 ]; then
  echo "Jalankan script sebagai root."
  exit 1
fi

if [ ! -x "$CURL" ]; then
  echo "curl Termux tidak ditemukan. Jalankan: pkg install curl"
  exit 1
fi

mkdir -p "$WORK" || exit 1

# Terapkan setting dan verifikasi nilai
put_setting() {
  namespace="$1"
  key="$2"
  value="$3"

  if settings put "$namespace" "$key" "$value" 2>/dev/null; then
    actual="$(settings get "$namespace" "$key" 2>/dev/null)"
    if [ "$actual" = "$value" ]; then
      log "OK: $key = $value"
    else
      log "TIDAK TERVERIFIKASI: $key"
    fi
  else
    log "DILEWATI: $key tidak didukung"
  fi
}

log "Mematikan animasi..."
put_setting global window_animation_scale 0
put_setting global transition_animation_scale 0
put_setting global animator_duration_scale 0

log "Mencoba opsi Developer Options..."
put_setting global force_allow_on_external 1
put_setting global force_resizable_activities 1
put_setting global enable_freeform_support 1
put_setting global force_desktop_mode_on_external_displays 1

log "Menghitung density untuk target 960 dp..."
SIZE="$(wm size | grep -oE '[0-9]+x[0-9]+' | tail -n 1)"

if [ -n "$SIZE" ]; then
  W="${SIZE%x*}"
  H="${SIZE#*x}"
  MIN_SIDE=$(( W < H ? W : H ))
  DENSITY=$(( MIN_SIDE * 160 / TARGET_DP ))

  if [ "$DENSITY" -gt 0 ]; then
    if wm density "$DENSITY"; then
      log "Density disetel ke $DENSITY dpi (perkiraan)."
      log "Periksa Smallest width aktual di Developer Options."
    else
      log "GAGAL mengubah density."
    fi
  fi
else
  log "Resolusi tidak terbaca; density dilewati."
fi

log "Memulai download dan instalasi APK..."
i=1

for URL in "${APK_URLS[@]}"; do
  FILE="$WORK/app${i}.apk"
  PART="$WORK/app${i}.download"

  rm -f "$PART" "$FILE"
  log "Download APK $i..."

  if ! "$CURL" -fLsS --connect-timeout 20 \
       --max-time 300 --retry 1 \
       -o "$PART" "$URL"; then
    log "GAGAL download APK $i; lanjut."
    rm -f "$PART"
    i=$((i + 1))
    continue
  fi

  MAGIC="$(od -An -tx1 -N2 "$PART" 2>/dev/null | tr -d ' \n')"

  if [ ! -s "$PART" ] || [ "$MAGIC" != "504b" ]; then
    log "File APK $i tidak valid atau link bukan direct download."
    rm -f "$PART"
    i=$((i + 1))
    continue
  fi

  mv "$PART" "$FILE"

  if pm install -r "$FILE"; then
    log "BERHASIL memasang APK $i."
  else
    log "Instalasi APK $i gagal; lanjut ke berikutnya."
  fi

  i=$((i + 1))
done

log "Semua proses selesai. Tidak ada reboot otomatis."
