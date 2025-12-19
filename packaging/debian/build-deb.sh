#!/usr/bin/bash

# Tested on LMDE 7/Debian 13

###############################
# --- Available to modify --- #
###############################
version='1.33'
rev='1'
arch="$(dpkg --print-architecture)"
package="flux_${version}-${rev}_${arch}"

build_deps=(
'libxres-dev'
'libx11-dev'
'libxext-dev'
'x11proto-dev'
'make'
'gcc'
)

required_deps=(
'bash'
'cpulimit'
'coreutils'
'libxres1'
'libx11-6'
'libxext6'
'less'
)

optional_deps=(
'mangohud'
'mangohud:i386'
'libnotify-bin'
'pulseaudio-utils'
)


##################
# --- Script --- #
##################
required_deps_str="${required_deps[*]}"
required_deps_str="${required_deps_str//' '/', '}"

optional_deps_str="${optional_deps[*]}"
optional_deps_str="${optional_deps_str//' '/', '}"

source_code_archive="v$version.tar.gz"
source_code_url="https://github.com/itz-me-zappex/flux/archive/refs/tags/$source_code_archive"

prefix_error="$(echo -e "[\e[31mx\e[0m]")"
prefix_info="$(echo -e "[\e[32mi\e[0m]")"
prefix_question="$(echo -e "[\e[34m?\e[0m]")"
prefix_warning="$(echo -e "[\e[33m!\e[0m]")"

msg_error(){
  echo "$prefix_error $*" >&2
}

msg_info(){
  echo "$prefix_info $*"
}

msg_question(){
  echo "$prefix_question $*"
}

msg_warning(){
  echo "$prefix_warning $*" >&2
}

# Dumbass protection
if (( UID == 0 )); then
  msg_error "Do not run this script as root!"
  exit 1
fi

msg_warning "Make sure you have updated database with 'sudo apt update' before continue!"

# Get missing packages required for building
for build_dep in wget tar "${build_deps[@]}"; do
  if ! dpkg-query -W "$build_dep" > /dev/null 2>&1; then
    missing_build_deps+=("$build_dep")
  fi
done

if [[ -n "${missing_build_deps[*]}" ]]; then
  # Ask user before install missing build dependencies
  msg_info "Following build dependencies are missing:"
  for missing_build_dep in "${missing_build_deps[@]}"; do
    echo "$missing_build_dep"
  done
  read -p "$(msg_question 'Do you want to install following build dependencies and continue? [Y/n]: ')" install_missing_deps

  # Install build deps if answer is blank or positive
  case "$install_missing_deps" in
  Y | y | '' )
    if ! sudo apt install --mark-auto "${missing_build_deps[@]}" -y; then
      msg_error "Unable to install missing dependencies!"
      exit 1
    fi
  ;;
  N | n )
    msg_info "Building has been cancelled."
    exit 0
  ;;
  * )
    msg_error "Incorrect answer!"
    exit 1
  esac
fi

# Download archive with source code if needed
if [[ -f "$source_code_archive" ]]; then
  msg_info "Source code archive '$source_code_archive' already exists, downloading skipped."
else
  msg_info "Downloading '$source_code_url'..."
  if ! wget "$source_code_url"; then
    msg_error "Unable to download source code archive from '$source_code_url'!"
    exit 1
  fi
fi

# Extract source code archive
if ! tar -xvf "$source_code_archive"; then
  msg_error "Unable to extract source code archive '$source_code_archive'!"
  exit 1
fi

# Enter and build
msg_info "Bulding through 'make'..."
cd "flux-$version"
if ! make; then
  msg_error "Unable to build source code, 'make' process returned an error!"
  exit 1
fi
cd ..

msg_info "Creating package tree..."
mkdir -p "$package"/{bin,etc/security/limits.d,lib,DEBIAN}

msg_info "Creating control file for package..."
cat << EOF > "$package/DEBIAN/control"
Package: flux
Version: $version-$rev
Architecture: $arch
Maintainer: ZaPPeX <https://github.com/itz-me-zappex/flux/issues>
Depends: $required_deps_str
Recommends: $optional_deps_str
Section: utils
Priority: standard
Homepage: https://github.com/itz-me-zappex/flux
Description: advanced daemon for X11 desktops and window managers
 Advanced daemon for X11 desktops and window managers, designed to
 automatically limit FPS/CPU usage of unfocused windows and run
 commands on focus and unfocus events.
 Written in Bash and partially in C.
EOF

msg_info "Creating post install script for package..."
cat << "EOF" > "$package/DEBIAN/postinst"
#!/usr/bin/bash
groupadd -r flux
echo "Group 'flux' has been created, you may want to add your user to there by 'sudo usermod -aG flux \$USER' to bypass scheduling policy changing restrictions."
EOF
chmod 0755 "$package/DEBIAN/postinst"

msg_info "Creating post remove script for package..."
cat << "EOF" > "$package/DEBIAN/postrm"
groupdel flux
echo "Group 'flux' has been removed."
EOF
chmod 0755 "$package/DEBIAN/postrm"

msg_info "Installing into package tree..."
cd "flux-$version"
if ! PREFIX="../$package" make install; then
  msg_error "Unable to install daemon into package tree, 'make' process returned an error!"
  exit 1
fi
msg_info "Installing scheduling policy change restrictions bypass for users in 'flux' group..."
if ! install -Dm644 '10-flux.conf' "../$package/etc/security/limits.d/"; then
  msg_error "Unable to install scheduling policy change restrictions bypass!"
  exit 1
fi
cd ..

msg_info "Creating '$package.deb' package using 'dpkg-deb'..."
if ! dpkg-deb --root-owner-group --build "$package"; then
  msg_error "Unable to create a '$package.deb' package!"
  exit 1
fi

msg_info "Package has been built successfully. You may want to install it with 'sudo dpkg -i $package.deb ; sudo apt install -f' command."
