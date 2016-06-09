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

if $environment == 'ci' {
  class { 'docker':
    version => '1.10.3-0~trusty',
    docker_users => [ 'vagrant', 'jenkins' ],
    notify => Service['jenkins']
  }
}
else {
  class { 'docker':
    version => '1.10.3-0~trusty',
    docker_users => [ 'vagrant' ]
  }
}

exec { 'docker-compose':
  command => 'curl -L https://github.com/docker/compose/releases/download/1.6.2/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose',
  path => ['/bin', '/usr/bin'],
  creates => '/usr/local/bin/docker-compose'
}

file { 'app-share':
  path  => "/share/apps/icebridge-portal/${icebridge_env}",
  ensure => "directory"
}

file { 'upstart-config':
  ensure => file,
  path   => '/etc/init/icebridge.conf',
  source => '/vagrant/puppet/files/icebridge.conf'
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
}

# Directory to contain order data
file { '/icebridge':
  ensure => 'directory'
}
->
file { '/icebridge/orders':
  ensure => 'directory',
}
