echo -e "Read carefully throughout this script and correct it for your needs.
Then run it as root. Are you ready? (y/N)"
read ready
# default answer: answer not set or it's first letter is not `y` or `Y`
if [ -v $ready ] || ([ ${ready::1} != "y" ] && [ ${ready::1} != "Y" ])
then
    exit 1
fi

# delete lines with comments from jsonC
jsonc2json () {
    if [ ! -v $1 ]
    then
        filename=$1
        cat $filename | grep -v \/\/
    else
        echo "jsonc2json: no argument is given, aborting"
        exit 1
    fi
}

# drop quotes (") at the start and at the end of a string
strip_quotes () {
    if [ -v $1 ] || [ ${#1} -lt 2 ]
    then
        echo ""
    else
        s=$1
        s=${s: 1} # from 1 to the end
        s=${s:: -1} # from 0 to that is before the last one
        echo $s
    fi
}

## Add user to system ##
echo -e "Enter username if you want to create new user or
add existing user to 'wheel' group; enter nothing to skip"
read username
if [ ! -v $username ]
then
    if ! getent passwd $username >/dev/null # user doesn't exist yet
    then
        useradd -m $username
        password=$(openssl rand -base64 9)
        echo -e "password\npassword" | passwd $username --stdin
    fi
    # if wheel group exists, add the user to it
    if getent group wheel > /dev/null
    then
        usermod -aG wheel $username
    else
        no_wheel=true
    fi
fi

## Configure ssh ##
port=$(jsonc2json "info.jsonc" | jq ".sshPort")
if [ ! -v $port ]
then
    if ss -tunlp | grep :${port} > /dev/null
    then
        echo -e "port ${port} is already in use, aborting"
        exit 1
    else
        ssh_port=$port
        # sometimes port 22 is already commented in config,
        # but 22 port can be needed if new port is not available
        echo "Port 22" | tee -a /etc/ssh/sshd_config
        echo "Port ${port}" | tee -a /etc/ssh/sshd_config
        sshd -t && systemctl restart sshd
    fi
else
    echo -e "sshPort not set in info.jsonc, aborting"
    exit 1
fi

## Configure firewall ##
if [ $(command -v firewall-cmd > /dev/null) ] && [ $(firewall-cmd --state) = "running" ]
then
    firewall-cmd --list-all
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --permanent --add-port=443/tcp
    firewall-cmd --permanent --add-port=${ssh_port}/tcp
    firewall-cmd --reload
fi

## Configure SELinux ##
command -v semanage > /dev/null && semanage port -a -t ssh_port_t -p tcp ${ssh_port}

## for podman ##
# allow user apps (including podman) use ports from 80 and above
sysctl -w net.ipv4.ip_unprivileged_port_start=80
if [ -v $username ]
then
    echo -e "Enter username for which to enable long-running services"
    read username
fi
# allow non-logged user to run long-running services, such as podman container
if [ ! -v $username ]
then
    loginctl enable-linger $username
else
    echo -e "username not set, aborting"
    exit 1
fi

## prepare files ##
server=$(strip_quotes $(jsonc2json "info.jsonc" | jq ".server"))
mkdir -p ./servers/${server}
cp info.jsonc ./servers/${server}/
cp server-rules.dat ./servers/${server}/

## Summary ##
echo -e "
---- Summary ----
"
if [ ! -v $password ]
then
    echo -e "New user ${username} is created with password:
    ${password}
don't forget to change it with
    passwd ${username}
"
fi

echo -e "Check that ssh is available at port ${ssh_port} then close
port 22 commenting line(s)
    Port 22
in /etc/ssh/sshd_config and running
    systemctl restart sshd
"

echo -e "To run a podman container, log out from the server, then log in as ${username},
copy ./servers/${server} directory to your home, and run init2.sh script there.
"

