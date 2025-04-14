# Load modules and classes
lookup('classes', {merge => unique}).include

class {'docker':
  docker_users => ['vagrant'],
}

class {'docker::compose':
  ensure  => 'present',
}

if $::environment in ['dev', 'integration'] {
  $dat_backend_revision = 'main'
} else {
  $dat_backend_revision = strip(file('/vagrant/DAT_BACKEND_VERSION.txt'))
}

vcsrepo { 'clone data-access-tool-backend':
  ensure   => present,
  path     => '/home/vagrant/data-access-tool/data-access-tool-backend',
  provider => git,
  source   => 'git@github.com:nsidc/data-access-tool-backend.git',
  owner    => 'vagrant',
  group    => 'vagrant',
  revision => $dat_backend_revision,
}

$nfs_share_logs_dir = $::environment ? {
  'dev'   => "/share/logs/data_access_tool/${::environment}/${provisioned_by}",
  default => "/share/logs/data_access_tool/${::environment}"
}

$local_logs_dir = "/home/vagrant/data-access-tool/data-access-tool-backend/logs"

exec { 'make_local_logs_dir':
  command => "mkdir -p ${local_logs_dir}/server",
  path => '/usr/bin/',
  user => 'vagrant',
}

file { 'envvars':
  ensure  => file,
  content => vault_template('/vagrant/puppet/templates/dat.erb'),
  path    => '/etc/profile.d/envvars.sh'
}

nsidc_nfs::sharemount { '/share/logs/data_access_tool':
  options => 'rw',
  project => 'logs',
  share   => "data_access_tool",
}->
exec { 'make_logs_subdir':
  command => "mkdir -p ${nfs_share_logs_dir}/server",
  path => '/usr/bin/',
  user => 'vagrant',
}->
exec {'chown_logs_subdir':
  command => "chown -R vagrant:vagrant ${nfs_share_logs_dir}",
  path => '/usr/bin/',
}

file { 'nginx_logrotate':
  ensure  => file,
  content => template('/vagrant/puppet/templates/logrotate_server.erb'),
  path    => '/etc/logrotate.d/server',
  owner   => 'root',
  group   => 'root',
  require => [Exec['make_logs_subdir']],
}


# Setup symlink for docker-compose
$override_file = $environment ? {
  'dev'         => 'docker-compose.dev.yml',
  'integration' => 'docker-compose.integration.yml',
  default       => 'docker-compose.production.yml',
}
exec { 'setup backend docker-compose override':
  command => "ln -s ${override_file} docker-compose.override.yml",
  path => '/usr/bin/',
  cwd    => '/home/vagrant/data-access-tool/data-access-tool-backend',
  unless => 'test -f /home/vagrant/data-access-tool/data-access-tool-backend/docker-compose.override.yml',
  require => [Vcsrepo['clone data-access-tool-backend']],
}

if $::environment == 'dev' {

  exec { 'build-docker-stack':
    command => 'bash -lc "docker compose build"',
    path => '/usr/bin/',
    cwd    => '/home/vagrant/data-access-tool/data-access-tool-backend',
    user => 'vagrant',
    require => [
      File['envvars'],
      Vcsrepo['clone data-access-tool-backend'],
      Exec['setup backend docker-compose override'],
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
      Exec['setup backend docker-compose override'],
      Class['docker'],
      Class['docker::compose'],
      Exec['chown_logs_subdir'],
      Exec['make_local_logs_dir'],
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
      Exec['setup backend docker-compose override'],
      Class['docker'],
      Class['docker::compose'],
      Exec['chown_logs_subdir'],
      Exec['make_local_logs_dir'],
    ],
  }
}
