#!/bin/bash

# Description: Builds and installs a 32bit and 64bit version of wine 
# from git://source.winehq.org/git/wine.git to a seperate directory
# Scripts accepts a few arguments, use -h to list 
# See: https://wiki.winehq.org/Building_Wine

# Some build options mirrored from: 
# https://git.archlinux.org/svntogit/community.git/tree/trunk/PKGBUILD?h=packages/wine

get_wine()
{

	SRC_URL="git://source.winehq.org/git/wine.git"

	WINE_BUILD_ROOT="${HOME}/wine-builds"
	WINE_GIT_ROOT="${WINE_BUILD_ROOT}/wine-git"
	WINE_TARGET_DIR="${WINE_BUILD_ROOT}/wine-$WINE_VERSION"

	mkdir -p "${WINE_BUILD_ROOT}"
	mkdir -p "${WINE_TARGET_DIR}"

	CURRENT_DIR=$(dirname $(readlink -f "$0"))

	echo -e "\n==> Obtaining upstream source code"

	if [[ -d "${WINE_GIT_ROOT}" ]]; then

		echo -e "\n==Info==\nGit source files already exist! Remove and [r]eclone or [c]lean? ?\n"
		sleep 1s
		read -ep "Choice: " git_choice

		if [[ "$git_choice" == "r" ]]; then

			echo -e "\n==> Removing and cloning repository again...\n"
			sleep 2s
			# reset retry flag
			retry="no"
			# clean and clone
			sudo rm -rf "${WINE_GIT_ROOT}"
			git clone "${SRC_URL}" "${WINE_GIT_ROOT}"

		else

			# Clean up and changes
			echo "Updating Wine source code"
			git checkout master
			git reset --hard
			git clean -dxf
			git fetch origin


		fi

	else

			echo -e "\n==> Git directory does not exist. cloning now...\n"
			sleep 2s
			# create and clone to dir
			git clone "${SRC_URL}" "${WINE_GIT_ROOT}"

	fi

}

build_wine()
{
	# Prep git source
	cd "${WINE_GIT_ROOT}"
	
	if [[ "${WINE_VERSION}" == "" ]]; then

		# List tags and ask for version
		# show tags instead of TARGETs
		git tag -l --column
		echo -e "\nWhich wine release do you wish to build for:"
		echo -e "Type 'master' to use the master tree\n"

		# get user choice
		sleep 0.2s
		read -erp "Release Choice: " WINE_VERSION

	else

		git checkout wine-$WINE_VERSION

	fi

	# Get rid of old build dirs
	rm -rf "${WINE_GIT_ROOT}/wine-{32,64}-build"
	mkdir -p "${WINE_GIT_ROOT}/wine-{32,64}-build"

	# Check if an existing wine build result exists
	
	if [[ -d "${WINE_TARGET_DIR}" ]]; then

		cat <<-EOF

		NOTICE: You may have already built this version nof wine.
		Please check/remove ${WINE_BUILD_ROOT}/wine-$WINE_VERSION
		before continuing...

		EOF
		sleep 3s
		exit 1

	else
	
		# Make sure our destination exists
		mkdir -p "${WINE_BUILD_ROOT}/wine-$WINE_VERSION"

	fi

	# clean makefiles (just in case)
	cd "${WINE_GIT_ROOT}"
	make distclean

	# Build
	if [[ "${SYSTEM_ARCH}" == "x86_64" ]]; then

		cat<<- EOF

		----------------------------------------------
		Building Wine ${WINE_VERSION} for 64 bit
		----------------------------------------------

		EOF
		sleep 2s

		cd "${WINE_GIT_ROOT}/wine-64-build"

		sleep 2s

		../configure \
			--prefix=${WINE_TARGET_DIR}/ \
			--libdir=${OS_LIB_DIR_64} \
			--with-x \
			--with-gstreamer \
			--enable-win64

		make

		# Set opts for 32 bit build
		WINE32OPTS=()
		WINE32OPTS=+("--libdir=${OS_LIB_DIR_32)")
		WINE32OPTS=+("--with-wine64=${WINE_GIT_ROOT}/wine-64-build")

	elif [[ "${SYSTEM_ARCH}" == "i386" || "${SYSTEM_ARCH}" == "i686" ]]; then
	
		cat<<- EOF

		----------------------------------------------
		Building Wine ${WINE_VERSION} for 32 bit"
		----------------------------------------------

		EOF
		sleep 2s

		cd "${WINE_BUILD_ROOT}/wine-32-build"

		../configure \
			--prefix=${WINE_TARGET_DIR}/ \
			--libdir=${WINE_TARGET_LIB_DIR_32} \
			--with-x \
			--with-gstreamer \
			"${WINE32OPTS[@]}"

		make


	else

		echo -e "\nUnsupported arch! Exiting..."
		sleep 5s
		exit 1

	fi

	# Install
	sudo make install

}

function getScriptAbsoluteDir()
{

    # @description used to get the script path
    # @param $1 the script $0 parameter
    local SCRIPT_INVOKE_PATH="$1"
    local CWD=$(pwd)

    # absolute path ? if so, the first character is a /
    if test "x${SCRIPT_INVOKE_PATH:0:1}" = 'x/'
    then
	RESULT=$(dirname "$SCRIPT_INVOKE_PATH")
    else
	RESULT=$(dirname "$CWD/$SCRIPT_INVOKE_PATH")
    fi
}

