# Load modules and classes
lookup('classes', {merge => unique}).include

$stackdir = '/home/vagrant/hermes/hermes-stack'

if $::environment == 'dev' {
  $dev_name = chomp(generate('/bin/sed', 's/^dev\.[^.]*\.\([^.]*\).*$/\1/', '/etc/fqdn'))
}

$db_host = $::environment ? {
  'dev'        => "dev.hermes-db.${dev_name}.dev.int.nsidc.org",
  'production' => "hermes-db.apps.int.nsidc.org",
  default      => "${::environment}.hermes-db.apps.int.nsidc.org",
}

$nfs_share_postfix = $::environment ? {
  'dev'   => "${::environment}/${dev_name}",
  default => "${::environment}"

}

nsidc_nfs::sharemount { '/share/apps/hermes':
  options => 'rw',
  project => 'apps',
  share   => "hermes/${nfs_share_postfix}",
}
nsidc_nfs::sharemount { '/share/apps/hermes-orders':
  options => 'rw',
  project => 'appdata',
  share   => "hermes-orders/${nfs_share_postfix}",
}
nsidc_nfs::sharemount { '/share/logs/hermes':
  options => 'rw',
  project => 'logs',
  share   => "hermes/${nfs_share_postfix}",
}

file { 'rabbitmq-db-dir':
  path   => "/share/apps/hermes/rabbitmq",
  ensure => "directory",
  require => Nsidc_nfs::Sharemount['/share/apps/hermes']
}
->
file { 'envvars':
  ensure  => file,
  content => vault_template('/vagrant/puppet/templates/hermes.erb'),
  path    => '/etc/profile.d/envvars.sh'
}

if $environment == 'dev' {

  exec { 'setup node':
    command => 'curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash - && sudo apt-get install -y nodejs',
    path    => '/usr/bin'
  }

  package { 'jq': }

  file { '/home/vagrant/hermes':
    ensure => directory,
    owner  => vagrant,
  } ->
  exec { 'clone hermes-stack':
    command => "git clone git@bitbucket.org:nsidc/hermes-stack.git ${stackdir}",
    creates => '/home/vagrant/hermes/hermes-stack',
    path    => '/usr/bin:/bin'
  } ->

  exec { 'clone all the hermes repos':
    command => 'bash ./scripts/clone-dev.sh',
    cwd     => '/home/vagrant/hermes/hermes-stack',
    path    => '/bin:/usr/bin:/usr/local/bin',
    require => [Package['jq']]
  } ->

  exec { 'vagrant permissions':
    command => 'chown -R vagrant:vagrant /home/vagrant/hermes',
    path    => '/bin'
  }
}

$service_versions_target = $::environment ? {
  'production' => 'prod',
  'staging'    => 'prod',
  'qa'         => 'prod',
  default      => 'integration',
}
file { "${stackdir}/service-versions.env":
  ensure  => link,
  target  => "${stackdir}/service-versions.${service_versions_target}.env",
  owner   => vagrant,
  require => Exec['clone hermes-stack'],
}

exec { 'swarm':
  command => 'docker swarm init --advertise-addr eth0:2377 --listen-addr eth0:2377 || true',
  path    => ['/usr/bin', '/usr/sbin',]
}
->
file { "${stackdir}/scripts/docker-cleanup.sh":
  ensure  => present,
  mode    => 'u+x',
  require => Exec['clone hermes-stack'],
}
->
cron { 'docker-cleanup':
  command => "${stackdir}/scripts/docker-cleanup.sh",
  user    => 'vagrant',
  hour    => '*'
}
