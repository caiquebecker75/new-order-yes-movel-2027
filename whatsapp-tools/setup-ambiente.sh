#!/usr/bin/env bash
# Script de setup do ambiente em nuvem do Claude Code.
# Cole este conteudo em: menu do ambiente (barra de titulo da sessao) > Edit > Setup script.
# Ele roda no inicio de cada nova sessao e instala as ferramentas de WhatsApp em
# /opt/whatsapp-tools, sem depender de nenhum repositorio.
#
# Comandos disponiveis nas sessoes:
#   whatsapp-verificar   confere se tudo carrega
#   wtsexporter          exporta conversas de backups (Android/iOS, crypt12/14/15)
#   whatsapp-analisar    gera graficos de uma conversa exportada em portugues
#   whatsapp-chat-analyze
# Bibliotecas Node: require('whatsapp-web.js'), require('baileys'), ... de qualquer pasta
# (NODE_PATH ja configurado). Go: go get go.mau.fi/whatsmeow (ja no cache).
set -euo pipefail
# Caminhos padrao da imagem do ambiente, caso o PATH do setup venha reduzido
export PATH="$PATH:/opt/node22/bin:/usr/local/go/bin:$HOME/.local/bin"

D=/opt/whatsapp-tools
mkdir -p "$D/node" "$D/go" "$D/python"

# zstd e usado pelo open-wa
command -v zstd >/dev/null || { apt-get update -qq && apt-get install -y -qq zstd; }

echo "== Bibliotecas Node"
cd "$D/node"
[ -f package.json ] || echo '{ "name": "whatsapp-tools-node", "private": true }' > package.json
PUPPETEER_SKIP_DOWNLOAD=true PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
  npm install --no-audit --no-fund --save-exact --loglevel=error \
  whatsapp-web.js@1.34.7 baileys@7.0.0-rc14 @wppconnect-team/wppconnect@2.3.6 \
  @open-wa/wa-automate@5.9.7 venom-bot@5.3.0
cat > check.js <<'JSEOF'
// Confere se cada biblioteca carrega e se o Chromium usado pelas libs
// baseadas em navegador abre corretamente. Nao conecta em nenhum numero.
const fs = require('fs');

const libs = [
  'whatsapp-web.js',
  'baileys',
  '@wppconnect-team/wppconnect',
  '@open-wa/wa-automate',
  'venom-bot',
];

const path = require('path');

const version = (name) =>
  JSON.parse(fs.readFileSync(path.join(__dirname, 'node_modules', name, 'package.json'))).version;

(async () => {
  let ok = true;
  for (const name of libs) {
    try {
      await import(name);
      console.log(`OK    ${name}@${version(name)}`);
    } catch (err) {
      ok = false;
      console.log(`FALHA ${name}: ${err.message.split('\n')[0]}`);
    }
  }

  const executablePath = process.env.PUPPETEER_EXECUTABLE_PATH || '/opt/pw-browsers/chromium';
  try {
    const puppeteer = require('puppeteer');
    const browser = await puppeteer.launch({ executablePath, headless: true, args: ['--no-sandbox'] });
    console.log(`OK    Chromium ${await browser.version()} (${executablePath})`);
    await browser.close();
  } catch (err) {
    ok = false;
    console.log(`FALHA Chromium em ${executablePath}: ${err.message.split('\n')[0]}`);
  }
  process.exit(ok ? 0 : 1);
})();
JSEOF

echo "== Biblioteca Go"
cd "$D/go"
[ -f go.mod ] || go mod init whatsapp-tools/go
cat > main.go <<'GOEOF'
// Confere se o whatsmeow compila e mostra a versao do protocolo usada.
// Nao conecta em nenhum numero.
package main

import (
	"fmt"

	"go.mau.fi/whatsmeow/store"
)

func main() {
	fmt.Printf("OK    go.mau.fi/whatsmeow (versao do WhatsApp Web: %s)\n", store.GetWAVersion())
}
GOEOF
go get go.mau.fi/whatsmeow@v0.0.0-20261017175727-b2b1e71d45e2
go mod tidy
go build -o /dev/null .

echo "== Ferramentas Python"
cd "$D/python"
uv venv -q --allow-existing .venv
uv pip install -q --python .venv/bin/python \
  "whatsapp-chat-exporter[all]==0.13.1" "whatsapp-chat-analyze==0.1.7"
