# Load modules and classes
hiera_include('classes')

if $environment == 'ci' {
  class { 'docker':
    version => '1.7.0',
    docker_users => [ 'vagrant', 'jenkins' ],
    notify => Service['jenkins']
  }
}
else {
  class { 'docker':
    version => '1.7.0',
    docker_users => [ 'vagrant' ]
  }
}

exec { 'docker-compose':
  command => 'curl -L https://github.com/docker/compose/releases/download/1.4.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose',
  path => ['/bin', '/usr/bin'],
  creates => '/usr/local/bin/docker-compose'
}

file { 'app-share':
  path  => "/share/apps/icebridge-portal/${environment}",
  ensure => "directory"
}

file { 'upstart-config':
  ensure => file,
  path   => '/etc/init/icebridge.conf',
  source => '/vagrant/puppet/files/icebridge.conf'
}
