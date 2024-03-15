echo -e "Read carefully throughout this script and correct it for your needs.
Then run it as root. Are you ready? (y/N)"
read ready
# default answer: answer not set or it's first letter is not `y` or `Y`
if [ -v $ready ] || ([ ${ready::1} != "y" ] && [ ${ready::1} != "Y" ])
then
    exit 1
fi

dnf update --assumeyes
dnf install --assumeyes podman openssl jq vim iproute tcpdump
