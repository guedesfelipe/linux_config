#!/usr/bin/env bash
# Configura o ambiente de dev. Idempotente: pode rodar quantas vezes quiser.
#
#   ./install.sh               roda todas as etapas
#   ./install.sh tmux nvim     roda só as etapas escolhidas
#   ./install.sh --help        lista as etapas
# shellcheck disable=SC2088  # "~" nas mensagens é só texto
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
export PATH="$LOCAL_BIN:$PATH"           # o que instalamos em ~/.local/bin vem antes do apt

STEPS=(packages dotfiles terminal mise pipx atuin tmux nvim zen docker)

PIPX_PACKAGES=(pls-cli)                  # ferramentas Python instaladas via pipx
PTYXIS_FONT='FiraCode Nerd Font 11'
PTYXIS_PALETTE='Catppuccin Macchiato'    # paletas embutidas no Ptyxis (combina com o tmux)
BASH_PREEXEC_VERSION=0.6.0

# -- helpers ------------------------------------------------------------------

info() { printf '\n\033[1;35m[*]\033[0m \033[1m%s\033[0m\n' "$*"; }
ok()   { printf '\033[0;32m[✓]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[-]\033[0m %s\n' "$*"; }
has()  { command -v "$1" >/dev/null 2>&1; }

# link <origem> <destino>: cria symlink; se já existir algo diferente, faz backup
link() {
  local src="$1" dst="$2"
  [ "$(readlink "$dst" 2>/dev/null)" = "$src" ] && return 0
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "${dst#"$HOME"/}")"
    mv "$dst" "$BACKUP_DIR/${dst#"$HOME"/}"
    warn "backup: ~/${dst#"$HOME"/} -> $BACKUP_DIR"
  fi
  ln -s "$src" "$dst"
  ok "~/${dst#"$HOME"/}"
}

# gh_install <owner/repo> <asset> <destino> <versão atual> [processo]
# Instala o <asset> (.tar.gz/.tar.xz) da última release estável do GitHub em <destino>,
# conferindo o sha256. Não faz nada se <versão atual> já for a última.
# Se [processo] estiver rodando, não atualiza (para não trocar arquivos em uso).
gh_install() {
  local repo="$1" asset="$2" dest="$3" current="${4#v}" busy="${5:-}"
  local release latest url digest tmp
  release="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest")"
  latest="$(jq -r .tag_name <<<"$release")"
  url="$(jq -r --arg a "$asset" '.assets[] | select(.name == $a) | .browser_download_url' <<<"$release")"
  digest="$(jq -r --arg a "$asset" '.assets[] | select(.name == $a) | .digest // empty' <<<"$release")"

  if [ -z "$url" ]; then
    warn "$asset não encontrado na última release de $repo"
    return 1
  elif [ "$current" = "${latest#v}" ]; then
    ok "$repo $latest já é a última versão"
    return 0
  elif [ -n "$busy" ] && pgrep -x "$busy" >/dev/null; then
    warn "$repo $latest disponível, mas $busy está aberto — feche e rode de novo"
    return 0
  fi

  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/$asset"
  if [ -n "$digest" ]; then
    echo "${digest#sha256:}  $tmp/$asset" | sha256sum -c --quiet
  else
    warn "release sem sha256, pulando verificação"
  fi
  mkdir "$tmp/out"
  tar -xf "$tmp/$asset" -C "$tmp/out" --strip-components=1
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  mv "$tmp/out" "$dest"
  rm -rf "$tmp"
  ok "$repo ${current:+$current -> }$latest instalado em ${dest/#"$HOME"/\~}"
}

# -- etapas -------------------------------------------------------------------

step_packages() {
  info "Pacotes apt (packages.txt)"
  local pkgs
  mapfile -t pkgs < <(sed -e 's/#.*//' -e '/^\s*$/d' "$REPO/packages.txt")
  sudo apt-get update -qq
  sudo apt-get install -y "${pkgs[@]}"

  # No Ubuntu o bat e o fd vêm como batcat/fdfind
  mkdir -p "$LOCAL_BIN"
  has batcat && ln -sf "$(command -v batcat)" "$LOCAL_BIN/bat"
  has fdfind && ln -sf "$(command -v fdfind)" "$LOCAL_BIN/fd"
  ok "pacotes instalados"
}

