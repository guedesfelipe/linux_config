# Prompt (starship) e histórico (atuin).
# A ordem importa: bash-preexec primeiro, para starship e atuin usarem os mesmos hooks.

# shellcheck source=/dev/null
[ -f "$HOME/.bash-preexec.sh" ] && . "$HOME/.bash-preexec.sh"

command -v starship >/dev/null && eval "$(starship init bash)"
command -v atuin >/dev/null && eval "$(atuin init bash)"
