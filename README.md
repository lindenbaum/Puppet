# Puppet

Install Puppetmaster on yum-based hosts.

- puppetmaster
- puppet
- puppetdb
- postgresql



#Puppet Agent
##Installation des Agents. 

`yum install -y puppet.noarch`

`puppet resource package puppet ensure=latest`

`chown -R puppet:puppet $(puppet config print confdir) /var/lib/puppet`

Auf dem Agent (Note, Site) bedarf es im normalen Fall keiner Konfiguration.
Der Puppet Agent wird einmalig mit "puppet agent --test --waitforcert 10" initialisiert.

Dieser muss dann nur noch als Daemon aktiviert werden. "puppet agent --enable"
