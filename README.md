# Native Access 2 no Linux (Wine)

Scripts para instalar e usar o **Native Access 2** da Native Instruments no Linux via Wine.
Com ele você baixa o **Kontakt Player** (grátis), o Komplete Start e suas bibliotecas.

Testado no **Ubuntu 26.04** com **WineHQ Stable 11.0**.

> Este projeto não inclui nenhum programa da Native Instruments. O script baixa o
> instalador oficial do site deles, e você precisa da sua própria conta NI (grátis).

## Instalação

```bash
git clone https://github.com/GardPardal/native-access-linux.git
cd native-access-linux
bash instalar.sh
```

Depois abra **Native Access** pelo menu de aplicativos e faça login.

Precisa de **Node.js 22+** (para o `native-access`, que corrige o login).

## Problemas que isto resolve

| Problema | Causa | Solução |
|---|---|---|
| Instalador trava / pasta `Native Access` vazia | Wine do Ubuntu roda em modo *wow64 experimental* e o `VC_redist.x64.exe` falha | Usa o **WineHQ Stable** e instala o Visual C++ pelo `winetricks vcrun2022` |
| Instalador continua falhando mesmo assim | O instalador NSIS do Electron aborta no Wine | Extrai `app-64.7z` direto para `Program Files` |
| App abre mas não baixa nada (`sc stop NTKDaemonService`, `failed to send zmq request`) | Falta o serviço **NTKDaemon** | Instala o `NTKDaemon Setup PC.exe` que vem dentro do app |
| Depois do login no navegador, "o Linux não acha o app" | O protocolo `native-access://` não está registrado | Atalho `.desktop` com `MimeType=x-scheme-handler/native-access` |
| Erro de JavaScript: `login: no PKCE verifier available` | No Wine o Electron não acha a cópia aberta, e o link abre uma **segunda cópia**, que não tem o verificador PKCE | O script `native-access` abre o app com `--inspect` e entrega o link na cópia aberta pelo evento `second-instance` |

## Como funciona a correção do login

O `native-access` é o que o menu e o navegador chamam:

- **Nenhuma cópia aberta:** abre o Native Access no Wine com `--inspect=127.0.0.1:9229`.
- **Já tem uma cópia aberta:** conecta na porta de depuração e executa
  `app.emit('second-instance', …, [exe, 'native-access://authorize?code=…'])`,
  que é o mesmo caminho que o Electron usa no Windows. O login termina na cópia certa.

**Sempre abra o Native Access pelo menu**, senão a porta de controle não fica ativa.

> A porta de depuração só escuta em `127.0.0.1` (não é acessível pela rede), mas
> enquanto o Native Access está aberto qualquer programa do seu usuário pode usá-la.
> Feche o Native Access quando não estiver usando.

## Usando o Kontakt no Carla / Reaper

Depois de instalar o Kontakt pelo Native Access, use o [yabridge](https://github.com/robbert-vdh/yabridge):

```bash
yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST3"
yabridgectl sync
```

## Dicas

- Se o login ficar preso, feche todas as cópias e abra de novo pelo menu:
  `pkill -f 'Native Access.exe'`
- Produtos grátis (Kontakt Player, Komplete Start) precisam ser adicionados à conta no
  site da Native Instruments antes de aparecerem no Native Access.
