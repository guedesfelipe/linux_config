# 🐧 Linux config

Meu ambiente de dev (Ubuntu 26.04) em um repo só: dotfiles + um script idempotente.

```bash
git clone git@github.com:guedesfelipe/linux_config.git ~/workspace/linux_config
cd ~/workspace/linux_config
./install.sh            # tudo
./install.sh tmux nvim  # só algumas etapas
```

Pode rodar quantas vezes quiser: o que já está pronto é pulado e nada é duplicado no `~/.bashrc`.

## Etapas

| etapa      | o que faz |
|------------|-----------|
| `packages` | `apt install` de tudo em [`packages.txt`](packages.txt) (tmux, starship, eza, bat, rg, fd, fzf…) |
| `dotfiles` | cria symlinks de tudo em [`home/`](home) para `~` (faz backup do que existir em `~/.dotfiles-backup/`) |
| `terminal` | FiraCode Nerd Font + fonte e tema Catppuccin Macchiato no Ptyxis |
| `mise`     | instala o [mise](https://mise.jdx.dev) e as linguagens de [`config.toml`](home/.config/mise/config.toml) (Python, Node, Rust, uv, poetry, gitmoji) |
| `pipx`     | ferramentas Python via pipx (`pls-cli`) — lista em `PIPX_PACKAGES` no `install.sh` |
| `atuin`    | [atuin](https://atuin.sh) (última release do GitHub, rodar de novo atualiza) + bash-preexec; importa o histórico do bash |
| `tmux`     | TPM + plugins (catppuccin, cpu, battery) |
| `nvim`     | Neovim (última release do GitHub) + plugins do [LazyVim](https://www.lazyvim.org) + servidores LSP via mason |
| `zen`      | [Zen Browser](https://zen-browser.app) (última release do GitHub) em `~/.local/share/zen`, atalho no menu e perfil AppArmor; ele se auto-atualiza |
| `docker`   | Docker + seu usuário no grupo `docker` |

## Estrutura

```
install.sh                 # o script
packages.txt               # pacotes apt
etc/apparmor.d/            # perfis AppArmor (copiados com sudo)
scripts/                   # auxiliares usados pelo install.sh
home/                      # espelho do ~ (cada arquivo vira um symlink)
├── .bashrc.d/             # carregado pelo ~/.bashrc
│   ├── 10-env.sh          #   PATH, EDITOR, mise
│   ├── 20-aliases.sh      #   aliases
│   ├── 30-prompt.sh       #   starship + atuin
│   ├── 95-pls.sh          #   mostra as tarefas do pls em cada pane
│   └── 99-tmux.sh         #   abre o tmux ao abrir o terminal
└── .config/
    ├── mise/config.toml   # versões das linguagens
    ├── nvim/              # LazyVim: plugins em lua/plugins/, linguagens em lazyvim.json
    ├── starship.toml      # prompt
    └── tmux/tmux.conf     # tmux
```

Como são symlinks, editar `~/.config/tmux/tmux.conf` (ou qualquer outro) já edita o repo — é só commitar.
Para adicionar um dotfile novo: coloque em `home/` no mesmo caminho relativo ao `~` e rode `./install.sh dotfiles`.

## Dia a dia

- **Mudar versão de linguagem:** edite `home/.config/mise/config.toml` e rode `mise install`.
- **Pacote novo:** adicione em `packages.txt` e rode `./install.sh packages`.
- **tmux:** `prefix` é `C-b` ou `C-a`. `prefix r` recarrega, `prefix e` edita, `prefix C-s` sincroniza panes, `prefix g` roda `git status`, `prefix -`/`_` divide, `prefix hjkl` navega.
- **Neovim:** `gd` vai para a definição, `gr` lista referências, `K` mostra a documentação. Linguagem nova: `:LazyExtras` (salva em `lazyvim.json`). Plugin novo: um arquivo em `home/.config/nvim/lua/plugins/` que faz `return { "autor/plugin", opts = {...} }`.
- **Atualizar Neovim/atuin/Zen:** `./install.sh nvim atuin zen` (só baixa se houver versão nova).
- **Histórico:** `ctrl-r` (ou seta ↑) abre a busca do atuin. Para sincronizar entre máquinas: `atuin register` / `atuin login`.
- **Sem tmux numa sessão:** `NO_TMUX=1 bash`.
