#!/usr/bin/env bash

showUsage () {
    echo "
    $0 - generates debian package for rootsh 

    Usage: $0 [option]

        -h | --help         show help message
        -b | --build        build the rootsh deb package
        -l | --local-build  set local env (not in gitlab env) and build the rootsh deb package
        -t | --test         test the created rootsh deb package
        -u | --upload       upload the created deb package to the gitlab generic package repository

    " 
}


local_env () {
    NAME=$(grep " NAME:" .gitlab-ci.yml | awk -F '"' '{print $2}')
    VERSION=$(grep " VERSION:" .gitlab-ci.yml | awk -F '"' '{print $2}')
    PKGNAME="${NAME}_${VERSION}"
    PKGARCH="amd64"
    PKGDIR="${PKGNAME}_${PKGARCH}"
    PKGDEB="${PKGDIR}.deb"
    CI_COMMIT_AUTHOR="mipolak"
}


download_rootsh () {
    cd ${PKGDIR}
    wget -O "rootsh-1.5.3.tar.gz" "https://sourceforge.net/projects/rootsh/files/latest/download"
    if [[ $? -ne 0 ]];then
        echo "Download failed. Please check the source url."
        exit 1
    fi
}

pkgstructure () {
    mkdir -p ${PKGDIR}/DEBIAN
    mkdir -p ${PKGDIR}/usr/local/bin
    mkdir -p ${PKGDIR}/usr/local/man/man1
}

pkgcontrolscripts () {
cat > ${PKGDIR}/DEBIAN/control <<-EOF
Package: ${NAME}
Version: ${VERSION}
Architecture: ${PKGARCH}
Maintainer: ${CI_COMMIT_AUTHOR}
Section: admin
Priority: optional
Depends: sudo
Recommends: 
Suggests: 
Replaces:
Conflicts:
Source: 
Homepage: https://sourceforge.net/projects/rootsh/
Description: ${NAME}
 Rootsh is a wrapper for shells which logs all echoed keystrokes and terminal output to a file and/or to syslog. 
 It's main purpose is the auditing of users who need a shell with root privileges. 
 They start rootsh through the sudo mechanism.
 Originally written by: Gerhard Lausser <gerhard.lausser@consol.de>
 Maintained by: Corey Henderson <corman@cormander.com>
EOF


## pre and post scripts 
cat > ${PKGDIR}/DEBIAN/preinst <<-EOF
#!/bin/sh
if [ ! -d /var/log/rootsh ]; then
    mkdir /var/log/rootsh
fi
EOF

cat > ${PKGDIR}/DEBIAN/postinst <<-EOF
#!/bin/sh
echo "/usr/local/bin/rootsh" >> /etc/shells
EOF

#cat > ${PKGDIR}/DEBIAN/prerm <<-EOF
##!/bin/sh
#EOF

cat > ${PKGDIR}/DEBIAN/postrm <<-EOF
#!/bin/sh
if [  -d /var/log/rootsh ]; then
    mv /var/log/rootsh /var/log/rootsh.$(date +%s)
fi
sed -i "/rootsh/d" /etc/shells
EOF

chmod 755 ${PKGDIR}/DEBIAN/p*
}


compilecode () {
    tar xzf rootsh-1.5.3.tar.gz
    cd rootsh-1.5.3
    sed -i -e '/pedantic -Wstrict-prototypes/a \    CFLAGS="$CFLAGS -D_FORTIFY_SOURCE=0"' configure.in
    ./configure
    make
    /usr/bin/install -c src/rootsh ../${PKGDIR}/usr/local/bin/rootsh
    /usr/bin/install -c -m644 rootsh.1 ../${PKGDIR}/usr/local/man/man1/rootsh.1
    cd ..
}


pkgcreate () {
    download_rootsh
    pkgstructure
    pkgcontrolscripts
    compilecode
    pwd
    dpkg-deb -v --build --root-owner-group ${PKGDIR}
    if [[ ! -d package ]];then 
        mkdir package
    fi
    cp ${PKGDEB} package/.
}



pkgtest () {
    set -e
    apt -qq update &>/dev/null
    cd $(pwd)/package
    echo -e "\n##############################"
    echo -e "### PACKAGE TESTING\n##############################\n"
    echo -e "### Package Installation\n"
    apt install -y ./${PKGDEB}
    echo -e "\n### Package Info\n"
    dpkg -s ${NAME}
    echo -e "\n### Package Uninstallation\n"
    apt remove -y ${NAME}
    echo -e "\n##############################\n"
}

pkgupload () {
    # all used variables are predefined by default in gitlab or specified in .gitlab-ci.yml and automatically loaded in gitlab env
    curl -L -X PUT --header "JOB-TOKEN: $CI_JOB_TOKEN" -H "charset=utf-8" \
    -H "Content-Type:application/octet-stream" --data-binary "@package/${PKGDEB}" \
    "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/${CI_PROJECT_NAME}/${VERSION}/${PKGDEB}"
    UPLOADED=$?

    if [ $UPLOADED -eq 0 ]; then 
        echo "Package ${PKGDEB} uploaded successfully to Package Registry - Version ${VERSION} "
    fi
}




OPTIONS=$(getopt -q -o "hbltu" -l "help,build,local-build,test,upload" -a -- "$@")
[ $? -eq 0 ] || {
    echo "Incorrect option provided"
    exit 1
}
eval set -- "$OPTIONS"

while true
do
case "$1" in
-h|--help)
    showUsage
    exit 0
    ;;
-b|--build)
    pkgcreate
    exit 0
    ;;
-l|--local-build)
    local_env
    pkgcreate
    exit 0
    ;;
-t|--test)
    pkgtest
    exit 0
    ;;
-u|--upload)
    pkgupload
    exit 0
    shift;
    ;;
--)
    shift;
    break
    ;;
esac
shift
done
