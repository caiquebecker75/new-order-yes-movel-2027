# Ferramentas de WhatsApp

Bibliotecas e ferramentas de código aberto para WhatsApp, instaladas a partir
dos registros oficiais (npm, Go proxy e PyPI), com versões fixadas.

```bash
./whatsapp-tools/setup.sh   # instala tudo e roda a verificação
```

> ⚠️ As bibliotecas da pasta `node/` e `go/` **não são oficiais**: elas imitam o
> WhatsApp Web. Usá-las viola os termos do WhatsApp e pode levar ao **banimento
> do número**. Teste com um número descartável; para uso com clientes, prefira a
> Cloud API oficial da Meta.

## Bibliotecas que conectam como o WhatsApp Web

| Pasta | Pacote | Versão | Como conecta |
|---|---|---|---|
| `node/` | [`whatsapp-web.js`](https://github.com/wwebjs/whatsapp-web.js) | 1.34.7 | Navegador (Puppeteer) |
| `node/` | [`baileys`](https://github.com/WhiskeySockets/Baileys) | 7.0.0-rc14 | WebSocket direto, sem navegador |
| `node/` | [`@wppconnect-team/wppconnect`](https://github.com/wppconnect-team/wppconnect) | 2.3.6 | Navegador (Puppeteer) |
| `node/` | [`@open-wa/wa-automate`](https://github.com/open-wa/wa-automate-nodejs) | 5.9.7 | Navegador (Puppeteer) |
| `node/` | [`venom-bot`](https://github.com/orkestral/venom) | 5.3.0 | Navegador (Puppeteer), sem atualização desde 2024 |
| `go/` | [`go.mau.fi/whatsmeow`](https://github.com/tulir/whatsmeow) | commit de 17/10/2026 | WebSocket direto, sem navegador |

As bibliotecas baseadas em navegador usam o Chromium já instalado na máquina
(`/opt/pw-browsers/chromium` no ambiente do agente). Passe o caminho ao criar o
cliente, por exemplo no whatsapp-web.js:

```js
const { Client, LocalAuth } = require('whatsapp-web.js');
const client = new Client({
  authStrategy: new LocalAuth(),
  puppeteer: { executablePath: '/opt/pw-browsers/chromium', args: ['--no-sandbox'] },
});
client.on('qr', (qr) => console.log('Escaneie o QR code:', qr));
client.on('ready', () => console.log('Conectado'));
client.initialize();
```

Para conectar de fato, a máquina precisa acessar `web.whatsapp.com` (e, nas
libs por WebSocket, `*.whatsapp.net`). No ambiente em nuvem do agente esses
domínios precisam ser liberados em *Network access* nas configurações do ambiente.

Pastas de sessão (`.wwebjs_auth/`, `auth_info*/`, `tokens/`) guardam o login do
número e estão no `.gitignore`: nunca as envie ao Git.

O `npm audit` aponta vulnerabilidades em dependências indiretas (ex.: `tar`,
usado no download do navegador). As "correções" sugeridas são versões antigas
das bibliotecas, então elas foram mantidas na versão atual.

## Exportar conversas de backups

[`whatsapp-chat-exporter`](https://github.com/KnugiHK/Whatsapp-Chat-Exporter)
lê o banco de dados do WhatsApp (Android ou iPhone), inclusive backups
criptografados `.crypt12`, `.crypt14` e `.crypt15`, e gera HTML/JSON.

```bash
cd whatsapp-tools/python
# Android, backup criptografado (precisa do arquivo "key" ou da chave de 64 dígitos)
.venv/bin/wtsexporter -a -k key -b msgstore.db.crypt15 -o saida
# iPhone, a partir de um backup do iTunes/Finder
.venv/bin/wtsexporter -i -b "/caminho/do/backup" -o saida
# Conversa exportada pelo app (.txt), formato "25/10/2026, 14:30 - Nome: msg"
.venv/bin/wtsexporter -e conversa/_chat.txt --assume-first-as-me -o saida
```

No modo `-e`, deixe o `.txt` numa pasta só dele (como vem no `.zip` exportado):
o exportador copia todos os arquivos dessa pasta para a saída como mídia. Esse
modo só aceita a data com vírgula (`25/10/2026, 14:30`).

## Gráficos de conversas exportadas

[`whatsapp-chat-analyze`](https://github.com/tddschn/whatsapp-chat-analyze)
gera gráficos (PNG e HTML interativo) de mensagens por pessoa e por dia.

Ele só entende o formato americano do iPhone e nomes sem acento, então use o
`analisar.sh`, que antes converte a conversa em português
(`converter_br.py`, formatos Android e iPhone):

```bash
cd whatsapp-tools/python
./analisar.sh "Conversa do WhatsApp com Stand 2027.txt" "Stand 2027" graficos
```

Na conversão, os acentos dos nomes são removidos e os números de telefone
viram "Contato A", "Contato B"...
