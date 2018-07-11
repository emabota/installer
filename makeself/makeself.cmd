. ./install-esaude/get_version.sh

mkdir install-esaude/log -p
mkdir build -p

makeself --notemp --follow install-esaude/ build/install-esaude-${installer_version}.run "eSaúde Platform & EMR POC v${installer_version}" ./install-eSaude.sh
