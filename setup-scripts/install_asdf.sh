#!/bin/bash
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
        if [[ ! -x "$(command -v brew)" ]]; then
            echo -e "\033[0;36m ⚠️ Homebrew is not installed. Please install homebrew and relaunch this tool.\033[0m"
            exit 0
        else
            echo -e "\033[0;32m ✅ Homebrew is already installed.\n\033[0m"
        fi
    }

    check_package_manager(){
        if command -v apt-get > /dev/null ; then
            PACKAGE_MGR="apt-get"
        elif command -v yum > /dev/null; then
            PACKAGE_MGR="yum"
        elif command -v dnf > /dev/null; then
            PACKAGE_MGR="dnf"
        else
            echo -e "\033[0;31m ❌ Error: your package manager is not currently supported by this script or no package manager was found.\033[0m"
            exit 1
        fi
        echo -e "\033[0;36m ℹ️ The package manager is $PACKAGE_MGR.\n\033[0m"
    }
    
    variables_selections(){
        echo -e -n "\033[0;36m ℹ️ This tool requires several information to run correctly. If you don't know what to put, leave default.\n\033[0m"
        echo -e -n "\033[0;33m ➖ Enter the desired config file name for your shell [DEFAULTS: will display availiable] : \033[0m" 
        read CONFIG_FILE
        CONFIG_FILE=${CONFIG_FILE:-"selection"}
        echo -e -n "\033[0;33m ➖ Enter ASDF desired version [DEFAULTS: v0.14.1] : \033[0m"
        read ASDF_VERSION
        ASDF_VERSION=${ASDF_VERSION:-"v0.14.1"}
        echo -e -n "\033[0;33m ➖ Enter the path to the YAML file containing the configuration [DEFAULTS: configuration.yaml] : \033[0m"
        read YAML_FILE
        YAML_FILE=${YAML_FILE:-"configuration.yaml"}
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
        echo -e "\033[0;36m 🚀 Welcome to my ASDF & tools installation scriptfor the repo ! 🚀\n\033[0m"
    }

    welcome_message
    check_os
    if [[ "$OS" == "mac" ]]; then
        check_homebrew
    fi
    check_package_manager
    check_root
    variables_selections
    check_config_file
}

install_dependencies() {
    get_packages(){
        # Checks the dependancies in the configuration.yaml file
        awk '/^dependencies:/ {flag=1} /^  global:/ {sub(/^  global:/, ""); global_flag=1; next} 
         /^[^ ]/ {flag=0; global_flag=0} 
         flag && global_flag {gsub(/- /, ""); print}' "$YAML_FILE"
    }

    update_packages(){
        # Updates the package list and installs the required packages
        if [[ "$OS" == "mac" ]]; then
            echo -e "\033[0;33m\n ⌛ Updating Homebrew...\033[0m"
            brew update > /dev/null || { echo -e "\033[0;31m ❌ An error occurred while updating Homebrew.\n\033[0m"; exit 1; }
        else
            echo -e "\033[0;33m\n ⌛ Updating the packages list...\033[0m"
            if [[ "$IS_ROOT" == "true" ]]; then
               $PACKAGE_MGR update || { echo -e "\033[0;31m ❌ An error occurred while updating the packages list.\n\033[0m"; exit 1; }
            else
                echo "$SUDO_PASSWORD" | sudo -S $PACKAGE_MGR update || { echo -e "\033[0;31m ❌ An error occurred while updating the packages list.\n\033[0m"; }
            fi
        fi
    }

    install_required_packages(){
        local packages=$(get_packages)
        echo $packages
        if [[ OS == "mac" ]]; then
            for package in "${packages[@]}"; do
                echo -e "\033[0;33m ⌛ Installing $package...\033[0m"
                brew install $package > /dev/null || { echo -e "\033[0;31m ❌ An error occurred while installing $package.\n\033[0m"; exit 1; }
            done
        else
            for package in "${packages[@]}"; do
                if [[ "$IS_ROOT" == "true" ]]; then
                    echo -e "\033[0;33m ⌛ Installing $package...\033[0m"
                    $PACKAGE_MGR install -y $package || { echo -e "\033[0;31m ❌ An error occurred while installing $package.\n\033[0m"; exit 1; }
                else
                    echo -e "\033[0;33m ⌛ Installing $package...\033[0m"
                    echo "$SUDO_PASSWORD" | sudo -S $PACKAGE_MGR install -y $package || { echo -e "\033[0;31m ❌ An error occurred while installing $package.\n\033[0m"; exit 1; }
                fi
            done
        fi
        echo -e "\033[0;32m ✅ The required packages have been installed successfully.\n\033[0m"
    }
    
    update_packages
    install_required_packages
}

