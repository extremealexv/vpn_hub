#!/bin/bash
# shared/utils.sh

log_info() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

log_warn() {
    echo -e "\e[33m[WARN]\e[0m $1"
}

log_error() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root (or with sudo)"
        exit 1
    fi
}
