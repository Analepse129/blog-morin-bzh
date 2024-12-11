#!/bin/bash
# Global variables & default values
DEPENDENCIES=(git, curl, wget)
PROFILE_FILES=(".profile" ".zprofile" ".bash_profile" ".bashrc" ".zshrc" ".config/shellrc")
HOME_PATH=$HOME

# Packages & definitions
declare -A PACKAGES
PACKAGES=(
    [oh-my-posh]="eval \$(oh-my-posh init bash)"
    [bat]="alias cat='bat'"
    [lsd]="alias ls='lsd -la'"
    [asdf]=""
)

# Functions
welcome(){
    check_root(){
    # Checks if the script is running as root and registers the sudo password if not
        if [[ $EUID -ne 0 ]]; then
            IS_ROOT=false
            echo -e "\033[0;36m 🛡️ This script contains commands that require sudo privileges.\n Please enter your sudo password : \033[0m"
            stty -echo
            while IFS= read -r -n1 -s char; do
                if [[ $char == $'\0' ]]; then
                    break
                fi
                if [[ "$char" == $'\x7f' ]]; then
                    if [ -n "$password" ]; then
                        password="${password%${password: -1}}"
                        echo -ne "\b \b"
                    fi
                else
                    SUDO_PASSWORD+="$char"
                    echo -n '*'
                fi
            done
            stty echo
            echo -e "\n"
        else
            IS_ROOT=true
            echo -e "\033[0;32m ✅ Script is running as root.\n\033[0m"
        fi
    }

    check_os(){
        if [[ "$OSTYPE" == "darwin"* ]]; then
            OS=mac
            echo -e "\033[0;36m 🍎 MacOS detected\033[0m"
        elif [[ -f /etc/os-release ]]; then
            . /etc/os-release
            if [[ "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
                OS=deb
                echo -e "\033[0;36m 🐧 Debian-based system detected\n\033[0m"
            elif [[ "$ID" == "rhel" || "$ID_LIKE" == *"rhel"* ]]; then
                OS=rpm
                echo -e "\033[0;36m 🐧 RHEL-based system detected\n\033[0m"
            else
                OS=unknown
                echo -e "\033[0;36m❓ Unknown system detected. This tool might not work correctly with your system.\n\033[0m"
            fi
        else
            OS=unsupported
            echo -e "\033[0;31m❌ Unsupported system detected. This tool doesn't work with Windows based systems.\033[0m"
            exit 0
        fi
    }

    check_homebrew(){
        local config_lines_linux=(
            ""
            "# HOMEBREW"
            "eval \$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        )
        local config_lines_macos=(
            ""
            "# HOMEBREW"
            "eval \$(/opt/homebrew/bin/brew shellenv)"
        )
        if [[ ! -x "$(command -v brew)" ]]; then
            echo -e "\n\033[0;36m ⚠️ Homebrew is not installed.\n\033[0;33m ⚙️ Installing Homebrew...\033[0m"
            NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > /dev/null 2>&1 || echo -e "\033[0;31m ❌ Error: Homebrew could not be installed.\n\033[0m" && exit 1
            echo -e "\033[0;33m ⚙️ Initializing homebrew... \n\033[0m"
            if [ OS == "mac" ]; then
                config_lines=("${config_lines_macos[@]}")
            else
                config_lines=("${config_lines_linux[@]}")
            fi
            for line in "${config_lines[@]}"; do
                echo "$line" >> $PROFILE_FILE
                sleep 1
            done
            echo -e "\033[0;33m ⚙️ Reloading shell... \n\033[0m"
            source "$PROFILE_FILE" > /dev/null
            sleep 1
            echo -e "\033[0;33m ⚙️ Updating packages... \n\033[0m"
            brew update > /dev/null || echo -e "\033[0;31m ❌ Error: Homebrew package list could not be updated.\n\033[0m" && exit 1
            echo -e "\033[0;32m ✅ Homebrew has been installed successfully.\n\033[0m"
        else
            echo -e "\033[0;32m ✅ Homebrew is already installed.\n\033[0m"
        fi
    }

    check_users(){
        local found_users=()
        for dir in /home/*; do
            if [ -d "$dir" ]; then
                user=$(basename "$dir")
                found_users+=$user
            fi
        done
        PS3=$'\033[0;33m 📄 Select the desired user : \033[0m'
        echo -e "\033[0;36m ℹ️ Select the user you want to configure the tools for in the ${#found_users[@]} options found.\033[0;33m"
        select user in "${found_users[@]}"; do
            case $user in 
                *)
                    if [[ -n "$user" ]]; then
                        HOME_PATH="/home/$user"
                        break
                    else
                        echo -e "\033[0;31m ❌ Error: invalid choice.\033[0m"
                    fi
                    ;;
            esac
        done
    }

    check_profile_file(){
        local found_files=()
        local preferred_option=${found_files[0]}
        for file in "${PROFILE_FILES[@]}"; do
            if [ -f "$HOME_PATH/$file" ]; then
                found_files+=("$HOME_PATH/$file")
            fi
        done
        if [[ ${#found_files[@]} -eq 0 ]]; then
            echo -e "\033[0;31m ❌ Error: no config file found.\033[0m"
            echo -e "\033[0;36m ⚠️ This script will stop.\033[0m"
            exit 1
        else
            PS3=$'\033[0;33m 📄 Select the config file : \033[0m'
            echo -e "\033[0;36m ℹ️ Select the config file your shell sources between the ${#found_files[@]} options found. Usually $preferred_option works well.\033[0;33m"
            select file in "${found_files[@]}"; do
                case $file in 
                    *)
                        if [[ -n "$file" ]]; then
                            PROFILE_FILE="$file"
                            break
                        else
                            echo -e "\033[0;31m ❌ Error: invalid choice.\033[0m"
                        fi
                        ;;
                esac
            done
        fi
    }

    check_config_file(){
    #Verifies if the plugins definition file exists
    echo -e "\033[0;33m ⌛ Looking for the plugins definition file...\033[0m"
    if [[ ! -f "$YAML_FILE" ]]; then
        echo -e "\033[0;31m ❌ Error: the file '$yaml_file' cannot be found.\033[0m"
        exit 1
    else
        echo -e "\033[0;32m ✅ The file '$YAML_FILE' has been found.\n\033[0m"
    fi
    }

    welcome_message(){
        echo -e "\033[0;36m 🚀 Welcome to my configuration tool ! 🚀\n\033[0m"
    }

    welcome_message
    check_os
    check_root
    if [[ $IS_ROOT == true ]]; then
        check_users
    fi
    check_profile_file
    check_homebrew
}

configure_tools() {
    install_packages(){
        for package in "${!PACKAGES[@]}"; do
            echo -e "\033[0;33m ⚙️ Installing $package...\033[0m"
            brew install "$package" > /dev/null 2>&1  || echo -e "\033[0;31m ❌ Error: $package could not be installed.\033[0m"
        done
    }

    configure_packages(){
        for package in "${!PACKAGES[@]}"; do
            echo -e "\033[0;33m ⚙️ Configuring $package...\033[0m"
            echo "${PACKAGES[$package]}" >> "$PROFILE_FILE" || echo -e "\033[0;31m ❌ Error: $package could not be configured.\033[0m"
            sleep 1
        done
    }

    echo -e "\033[0;36m ℹ️ Preparing packages installation...\033[0m"
    install_packages
    configure_packages
    echo -e "\033[0;33m ⚙️ Reloading the shell...\033[0m"
    source "$PROFILE_FILE" && sleep 1 || echo -e "\033[0;31m ❌ Error: the shell could not be reloaded.\033[0m"
    echo -e "\033[0;32m ✅ All packages have been installed and configured successfully.\n\033[0m"
}

welcome
configure_tools