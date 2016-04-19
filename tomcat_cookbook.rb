Cookbook Name:: tomcat-ii
# Recipe:: default
#
# Copyright 2013, company.com
#
# All rights reserved - Do Not Redistribute
#

return if tagged?('norun::tomcat-ii')

user "tomcat" do
    system true
end

bash "download_tomcat_6" do
  user "root"
  code <<-EOH
  cd /company/inst-files/
  if [ ! -f /company/inst-files/tomcat-6.tar.gz ]; then
    wget https://s3.amazonaws.com/company-backup/infra/linux/software/tomcat-6.tar.gz
    tar xzvf tomcat-6.tar.gz -C /company/inst-files/
  fi
  EOH
end

node['tomcat']['port'].each do |port|
  directory "/company/tomcat-6-port-#{port}" do
    owner "tomcat"
    group "tomcat"
    mode 00755
    action :create
  end

  directory "/company-logs/tomcat-6-port-#{port}/old" do
    owner "tomcat"
    group "tomcat"
    mode 00755
    action :create
    recursive true
  end

  directory "/company/tomcat-6-port-#{port}/webapps" do
    owner "tomcat"
    group "tomcat_admin"
    mode 00755
    action :nothing
    recursive true
  end

  bash "install_tomcat_6" do
    user "root"
    code <<-EOH
    if [ ! -d "/company/tomcat-6-port-#{port}/conf" ]; then
        cd /company/inst-files
        cp -rv tomcat-6/* /company/tomcat-6-port-#{port}/
        rm -rf /company/tomcat-6-port-#{port}/logs
        ln -s /company-logs/tomcat-6-port-#{port}/ /company/tomcat-6-port-#{port}/logs

        port="#{port}"
        echo "$port" > /tmp/port.log
        short_port="${port:2:2}";
        sed 's:<Server port="8005" shutdown="SHUTDOWN">:<Server port="'"$short_port"05'" shutdown="SHUTDOWN">:' /company/tomcat-6-port-#{port}/conf/server.xml > /company/temp_server_1.xml;
        sed 's:<Connector port="8080" protocol="HTTP/1\.1:<Connector port="'"$port"'" protocol="HTTP/1\.1:' /company/temp_server_1.xml > /company/temp_server_2.xml;
        sed 's:<Connector port="8009" protocol="AJP/1\.3" redirectPort="8443" />:<Connector port="'"$short_port"09'" protocol="AJP/1.3" redirectPort="'"$short_port"43'" />":' /company/temp_server_2.xml > /company/temp_server_3.xml;
        sed 's:<Engine name="Catalina" defaultHost="localhost">:<Engine name="Catalina" defaultHost="localhost" jvmRoute="'tomcat"$port"'">":' /company/temp_server_3.xml > /company/temp_server_4.xml;
        mv /company/tomcat-6-port-#{port}/conf/server.xml /company/tomcat-6-port-#{port}/conf/server.xml.original;
        mv /company/temp_server_4.xml /company/tomcat-6-port-#{port}/conf/server.xml;
        rm /company/temp_server*;

        /bin/chown tomcat:tomcat /company/tomcat-6-port-#{port}/ -R
        /bin/chown tomcat:tomcat /company-logs/tomcat-6-port-#{port}/ -R
        /bin/chown tomcat:tomcat /company/tomcat-6-port-#{port}/webapps -R
    fi        
    EOH
  end

  execute "set permissions tomcat" do
    command "/bin/chown tomcat:tomcat /company/tomcat-6-port-#{port}/ -R"
    action :run
    only_if do File.exists?("/company/tomcat-6-port-#{port}") end
  end

  execute "set permissions tomcat" do
    command "/bin/chown tomcat:tomcat /company-logs/tomcat-6-port-#{port}/ -R"
    action :run
    only_if do File.exists?("/company-logs/tomcat-6-port-#{port}") end
  end

  execute "set permissions tomcat" do
    command "/bin/chown tomcat:tomcat_admin /company/tomcat-6-port-#{port}/webapps -R"
    action :run
    only_if do File.exists?("/company/tomcat-6-port-#{port}/webapps") end
  end    

  template "/etc/init.d/tomcat-6-port-#{port}" do
    owner "root"
    group "root"
    mode "0755"
    source "tomcat-service.erb"
    variables(
    :port => "#{port}"
    )
  end

  cookbook_file "/company/tomcat-6-port-#{port}/conf/tomcat-users.xml" do
    owner "tomcat"
    group "tomcat"
    mode "0755"
    source "tomcat-users.xml"
  end

  cookbook_file "/company/tomcat-6-port-#{port}/bin/catalina.sh" do
    owner "tomcat"
    group "tomcat"
    mode "0755"
    source "catalina.sh"
  end

  service "tomcat-6-port-#{port}" do
   supports :status => true,
            :start => true,
            :stop => true,
            :restart => true
   action [ :enable, :start ]
  end
end

templates/default/tomcat-service.erb

# This is the init script for starting up the
#  Jakarta Tomcat server
#
# chkconfig: 345 91 10
# description: Starts and stops the Tomcat daemon.
#

# Source function library.
. /etc/rc.d/init.d/functions

# Get config.
. /etc/sysconfig/network

# Check that networking is up.
[ "${NETWORKING}" = "no" ] && exit 0

tomcat=/company/tomcat-6-port-<%= @port %>
startup=$tomcat/bin/startup.sh
shutdown=$tomcat/bin/shutdown.sh
export JAVA_HOME=/company/jdk6

start(){

  #move os arquivos de log para os arquivos antigos
  /bin/ls /company-logs/tomcat-6-port-<%= @port %>/*.log > /dev/null  2>&1
  if [ $? -eq 0 ]; then
    mv -f /company-logs/tomcat-6-port-<%= @port %>/*.log /company-logs/tomcat-6-port-<%= @port %>/old/
  fi

  #move o catalina.out para os arquivos antigos
  if [ -e /company-logs/tomcat-6-port-<%= @port %>/catalina.out ]; then
    mv -f /company-logs/tomcat-6-port-<%= @port %>/catalina.out /company-logs/tomcat-6-port-<%= @port %>/old/
  fi

  numproc=`ps -ef | grep "/company/tomcat-6-port-<%= @port %>/bin/bootstrap.jar" | grep -v grep |awk -F' ' '{ print $2 }'`;

  if [ $numproc ]; then
    echo "Tomcat <%= @port %> is running!"
    echo "Stop then first!"
  else
    action $"Starting Tomcat <%= @port %> service: " su - tomcat -c $startup
    RETVAL=$?
  fi

}

stop(){
  numproc=`ps -ef | grep "/company/tomcat-6-port-<%= @port %>/bin/bootstrap.jar" | grep -v grep |awk -F' ' '{ print $2 }'`;

  if [ $numproc ]; then
    action $"Stopping Tomcat <%= @port %> service: " $shutdown
    RETVAL=$?
  else
    echo "Tomcat <%= @port %> is not running..."
  fi

  numproc=`ps -ef | grep "/company/tomcat-6-port-<%= @port %>/bin/bootstrap.jar" | grep -v grep |awk -F' ' '{ print $2 }'`;
  if [ $numproc ]; then
    kill -9 $numproc
  fi
}

restart(){
  stop
  start
}

status(){
  numproc=`ps -ef | grep "/company/tomcat-6-port-<%= @port %>/bin/bootstrap.jar" | grep -v grep | wc -l`
  if [ $numproc -gt 0 ]; then
    echo "Tomcat is running..."
  else
    echo "Tomcat is stopped..."
  fi
}

# See how we were called.
case "$1" in
start)
 start
 ;;
stop)
 stop
 ;;
status)
 status
 ;;
restart)
 restart
 ;;
*)


    echo $"Usage: $0 {start|stop|status|restart}"
     exit 1
    esac

exit 0