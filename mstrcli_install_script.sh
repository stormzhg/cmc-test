#!/bin/bash

set -e

trap 'echo "ERROR: script exited at line $LINENO."; exit 1' ERR

# Resolve privilege escalation once.
# - If already running as root (e.g. environments where sudo is not permitted),
#   no sudo is needed and commands run bare.
# - If not root, use sudo when available; otherwise fail with a clear message.
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        echo "ERROR: this installer needs root privileges. Re-run as root or install sudo."
        exit 1
    fi
fi

PATH_VAL=$PATH
# Split PATH into array
IFS=':' read -r -a path_array <<< "$PATH_VAL"

bin_array=()
for element in "${path_array[@]}"; do
    if [ "$element" == "/usr/local/bin" ]; then
        bin_array[0]=$element
        break
    elif [ "$element" == "/usr/bin" ]; then
        bin_array[1]=$element
    elif [[ "$element" == /usr* ]]; then
        bin_array[2]=$element
    fi
done

target_path=${path_array[0]}
for item in "${bin_array[@]}"; do
    if [ -n "$item" ]; then
        target_path=$item
        break
    fi
done

resolved_script_path="$(readlink -f "$0")"
current_path="$(dirname "$resolved_script_path")/mstrcli"

find_via_ldconfig() {
    if command -v ldconfig &> /dev/null; then
        $SUDO ldconfig -p 2>/dev/null | grep -m1 'libgcc_s.so.1' | awk '{print $NF}'
    fi
}

find_via_search() {
    $SUDO find /usr/lib* /lib* -name "libgcc_s.so.1" 2>/dev/null | head -n1
}

source_libgcc=""
echo "Checking..."
source_libgcc=$(find_via_ldconfig)
if [[ -n "$source_libgcc" ]] && [[ -f "$source_libgcc" ]]; then
    echo "ldconfig passed"
else
    source_libgcc=$(find_via_search)
fi

if [[ -n "$source_libgcc" ]] && [[ -f "$source_libgcc" ]]; then
    libgcc_path="$current_path/_internal/libgcc_s.so.1"
    if ! $SUDO cp "$source_libgcc" "$libgcc_path"; then
        echo "Default used"
    fi
else
    echo "Use default"
fi

new_path="$target_path/mstr_cli"
if [ -d "$new_path" ]; then
    $SUDO rm -rf "$new_path"
fi
echo "$SUDO cp -r $current_path $new_path"
$SUDO cp -r "$current_path" "$new_path"

real_path="$new_path/mstrcli"
soft_link="$target_path/mstrcli"
if [ -L "$soft_link" ]; then
    $SUDO rm "$soft_link"
fi
echo "$SUDO ln -s $real_path $soft_link"
$SUDO ln -s "$real_path" "$soft_link"
echo "mstrcli has been installed successfully."

echo "create credentials file"
$SUDO mkdir -p /opt/.strategy
$SUDO touch /opt/.strategy/credentials
$SUDO chmod 666 /opt/.strategy/credentials

if [ -f "$HOME/.strategy/credentials" ]; then
    echo "copy profile"
    $SUDO cp "$HOME/.strategy/credentials" /opt/.strategy/credentials
    rm "$HOME/.strategy/credentials"
fi

if [ -f "$HOME/.strategy/config" ] && [ ! -f "/opt/.strategy/config" ]; then
    echo "remove config file"
    $SUDO mv "$HOME/.strategy/config" /opt/.strategy/config
    $SUDO chmod 644 /opt/.strategy/config
    echo "Attention: please note that the location of the config file has been moved from $HOME/.strategy/config to /opt/.strategy/config"
fi

echo ""
echo "Checking version of prerequisites, this will take some time..."

version=$(mstrcli version)
echo "$version"
