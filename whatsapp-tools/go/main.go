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
