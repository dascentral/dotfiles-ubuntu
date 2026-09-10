abort() {
    echo -e "${YELLOW}${*}${NC}"; exit 1;
}

usage() {
    echo -e "${WHITE}${*}${NC}"; exit 1;
}

info() {
    echo -e "${WHITE}${*}${NC}"
}

line() {
    echo -e "${GRAY}${*}${NC}"
}

success() {
    echo -e "${GREEN}${*}${NC}"
}

warn() {
    echo -e "${YELLOW}${*}${NC}"
}

die() {
    warn "$@"; exit 1;
}

section() {
    printf "\n${BLUE}==> %s${NC}\n" "$1"
}

ok() {
    printf "${GREEN}    ok:${NC} %s\n" "$1"
}

escape() {
    echo "$1" | sed 's/\([\.\$\*]\)/\\\1/g'
}

has() {
    local item="$1"; shift
    echo " $* " | grep -q " $(escape "$item") "
}

mkd() {
    mkdir -p "$@" && cd "$@"
}
