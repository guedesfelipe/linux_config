# Ambiente: PATH, editor e ferramentas de linguagem.

case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

export EDITOR=nvim
export VISUAL=nvim

command -v mise >/dev/null && eval "$(mise activate bash)"
