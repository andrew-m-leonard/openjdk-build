#!/bin/bash

echo "Processing strace files $1/$2 for openjdk work directory $3"

# File patterns to ignore
ignores=("^/dev/")
ignores+=("^/proc/")
ignores+=("^/etc/ld.so.cache$")
ignores+=("^/etc/nsswitch.conf$")
ignores+=("^/etc/passwd$")
ignores+=("^/etc/timezone$")
ignores+=("^/sys/devices/system/cpu")
ignores+=("^/sys/fs/cgroup/")
ignores+=("^/lib/locale/locale-archive$")
ignores+=("^/etc/mailcap$")

isBinSymLink=false
isLibSymLink=false
isSbinSymLink=false

# Check if /bin, /lib, /sbin are symlinks, as sometimes pkgs are installed
# under the symlink folder, eg.in Ubuntu 20.04
binDir=$(readlink -f "/bin")
if [[ "$binDir" != "/bin" ]]; then
    isBinSymLink=true
fi
libDir=$(readlink -f "/lib")
if [[ "$libDir" != "/lib" ]]; then
    isLibSymLink=true
fi
sbinDir=$(readlink -f "/sbin")
if [[ "$sbinDir" != "/sbin" ]]; then
    isSbinSymLink=true
fi

echo "/bin is symlink: $isBinSymLink"
echo "/lib is symlink: $isLibSymLink"
echo "/sbin is symlink: $isSbinSymLink"

# grep strace files,
# ignoring:
#   ENOENT           : strace no entry
#   +++              : strace +++ lines
#   ---              : strace --- lines
#   /dev/            : devices
#   /proc/           : /proc processor paths
#   /tmp/            : /tmp files
#   .java            : .java files
#   .d               : .d compiler output
#   .o               : .o compiler output
#   .d.targets       : .d.targets make compiler output
#   <build_dir>      : begins with build directory
#   <relative paths> : relative file paths
#files="$(grep -v ENOENT --include="$1" | cut -d'"' -f2 | grep -v "\+\+\+" | grep -v "\-\-\-" | grep -v "^/dev/" | grep -v "^/proc/" | grep -v "^/tmp/" | grep -v "\.java$" | grep -v "\.d$" | grep -v "\.o$" | grep -v "\.d\.targets$" | grep -v "^$2" | grep "^/" | sort | uniq)"
set -f
files="$(find "$1" -name "$2" | xargs -n100 grep -v ENOENT | cut -d'"' -f2 | grep "^/" | grep -v "\.java$" | grep -v "\.d$" | grep -v "\.o$" | grep -v "\.d\.targets$" | grep -v "^$3" | grep -v "\+\+\+" | grep -v "\-\-\-" | grep -v "^/dev/" | grep -v "^/proc/" | grep -v "^/tmp/" | sort | uniq)"
set +f

cc=0
for file in $files
do
    echo $file
    ((cc=cc+1))
done
echo "Number of unique file reads = $cc"

cc=0
pkgs=()
no_pkg_files=()
for file in $files
do
    ((cc=cc+1))
    if [[ $(expr $cc % 10) == 0 ]]; then
        echo "Processing file $cc"
    fi
    filePath="$(readlink -f "$file")"

    pkg=$(dpkg -S "$filePath" 2>/dev/null)
    rc=$?
    if [[ "$rc" != "0" ]]; then
        # bin, lib, sbin pkgs may be installed under the root symlink
        if [[ "$isBinSymLink" == "true" ]] && [[ $filePath == /usr/bin* ]]; then
	    filePath=${filePath/#\/usr\/bin}
	    filePath="/bin${filePath}"
	    pkg=$(dpkg -S "$filePath" 2>/dev/null)
	    rc=$?
	fi
        if [[ "$isLibSymLink" == "true" ]] && [[ $filePath == /usr/lib* ]]; then
            filePath=${filePath/#\/usr\/lib}
            filePath="/lib${filePath}"
            pkg=$(dpkg -S "$filePath" 2>/dev/null)
            rc=$?
        fi
        if [[ "$isSbinSymLink" == "true" ]] && [[ $filePath == /usr/sbin* ]]; then
            filePath=${filePath/#\/usr\/sbin}
            filePath="/sbin${filePath}"
            pkg=$(dpkg -S "$filePath" 2>/dev/null)
            rc=$?
        fi
    fi

    ignoreFile=false
    for ignoreFile in "${ignores[@]}"
    do
        if [[ "$filePath" =~ $ignoreFile ]]; then
            ignoreFile=true
            break
        fi
    done
    if [[ $ignoreFile == true ]]; then
        continue
    fi

    if [[ "$rc" != "0" ]]; then
        #echo "no pkg: $filePath"
        no_pkg_files+=("$filePath")
    else
        pkg="$(echo "$pkg" | cut -d" " -f1)"
	pkg=${pkg::-1}
	pkgVersion="$(apt show "$pkg" 2>/dev/null | grep Version | cut -d" " -f2)"
        #echo "file: $filePath pkg: $pkg version: $pkgVersion"
	pkgString="pkg: $pkg version: $pkgVersion"
	if ! echo "${pkgs[@]}" | grep "temurin_${pkgString}_temurin" >/dev/null; then
            pkgs+=("temurin_${pkgString}_temurin")
        fi
    fi
done

echo "Files with no found package:"
for file in "${no_pkg_files[@]}"
do
    echo "$file"
done

echo ""
echo "Packages:"
for pkg in "${pkgs[@]}"
do
    trimPkg=${pkg/#temurin_}
    trimPkg=${trimPkg%_temurin}
    echo $trimPkg
done

