codenames=("trusty" "xenial" "bionic")

version="18.03.1"

for codename in ${codenames[@]}; do
	wget -r -l1 -np -nd -P "$codename" "https://download.docker.com/linux/ubuntu/dists/$codename/pool/stable/amd64/" -A "docker-ce_${version}*.deb"
done

mkdir -p common && wget "https://github.com/docker/compose/releases/download/1.21.0/docker-compose-Linux-x86_64" -O "common/docker-compose" && chmod +x common/docker-compose
