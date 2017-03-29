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
file {'docker-cleanup.sh':
  ensure => present,
  path   => '/etc/profile.d/docker-cleanup.sh',
  source => '/vagrant/scripts/docker-cleanup.sh'
}
->
file { 'envvars':
  ensure  => file,
  content => vault_template('/vagrant/puppet/templates/icebridge.erb'),
  path    => '/etc/profile.d/envvars.sh',
  before  => File['upstart-config']
}

if $environment == 'ci' {
  class { 'docker':
    version => '17.03.1~ce-0~ubuntu-trusty',
    docker_users => [ 'vagrant', 'jenkins' ],
    notify => Service['jenkins'],
    before => Exec['docker-compose']
  }
}
else {
  class { 'docker':
    version => '17.03.1~ce-0~ubuntu-trusty',
    docker_users => [ 'vagrant' ]
  }
}

file { 'upstart-config':
  ensure => file,
  path   => '/etc/init/icebridge.conf',
  source => '/vagrant/puppet/files/icebridge.conf',
  before => File['icebridge.sh']
}

if $icebridge_env == 'integration' {
  file {'icebridge.sh':
    ensure => present,
    path   => '/etc/profile.d/icebridge.sh',
    source => '/vagrant/docker-compose/versions/integration.sh'
  }
}
else {
  file {'icebridge.sh':
    ensure => present,
    path   => '/etc/profile.d/icebridge.sh',
    source => '/vagrant/docker-compose/versions/release.sh'
  }
}

file_line {'set ICEBRIDGE_ENV':
  path    => '/etc/profile.d/icebridge.sh',
  line    => "export ICEBRIDGE_ENV=${icebridge_env}",
  require => File['icebridge.sh']
  # notify  => Service['icebridge']
}

# service { 'icebridge':
#   ensure => 'running'
# }
