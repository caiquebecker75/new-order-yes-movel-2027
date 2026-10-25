#!/usr/bin/env bash
# Instala todas as ferramentas de WhatsApp desta pasta.
# Uso: ./whatsapp-tools/setup.sh
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

echo "== Dependencias do sistema (zstd, usado pelo open-wa)"
if ! command -v zstd >/dev/null; then
  if command -v apt-get >/dev/null; then
    apt-get install -y zstd || { apt-get update && apt-get install -y zstd; }
  else
    echo "Instale o zstd manualmente (ex.: brew install zstd)" >&2
  fi
fi

echo "== Bibliotecas Node (whatsapp-web.js, Baileys, WPPConnect, open-wa, Venom)"
# As libs baseadas em navegador usam o Chromium ja instalado na maquina,
# entao o download do Chrome pelo Puppeteer e pulado.
(cd "$here/node" && PUPPETEER_SKIP_DOWNLOAD=true PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true npm ci)

echo "== Biblioteca Go (whatsmeow)"
(cd "$here/go" && go mod download && go build -o /dev/null .)

echo "== Ferramentas Python (exportador de backups e graficos)"
(cd "$here/python" && uv venv -q --allow-existing .venv && uv pip install -q --python .venv/bin/python -r requirements.txt)

echo "== Verificacao"
(cd "$here/node" && node check.js 2>&1 | grep -v -e ExperimentalWarning -e trace-warnings)
(cd "$here/go" && go run .)
"$here/python/.venv/bin/wtsexporter" --help >/dev/null && echo "OK    whatsapp-chat-exporter (wtsexporter)"
"$here/python/.venv/bin/whatsapp-chat-analyze" --version
