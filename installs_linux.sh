#!/bin/bash

# Text style codes
BOLD='\033[1m'
RESET='\033[0m' # Reset all attributes
TAB="  "

# Text color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'

# Bullets
BULLET="${BOLD}${MAGENTA}[*]${RESET}"
BULLET_ERROR="${RED}[x]${RESET}"
BULLET_WARNING="${YELLOW}[-]${RESET}"
BULLET_SUCCESS="${GREEN}[✓]${RESET}"

header(){
    clear
    echo -e "${CYAN}    __    _                     ______            _____      "
    echo -e "   / /   (_)___  __  ___  __   / ____/___  ____  / __(_)___ _"
    echo -e "  / /   / / __ \/ / / / |/_/  / /   / __ \/ __ \/ /_/ / __ \`/"
    echo -e " / /___/ / / / / /_/ />  <   / /___/ /_/ / / / / __/ / /_/ / "
    echo -e "/_____/_/_/ /_/\__,_/_/|_|   \____/\____/_/ /_/_/ /_/\__, /  "
    echo -e "                                                    /____/   ${RESET}"
    echo
    echo -e "-------------------------------------------------------------"
    echo -e "            Versão ${BOLD}1.0${RESET} - Autor: ${MAGENTA}Felipe Guedes${RESET}          "
    echo -e "-------------------------------------------------------------"
    echo
}

header

# Ask the user for input with default Python values
read -p "🐍 Enter the major Python version (default: 3): " python_major_user
major_python_input="${python_major_user:-3}"  # Use 3 as the default if user input is empty

read -p "🐍 Enter the minor Python version (default: 11): " python_minor_user
minor_python_input="${python_minor_user:-11}"  # Use 11 as the default if user input is empty

PYTHON_VERSION="${major_python_input}.${minor_python_input}.*"


# Ask the user for input with default Node values
read -p "🤖 Enter the major Node version (default: 20): " node_major_user
major_node_input="${node_major_user:-20}"  # Use 20 as the default if user input is empty

read -p "🤖 Enter the minor Node version (default: 10): " node_minor_user
minor_node_input="${node_minor_user:-10}"  # Use 10 as the default if user input is empty

NODE_VERSION="${major_node_input}.${minor_node_input}.*"



# Ask the user for input with default Rust values
read -p "🦀 Enter the major Rust version (default: 1): " rust_major_user
major_rust_input="${rust_major_user:-1}"  # Use 1 as the default if user input is empty

read -p "🦀 Enter the minor Rust version (default: 74): " rust_minor_user
minor_rust_input="${rust_minor_user:-74}"  # Use 74 as the default if user input is empty

RUST_VERSION="${major_rust_input}.${minor_rust_input}.*"



# Shell RC File
shell_rc_file="$HOME/.$(basename "$SHELL")rc"

# Echo functions
echo_header(){
    echo -e "\n${BULLET} ${BOLD}${1}${RESET}"
}

echo_error(){
    echo -e "\n${BULLET_ERROR} ${BOLD}${1}${RESET}"
}

echo_warinig(){
    echo -e "\n${BULLET_WARING} ${BOLD}${1}${RESET}"
}

echo_success(){
    echo -e "\n${BULLET_SUCCESS} ${BOLD}${1}${RESET}"
}


# Functions
install() {
    echo_header "Installing dependencies..."
    sudo apt install git curl tmux unzip xclip jq build-essential gnustep-gui-runtime meld tree zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libbz2-dev libreadline-dev libsqlite3-dev liblzma-dev python3-tk pkg-config g++ cmake automake autoconf libtool-bin libtool gettext ninja-build pipx gnome-tweaks gnome-shell-extensions exa bat flameshot ripgrep htop -y
}


starship() {
    starship_dir="$HOME/.starship"

    # Check if the directory exists
    if [ ! -d "$starship_dir" ]; then
        echo_header "Installing starship..."
        curl -sS https://starship.rs/install.sh | sh
        echo -e "${TAB}${BULLET_WARNING} Configure starship..."
        mkdir -p ~/.starship
        git clone https://github.com/guedesfelipe/starship_config.git ~/.starship
        echo -e '\nexport STARSHIP_CONFIG=~/.starship/starship.toml' >> "$shell_rc_file"
        echo -e '\neval "$(starship init bash)"' >> "$shell_rc_file"
        
        # Source the configuration file
        source "$shell_rc_file"
        
        echo_success "Starship insalled and configured"
    else
        echo_error "Starship already exists"
    fi

}


