#!/usr/bin/env bash
# Gera os graficos de uma conversa exportada do WhatsApp em portugues.
# Uso: ./analisar.sh conversa.txt "Nome do grupo" [pasta-de-saida]
set -euo pipefail

if [ $# -lt 2 ]; then
  echo 'Uso: ./analisar.sh conversa.txt "Nome do grupo" [pasta-de-saida]' >&2
  exit 1
fi

here="$(dirname "$(readlink -f "$0")")"
source_file="$(realpath "$1")"
chat_name="$2"
out_dir="$(realpath -m "${3:-graficos}")"

mkdir -p "$out_dir"
"$here/.venv/bin/python" "$here/converter_br.py" "$source_file" "$out_dir/conversa-convertida.txt"
cd "$out_dir"
"$here/.venv/bin/whatsapp-chat-analyze" -n "$chat_name" -o whatsapp conversa-convertida.txt
echo "Graficos salvos em $out_dir"
