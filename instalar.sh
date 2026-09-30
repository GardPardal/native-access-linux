#!/usr/bin/env bash
# =============================================================================
#  instalar.sh — Native Access 2 (Native Instruments) no Linux via Wine
#
#  Testado no Ubuntu 26.04 com WineHQ Stable 11.0.
#  Uso (sem sudo; ele pede a senha quando precisa):  bash instalar.sh
#
#  O que faz:
#   1. Instala o WineHQ Stable (o Wine do Ubuntu, em modo "wow64 experimental",
#      trava no instalador do Visual C++), winetricks e 7zip
#   2. Cria o prefixo Wine com Visual C++ 2015-2022, Windows 10 e fontes
#   3. Baixa o Native Access e extrai o app direto (o instalador NSIS falha no Wine)
#   4. Instala o NTKDaemon (serviço que faz downloads e instalações)
#   5. Instala o "entregador" do login (native-access://) e o atalho no menu
# =============================================================================
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine}" WINEDEBUG=-all WINEARCH=win64
NA_URL="https://assets.native-instruments.com/downloads/Native-Access_2.exe"
NA_DIR="$WINEPREFIX/drive_c/Program Files/Native Instruments/Native Access"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

passo() { echo; echo "==> $*"; }

# --- Node 22+ é necessário para o entregador do login --------------------------
NODE="$(command -v node || true)"
if [ -z "$NODE" ] || [ "$("$NODE" -p 'process.versions.node.split(".")[0]')" -lt 22 ]; then
  echo "Precisa do Node.js 22 ou mais novo (ex.: 'nvm install --lts' ou 'sudo apt install nodejs')."
  exit 1
fi

# --- 1. WineHQ -----------------------------------------------------------------
if ! wine --version 2>/dev/null | grep -qE '^wine-(1[1-9]|[2-9][0-9])'; then
  passo "Instalando WineHQ Stable"
  . /etc/os-release
  sudo dpkg --add-architecture i386
  sudo mkdir -p /etc/apt/keyrings
  # A chave precisa estar em formato binário (dearmor); em texto o apt ignora
  wget -qO- https://dl.winehq.org/wine-builds/winehq.key | sudo gpg --dearmor --yes -o /etc/apt/keyrings/winehq-archive.key
  sudo wget -qNP /etc/apt/sources.list.d/ \
    "https://dl.winehq.org/wine-builds/ubuntu/dists/${VERSION_CODENAME}/winehq-${VERSION_CODENAME}.sources"
  sudo apt-get update -qq
  # Remove o Wine do Ubuntu, se houver, para não conflitar
  sudo apt-get remove -y -qq wine wine64 wine32:i386 libwine libwine:i386 2>/dev/null || true
  sudo apt-get install -y -qq --install-recommends winehq-stable
fi
sudo apt-get install -y -qq winetricks 7zip curl
wine --version

# --- 2. Prefixo Wine -------------------------------------------------------------
passo "Preparando o prefixo Wine em $WINEPREFIX"
wineboot -i >/dev/null 2>&1; wineserver -w
winetricks -q --unattended vcrun2022 win10 corefonts

# --- 3. Native Access ------------------------------------------------------------
passo "Baixando e extraindo o Native Access"
curl -fSL -o "$TMP/NativeAccess.exe" "$NA_URL"
7z x -y -o"$TMP/na" "$TMP/NativeAccess.exe" >/dev/null
mkdir -p "$NA_DIR"
7z x -y -o"$NA_DIR" "$TMP/na/\$PLUGINSDIR/app-64.7z" >/dev/null
[ -d "$TMP/na/\$0/ProgramData" ] && cp -r "$TMP/na/\$0/ProgramData/"* "$WINEPREFIX/drive_c/ProgramData/" || true

# --- 4. NTKDaemon ----------------------------------------------------------------
passo "Instalando o NTKDaemon"
DAEMON="$(find "$NA_DIR/resources/daemon/win" -iname 'NTKDaemon*Setup*.exe' | head -n1)"
wine "$DAEMON" /S /quiet /norestart >/dev/null 2>&1 || true   # sai com 100 = "reiniciar"
wineboot -r >/dev/null 2>&1
wine sc query NTKDaemonService | grep STATE

# --- 5. Entregador do login + atalho ----------------------------------------------
passo "Instalando atalho e tratamento do login (native-access://)"
mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
install -m 755 "$DIR/native-access" "$HOME/.local/bin/native-access"
# Caminho absoluto do node: atalhos do menu não carregam o PATH do nvm
cat > "$HOME/.local/share/applications/native-access.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Native Access
Comment=Instalar Kontakt e bibliotecas (Wine)
Exec=env WINEPREFIX=$WINEPREFIX $NODE $HOME/.local/bin/native-access %u
Icon=system-software-install
Categories=Audio;Music;
MimeType=x-scheme-handler/native-access;
Terminal=false
EOF
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
xdg-mime default native-access.desktop x-scheme-handler/native-access

echo
echo "PRONTO! Abra 'Native Access' pelo menu de aplicativos e faça login."
echo "Sempre abra pelo menu (é ele que liga a correção do login)."
