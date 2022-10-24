# rootsh-deb-package

Gitlab Pipeline for creating rootsh deb package for ubuntu* from source code



## Manual package build in local env


install dependencies

```
apt -qq update 
apt -qq install -y libc6 build-essential automake libtool libdbus-1-dev libglib2.0-dev libcurl3-dev libssl-dev libjson-glib-dev jq curl

```


fix execution permissions if required

```
chmod u+x ./pkg-deb.sh
```


build package 

```
./deb-pkg.sh --local-build

```


 tested on ubuntu22.04