function import()
{

    # @description importer routine to get external functionality.
    # @description the first location searched is the script directory.
    # @description if not found, search the module in the paths contained in ${SHELL_LIBRARY_PATH} environment variable
    # @param $1 the .shinc file to import, without .shinc extension
    MODULE=$1

    if [ -f "${MODULE}.shinc" ]; then
      source "${MODULE}.shinc"
      echo "Loaded module $(basename ${MODULE}.shinc)"
      return
    fi

    if test "x${MODULE}" == "x"
    then
	echo "${SCRIPT_NAME} : Unable to import unspecified module. Dying."
        exit 1
    fi

	if test "x${SCRIPT_ABSOLUTE_DIR:-notset}" == "xnotset"
    then
	echo "${SCRIPT_NAME} : Undefined script absolute dir. Did you remove getScriptAbsoluteDir? Dying."
        exit 1
    fi

	if test "x${SCRIPT_ABSOLUTE_DIR}" == "x"
    then
	echo "${SCRIPT_NAME} : empty script path. Dying."
        exit 1
    fi

    if test -e "${SCRIPT_ABSOLUTE_DIR}/${MODULE}.shinc"
    then
        # import from script directory
        . "${SCRIPT_ABSOLUTE_DIR}/${MODULE}.shinc"
        echo "Loaded module ${SCRIPT_ABSOLUTE_DIR}/${MODULE}.shinc"
        return
    elif test "x${SHELL_LIBRARY_PATH:-notset}" != "xnotset"
    then
        # import from the shell script library path
        # save the separator and use the ':' instead
        local saved_IFS="$IFS"
        IFS=':'
        for path in $SHELL_LIBRARY_PATH
        do
          if test -e "$path/$module.shinc"
          then
                . "$path/$module.shinc"
                return
          fi
        done
        # restore the standard separator
        IFS="$saved_IFS"
    fi
    echo "$script_name : Unable to find module $module"
    exit 1
}


function loadConfig()
{
    # @description Routine for loading configuration files that contain key-value pairs in the format KEY="VALUE"
    # param $1 Path to the configuration file relate to this file.
    local ${CONFIG_FILE}=$1
    if test -e "${SCRIPT_ABSOLUTE_DIR}/${CONFIG_FILE}"
    then
        echo "Loaded configuration file ${SCRIPT_ABSOLUTE_DIR}/${CONFIG_FILE}"
        return
    else
	echo "Unable to find configuration file ${SCRIPT_ABSOLUTE_DIR}/${CONFIG_FILE}"
        exit 1
    fi
}

function setDesktopEnvironment()
{

  ARG_UPPER_CASE="$1"
  ARG_LOWER_CASE=`echo $1|tr '[:upper:]' '[:lower:]'`
  XDG_DIR="XDG_"${ARG_UPPER_CASE}"_DIR"
  xdg_dir="xdg_"${ARG_LOWER_CASE}"_dir"

  setDir=`cat ${HOME}/.config/user-dirs.dirs | grep $XDG_DIR| sed s/$XDG_DIR/$xdg_dir/|sed s/HOME/home/`
  target=`echo ${SET_DIR}| cut -f 2 -d "="| sed s,'${HOME}',${HOME},`

  checkValid=`echo ${SET_DIR}|grep $xdg_dir=\"|grep home/`

  if [ -n "${CHK_VALID}" ]; then
    eval "${SET_DIR}"

  else

    echo "local desktop setting" ${XDG_DIR} "not found"

  fi
}

source_modules()
{

	SCRIPT_INVOKE_PATH="$0"
	SCRIPT_NAME=$(basename "$0")
	getScriptAbsoluteDir "${SCRIPT_INVOKE_PATH}"
	SCRIPT_ABSOLUTE_DIR="${RESULT}"
	export SCRIPTDIR=`dirname "${SCRIPT_ABSOLUTE_DIR}"`

}

##########################
# source options
##########################

while :; do
	case $1 in

		-v|--wine-version)
			WINE_VERSION=$2
		;;

		--help|-h)

			cat<<-EOF

			v|--wine-version

			EOF
			break
		;;

		--)
			# End of all options.
			shift
			break
		;;

		-?*)
			printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
		;;

		*)  
			# Default case: If no more options then break out of the loop.
			break

	esac

	# shift args
	shift
done

install_prereqs()
{

	# Test OS first, so we can allow configuration on multiple distros
	export SYSTEM_OS=$(lsb_release -si)
	export SYSTEM_ARCH=$(uname -m)

	# handle OS dependencies in .shinc modules
	case $OS in

		Arch)
		OS_LIB_DIR_64="/usr/lib"
		OS_LIB_DIR_32="/usr/lib32"
		install_packages_arch_linux
		;;

		*)
		echo "Unsupported OS!"
		exit 1
		;;

	esac


}

main()
{

	SCRIPTDIR=$(pwd)
	
	# load script modules
	import "${SCRIPTDIR}/modules/arch-linux.txt"

	# Install prereqs based on OS
	install_prereqs

	# Build wine
	get_wine
	build_wine

}

# Start main
main
