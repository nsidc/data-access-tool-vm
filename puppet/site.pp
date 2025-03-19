# Load modules and classes
lookup('classes', {merge => unique}).include

class {'docker':
  docker_users => ['vagrant'],
}

class {'docker::compose':
  ensure  => 'present',
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
  # TODO: change this back to `main` once merged.
  revision => 'dev-and-prod-server-settings',
}

if $::environment == 'dev' {
  # Setup symlink for docker-compose dev
  exec { 'setup backend docker-compose-dev':
    command => 'ln -s docker-compose.dev.yml docker-compose.override.yml',
    path => '/usr/bin/',
    cwd    => '/home/vagrant/data-access-tool/data-access-tool-backend',
    unless => 'test -f /home/vagrant/data-access-tool/data-access-tool-backend/docker-compose.override.yml',
    require => [Vcsrepo['clone data-access-tool-backend']],
  }

  # Bring up the stack with docker compose up --detach.
  # TODO: this does not work. The images get built but the stack is not up,
  # despite the logs showing success...
  exec { 'up-docker-stack':
    command => 'bash -lc "nohup docker compose up --detach"',
    path => '/usr/bin/',
    cwd    => '/home/vagrant/data-access-tool/data-access-tool-backend',
    user => 'vagrant',
    require => [
      Vcsrepo['clone data-access-tool-backend'],
      Exec['setup backend docker-compose-dev'],
      Class['docker'],
      Class['docker::compose'],
    ],
  }
} else {
  # Bring up the stack with docker compose up --detach.
  # TODO: this does not work. The images get built but the stack is not up,
  # despite the logs showing success...
  exec { 'up-docker-stack':
    # TODO: remove build setep once images are published and we have
    # version-driven releases
    command => 'bash -lc "nohup docker compose up --detach"',
    path => '/usr/bin/',
    cwd    => '/home/vagrant/data-access-tool/data-access-tool-backend',
    user => 'vagrant',
    require => [
      Vcsrepo['clone data-access-tool-backend'],
      Class['docker'],
      Class['docker::compose'],
    ],
  }
}
