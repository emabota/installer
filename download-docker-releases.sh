codenames=("trusty" "xenial" "bionic")

version="18.03.1"

for codename in ${codenames[@]}; do
	wget -r -l1 -np -nd -P "$codename" "https://download.docker.com/linux/ubuntu/dists/$codename/pool/stable/amd64/" -A "docker-ce_${version}*.deb"
done