check_config_file() {
    local files=(".bashrc" ".zshrc" ".profile" ".bash_profile" ".zprofile" ".config/shellrc")
    local found_files=()

    look_for_config_file(){
        for file in "${files[@]}"; do
            if [ -f "$HOME/$file" ]; then
                found_files+=("$HOME/$file")
            fi
        done
    }

    select_config_file(){
        if [[ ${#found_files[@]} -eq 0 ]]; then
            echo -e "\033[0;31m ❌ Error: no config file found.\033[0m"
            echo -e "\033[0;36m ⚠️ ASDF installation will stop.\033[0m"
            exit 1
        else
            PS3=$'\033[0;33m 📄 Select the config file : \033[0m'
            echo -e "\033[0;36m ℹ️ Select the config file your shell sources between the ${#found_files[@]} options found. Usually ${preferred_option} works well.\033[0;33m"
            select file in "${found_files[@]}"; do
                case $file in 
                    *)
                        if [[ -n "$file" ]]; then
                            CONFIGFILE="$file"
                            break
                        else
                            echo -e "\033[0;31m ❌ Error: invalid choice.\033[0m"
                        fi
                        ;;
                esac
            done
        fi
    }
    if [[ "$CONFIG_FILE" == "selection" ]]; then
        look_for_config_file
        select_config_file
    else
        if [[ -f "$HOME/$CONFIG_FILE" ]]; then
            CONFIGFILE="$HOME/$CONFIG_FILE"
        else
            echo -e "\n\033[0;31m ❌ Error: the file '$CONFIG_FILE' cannot be found.\033[0m"
            exit 1
        fi
    fi
    echo -e "\033[0;36m ℹ️ The selected config file is '$CONFIGFILE'.\n\033[0m"
}

get_asdf() {
    # Clones the ASDF repository
    echo -e "\033[0;33m ⌛ Cloning the ASDF repository...\033[0m"
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch $ASDF_VERSION > /dev/null 2>&1 || { echo -e "\033[0;31m ❌ An error occurred while cloning the ASDF repository.\033[0m"; exit 1; }
}

update_asdf() {
    echo -e -n "\033[0;36m ASDF is already installed in version $VERSION_FROM_FILE. Do you want to update it to version $ASDF_VERSION? [y/n] " 
    read response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY]|[oO])$ ]]; then
        echo -e "\033[0;33m ⌛ Updating ASDF to version $ASDF_VERSION...\033[0m"
        rm -rf "$HOME/.asdf" > /dev/null 2>&1 || { echo -e "\033[0;31m ❌ An error occurred while removing ASDF folder.\033[0m"; exit 1; }
        get_asdf
    elif [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
        echo -e "\033[0;36m ⚠️ The installation of ASDF has been canceled.\033[0m"
        exit 0
    else
        echo -e "\033[0;31m ❌ Error: invalid response.\033[0m"
        exit 1
    fi
    echo -e "\033[0;33m ⌛ Updating ASDF to version $ASDF_VERSION...\033[0m"
    echo "$SUDO_PASSWORD" | sudo -S rm -rf "$HOME/.asdf" > /dev/null 2>&1 || { echo -e "\033[0;31m ❌ An error occurred while updating ASDF.\033[0m"; exit 1; }
    get_asdf
}

configure_asdf() {
    # Adds the ASDF configuration to the shell configuration file
    local perm_file=".asdf/asdf.sh"
    echo -e "\033[0;33m ⌛ Configuring ASDF...\033[0m"
    chmod +x "$HOME/$perm_file" > /dev/null 2>&1 || { echo -e "\033[0;31m ❌ An error occurred while csetting permission on file $perm_file.\033[0m"; exit 1; }
    sleep 1
    echo -e "\n# ASDF" >> $CONFIGFILE
    sleep 1
    echo ". $HOME/.asdf/asdf.sh" >> $CONFIGFILE
    sleep 1
    echo ". $HOME/.asdf/completions/asdf.bash" >> $CONFIGFILE
    sleep 1
    source $CONFIGFILE > /dev/null 2>&1 || { echo -e "\033[0;31m ❌ An error occurred while sourcing the configuration file.\033[0m"; exit 1; }
    sleep 1
}

install_asdf_plugins(){
    install_plugins(){
        # Plugins list reading & installation using asdf
        echo -e "\033[0;33m 📑 Installing the plugins...\033[0m"
        local plugins=$(yq '.asdf_plugins' "$YAML_FILE" | jq -c '.[]' || { echo -e "\033[0;31m ❌ An error occurred while retrieving plugins list.\033[0m"; exit 1; })
        echo "$plugins" | while read -r plugin; do
            local name url version
            name=$(echo "$plugin" | jq -r '.name')
            url=$(echo "$plugin" | jq -r '.url')
            echo -e "\033[0;33m ⌛ Adding the plugin '$name' depuis '$url'..."
            asdf plugin add "$name" "$url" > /dev/null 2>&1 || { echo -e "\033[0;31m ❌ An error occurred while installing the plugin '$name'.\033[0m"; exit 1; }
        done
    }

    install_tools(){
        echo -e "\033[0;33m 📑 Installing the tools...\033[0m"
        asdf install > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            echo -e "\033[0;32m ✅ The tools have been installed successfully.\033[0m"
        else
            echo -e "\033[0;31m ❌ An error occurred while installing the tools.\033[0m"
            exit 1
        fi
    }

    install_plugins
    install_tools
}

# Main
welcome
install_dependencies
check_config_file
if [[ -d "$HOME/.asdf" ]]; then
    if [[ -f "$HOME/.asdf/version.txt" ]]; then
        VERSION_FROM_FILE=$(cat "$HOME/.asdf/version.txt")
        if [[ "v$VERSION_FROM_FILE" == "$ASDF_VERSION" ]]; then
            echo -e "\033[0;36m ℹ️ ASDF is already installed in version $ASDF_VERSION. Skipping installation & configuration steps.\n\033[0m"
        else
            update_asdf
        fi
    else
        echo -e "\033[0;31m ❌ Error: ASDF seems installed but version cannot be found. Exiting.\033[0m"
        exit 1
    fi
else
    get_asdf
    configure_asdf
fi
install_asdf_plugins