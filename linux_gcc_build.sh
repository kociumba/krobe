#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="bin"
FINAL_LIB="krobe.a"
JOBS="$(nproc || echo 1)"
FORCE=false
TARGET="all"

COMPONENTS=(
  "tcp_wrapper|c|c/tcp_udp_wrapper_linux.c|tcp_wrapper.o"
  # …add more as needed…
)

usage() {
  cat <<EOF
Usage: $0 [-j N] [-f] [-t all|c|cpp|lib]
  -j N   parallel jobs (default: auto)
  -f     force clean
  -t T   target: all, c, cpp, lib (default: all)
EOF
  exit
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -j|--jobs) JOBS=$2; shift 2 ;;
    -f|--force) FORCE=true; shift ;;
    -t|--target) TARGET=$2; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option $1"; usage ;;
  esac
done

mkdir -p "$OUTPUT_DIR"

$FORCE && rm -f "$OUTPUT_DIR"/*.o "$OUTPUT_DIR/$FINAL_LIB"

# temp file to capture object paths
TMP_OBJS="$(mktemp)"
trap 'rm -f "$TMP_OBJS"' EXIT

compile() {
  local name=$1 type=$2 src=$3 out=$4
  local obj="$OUTPUT_DIR/$out" cc flags

  [[ ! -f $src ]] && { echo "ERROR: $src not found"; exit 1; }
  case $type in
    c)   cc=gcc ;;
    cpp) cc=g++ ;;
    *)   echo "ERROR: unknown type $type"; exit 1 ;;
  esac
  flags=(-c -O2 -Wall -Wextra)

  echo "[$type] $name → $out"
  "$cc" "${flags[@]}" "$src" -o "$obj"
  echo "$obj" >> "$TMP_OBJS"
}

# launch compiles
for comp in "${COMPONENTS[@]}"; do
  IFS="|" read -r name type src out <<<"$comp"
  case $TARGET in
    all) compile "$name" "$type" "$src" "$out" & ;;
    c)   [[ $type == c   ]] && compile "$name" "$type" "$src" "$out" & ;;
    cpp) [[ $type == cpp ]] && compile "$name" "$type" "$src" "$out" & ;;
    lib) ;;  # no compile
    *) echo "ERROR: invalid target '$TARGET'"; exit 1 ;;
  esac
done

# wait for all background jobs
wait

# read back the list of successfully compiled objects
mapfile -t COMPILED < "$TMP_OBJS"

if [[ $TARGET == all || $TARGET == lib ]]; then
  if (( ${#COMPILED[@]} == 0 )); then
    echo "Nothing to archive!"
    exit 1
  fi
  echo "Creating $FINAL_LIB from ${#COMPILED[@]} objects…"
  ar rcs "$OUTPUT_DIR/$FINAL_LIB" "${COMPILED[@]}"
fi

echo "Build ($TARGET) complete!"
