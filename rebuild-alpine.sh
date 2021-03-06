rootdir=$(pwd -P)

distclean () {
    echo "Removing traces of previous builds from $rootdir"
    local allpkgs=$(find $rootdir -maxdepth 3 -name APKBUILD -print | sed -e 's/\/APKBUILD//g' | sort)
    for p in $allpkgs ; do
        cd $p
        pwd
        abuild clean            2>&1
        abuild cleanoldpkg      2>&1
        abuild cleanpkg         2>&1
        abuild cleancache       2>&1
    done
}

build () {
    local pkgs
    local maintainer
    local pkgno
    local failed
    pkgs=$($rootdir/aport.lua deplist $rootdir $1)
    pktcnt=$(echo $pkgs | wc -w)
    pkgno=0
    failed=0
    for p in $pkgs ; do
        pkgno=$(expr "$pkgno" + 1)
        echo "Building $p ($pkgno of $pktcnt in $1 - $failed failed)"
        cd $rootdir/$1/$p
        if [ -n "$debug" ] ; then
            apk info | sort > $rootdir/packages.$1.$pkgno.$p.before
        fi
        abuild -rm > $rootdir/$1_$p.txt 2>&1
        if [ "$?" = "0" ] ; then
    	    if [ -z "$debug" ] ; then
                rm $rootdir/$1_$p.txt
            fi
        else
            echo "Package $1/$p failed to build (output in $rootdir/$1_$p.txt)"
            if [ -n "$mail" ] ; then
                maintainer=$(grep Maintainer APKBUILD | cut -d " " -f 3-)
                if [ -n "$maintainer" ] ; then
                    recipients="$maintainer -cc dev@lists.alpinelinux.org"
                else
                    recipients="dev@lists.alpinelinux.org"
                fi
    	        if [ -n "$mail" ] ; then
                    echo "Package $1/$p failed to build. Build output is attached" | \
                        email -s "NOT SPAM $p build report" -a $rootdir/$1_$p.txt \
                              -n AlpineBuildBot -f buildbot@alpinelinux.org $recipients
                fi
            fi
            failed=$(expr "$failed" + 1)
        fi
        if [ -n "$debug" ] ; then
            apk info | sort > $rootdir/packages.$1.$pkgno.$p.after
        fi
    done
    cd $rootdir
}

touch START_OF_BUILD.txt

unset clean
unset mail
while getopts "cmd" opt; do
	case $opt in
		'c') clean="--clean";;
		'm') mail="--mail";;
		'd') debug="--debug";;
	esac
done

if [ -n "$clean" ] ; then
    echo "Invoked with 'clean' option. This will take a while ..."
    tmp=$(distclean)
    echo "Done"
fi

echo "Refresh aports tree"
git pull

#cd main/build-base
#abuild -Ru
#cd $rootdir

for s in main testing unstable ; do
    echo "Building packages in $s"
    build $s
done

touch END_OF_BUILD.txt

echo "Done"

