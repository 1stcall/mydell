#!/usr/bin/env bash
#
set -o errexit
set -o errtrace
set -o functrace
set -o nounset
set -o pipefail
set -o noclobber
#
SECONDS=0
#
# set some constants used within this script
#
LBLUE='\033[0;34m'          # Colour light blue
NC='\033[0m'                # Reset colour
VERSION="0.0.12dev"
scriptName=$(basename ${0})  # Script name
userName="carl"
[[ $scriptName =~ "bash" ]] && scriptName="install_apts_dell.sh"
#
# make apt-get non-interactive
#
export DEBIAN_FRONTEND=noninteractive 
#
# Function for basic logging to stderr
#
log(){
  printf  "${LBLUE}%s:${NC} %s\n" $scriptName "${*}" 1>&2
}
#
log "Running: $scriptName version: $VERSION  User name is: $userName"
#
# update apt
#
log "Running apt-get update to update apt packages"
apt-get update 1>/dev/null || exit 1
#
# remove libre-office
#
log "Removing libreoffice"
apt-get remove --purge --assume-yes libreoffice* 1>/dev/null
#
# autoremove any uneeded apts
#
log "Removing apts no longer required"
apt-get autoremove -y 1>/dev/null
#
# install script dependencies
#
log "Installing script dependencies gnupg debian-archive-keyring apt-transport-https wget"
apt-get install -y gnupg debian-archive-keyring apt-transport-https wget 1>/dev/null
#
# install sid sources lists
#
log "Replacing bullseye's sources list with sid's"
#install -v -D -o root -g root -m 644 sid.list /etc/apt/sources.list
rm -vf /etc/apt/sources.list
cat <<EOF > /etc/apt/sources.list
# See https://wiki.debian.org/SourcesList for more information.
deb http://deb.debian.org/debian sid main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian sid main contrib
EOF
#
# upgrade to sid
#
log "Running apt-get dist-upgrade to update to sid's packages"
apt-get update 1>/dev/null
apt-get dist-upgrade -y # 1>/dev/null
#
# install code repo from microsoft
#
log "Adding the microsoft repo and gpg key for vs code"
tmpdir=$(mktemp -d)
#
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > $tmpdir/packages.microsoft.gpg
install -v -D -o root -g root -m 644 $tmpdir/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] \
  https://packages.microsoft.com/repos/code stable main" > \
  /etc/apt/sources.list.d/vscode.list || log "vscode.list already exists"
rm -rvf $tmpdir
log "Updating apt and installing code-insiders"
apt-get update 1>/dev/null && apt-get install -y code-insiders 1>/dev/null
#
# install bash utilities
#
log "installing utilities (command-not-found bash-completion tmux openssh-server openssh-client nfs-common btrfs-progs ovmf swtpmn fcitx5 git)"
apt-get install -y command-not-found bash-completion tmux openssh-server openssh-client nfs-common btrfs-progs ovmf swtpm fcitx5 git 1>/dev/null
#
log "installing emulation (qemu-system-x86 qemu-utils virt-manager libvirt-daemon virt-manager lxd lxd-tools)"
apt-get install -y qemu-system-x86 qemu-utils virt-manager libvirt-daemon virt-manager lxd lxd-tools 1>/dev/null
#
# enable ssh server on boot
#
log "Enabling ssh service"
systemctl enable ssh --now
#
# update apt-file database for command-not-found
#
log "Updating apt-file for command-not-found database"
apt-file update 1>/dev/null
#
# install edi reop from packagecloud
#
unknown_os ()
{
  echo "Unfortunately, your operating system distribution and version are not supported by this script."
  echo
  echo "You can override the OS detection by setting os= and dist= prior to running this script."
  echo "You can find a list of supported OSes and distributions on our website: https://packagecloud.io/docs#os_distro_version"
  echo
  echo "For example, to force Ubuntu Trusty: os=ubuntu dist=trusty ./script.sh"
  echo
  echo "Please email support@packagecloud.io and let us know if you run into any issues."
  exit 1
}

gpg_check ()
{
  echo "Checking for gpg..."
  if command -v gpg > /dev/null; then
    echo "Detected gpg..."
  else
    echo "Installing gnupg for GPG verification..."
    apt-get install -y gnupg
    if [ "$?" -ne "0" ]; then
      echo "Unable to install GPG! Your base system has a problem; please check your default OS's package repositories because GPG should work."
      echo "Repository installation aborted."
      exit 1
    fi
  fi
}