cat > converter_br.py <<'PYEOF'
"""Converte uma conversa exportada do WhatsApp em portugues (Android ou iPhone)
para o formato que o whatsapp-chat-analyze entende.

O whatsapp-chat-analyze so reconhece o formato americano do iPhone
("[10/25/26, 2:30:00 PM] Nome: msg") e nomes sem acento. Este script:
  - le os formatos brasileiros "25/10/2026 14:30 - Nome: msg" (Android)
    e "[25/10/2026, 14:30:12] Nome: msg" (iPhone), com ano de 2 ou 4 digitos;
  - junta mensagens de varias linhas;
  - tira acentos dos nomes e troca numeros de telefone por "Contato A", "Contato B"...;
  - ignora mensagens do sistema (sem autor).

Uso: python converter_br.py conversa.txt saida.txt
"""

import re
import string
import sys
import unicodedata
from datetime import datetime

ANDROID = re.compile(r"^(\d{1,2}/\d{1,2}/\d{2,4}),? (\d{1,2}:\d{2}(?::\d{2})?) - (.*)$")
IOS = re.compile(r"^\[(\d{1,2}/\d{1,2}/\d{2,4}),? (\d{1,2}:\d{2}(?::\d{2})?)\] (.*)$")
INVISIBLE = dict.fromkeys(map(ord, "‎‏‪‬﻿"))


def parse_datetime(date, time):
    day, month, year = date.split("/")
    if len(year) == 2:
        year = "20" + year
    if time.count(":") == 1:
        time += ":00"
    return datetime.strptime(f"{day}/{month}/{year} {time}", "%d/%m/%Y %H:%M:%S")


def ascii_name(name, aliases):
    plain = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    plain = re.sub(r"[^a-zA-Z ]", "", plain)
    plain = re.sub(r" +", " ", plain).strip()
    if plain:
        return plain
    # Nomes sem letras (ex.: numero de telefone) viram "Contato A", "Contato B"...
    if name not in aliases:
        index = len(aliases)
        letters = ""
        while True:
            letters = string.ascii_uppercase[index % 26] + letters
            index = index // 26 - 1
            if index < 0:
                break
        aliases[name] = f"Contato {letters}"
    return aliases[name]


def convert(lines):
    messages = []
    aliases = {}
    for raw in lines:
        line = raw.translate(INVISIBLE).rstrip("\n")
        match = ANDROID.match(line) or IOS.match(line)
        if not match:
            # Continuacao de uma mensagem com varias linhas
            if messages and messages[-1] is not None and line.strip():
                messages[-1][2] += " " + line.strip()
            continue
        date, time, rest = match.groups()
        author, sep, text = rest.partition(": ")
        if not sep:
            messages.append(None)  # mensagem do sistema: descarta inclusive as continuacoes
            continue
        messages.append([parse_datetime(date, time), ascii_name(author, aliases), text.strip()])

    for message in messages:
        if message is None:
            continue
        when, author, text = message
        hour = when.hour % 12 or 12
        yield f"[{when.month}/{when.day}/{when:%y}, {hour}:{when:%M:%S} {when:%p}] {author}: {text}\n"


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__.strip().splitlines()[-1])
    source, target = sys.argv[1:]
    with open(source, encoding="utf-8") as f:
        converted = list(convert(f))
    with open(target, "w", encoding="utf-8") as f:
        f.writelines(converted)
    print(f"{len(converted)} mensagens convertidas para {target}")


if __name__ == "__main__":
    main()
PYEOF
cat > analisar.sh <<'SHEOF'
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
SHEOF
chmod +x analisar.sh

echo "== Comandos e variaveis para todas as sessoes"
ln -sf "$D/python/.venv/bin/wtsexporter" /usr/local/bin/wtsexporter
ln -sf "$D/python/.venv/bin/whatsapp-chat-analyze" /usr/local/bin/whatsapp-chat-analyze
ln -sf "$D/python/analisar.sh" /usr/local/bin/whatsapp-analisar
cat > /usr/local/bin/whatsapp-verificar <<'SHEOF'
#!/usr/bin/env bash
(cd /opt/whatsapp-tools/node && node check.js 2>&1 | grep -v -e ExperimentalWarning -e trace-warnings)
(cd /opt/whatsapp-tools/go && "$(command -v go || echo /usr/local/go/bin/go)" run .)
wtsexporter --help >/dev/null && echo "OK    whatsapp-chat-exporter (wtsexporter)"
whatsapp-chat-analyze --version
SHEOF
chmod +x /usr/local/bin/whatsapp-verificar
cat > /etc/profile.d/whatsapp-tools.sh <<'SHEOF'
export NODE_PATH="/opt/whatsapp-tools/node/node_modules${NODE_PATH:+:$NODE_PATH}"
export PUPPETEER_EXECUTABLE_PATH=/opt/pw-browsers/chromium
export PUPPETEER_SKIP_DOWNLOAD=true
SHEOF

echo "Ferramentas de WhatsApp instaladas em $D (rode: whatsapp-verificar)"
