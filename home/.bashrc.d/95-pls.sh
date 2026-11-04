# Mostra as tarefas do pls-cli em cada novo terminal/pane do tmux
# (no shell "de fora" não, porque ele abre o tmux logo em seguida).
if [[ $- == *i* ]] && command -v pls >/dev/null \
  && { [ -n "$TMUX" ] || [ -n "$NO_TMUX" ] || ! command -v tmux >/dev/null; }; then
  pls
fi
