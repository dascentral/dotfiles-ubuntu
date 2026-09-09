abort() {
    echo -e "${YELLOW}$@${NC}"; exit 1;
}

usage() {
    echo -e "${WHITE}$@${NC}"; exit 1;
}

info() {
    echo -e "${WHITE}$@${NC}"
}

line() {
    echo -e "${GRAY}$@${NC}"
}

success() {
    echo -e "${GREEN}$@${NC}"
}

warn() {
    echo -e "${YELLOW}$@${NC}"
}

die() {
    warn "$@"; exit 1;
}

escape() {
    echo "$1" | sed 's/\([\.\$\*]\)/\\\1/g'
}

has() {
    local item=$1; shift
    echo " $@ " | grep -q " $(escape $item) "
}


################################################################


dotfiles_live_where_expected() {
    if [ ! -e "${DOTFILES}" ]; then
        abort "The dotfiles repo does not exist in the expected location."
    fi
}

dotfiles_confirm_stable() {
    cd "${DOTFILES}"
    git update-index -q --refresh
    if ! git diff-index --quiet HEAD --; then
        abort "The dotfiles repo has pending changes."
    fi
}

install_check_composer() {
    [ -e /usr/local/bin/composer ] ||
    [ -e /usr/bin/composer ]
}

install_check_oh_my_zsh() {
    [ -e "${HOME}/.oh-my-zsh" ]
}

mkd() {
    mkdir -p "$@" && cd "$@"
}
