#!/bin/bash

# Description: Builds and installs a 32bit and 64bit version of wine 
# from git://source.winehq.org/git/wine.git to a seperate directory
# Scripts accepts a few arguments, use -h to list 
# See: https://wiki.winehq.org/Building_Wine

# Some build options mirrored from: 
# https://git.archlinux.org/svntogit/community.git/tree/trunk/PKGBUILD?h=packages/wine

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

get_wine()
{

	SRC_URL="git://source.winehq.org/git/wine.git"
	echo -e "\n==> Obtaining upstream source code" 

	cd "${WINE_BUILD_ROOT}"

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
			cd "${WINE_GIT_ROOT}"
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

test_dependencies()
{

	MISSING_DEPS=$(cat config.log | grep "files not found")

	if [[ "${MISSING_DEPS}" != "" ]]; then

		cat<<- EOF

		WARNING: You have missing depenencies!
		It is recommended you exit and resolve these first.
		Continuing may result in missing features.

		You can review this log at:
		${CONFIGURE_LOG}

		Abort?

		EOF


		read -erp "Choice [y/n]: " ABORT_CHOICE

		if [[ "${ABORT_CHOICE}" == "y" ]]; then

			exit 1

		fi


	fi

}

build_wine()
{

	# Notes
	# Verified install files with `make -n install`
	
	# set env
	WINE_BUILD_ROOT="${HOME}/wine-builds"
	WINE_GIT_ROOT="${WINE_BUILD_ROOT}/wine-git"

	mkdir -p "${WINE_BUILD_ROOT}"

	CURRENT_DIR=$(dirname $(readlink -f "$0"))

	# fetch wine
	get_wine

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

	# Set the rest of the vars
	WINE_TARGET_DIR="${WINE_BUILD_ROOT}/$WINE_VERSION"
	WINE_TARGET_LIB_DIR="${WINE_TARGET_DIR}/lib"
	WINE_TARGET_DLL_DIR="${WINE_TARGET_LIB_DIR}/wine"
	WINE_TARGET_LIB_DIR_32="${WINE_TARGET_DIR}/lib32"
	WINE_TARGET_DLL_DIR_32="${WINE_TARGET_LIB_DIR_32}/wine"

	# Check if an existing wine build result exists
	
	if [[ -d "${WINE_TARGET_DIR}" ]]; then

		cat <<-EOF

		NOTICE: You may have already built this version sof wine.
		Please check/remove ${WINE_BUILD_ROOT}/wine-$WINE_VERSION
		before continuing...

		EOF
		
		echo "Remove? "
		read -erp "Choice [y/n]: " WINE_REMOVE_CHECK
		
		if [[ "${WINE_REMOVE_CHECK}" == "y" ]]; then
		
			rm -rf 	"${WINE_TARGET_DIR}"

		else
			sleep 3s
			exit 1

		fi

	else
	
		# Make sure our destination exists
		mkdir -p "${WINE_BUILD_ROOT}/wine-$WINE_VERSION"

	fi

	mkdir -p "${WINE_TARGET_DIR}"
	mkdir -p "${WINE_TARGET_LIB_DIR}"
	mkdir -p "${WINE_TARGET_DLL_DIR}"
	mkdir -p "${WINE_TARGET_LIB_DIR_32}"
	mkdir -p "${WINE_TARGET_DLL_DIR_32}"

	# Get rid of old build dirs
	rm -rf "${WINE_GIT_ROOT}/wine-32-build"
	rm -rf "${WINE_GIT_ROOT}/wine-64-build"
	mkdir -p "${WINE_GIT_ROOT}/wine-32-build"
	mkdir -p "${WINE_GIT_ROOT}/wine-64-build"

	# Build
	if [[ "${SYSTEM_ARCH}" == "x86_64" ]]; then

		cat<<- EOF

		----------------------------------------------
		Building ${WINE_VERSION} for 64 bit
		----------------------------------------------

		EOF
		sleep 3s

		cd "${WINE_GIT_ROOT}/wine-64-build"

		sleep 2s

		make distclean
		../configure \
			--prefix=${WINE_TARGET_DIR}/ \
			--libdir=${WINE_TARGET_LIB_DIR} \
			--with-x \
			--with-gstreamer \
			--enable-win64

		# test for missing dependencies, ask to abort
		CONFIGURE_LOG="${WINE_GIT_ROOT}/wine-64-build/config.log"
		test_dependencies
	
		make

		# Set opts for 32 bit build
		WINE32OPTS=()
		WINE32OPTS+=("--libdir=${WINE_TARGET_LIB_DIR_32}")
		WINE32OPTS+=("--with-wine64=${WINE_GIT_ROOT}/wine-64-build")

	else

		echo -e "\nUnsupported arch! Exiting..."
		sleep 5s
		exit 1

	fi

	
	# Always build
	cat<<- EOF

	----------------------------------------------
	Building ${WINE_VERSION} for 32 bit"
	----------------------------------------------

	EOF
	sleep 3s

	cd "${WINE_GIT_ROOT}/wine-32-build"

	make distclean
	../configure \
		--prefix=${WINE_TARGET_DIR}/ \
		--libdir=${WINE_TARGET_LIB_DIR_32} \
		--with-x \
		--with-gstreamer \
		"${WINE32OPTS[@]}"

	# test for missing dependencies, ask to abort
	CONFIGURE_LOG="${WINE_GIT_ROOT}/wine-32-build/config.log"
	test_dependencies

	make

	cat<<- EOF

	----------------------------------------------
	Installing Wine
	----------------------------------------------

	EOF
	sleep 2s

	# Install
	echo -e "\n==> Installing Wine-32...\n"

	cd "${WINE_GIT_ROOT}/wine-32-build"
	
	if [[ "${SYSTEM_ARCH}" == "i686" ]]; then

		make prefix="${WINE_TARGET_DIR}" install

	else

		make prefix="${WINE_TARGET_DIR}" install \
		libdir="${WINE_TARGET_LIB_DIR_32}" \
		dlldir="${WINE_TARGET_DLL_DIR_32}" install

		echo -e "\n==> Installing Wine-64...\n"

		cd "${WINE_GIT_ROOT}/wine-64-build"
		make prefix="${WINE_TARGET_DIR}" \
		libdir="${WINE_TARGET_LIB_DIR}" \
		dlldir="${WINE_TARGET_DLL_DIR}" install

	fi

}

cat<<- EOF

------------------------------------------
wine-builder
------------------------------------------

EOF
sleep 2s

##########################
# source modules
##########################

# Source env for imports
script_invoke_path="$0"
script_name=$(basename "$0")
getScriptAbsoluteDir "$script_invoke_path"
script_absolute_dir=$RESULT

# load script modules
echo -e "\n==> Loading script modules\n"

import "${script_absolute_dir}/modules/arch-linux"
import "${script_absolute_dir}/modules/debian"

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

	echo -e "\n==> Asssesing distro-specific dependencies\n"
	sleep 2s

	# handle OS dependencies in .shinc modules
	case $SYSTEM_OS in

		Arch)
		install_packages_arch_linux
		;;

		SteamOS|Debian)
		install_packages_debian
		;;

		*)
		UNSUPOPRTED="true"
		cat<<- EOF

		NOTICE: Non-support OS detected. Proceed at your own risk!
		You may encounter dependency errors. Continue?
		
		EOF
		
		read -erp "Choice [y/n]: " CONTINUE_CHOICE
		
		if [[ "${CONTINUE_CHOICE}" == "n" ]]; then

			exit 1

		fi

		;;

	esac


}

main()
{

	# Install prereqs based on OS
	install_prereqs

	# Build wine
	build_wine

}

# Start main
main 2>&1 | tee log.txt
