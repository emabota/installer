path_to_here=$( dirname "${BASH_SOURCE[0]}" )

pushd $path_to_here

. ./install-esaude/get_version.sh

mkdir install-esaude/log -p
mkdir build -p

makeself --notemp --follow install-esaude/ build/install-esaude-${installer_version}.run "eSaúde Installer v${installer_version}" ./install-eSaude.sh

popd
