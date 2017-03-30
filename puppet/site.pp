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
  line    => "export ICEBRIDGE_ENV=${icebridge_env}"
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

exec { 'swarm':
  command => 'docker swarm init --advertise-addr eth0:2377 --listen-addr eth0:2377',
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
exec { 'docker stack deploy --with-registry-auth --compose-file docker-stack.yml icebridge':
  cwd => '/home/vagrant/icebridge-stack',
  path => ['/usr/bin', '/usr/sbin',]
}