curl_check ()
{
  echo "Checking for curl..."
  if command -v curl > /dev/null; then
    echo "Detected curl..."
  else
    echo "Installing curl..."
    apt-get install -q -y curl
    if [ "$?" -ne "0" ]; then
      echo "Unable to install curl! Your base system has a problem; please check your default OS's package repositories because curl should work."
      echo "Repository installation aborted."
      exit 1
    fi
  fi
}

install_debian_keyring ()
{
  if [ "${os,,}" = "debian" ]; then
    echo "Installing debian-archive-keyring which is needed for installing "
    echo "apt-transport-https on many Debian systems."
    apt-get install -y debian-archive-keyring &> /dev/null
  fi
}


detect_os ()
{
  if [[ ( -z "${os+x}" ) && ( -z "${dist+x}" ) ]]; then
    # some systems dont have lsb-release yet have the lsb_release binary and
    # vice-versa
    if [ -e /etc/lsb-release ]; then
      . /etc/lsb-release

      if [ "${ID}" = "raspbian" ]; then
        os=${ID}
        dist=`cut --delimiter='.' -f1 /etc/debian_version`
      else
        os=${DISTRIB_ID}
        dist=${DISTRIB_CODENAME}

        if [ -z "$dist" ]; then
          dist=${DISTRIB_RELEASE}
        fi
      fi

    elif [ `which lsb_release 2>/dev/null` ]; then
      dist=`lsb_release -c | cut -f2`
      os=`lsb_release -i | cut -f2 | awk '{ print tolower($1) }'`

    elif [ -e /etc/debian_version ]; then
      # some Debians have jessie/sid in their /etc/debian_version
      # while others have '6.0.7'
      os=`cat /etc/issue | head -1 | awk '{ print tolower($1) }'`
      if grep -q '/' /etc/debian_version; then
        dist=`cut --delimiter='/' -f1 /etc/debian_version`
      else
        dist=`cut --delimiter='.' -f1 /etc/debian_version`
      fi

    else
      unknown_os
    fi
  fi

  if [ -z "$dist" ]; then
    unknown_os
  fi

  # remove whitespace from OS and dist name
  os="${os// /}"
  dist="${dist// /}"

  echo "Detected operating system as $os/$dist."
}

detect_apt_version ()
{
  apt_version_full=`apt-get -v | head -1 | awk '{ print $2 }'`
  apt_version_major=`echo $apt_version_full | cut -d. -f1`
  apt_version_minor=`echo $apt_version_full | cut -d. -f2`
  apt_version_modified="${apt_version_major}${apt_version_minor}0"

  echo "Detected apt version as ${apt_version_full}"
}

