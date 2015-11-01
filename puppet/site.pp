# Load modules and classes
hiera_include('classes')

$icebridge_env = $environment ? {
  /(dev|integration)/ => 'integration',
  /qa/                => 'qa',
  /staging/           => 'staging',
  /blue/              => 'production',
  default             => 'integration'
}

apt::source { 'docker':
  comment  => 'This is the official Docker repository',
  location => 'https://apt.dockerproject.org/repo',
  release  => 'ubuntu-trusty',
  repos    => 'main',
  pin      => '500',
  key      => '58118E89F3A912897C070ADBF76221572C52609D',
  key_server => 'pgp.mit.edu',
  include_src => false,
  include_deb => true
}

if $environment == 'ci' {
  package { 'docker-engine':
    ensure => installed
  }
  ->
  group { 'docker':
    ensure => present,
    members => ['vagrant', 'jenkins'],
    notify => Service['jenkins']
  }
}
else {
  package { 'docker-engine':
    ensure => installed
  }
  ->
  group { 'docker':
    ensure => present,
    members => ['vagrant']
  }
}

exec { 'docker-compose':
  command => 'curl -L https://github.com/docker/compose/releases/download/1.5.0rc3/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose',
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
