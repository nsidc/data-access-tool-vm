# Load modules and classes
lookup('classes', {merge => unique}).include

# NOTE: only dev is currently supported.

class {'docker':
  # TODO: update version
  # version      => '5:26.1.1-1~ubuntu.22.04~jammy',
  docker_users => ['vagrant'],
}

class {'docker::compose':
  ensure  => 'present',
  # TODO: update version
  # version => '1.28.5',
}

file { 'envvars':
  ensure  => file,
  content => vault_template('/vagrant/puppet/templates/dat.erb'),
  path    => '/etc/profile.d/envvars.sh'
}

file { '/home/vagrant/data-access-tool':
  ensure => directory,
  owner  => vagrant,
} ->
vcsrepo { 'clone data-access-tool-backend':
  ensure   => present,
  path     => '/home/vagrant/data-access-tool/data-access-tool-backend',
  provider => git,
  source   => 'git@github.com:nsidc/data-access-tool-backend.git',
  owner    => 'vagrant',
  group    => 'vagrant',
  revision => 'main',
}
