# Load modules and classes
hiera_include('classes')

class { 'docker':
  version => '1.7.0',
  docker_users => [ 'vagrant', 'jenkins' ],
}

exec { 'docker-compose':
  command => 'curl -L https://github.com/docker/compose/releases/download/1.3.1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose',
  path => ['/bin', '/usr/bin']
}
