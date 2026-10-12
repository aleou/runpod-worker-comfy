#!/usr/bin/env bash
# usage: fetch_model.sh <url> <dossier_dest> <nom> <taille_octets> [sha256]
# Fait échouer le build si la taille ou le hash ne correspond pas.
set -euo pipefail
URL="$1"; DEST="/comfyui/models/$2"; NAME="$3"; SIZE="$4"; SHA="${5:-}"
mkdir -p "$DEST"
# Token HF facultatif (rate-limit) : variable HF_TOKEN ou secret BuildKit "hf_token"
if [ -z "${HF_TOKEN:-}" ] && [ -s /run/secrets/hf_token ]; then HF_TOKEN="$(cat /run/secrets/hf_token)"; fi
HDR=(); [ -n "${HF_TOKEN:-}" ] && HDR=(--header="Authorization: Bearer ${HF_TOKEN}")
aria2c -x16 -s16 -k1M --max-tries=10 --retry-wait=15 --console-log-level=warn \
  --summary-interval=60 --file-allocation=none \
  "${HDR[@]}" -d "$DEST" -o "$NAME" "$URL"
GOT=$(stat -c %s "$DEST/$NAME")
[ "$GOT" = "$SIZE" ] || { echo "Taille KO $NAME: $GOT != $SIZE"; exit 1; }
[ -z "$SHA" ] || echo "$SHA  $DEST/$NAME" | sha256sum -c -
echo "OK $NAME ($GOT octets)"
