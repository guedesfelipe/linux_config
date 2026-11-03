# Aliases

alias vim='nvim'

if command -v eza >/dev/null; then
  alias ls='eza --icons -a'
  alias ll='eza --long --header --icons --git -a'
fi
command -v bat >/dev/null && alias cat='bat --paging=never'

alias ..='cd ..'
alias cd..='cd ..'

# git
alias g='git'
alias gaa='git add .'
alias gc='gitmoji -c'
alias gp='git push'
alias gd='git difftool -y'

# python
alias py='python'

# docker
alias d='docker'
