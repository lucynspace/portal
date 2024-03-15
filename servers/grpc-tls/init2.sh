echo -e "Read carefully throughout this script and correct it for your needs.
Then run it as user. Check that
    - info.jsonc is correct
    - cert.pem and cert.key are in this folder
Are you ready? (y/N)"
read ready
# default answer: answer not set or it's first letter is not `y` or `Y`
if [ -v $ready ] || ([ ${ready::1} != "y" ] && [ ${ready::1} != "Y" ])
then
    exit 1
fi

## prepare nginx-site: file which describes grpc configuration of nginx server ##

## create container image then run container ##
if podman build -t ximg . && podman run -d -it -p 80:80 -p 443:443 --name xcon ximg
then
    echo -e "
---- congratulations! ----
Podman container xcon is running. To attach it, use
    podman attach xcon
then use easy-xray.sh to install and configure xray,
start nginx and use xray with the generated server config file:
    ./easy-xray.sh install
    nginx
    xray -c conf/config_server.json
Press Ctrl+p then Ctrl+q to datach.
Also you can run bash in the container:
    podman exec -ti xcon bash"
else
    echo -e "Something goes wrong!"
fi