main ()
{
  detect_os || log "detact_os returned ${?}"
  curl_check || log "detact_os returned ${?}"
  gpg_check || log "detact_os returned ${?}"
  detect_apt_version || log "detact_os returned ${?}"

  # Need to first run apt-get update so that apt-transport-https can be
  # installed
  echo -n "Running apt-get update... "
  apt-get update &> /dev/null
  echo "done."

  # Install the debian-archive-keyring package on debian systems so that
  # apt-transport-https can be installed next
  install_debian_keyring

  echo -n "Installing apt-transport-https... "
  apt-get install -y apt-transport-https &> /dev/null
  echo "done."

  gpg_key_url="https://packagecloud.io/get-edi/debian/gpgkey"
  apt_config_url="https://packagecloud.io/install/repositories/get-edi/debian/config_file.list?os=${os}&dist=${dist}&source=script"

  apt_source_path="/etc/apt/sources.list.d/get-edi_debian.list"
  apt_keyrings_dir="/etc/apt/keyrings"
  if [ ! -d "$apt_keyrings_dir" ]; then
    mkdir -p "$apt_keyrings_dir"
  fi
  gpg_keyring_path="$apt_keyrings_dir/get-edi_debian-archive-keyring.gpg"
  gpg_key_path_old="/etc/apt/trusted.gpg.d/get-edi_debian.gpg"

  echo -n "Installing $apt_source_path..."

  # create an apt config file for this repository
  rm -fv $apt_source_path
  curl -sSf "${apt_config_url}" > $apt_source_path
  curl_exit_code=$?

  if [ "$curl_exit_code" = "22" ]; then
    echo
    echo
    echo -n "Unable to download repo config from: "
    echo "${apt_config_url}"
    echo
    echo "This usually happens if your operating system is not supported by "
    echo "packagecloud.io, or this script's OS detection failed."
    echo
    echo "You can override the OS detection by setting os= and dist= prior to running this script."
    echo "You can find a list of supported OSes and distributions on our website: https://packagecloud.io/docs#os_distro_version"
    echo
    echo "For example, to force Ubuntu Trusty: os=ubuntu dist=trusty ./script.sh"
    echo
    echo "If you are running a supported OS, please email support@packagecloud.io and report this."
    [ -e $apt_source_path ] && rm $apt_source_path
    exit 1
  elif [ "$curl_exit_code" = "35" -o "$curl_exit_code" = "60" ]; then
    echo "curl is unable to connect to packagecloud.io over TLS when running: "
    echo "    curl ${apt_config_url}"
    echo "This is usually due to one of two things:"
    echo
    echo " 1.) Missing CA root certificates (make sure the ca-certificates package is installed)"
    echo " 2.) An old version of libssl. Try upgrading libssl on your system to a more recent version"
    echo
    echo "Contact support@packagecloud.io with information about your system for help."
    [ -e $apt_source_path ] && rm $apt_source_path
    exit 1
  elif [ "$curl_exit_code" -gt "0" ]; then
    echo
    echo "Unable to run: "
    echo "    curl ${apt_config_url}"
    echo
    echo "Double check your curl installation and try again."
    [ -e $apt_source_path ] && rm $apt_source_path
    exit 1
  else
    echo "done."
  fi

  echo -n "Importing packagecloud gpg key... "
  # import the gpg key
  rm -vf ${gpg_keyring_path}
  curl -fsSL "${gpg_key_url}" | gpg --dearmor > ${gpg_keyring_path}
  # grant 644 permisions to gpg keyring path
  chmod 0644 "${gpg_keyring_path}"

  # move gpg key to old path if apt version is older than 1.1
  if [ "${apt_version_modified}" -lt 110 ]; then
    # move to trusted.gpg.d
    mv ${gpg_keyring_path} ${gpg_key_path_old}
    # grant 644 permisions to gpg key path
    chmod 0644 "${gpg_key_path_old}"

    # deletes the keyrings directory if it is empty
    if ! ls -1qA $apt_keyrings_dir | grep -q .;then
      rm -r $apt_keyrings_dir
    fi
    echo "Packagecloud gpg key imported to ${gpg_key_path_old}"
  else
    echo "Packagecloud gpg key imported to ${gpg_keyring_path}"
  fi
  echo "done."

  echo -n "Running apt-get update... "
  # update apt on this system
  apt-get update &> /dev/null
  echo "done."

  echo
  echo "The repository is setup! You can now install packages."
}

log "Adding packagecloud repo and gpgkey for edi"
main
#
# install edi
#
log "Installing edi (edi edi-boot-shim)"
apt-get install -y edi edi-boot-shim
#
# autoremove any uneeded apts
#
log "Autoremoving any apts no longer required"
apt-get autoremove -y
#
# Add /mnt/shared to fstab and mount.
#
log "Creating mountpoint for shared files and adding it to fstab (/mnt/shared/)"
mkdir -vp /mnt/shared/scratch /home/$userName/scratch
cat <<EOF | tee -a /etc/fstab
192.168.0.16:/srv/shared	 /mnt/shared		nfs	    defaults,vers=4.1,proto=tcp,nofail,_netdev		0	0
/mnt/shared/scratch			 /home/carl/scratch	none	bind                                            0   0
EOF
log "Mounting mountpoint (mount --all)"
systemctl daemon-reload
mount --verbose --all
#
# Installing login scripts (~/.bashrc & .bash_aliases)
#
#
# Create .gitconfig
#
log "Creating ~/.gitconfig"
cat << EOF >/home/$userName/.gitconfig
[user]
	name = Carl McAlwane
	email = carlmcalwane@hotmail.co.uk
[init]
	defaultBranch = development
EOF
log "Completed in $SECONDS seconds."
exit 0
