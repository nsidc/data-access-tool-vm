# Load modules and classes
lookup('classes', {merge => unique}).include

$hermes_env = $environment ? {
  /(dev|integration)/ => 'integration',
  /qa/                => 'qa',
  /staging/           => 'staging',
  /blue/              => 'production',
  /production/        => 'production',
  default             => 'integration'
}

if $::environment == 'dev' {
  $dev_name = chomp(generate('/bin/sed', 's/^dev\.[^.]*\.\([^.]*\).*$/\1/', '/etc/fqdn'))
}

$db_host = $::environment ? {
  'dev'        => "dev.hermes-db.${dev_name}.dev.int.nsidc.org",
  'production' => "hermes-db.apps.int.nsidc.org",
  default      => "${::environment}.hermes-db.apps.int.nsidc.org",
}

file { 'app-share':
  path   => "/share/apps/hermes/${hermes_env}",
  ensure => "directory"
}
->
file { 'rabbitmq-db-dir':
  path   => "/share/apps/hermes/${hermes_env}/rabbitmq",
  ensure => "directory"
}
->
file { 'data-share':
  path   => "/share/apps/hermes-orders/${hermes_env}",
  ensure => "directory"
}
->
file { 'envvars':
  ensure  => file,
  content => vault_template('/vagrant/puppet/templates/hermes.erb'),
  path    => '/etc/profile.d/envvars.sh'
}
->
file { 'hermes.sh':
  ensure => present,
  path   => '/etc/profile.d/hermes.sh'
}
->
file_line {'set HERMES_ENV':
  path    => '/etc/profile.d/hermes.sh',
  line    => "export HERMES_ENV=${hermes_env}",
  before  => Exec['swarm']
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
    command => 'git clone git@bitbucket.org:nsidc/hermes-stack.git /home/vagrant/hermes/hermes-stack',
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

exec { 'swarm':
  command => 'docker swarm init --advertise-addr eth0:2377 --listen-addr eth0:2377 || true',
  path    => ['/usr/bin', '/usr/sbin',]
}
->
vcsrepo { "/home/vagrant/hermes/hermes-stack":
  ensure   => present,
  provider => git,
  source   => 'git@bitbucket.org:nsidc/hermes-stack.git',
  owner    => 'vagrant',
  group    => 'vagrant'
}
->
file { '/home/vagrant/hermes/hermes-stack/scripts/docker-cleanup.sh':
  ensure => present,
  mode   => 'u+x'
}
->
cron { 'docker-cleanup':
  command => '/home/vagrant/hermes/hermes-stack/scripts/docker-cleanup.sh',
  user    => 'vagrant',
  hour    => '*'
}