asdf_install() {
    asdf_dir="$HOME/.asdf"
    
    # Check if the directory exists
    if [ ! -d "$starship_dir" ]; then
        echo_header "Installing ASDF..."
        latest_tag=$(git ls-remote --tags https://github.com/asdf-vm/asdf.git | awk '{print $2}' | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n 1)
        git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch "$latest_tag"
        
        # Source the configuration file
        source "$shell_rc_file"
        
        echo_success "ASDF Installed."
    else
        echo_error "ASDF already exists"
    fi

    asdf_config_line='. "$HOME/.asdf/asdf.sh"'
    asdf_completions_config_line='. "$HOME/.asdf/completions/asdf.bash"'

    if ! grep -qF "$asdf_config_line" "$shell_rc_file" && ! grep -qF "$asdf_completions_config_line" "$shell_rc_file"; then
        echo -e "${TAB}${BULLET_WARNING} Configure asdf..."
        
        if ! grep -qF "$asdf_config_line" "$shell_rc_file"; then
            echo -e "\n${asdf_config_line}" >> "$shell_rc_file"
        fi
        
        if ! grep -qF "$asdf_completions_config_line" "$shell_rc_file"; then
            echo -e "\n${asdf_completions_config_line}" >> "$shell_rc_file"
        fi
        
        # Source the configuration file
        source "$shell_rc_file"
        
        echo_success "ASDF Configured."
    else
        echo_error "ASDF config exists"
    fi

}

asdf_install_tools(){
    echo_header "Add ASDF plugins..."
    echo -e "\n${TAB}🐍 Add Python plugin..."
    asdf plugin-add python
    echo -e "\n${TAB}🦀 Add Rust plugin..."
    asdf plugin-add rust https://github.com/code-lever/asdf-rust.git
    echo -e "\n${TAB}🤖 Add Nodejs plugin..."
    asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
    
    install_python_version=$(asdf list-all python ${PYTHON_VERSION} | grep -v - | tail -n 1)
    echo -e "\n${TAB}🐍 Installing Python ${GREEN}${install_python_version}${RESET}..."
    asdf install python "${install_python_version}"
    asdf global python "${install_python_version}"
    
    install_rust_version=$(asdf list-all rust ${RUST_VERSION} | grep -v - | tail -n 1)
    echo -e "\n${TAB}🦀 Installing Rust ${GREEN}${install_rust_version}${RESET}..."
    asdf install rust "${install_rust_version}"
    asdf global rust "${install_rust_version}"
    
    install_node_version=$(asdf list-all nodejs ${NODE_VERSION} | grep -v - | tail -n 1)
    echo -e "\n${TAB}🤖 Installing Node ${GREEN}${install_node_version}${RESET}..."
    asdf install nodejs "${install_node_version}"
    asdf global nodejs "${install_node_version}"

    echo_success "ASDF plugins and tools installed"
}

pls_install() {
    if command -v "pls" &> /dev/null; then
        echo_error 'PLS-CLI already exists'
    else
        echo_header 'Installing pls-cli...'
        pip install pls-cli

        echo 'pls' >> "$shell_rc_file"
        # Source the configuration file
        source "$shell_rc_file"
        echo_success "pls-cli installed"
    fi
}

nvim_install() {
    if command -v "nvim" &> /dev/null; then
        echo_error 'Nvim already exists'
    else
        echo_header 'Installing nvim...'
        
        (
        git clone --branch stable https://github.com/neovim/neovim /tmp/neovim &&
        cd /tmp/neovim/ &&
        sudo make install &&
        sudo cp ./build/bin/nvim /usr/local/bin
        )

        # Source the configuration file
        source "$shell_rc_file"
        echo_success "nvim installed"
    fi
}

lunarvim_install() {

    if command -v "lvim" &> /dev/null; then
        echo_error 'LunarVim already exists'
    else
        echo_header 'Installing LunarVim...'
        LV_BRANCH='release-1.3/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.3/neovim-0.9/utils/installer/install.sh)
        
        # Create alias to type vim and open nvim
        echo -e '\nalias vim="lvim"' >> "$shell_rc_file"
        echo -e "\nexport EDITOR='lvim'" >> "$shell_rc_file"
        
        # Source the configuration file
        source "$shell_rc_file"
        
        echo_success 'LunarVim installed'
    fi
}

fonts_install() {

   local font_files=( $(fc-list : family file | grep "Fira Code") )

    if [ ${#font_files[@]} -gt 0 ]; then
        echo_error 'FiraCode already exists'
    else
        echo_header 'Installing FiraCode...'
        # Set the URL for the Fira Code release
        #
        firacode_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/FiraCode.zip"

        # Create a temporary directory
        temp_dir=$(mktemp -d)

        # Download and extract the Fira Code font
        curl -LO "$firacode_url" && unzip -q FiraCode.zip -d "$temp_dir"

        # Copy font files to system font directory (for Linux)
        font_dir="$HOME/.local/share/fonts"
        mkdir -p "$font_dir"
        cp "$temp_dir"/*.ttf "$font_dir"
        cp "$temp_dir"/*.otf"$font_dir"

        # Update font cache
        fc-cache -f -v

        # Clean up temporary files
        rm -rf "$temp_dir" FiraCode.zip
        
        echo_success 'FiraCode installed'
    fi

    # Set the desired font family and size
    # font_family="Fira Code"
    # font_size=12

    # Set the profile name in GNOME Terminal
    # profile_name="Default"

    # Change the font in GNOME Terminal
    # gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$profile_name/ font "$font_family $font_size"

}

tmux_configure() {

    tmux_config_line='f [ "$TMUX" = "" ]; then tmux; fi'

    if grep -qF "$tmux_config_line" "$shell_rc_file"; then
      echo_error 'Tmux already configured'
    else
      echo_header 'Configure tmux...'

      git clone https://github.com/gpakosz/.tmux.git ~/.tmux
      ln -s -f ~/.tmux/.tmux.conf ~/.tmux.conf
      cp ~/.tmux/.tmux.conf.local ~/

      # GTMUX
      # git clone git@github.com:guedesfelipe/.tmux.git ~/.gtmux
      # ln -s -f ~/.gtmux/.tmux.conf ~/.tmux.conf
      # ln -s -f ~/.gtmux/.tmux.conf.local ~/.tmux.conf.local

      echo -e '\nif [ "$TMUX" = "" ]; then tmux; fi' >> "$shell_rc_file"

      # Source the configuration file
      source "$shell_rc_file"

      echo_success 'Tmux configured'
      # /*/*Cellar/ncurses/6.3/bin/infocmp -x tmux-256color >tmux-256color.src
      # sudo /usr/bin/tic -x tmux-256color.src
    fi
}

docker_install() {
  if command -v "docker" &> /dev/null; then
    echo_error 'Docker already exists'
  else
    echo_header 'Installing Docker...'
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm -rf get-docker.sh
    echo_success 'Docker installed'
  fi
}

poetry_install() {

  if command -v "poetry" &> /dev/null; then
    echo_error 'Poetry already installed'
  else
    echo_header 'Installing Poetry...'
    pipx install poetry
    poetry completions bash >> ~/.bash_completion
    # Source the configuration file
    source "$shell_rc_file"
    poetry config virtualenvs.in-project true
  fi

}

gnome_terminal_theme() {
  curl -L https://raw.githubusercontent.com/catppuccin/gnome-terminal/v0.2.0/install.py | python3 -
}

bat_config() {
  folder_path="~/.local/bin"

  if [ -d "$folder_path" ]; then
    echo_error 'Bat already configured'
  else
    echo_header 'Configure bat...'
    mkdir -p folder_path
    ln -s /usr/bin/batcat ~/.local/bin/bat
    echo_success 'Bat configured'
  fi
}

rc_config() {

  echo_header 'Configure Aliases...'

  if ! grep -q "bat --paging=never" "$config_file"; then
    echo -e "\nalias cat='bat --paging=never'" >> "$shell_rc_file"
  fi

  
  if ! grep -q "exa --long --header --icons -a" "$config_file"; then
    echo -e "\nalias ll='exa --long --header --icons -a'" >> "$shell_rc_file"
  fi

  if ! grep -q "exa --header --icons -a" "$config_file"; then
    echo -e "\nalias ls='exa --header --icons -a'" >> "$shell_rc_file"
  fi

  if ! grep -q "## Get rid of command not found ##" "$config_file"; then
    echo -e "\n## Get rid of command not found ##\nalias cd..='cd ..'" >> "$shell_rc_file"
  fi

  if ! grep -q "## A quick way to get out of current directory ##" "$config_file"; then
    echo -e "\n## A quick way to get out of current directory ##\nalias ..='cd ..'" >> "$shell_rc_file"
  fi

  # Git alias
  if ! grep -q "## Git Aliases ##" "$config_file"; then
    echo -e "\n## Git Aliases ##">> "$shell_rc_file"
    echo -e "alias g='git'" >> "$shell_rc_file"
    echo -e "alias gaa='git add .'" >> "$shell_rc_file"
    echo -e "alias gc='gitmoji -c'" >> "$shell_rc_file"
    echo -e "alias gp='git push'" >> "$shell_rc_file"
    echo -e "alias gd='git difftool -y'" >> "$shell_rc_file"
  fi

  # Python
  if ! grep -q "## Python Aliases ##" "$config_file"; then
    echo -e "\n## Python Aliases ##">> "$shell_rc_file"
    echo -e "alias py='python'" >> "$shell_rc_file"
  fi

  # Docker
  if ! grep -q "## Docker Aliases ##" "$config_file"; then
    echo -e "\n## Docker Aliases ##">> "$shell_rc_file"
    echo -e "alias d='docker'" >> "$shell_rc_file"
  fi

  # Source the configuration file
  source "$shell_rc_file"

  echo_success 'Aliases Configured'

}

install
starship
asdf_install
asdf_install_tools
nvim_install
lunarvim_install
# fonts_install
tmux_configure
docker_install
poetry_install
bat_config
rc_config

# should always be the last
pls_install
echo -e "\n\n--Script Finished--\n\nMade with ${RED}❤${RESET} by Felipe Guedes"
if [ ! command -v "docker" &> /dev/null ]; then
  newgrp docker
fi
