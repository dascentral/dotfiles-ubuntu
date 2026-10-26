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

# Write stdin to a root-owned file (mode 644), creating parent directories.
# Returns 0 if the contents changed and 1 if not, so call it as an `if`
# condition (a bare call would trip `set -e` when nothing changed):
#   if write_if_changed /etc/foo.conf <<'EOF' ... EOF; then restart; fi
write_if_changed() {
    local dest="$1" tmp
    tmp="$(mktemp)"
    cat > "$tmp"
    if sudo cmp -s "$tmp" "$dest"; then
        rm -f "$tmp"
        return 1
    fi
    sudo install -D -m 644 "$tmp" "$dest"
    rm -f "$tmp"
}

# Exit unless the running release is one of the given versions.
require_ubuntu() {
    if ! has "$(ubuntu_version)" "$@"; then
        warn "This script supports Ubuntu $*. Detected:"
        grep PRETTY_NAME /etc/os-release >&2
        exit 1
    fi
}
