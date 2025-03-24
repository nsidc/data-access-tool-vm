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
  revision => 'main',
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

  vcsrepo { 'clone data-access-tool-server':
    ensure   => present,
    path     => '/home/vagrant/data-access-tool/data-access-tool-server',
    provider => git,
    source   => 'git@github.com:nsidc/data-access-tool-server.git',
    owner    => 'vagrant',
    group    => 'vagrant',
    revision => 'main',
  }

  exec { 'build-docker-stack':
    command => 'bash -lc "docker compose build"',
    path => '/usr/bin/',
    cwd    => '/home/vagrant/data-access-tool/data-access-tool-backend',
    user => 'vagrant',
    require => [
      File['envvars'],
      Vcsrepo['clone data-access-tool-backend'],
      Vcsrepo['clone data-access-tool-server'],
      Exec['setup backend docker-compose-dev'],
      Class['docker'],
      Class['docker::compose'],
    ],
  } ->
  exec { 'up-docker-stack':
    command => 'bash -lc "/vagrant/scripts/deploy.sh"',
    path => '/usr/bin/',
    user => 'vagrant',
    require => [
      File['envvars'],
      Vcsrepo['clone data-access-tool-backend'],
      Class['docker'],
      Class['docker::compose'],
    ],
  }
} else {
  exec { 'up-docker-stack':
    command => 'bash -lc "/vagrant/scripts/deploy.sh"',
    path => '/usr/bin/',
    user => 'vagrant',
    require => [
      File['envvars'],
      Vcsrepo['clone data-access-tool-backend'],
      Class['docker'],
      Class['docker::compose'],
    ],
  }
}
