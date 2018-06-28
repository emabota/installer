echo "---java version" > versions.log
sudo java -version 2>> versions.log
echo "---tomcat version and service status" >> versions.log
tomcat=`sudo service --status-all | grep 'tomcat[0-9]*' -o`
echo $tomcat >> versions.log
dpkg --list | grep tomcat >> versions.log
if [ $tomcat ]; then
sudo service $tomcat status >> versions.log
fi
echo "---mysql version and status" >> versions.log
sudo mysql --version >> versions.log
sudo service --status-all | grep mysql >> versions.log
sudo service mysql status >> versions.log
dpkg --list | grep mysql >> versions.log
echo "---docker" >> versions.log
dpkg --list | grep docker >> versions.log
whereis docker-compose -l >> versions.log
docker-compose -version >> versions.log
echo "---ubuntu version" >> versions.log
lsb_release -a >> versions.log
