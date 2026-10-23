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
    printf "${GREEN}✔${NC} %s\n" "$1"
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

ubuntu_version() {
    awk -F= '$1 == "VERSION_ID" { gsub(/"/, "", $2); print $2 }' /etc/os-release
}

# True when the running release is older than the given one, e.g. `ubuntu_version_lt 24.04`.
ubuntu_version_lt() {
    dpkg --compare-versions "$(ubuntu_version)" lt "$1"
}

# Exit unless the running release is one of the given versions.
require_ubuntu() {
    if ! has "$(ubuntu_version)" "$@"; then
        warn "This script supports Ubuntu $*. Detected:"
        grep PRETTY_NAME /etc/os-release >&2
        exit 1
    fi
}
