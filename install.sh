#!/bin/bash -eu

hostname=${1?"Usage: $0 <hostname>"}

cat > /etc/hostname <<EOF
$hostname
EOF

yum -y update

# Puppetlabs Repos
rpm -ivh https://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm


: '
Puppet Master

Der Puppet Master wird mit wie folgt Installiert:

- puppet-server (puppet master)
- puppetdb
- postgresql (Backend für PuppetDB)

'
yum install -y puppet-server.noarch postgresql-server.x86_64 postgresql-contrib.x86_64
puppet resource package puppet-server ensure=latest
puppet resource package puppetdb ensure=latest
puppet resource package puppetdb-terminus ensure=latest

# Puppet Setup
cat > /etc/puppet/puppet.conf <<EOF
[main]
    logdir = /var/log/puppet
    rundir = /var/run/puppet
    ssldir = \$vardir/ssl
    dns_alt_names = puppet,$hostname
[agent]
    classfile = \$vardir/classes.txt
    localconfig = \$vardir/localconfig
[master]
    autosign = true
    storeconfigs = true
    storeconfigs_backend = puppetdb
EOF

cat > /etc/puppet/routes.yaml <<EOF
---
master:
  facts:
    terminus: puppetdb
    cache: yaml
EOF

# PuppetDB Setup
cat > /etc/puppet/puppetdb.conf <<EOF
[main]
    server = puppet
    port = 8081
EOF

cat > /etc/puppetdb/conf.d/config.ini <<EOF
[global]
vardir = /var/lib/puppetdb
logging-config = /etc/puppetdb/logback.xml
[command-processing]
EOF

cat > /etc/puppetdb/conf.d/database.ini <<EOF
[database]
classname = org.postgresql.Driver
subprotocol = postgresql
subname = //localhost:5432/puppetdb
username = puppetdb
log-slow-statements = 10
EOF

cat > /etc/puppetdb/conf.d/jetty.ini <<EOF
[jetty]
ssl-host = 0.0.0.0
ssl-port = 8081
ssl-key = /etc/puppetdb/ssl/private.pem
ssl-cert = /etc/puppetdb/ssl/public.pem
ssl-ca-cert = /etc/puppetdb/ssl/ca.pem
EOF

cat > /etc/puppetdb/conf.d/repl.ini <<EOF
[repl]
enabled = false
type = nrepl
port = 8082
EOF

cat > /etc/puppet/manifests/site.pp <<EOF
file { "/tmp/puppet":
  ensure => "present",
  content => generate('/bin/date', '+%s'),
}

service { "puppet":
  enable => "true",
  ensure => "running",
}

Package {
  allow_virtual => true,
}
EOF

chown -R puppet:puppet $(puppet config print confdir) /var/lib/puppet

# PostgreSQL Setup
mkdir /etc/puppet/database
chown postgres:postgres /etc/puppet/database

cat > /etc/systemd/system/postgresql.service <<EOF
.include /lib/systemd/system/postgresql.service

[Service]
Environment=PGDATA=/etc/puppet/database
EOF

systemctl enable postgresql.service

su postgres -c "initdb -D /etc/puppet/database/"
sleep 5
systemctl start postgresql.service
sleep 5

su postgres -c "createuser -DRS puppetdb"
su postgres -c "createdb -E UTF8 -O puppetdb puppetdb"
su postgres -c "psql puppetdb -c 'create extension pg_trgm'"


systemctl enable puppetmaster.service
systemctl start puppetmaster.service

puppetdb ssl-setup
puppet resource service puppetdb ensure=running enable=true
