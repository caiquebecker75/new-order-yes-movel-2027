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
