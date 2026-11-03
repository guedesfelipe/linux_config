# Abre o tmux automaticamente em terminais interativos.
# Para pular uma vez: NO_TMUX=1 bash
if [[ $- == *i* ]] && [ -z "$TMUX" ] && [ -z "$NO_TMUX" ] \
  && [ "$TERM_PROGRAM" != vscode ] && command -v tmux >/dev/null; then
  tmux
fi
