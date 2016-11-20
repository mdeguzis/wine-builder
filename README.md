# wine-builder
Build different versions of wine for your system. Designed for use with qt4wine

# How to use

For now, just a default run can be achieved by issuing:

```
./build-wine.sh
```

You will be asked which wine version you wish to use (a list of the git tags).

# Wine versions
Built wine versions are deployed into WINE_BUILD_ROOT, by default `${HOME}/wine-builds`.

# Distro specifc installation notes

## Arch Linux

For libhal, and OSS support, you must first install these from the [AUR](https://aur.archlinux.org/). Because this is something a user must setup (either manual, or a helper, such as pacaur), those packages are not installed automatically.

```
pacaur -S hal oss 
```