step_dotfiles() {
  info "Dotfiles (home/ -> ~)"
  local f
  while IFS= read -r -d '' f; do
    link "$f" "$HOME/${f#"$REPO/home/"}"
  done < <(find "$REPO/home" -type f -print0)

  # Um único bloco no ~/.bashrc que carrega ~/.bashrc.d/*.sh
  if ! grep -q '>>> linux_config >>>' "$HOME/.bashrc" 2>/dev/null; then
    cat >>"$HOME/.bashrc" <<'EOF'

# >>> linux_config >>>
for f in "$HOME"/.bashrc.d/*.sh; do [ -r "$f" ] && . "$f"; done; unset f
# <<< linux_config <<<
EOF
    ok "bloco adicionado ao ~/.bashrc"
  fi

  [ -e "$HOME/.tmux.conf" ] && warn "~/.tmux.conf existe e tem prioridade sobre ~/.config/tmux/tmux.conf — remova-o"
  return 0
}

step_terminal() {
  info "Terminal: FiraCode Nerd Font + tema"
  if fc-list | grep -qi "FiraCode Nerd"; then
    ok "já instalada"
  else
    local dir="$HOME/.local/share/fonts/FiraCodeNerdFont"
    mkdir -p "$dir"
    curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.tar.xz | tar -xJ -C "$dir"
    fc-cache -f "$dir" >/dev/null
    ok "instalada em $dir"
  fi

  # Ptyxis (terminal padrão do Ubuntu)
  if has gsettings && gsettings list-schemas | grep -qx org.gnome.Ptyxis; then
    gsettings set org.gnome.Ptyxis use-system-font false
    gsettings set org.gnome.Ptyxis font-name "$PTYXIS_FONT"
    local uuid
    uuid="$(gsettings get org.gnome.Ptyxis default-profile-uuid | tr -d "'")"
    gsettings set "org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/$uuid/" palette "$PTYXIS_PALETTE"
    ok "Ptyxis: fonte '$PTYXIS_FONT', tema '$PTYXIS_PALETTE'"
  else
    warn "Ptyxis não encontrado, configure fonte/tema do seu terminal manualmente"
  fi
}

step_pipx() {
  info "pipx: ${PIPX_PACKAGES[*]}"
  local pkg installed
  installed="$(pipx list --short 2>/dev/null || true)"
  for pkg in "${PIPX_PACKAGES[@]}"; do
    if grep -q "^$pkg " <<<"$installed"; then
      ok "$pkg já instalado"
    else
      pipx install "$pkg"
      ok "$pkg instalado"
    fi
  done
}

step_atuin() {
  info "atuin (histórico do shell)"
  # última release estável do GitHub (o apt fica bem atrás); rodar de novo atualiza
  local dir="$HOME/.local/opt/atuin" current
  current="$("$dir/atuin" --version 2>/dev/null | awk '{print $2}')" || true
  gh_install atuinsh/atuin "atuin-$(uname -m)-unknown-linux-gnu.tar.gz" "$dir" "$current"
  ln -sf "$dir/atuin" "$LOCAL_BIN/atuin"

  # no bash, o atuin precisa do bash-preexec para capturar os comandos
  local preexec="$HOME/.bash-preexec.sh"
  if [ ! -f "$preexec" ]; then
    curl -fsSL "https://raw.githubusercontent.com/rcaloras/bash-preexec/$BASH_PREEXEC_VERSION/bash-preexec.sh" -o "$preexec"
    ok "bash-preexec $BASH_PREEXEC_VERSION em $preexec"
  fi
  # importa o ~/.bash_history uma única vez
  local marker="$HOME/.local/share/atuin/.imported-bash"
  if [ ! -f "$marker" ]; then
    atuin import bash
    mkdir -p "$(dirname "$marker")" && touch "$marker"
    ok "histórico do bash importado"
  fi
  ok "atuin pronto (ctrl-r para buscar; 'atuin login' para sincronizar entre máquinas)"
}

step_mise() {
  info "mise + linguagens (home/.config/mise/config.toml)"
  if ! has mise && [ ! -x "$LOCAL_BIN/mise" ]; then
    curl -fsSL https://mise.run | MISE_INSTALL_PATH="$LOCAL_BIN/mise" sh
  fi
  export PATH="$LOCAL_BIN:$HOME/.local/share/mise/shims:$PATH"
  mise install --yes

  # rust-analyzer (LSP do Rust usado pelo Neovim), clippy e rustfmt
  local rustup="$HOME/.cargo/bin/rustup"
  if [ -x "$rustup" ]; then
    "$rustup" component add rust-analyzer clippy rustfmt >/dev/null
    ok "rust: rust-analyzer, clippy, rustfmt"
  fi
  ok "ferramentas instaladas (confira com: mise ls)"

  # Completions geradas uma vez (mais rápido que eval a cada shell)
  local comp="$HOME/.local/share/bash-completion/completions"
  mkdir -p "$comp"
  mise completion bash >"$comp/mise" 2>/dev/null || true
  has uv && uv generate-shell-completion bash >"$comp/uv"
  has poetry && poetry completions bash >"$comp/poetry"
  has poetry && poetry config virtualenvs.in-project true
  return 0
}

step_tmux() {
  info "tmux + plugins (TPM)"
  local plugins="$HOME/.config/tmux/plugins"
  [ -d "$plugins/tpm" ] || git clone -q https://github.com/tmux-plugins/tpm "$plugins/tpm"
  # install_plugins precisa de um servidor tmux rodando
  tmux start-server \; source-file "$HOME/.config/tmux/tmux.conf" 2>/dev/null || true
  "$plugins/tpm/bin/install_plugins" >/dev/null
  ok "plugins instalados em $plugins"
}

step_nvim() {
  info "Neovim + LazyVim (config em home/.config/nvim)"
  # Neovim da última release estável do GitHub (o apt fica atrás e o LazyVim/rustaceanvim pedem 0.12+)
  local dir="$HOME/.local/opt/nvim" current arch
  current="$("$dir/bin/nvim" --version 2>/dev/null | awk 'NR==1 {print $2}')" || true
  arch="$(uname -m)"; [ "$arch" = aarch64 ] && arch=arm64
  gh_install neovim/neovim "nvim-linux-$arch.tar.gz" "$dir" "$current"
  ln -sf "$dir/bin/nvim" "$LOCAL_BIN/nvim"

  # a config chega via etapa dotfiles; aqui só instala os plugins nas versões do lazy-lock.json.
  nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1
  ok "plugins do LazyVim instalados"
  # servidores LSP/formatters dos extras (lazyvim.json), para o goto definition já funcionar
  nvim --headless -c "luafile $REPO/scripts/nvim-mason-install.lua"
  ok "servidores LSP instalados (mason)"
}

step_zen() {
  info "Zen Browser"
  # última release estável do GitHub em ~/.local/share/zen (sem sudo).
  # Como a pasta é sua, o próprio Zen se atualiza sozinho; rodar de novo também atualiza.
  local dir="$HOME/.local/share/zen" current
  current="$(sed -n 's/^Version=//p' "$dir/application.ini" 2>/dev/null)" || true
  gh_install zen-browser/desktop "zen.linux-$(uname -m).tar.xz" "$dir" "$current" zen-bin

  mkdir -p "$HOME/.local/share/applications"
  ln -sf "$dir/zen" "$LOCAL_BIN/zen"
  cat >"$HOME/.local/share/applications/zen.desktop" <<EOF
[Desktop Entry]
Name=Zen Browser
GenericName=Web Browser
Exec=$dir/zen %u
Icon=$dir/browser/chrome/icons/default/default128.png
Type=Application
Terminal=false
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
StartupWMClass=zen
StartupNotify=true
Actions=new-window;new-private-window;

[Desktop Action new-window]
Name=Nova janela
Exec=$dir/zen --new-window %u

[Desktop Action new-private-window]
Name=Nova janela privada
Exec=$dir/zen --private-window %u
EOF
  ok "atalho criado no menu de aplicativos"

  # Ubuntu 24.04+ bloqueia user namespaces de apps sem perfil AppArmor,
  # o que deixa o sandbox do Zen degradado. Mesmo esquema do perfil do Firefox.
  local profile="$REPO/etc/apparmor.d/zen-browser"
  if [ -d /etc/apparmor.d ] && ! cmp -s "$profile" /etc/apparmor.d/zen-browser; then
    sudo install -m 644 "$profile" /etc/apparmor.d/zen-browser
    sudo apparmor_parser -r /etc/apparmor.d/zen-browser
    ok "perfil AppArmor do Zen instalado"
  fi
}

step_docker() {
  info "Docker"
  if ! has docker; then
    curl -fsSL https://get.docker.com | sudo sh
  fi
  if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    warn "você foi adicionado ao grupo docker — faça logout/login para valer"
  fi
  ok "docker pronto"
}

# -- main ---------------------------------------------------------------------

usage() {
  echo "uso: $0 [etapa...]"
  echo "etapas: ${STEPS[*]}"
}

main() {
  case "${1:-}" in -h | --help) usage; exit 0 ;; esac
  local selected=("$@")
  [ ${#selected[@]} -eq 0 ] && selected=("${STEPS[@]}")

  local s
  for s in "${selected[@]}"; do
    declare -F "step_$s" >/dev/null || { echo "etapa desconhecida: $s"; usage; exit 1; }
  done
  for s in "${selected[@]}"; do "step_$s"; done

  printf '\n\033[0;32mPronto!\033[0m Abra um novo terminal (ou rode: exec bash).\n'
}

main "$@"
