#!/usr/bin/env zsh

function is_marked {
    # If it's a deb-file, don't try to read it
    if file "$1" | grep Debian > /dev/null;
    then
        false
        return
    fi

    # Ensure the commit actually exists
    commit="$(head -c40 $1)"
    if [ "$(git cat-file -t $commit 2>/dev/null)" = "commit" ];
    then
        true
        return
    fi

    false
    return
}

function mark {
    rm -f $1
    echo $2 > $1
}

function check() {
    for file in $1/**/*.deb(.);
    do
        if is_marked $file;
        then
            echo "$file OK"
            continue
        else
            dpkg-sig --verify $file || rm -f $file
        fi
    done
}

function download() {
    BASE_URLS=(
    "http://security.ubuntu.com"
    "http://old-releases.ubuntu.com"
    "https://mirrors.kernel.org"
    )

    URLS=()

    for URL in $BASE_URLS;
    do
        URLS+=("$URL/ubuntu/pool/main/g/glibc/"
                "$URL/ubuntu/pool/main/e/eglibc/"
                "$URL/ubuntu/pool/universe/d/dietlibc/"
                "$URL/ubuntu/pool/main/a/arm64-cross-toolchain-base/"
                "$URL/ubuntu/pool/main/a/armhf-cross-toolchain-base/"
                "$URL/ubuntu/pool/main/a/armel-cross-toolchain-base/"
                "$URL/ubuntu/pool/main/p/powerpc-cross-toolchain-base/"
            )
    done

    for URL in $URLS;
    do
        wget \
         --follow-ftp \
         --no-parent \
         -e robots=off \
         --no-proxy \
         --level=1 \
         --no-parent \
         --recursive \
         --no-clobber \
         --no-directories \
         --accept "*libc*.deb" \
         --reject "*-bin*" \
         --reject "*-dbg*" \
         --reject "*-doc*" \
         --reject "*-prof*" \
         --reject "*-udeb*" \
         --reject "*-xen*" \
         --reject "*-source*" \
         --reject "*-pic*" \
         --reject "*linux-libc-dev*"
         --verbose \
         -P $1 \
         $URL
    done

    for URL in $URLS;
    do
        wait
    done
}


function debextract {
    input=$1
    shift
    dpkg-deb --fsys-tarfile "$input" | tar --wildcards --extract $*
}


function extract {
for deb in $1/**/*.deb(.);
do
    echo $deb
    dir="libc/${deb:t:r}"

    echo "Checking $deb"
    if is_marked "$deb" ;
    then
        echo "...skipping"
        continue
    fi

    [[ -d $dir ]] || mkdir -p $dir

    echo "Extracting $deb"
    dpkg-deb \
        --fsys-tarfile "$deb" \
    | tar \
        --directory "$dir" \
        --wildcards \
        --wildcards-match-slash \
        --extract \
        '*libc.so.*' \
        '*libc-*.so*' \
        '*libc.a' \
        '*libc.so*'

    echo "Committing $deb"
    git add libc || continue
    git commit -m "$deb"

    mark $deb $(git rev-parse HEAD)
    git add $deb
    git commit -m "update .debs"
done
}

[[ -d debfiles ]] || mkdir debfiles

check    debfiles
# download debfiles
# extract  debfiles
