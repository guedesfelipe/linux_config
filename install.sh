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

STEPS=(packages dotfiles terminal mise pipx atuin tmux nvim docker)

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
  local latest current
  latest="$(curl -fsSI https://github.com/atuinsh/atuin/releases/latest | sed -n 's|^location: .*/tag/v\([^[:space:]]*\).*|\1|ip')"
  current="$("$LOCAL_BIN/atuin" --version 2>/dev/null | awk '{print $2}')" || true
  if [ -z "$latest" ]; then
    warn "não consegui descobrir a última versão do atuin no GitHub"
  elif [ "$current" = "$latest" ]; then
    ok "atuin $current já é a última versão"
  else
    local name tmp
    name="atuin-$(uname -m)-unknown-linux-gnu"
    tmp="$(mktemp -d)"
    (
      cd "$tmp"
      curl -fsSLO "https://github.com/atuinsh/atuin/releases/download/v$latest/$name.tar.gz"
      curl -fsSLO "https://github.com/atuinsh/atuin/releases/download/v$latest/$name.tar.gz.sha256"
      sha256sum -c --quiet "$name.tar.gz.sha256"
      tar -xzf "$name.tar.gz"
      mkdir -p "$LOCAL_BIN"
      install -m 755 "$name/atuin" "$LOCAL_BIN/atuin"
    )
    rm -rf "$tmp"
    ok "atuin ${current:+$current -> }$latest instalado em $LOCAL_BIN"
  fi
  export PATH="$LOCAL_BIN:$PATH"

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
  info "Neovim + LazyVim"
  if [ -e "$HOME/.config/nvim" ]; then
    ok "~/.config/nvim já existe, mantendo"
  else
    git clone -q https://github.com/LazyVim/starter "$HOME/.config/nvim"
    rm -rf "$HOME/.config/nvim/.git"
    ok "LazyVim instalado (plugins baixam ao abrir o nvim)"
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
