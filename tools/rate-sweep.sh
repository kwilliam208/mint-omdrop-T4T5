#!/bin/bash
# Send the same photo at several OWL data rates and judge each run.
#   tools/rate-sweep.sh --to DEVICE PHOTO [--rates "12 24 mcs7"] [--runs N]
# DEVICE from `omdrop peers -n`; set the iPhone to Everyone for 10 Minutes and
# tap Accept each time. Each run's copy is stamped "<rate> · run <n>". Checks:
# ACCEPT (/Ask 200), UPLOAD (/Upload 200), BYTES (awdl0 sent the archive),
# EXIT (0); LOSSY when TCP resent over half the file. Results, logs and a
# checklist for the phone go to rate-sweep-<time>/. Uses the real radio (Wi-Fi
# is off meanwhile on Intel) and restores /etc/omdrop/tx-rate when done.
set -euo pipefail

rates="12 24 54 mcs3 mcs5 mcs7"
runs=2
to='' photo=''

# The verdict on one run: "PASS" or "FAIL: <checks that failed>".
verdict() {  # LOG EXIT SENT_BYTES
  local log=$1 rc=$2 sent=$3 fails=() archive
  grep -q '/Ask answered 200' "$log" || fails+=(ACCEPT)
  grep -q '/Upload answered 200' "$log" || fails+=(UPLOAD)
  archive=$(sed -n 's/.* UPLOAD \([0-9]*\) B dvzip.*/\1/p' "$log" | tail -1)
  if [ -z "$archive" ] || [ "${sent:-0}" -lt "$archive" ]; then fails+=(BYTES); fi
  [ "$rc" = 0 ] || fails+=(EXIT)
  if [ ${#fails[@]} -eq 0 ]; then echo PASS; else echo "FAIL: ${fails[*]}"; fi
}

# Why a failed run failed, in a few words, from its log.
why() {  # LOG
  local line
  line=$(grep -v -E 'DEBUG|INFO' "$1" | grep -v '^\s*$' | tail -1)
  [ -n "$line" ] || line=$(grep -E 'answered [0-9]+' "$1" | grep -v 'answered 200' | tail -1)
  echo "${line:0:100}"
}

# The seconds between 5% and 95% of SIZE bytes leaving awdl0.
bulk_seconds() {  # SAMPLES SIZE
  awk -v size="$2" 'NR == 1 { base = $2 } {
      sent = $2 - base
      if (!t5 && sent >= size * 0.05) t5 = $1
      if (!t95 && sent >= size * 0.95) { t95 = $1; exit }
    } END { if (t5 && t95 && t95 > t5) printf "%.2f", t95 - t5 }' "$1"
}

# awdl0's bytes sent over the whole run: last sample less the first.
sent_bytes() {  # SAMPLES
  awk 'NR == 1 { base = $2 } { last = $2 } END { print (NR ? last - base : 0) }' "$1"
}

# A copy of PHOTO with LABEL stamped across its top, as a JPEG.
stamp() {  # PHOTO LABEL OUT
  python3 -I - "$@" <<'EOF'
import sys
from PIL import Image, ImageDraw, ImageFont, ImageOps
src, label, out = sys.argv[1:4]
im = ImageOps.exif_transpose(Image.open(src)).convert("RGB")
size = max(24, im.width // 14)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size)
except OSError:
    font = ImageFont.load_default()
draw = ImageDraw.Draw(im)
pad = size // 3
box = draw.textbbox((pad, pad), label, font=font)
draw.rectangle((0, 0, box[2] + pad, box[3] + pad), fill=(0, 0, 0))
draw.text((pad, pad), label, font=font, fill=(255, 255, 255))
im.save(out, "JPEG", quality=97, subsampling=0)   # near the original's size
EOF
}

# The table, the fastest rate and the phone's checklist, from results.csv.
summarize() {  # CSV
  python3 -I - "$1" <<'EOF'
import csv, sys
rows = list(csv.DictReader(open(sys.argv[1])))
head = ("RUN", "VERDICT", "", "TIME", "KB/s", "RESENT")
table = [(f'{r["rate"]} · run {r["run"]}', r["verdict"], r["lossy"], f'{r["wall_s"]}s' if r["wall_s"] else "",
          r["bulk_KBps"], r["retrans"]) for r in rows]
widths = [max(len(str(x)) for x in col) for col in zip(head, *table)]
for line in [head] + table:
    print("  ".join(str(x).ljust(w) for x, w in zip(line, widths)).rstrip())
passed = [r for r in rows if r["verdict"] == "PASS"]
print()
print(f"{len(passed)} of {len(rows)} passed the sender's checks (ACCEPT, UPLOAD, BYTES, EXIT).")
by_rate = {}
for r in passed:
    if r["bulk_KBps"]:
        by_rate.setdefault(r["rate"], []).append(int(r["bulk_KBps"]))
if by_rate:
    best = max(by_rate, key=lambda k: sorted(by_rate[k])[len(by_rate[k]) // 2])
    print("Median KB/s of passing runs: " + ", ".join(
        f"{k} {sorted(v)[len(v) // 2]}" for k, v in by_rate.items()) + f". Fastest: {best}.")
print()
print("On the iPhone, open Photos > Recents and tick off each stamped photo:")
for r in passed:
    print(f'  [ ] {r["rate"]} · run {r["run"]}')
print("A PASS here with no photo on the phone failed silently on the phone's side;")
print("its .log in this folder is what the sender saw.")
EOF
}

[ "${1-}" = --self-test ] && { shift; "$@"; exit $?; }   # for tests: run one function

while [ $# -gt 0 ]; do
  case "$1" in
    --to) to=${2:?--to needs a device}; shift 2 ;;
    --rates) rates=${2:?--rates needs a list}; shift 2 ;;
    --runs) runs=${2:?--runs needs a number}; shift 2 ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unknown option $1 (see --help)" >&2; exit 64 ;;
    *) photo=$1; shift ;;
  esac
done
usage='usage: tools/rate-sweep.sh --to DEVICE PHOTO [--rates "12 24 mcs7"] [--runs N]'
[ -n "$to" ] || { echo "$usage" >&2; echo "--to: the device's name or address, from: omdrop peers -n" >&2; exit 64; }
[ -f "$photo" ] || { echo "$usage" >&2; echo "no such file: ${photo:-(none given)}" >&2; exit 64; }
[[ "$runs" =~ ^[1-9][0-9]*$ ]] || { echo "--runs: a whole number" >&2; exit 64; }
command -v omdrop >/dev/null || { echo "omdrop isn't on PATH; run: omdrop-installer install" >&2; exit 1; }
grep -q '^tx_rate()' /usr/lib/omdrop/omdrop-discoverable 2>/dev/null \
  || { echo "The installed omdrop-owl has no tx-rate setting; reinstall: omdrop-installer install." >&2; exit 1; }

KNOB=/etc/omdrop/tx-rate
OWL_LOG=/run/omdrop-owl/owl.log
STATS=/sys/class/net/awdl0/statistics
dir="rate-sweep-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$dir"
csv=$dir/results.csv
summary=$dir/summary.txt

sudo -v   # once, for writing $KNOB
saved=''
[ -f "$KNOB" ] && saved=$(cat "$KNOB")
restore() {
  omdrop off --force >/dev/null 2>&1 || true
  if [ -n "$saved" ]; then echo "$saved" | sudo tee "$KNOB" >/dev/null; else sudo rm -f "$KNOB"; fi
}
trap restore EXIT

# Written even for 12: without it the helper sends at its default, MCS 3.
set_rate() {
  sudo mkdir -p /etc/omdrop && echo "$1" | sudo tee "$KNOB" >/dev/null
}

wait_visible() {
  for _ in $(seq 90); do
    omdrop status --json 2>/dev/null | grep -q '"visible": *true' && return 0
    sleep 1
  done
  return 1
}

retrans() { nstat -asz TcpRetransSegs 2>/dev/null | awk '/TcpRetransSegs/ {print $2}'; }

sample() {  # awdl0's transmit count every 0.2 s, until killed
  while :; do
    printf '%s %s\n' "$(date +%s.%N)" "$(cat "$STATS/tx_bytes" 2>/dev/null || echo 0)"
    sleep 0.2
  done
}

echo "rate,run,verdict,lossy,wall_s,bulk_s,bulk_KBps,retrans,archive_B,sent_B,owl_rate,photo" > "$csv"
total=$(( $(wc -w <<< "$rates") * runs ))
echo "Sending stamped copies of $(basename "$photo") to $to: $rates, $runs run(s) each ($total sends)."
echo "Results: $dir/. Keep the iPhone on Everyone for 10 Minutes; renew it if a run fails."
n=0
for rate in $rates; do
  for run in $(seq "$runs"); do
    n=$((n + 1))
    label="$rate · run $run"
    tag="${rate}-r${run}"
    copy="$dir/sweep-$tag.jpg"
    stamp "$photo" "$label" "$copy"
    size=$(stat -c %s "$copy")
    while :; do
      echo
      echo "== [$n/$total] $label: restarting OmDrop"
      set_rate "$rate"
      omdrop off --force >/dev/null 2>&1 || true
      omdrop on 10m >/dev/null
      if ! wait_visible; then
        echo "   OmDrop didn't come up."
        echo "$rate,$run,FAIL: RADIO,,,,,,,,,$copy" >> "$csv"
        break
      fi
      owl_rate=$(sed -n 's/.* data frame TX rate: //p' "$OWL_LOG" 2>/dev/null | tail -1)
      echo "   OWL: ${owl_rate:-unknown}. Sending sweep-$tag.jpg: tap Accept on $to."
      r0=$(retrans)
      sample > "$dir/$tag.samples" &
      sampler=$!
      start=$(date +%s.%N)
      rc=0
      omdrop send -v --to "$to" "$copy" > "$dir/$tag.log" 2>&1 || rc=$?
      end=$(date +%s.%N)
      kill "$sampler" 2>/dev/null; wait "$sampler" 2>/dev/null || true
      r1=$(retrans)
      resent=$(( ${r1:-0} - ${r0:-0} ))
      wall=$(awk -v a="$start" -v b="$end" 'BEGIN { printf "%.1f", b - a }')
      bulk=$(bulk_seconds "$dir/$tag.samples" "$size")
      kbps=''
      [ -n "$bulk" ] && kbps=$(awk -v s="$size" -v t="$bulk" 'BEGIN { printf "%.0f", s * 0.9 / t / 1000 }')
      sent=$(sent_bytes "$dir/$tag.samples")
      archive=$(sed -n 's/.* UPLOAD \([0-9]*\) B dvzip.*/\1/p' "$dir/$tag.log" | tail -1)
      result=$(verdict "$dir/$tag.log" "$rc" "$sent")
      lossy=''
      [ $(( resent * 1400 )) -gt $(( size / 2 )) ] && lossy=LOSSY
      echo "   $result ${lossy} · ${wall}s in all · ${kbps:-?} KB/s · $resent retransmits"
      [ "$result" = PASS ] || echo "   $(why "$dir/$tag.log")"
      if [ "$result" != PASS ] && [ -r /dev/tty ]; then
        read -r -p "   Retry this run (renew the phone's Everyone for 10 Minutes first)? [y/N] " again < /dev/tty || again=n
        if [ "${again,,}" = y ]; then continue; fi
      fi
      echo "$rate,$run,$result,$lossy,$wall,$bulk,$kbps,$resent,$archive,$sent,\"$owl_rate\",$copy" >> "$csv"
      break
    done
    sleep 3
  done
done

{
  echo "Rate sweep, $(date '+%Y-%m-%d %H:%M'), to $to, $(basename "$photo") stamped per run"
  echo
  summarize "$csv"
} | tee "$summary"
echo
echo "Saved in $dir/. OmDrop is off and $KNOB is back as it was."
