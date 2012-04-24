node.default[:apache][:default_vhost] = false
node.default[:apache][:mpm] = "prefork"

node.set[:php][:fpm][:conf] = "/srv/system/etc/php/fpm.conf"
include_recipe "php::fpm"

directory "/srv/system/etc/apache" do
  owner "root"
  group "root"
  mode "0755"
end

directory "/srv/system/etc/php" do
  owner "root"
  group "root"
  mode "0755"
end

ssl_certificate "/srv/system/etc/apache/server" do
  cn node[:fqdn]
end

execute "/usr/bin/nepalc generate_apache_conf" do
  creates "/srv/system/etc/apache/listen.conf"
end

include_recipe "apache::fastcgi"
include_recipe "apache::wsgi"

file "/etc/apache2/modules.d/70_php_fpm.conf" do
  action :delete
  notifies :reload, "service[apache2]"
end

apache_vhost "nepal" do
  template "web/apache.conf"
end
