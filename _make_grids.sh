#!/usr/bin/env bash
# Build 4x5 grid mp4 per (task, method), reading from per-rollout HD mp4s.
# 20 clips per cell. Missing clips replaced with a black tile of same size.
set -e
cd "$(dirname "$0")"

SRC=static/videos/rollouts_hd
DST=static/videos/grid
mkdir -p "$DST"

W=256     # per-tile width
H=192     # per-tile height
ROWS=4
COLS=5

# Create one black placeholder for missing clips
BLACK="$DST/_black.mp4"
if [ ! -f "$BLACK" ]; then
  ffmpeg -y -loglevel error -f lavfi -i "color=c=black:s=${W}x${H}:r=30:d=30" \
    -an -vcodec libx264 -crf 30 -preset veryfast -pix_fmt yuv420p \
    -movflags +faststart "$BLACK"
fi

for task in spill book; do
  for method in sync async rtc ours; do
    out="$DST/${task}_${method}_grid.mp4"

    # Collect 20 input clips (substitute black for missing)
    inputs=()
    filters=()
    for r in $(seq 1 20); do
      idx=$((r - 1))
      f="$SRC/${task}_${method}_${r}.mp4"
      if [ -f "$f" ]; then
        inputs+=("-i" "$f")
      else
        inputs+=("-i" "$BLACK")
      fi
      # scale each to fixed size, reset PTS
      filters+=("[$idx:v]scale=${W}:${H},setpts=PTS-STARTPTS[v${idx}];")
    done

    # hstack 4 rows of 5, vstack rows
    fstr="${filters[*]}"
    fstr+="[v0][v1][v2][v3][v4]hstack=inputs=5[r0];"
    fstr+="[v5][v6][v7][v8][v9]hstack=inputs=5[r1];"
    fstr+="[v10][v11][v12][v13][v14]hstack=inputs=5[r2];"
    fstr+="[v15][v16][v17][v18][v19]hstack=inputs=5[r3];"
    fstr+="[r0][r1][r2][r3]vstack=inputs=4[out]"

    ffmpeg -y -loglevel error "${inputs[@]}" \
      -filter_complex "$fstr" -map "[out]" \
      -an -vcodec libx264 -crf 27 -preset veryfast -pix_fmt yuv420p \
      -g 30 -keyint_min 30 -sc_threshold 0 -movflags +faststart "$out"

    echo "  $(basename $out): $(du -h $out | cut -f1)"
  done
done

rm -f "$BLACK"
echo ""
echo "TOTAL grid: $(du -sh $DST | cut -f1)"
