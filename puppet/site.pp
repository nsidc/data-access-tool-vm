# Load modules and classes
hiera_include('classes')

$icebridge_env = $environment ? {
  /(dev|integration)/ => 'integration',
  /qa/                => 'qa',
  /staging/           => 'staging',
  /blue/              => 'production',
  /production/        => 'production',
  default             => 'integration'
}

file { 'app-share':
  path   => "/share/apps/icebridge-portal/${icebridge_env}",
  ensure => "directory"
}
->
file { 'rabbitmq-db-dir':
  path => "/share/apps/icebridge-portal/${icebridge_env}/rabbitmq",
  ensure => "directory"
}
->
file { 'data-share':
  path   => "/share/apps/icebridge-order-data/${icebridge_env}",
  ensure => "directory"
}
->
file { 'envvars':
  ensure  => file,
  content => vault_template('/vagrant/puppet/templates/icebridge.erb'),
  path    => '/etc/profile.d/envvars.sh'
}
->
file { 'icebridge.sh':
  ensure => present,
  path   => '/etc/profile.d/icebridge.sh'
}
->
file_line {'set ICEBRIDGE_ENV':
  path    => '/etc/profile.d/icebridge.sh',
  line    => "export ICEBRIDGE_ENV=${icebridge_env}",
  before  => Exec['swarm']
}

if $environment == 'ci' {
  class { 'docker':
    version => '17.03.1~ce-0~ubuntu-trusty',
    docker_users => [ 'vagrant', 'jenkins' ],
    notify => Service['jenkins']
  }
}
else {
  class { 'docker':
    version => '17.03.1~ce-0~ubuntu-trusty',
    docker_users => [ 'vagrant' ],
    before => Exec['swarm']
  }
}

if $environment == 'dev' {

  exec { 'install docker-compose':
    command => 'sudo curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-Linux-x86_64 -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose',
    path => '/usr/bin'
  }

  exec { 'setup node':
    command => 'curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash - && sudo apt-get install -y nodejs',
    path => '/usr/bin'
  }

  package { 'jq': }

  exec { 'clone icebridge-stack':
    command => 'mkdir -p /home/vagrant/icebridge && git clone git@bitbucket.org:nsidc/icebridge-stack.git /home/vagrant/icebridge/icebridge-stack',
    creates => '/home/vagrant/icebridge/icebridge-stack',
    path => '/usr/bin:/bin'
  }



  # don't check this in
  exec { 'dev branch':
    command => 'git checkout changes',
    cwd => '/home/vagrant/icebridge/icebridge-stack',
    path => '/usr/bin',
    require => [Exec['clone icebridge-stack'], Exec['install docker-compose'], Package['jq']]
  } ->

  exec { 'clone all the icebridge repos':
    command => 'bash ./scripts/clone-dev.sh',
    cwd => '/home/vagrant/icebridge/icebridge-stack',
    path => '/bin:/usr/bin:/usr/local/bin',
    require => [Exec['clone icebridge-stack'], Exec['install docker-compose'], Package['jq']]
  }

  exec { 'vagrant permissions':
    command => 'chown -R vagrant:vagrant /home/vagrant/icebridge',
    path => '/bin',
    require => [Exec['clone all the icebridge repos']]
  }
}

exec { 'swarm':
  command => 'docker swarm init --advertise-addr eth0:2377 --listen-addr eth0:2377 || true',
  path => ['/usr/bin', '/usr/sbin',]
}
->
vcsrepo { "/home/vagrant/icebridge-stack":
  ensure   => present,
  provider => git,
  source   => 'git@bitbucket.org:nsidc/icebridge-stack.git',
  owner    => 'vagrant',
  group    => 'vagrant'
}
->
file { '/home/vagrant/icebridge-stack/scripts/docker-cleanup.sh':
  ensure => present,
  mode => 'u+x'
}
->
cron { 'docker-cleanup':
  command => '/home/vagrant/icebridge-stack/scripts/docker-cleanup.sh',
  user    => 'vagrant',
  hour    => '*'
}
