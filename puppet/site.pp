# Load modules and classes
lookup('classes', {merge => unique}).include

class {'docker':
  docker_users => ['vagrant'],
}

class {'docker::compose':
  ensure  => 'present',
}

# Logs are rotated here for long-term storage
$nfs_share_logs_dir = $::environment ? {
  'dev'   => "/share/logs/data_access_tool/${::environment}/${provisioned_by}",
  default => "/share/logs/data_access_tool/${::environment}"
}
# Logs are written directly to local storage.
$local_logs_dir = "/home/vagrant/logs/"

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

if $::environment == 'dev' {

  vcsrepo { 'clone data-access-tool-backend':
    ensure   => present,
    path     => '/opt/deploy/data-access-tool-backend',
    provider => git,
    source   => 'git@github.com:nsidc/data-access-tool-backend.git',
    owner    => 'vagrant',
    group    => 'vagrant',
    revision => 'da113-garrison-deploy',
  }

  # Setup symlink for docker-compose
  exec { 'setup backend docker-compose override':
    command => "ln -s docker-compose.dev.yml docker-compose.override.yml",
    path => '/usr/bin/',
    cwd    => '/opt/deploy/data-access-tool-backend',
    unless => 'test -f /opt/deploy/data-access-tool-backend/docker-compose.override.yml',
    require => [Vcsrepo['clone data-access-tool-backend']],
  }


  # Create conda environment on dev VM for utilities like `bump-my-version`
  exec { 'conda-init':
    command       => 'conda init bash',
    path          => '/opt/miniconda/bin/:/bin:/usr/bin/',
    user          => 'vagrant',
    unless        => 'cat /home/vagrant/.bashrc | grep -i "conda initialize"',
    require       => [
      Nsidc_miniconda::Install['/opt/miniconda'],
    ],
  }

  exec { 'install-mamba':
    # Install mamba
    command       => "conda install 'mamba ~=1.5.10'",
    path          => '/opt/miniconda/bin/:/bin/:/usr/bin/',
    user          => 'vagrant',
    unless        => "which mamba",
    require       => [Nsidc_miniconda::Install['/opt/miniconda']],
  }

  exec { 'mamba-init':
    command       => 'mamba init bash',
    path          => '/opt/miniconda/bin/:/bin/:/usr/bin/',
    user          => 'vagrant',
    unless        => 'cat /home/vagrant/.bashrc | grep -i "mamba"',
    require       => [
      Nsidc_miniconda::Install['/opt/miniconda'],
      Exec['install-mamba'],
    ],
  }

  exec { 'create-environment':
    command   => "/bin/bash -lc \"mamba env create -f environment.yml\"",
    user      => 'vagrant',
    path      => '/bin/:/opt/miniconda/bin/:/usr/bin/',
    cwd       => '/opt/deploy/data-access-tool-backend',
    timeout   => 1200,
    logoutput => true,
    unless    => "conda env list | grep dat-backend",
    require   => [
      Nsidc_miniconda::Install['/opt/miniconda'],
      Exec['conda-init'],
      Exec['mamba-init'],
      Vcsrepo['clone data-access-tool-backend'],
    ],
  }

  exec { 'default_env':
    command       => "echo 'source activate dat-backend' >> /home/vagrant/.bashrc",
    path          => '/bin/:/usr/bin/',
    user          => 'vagrant',
    unless        => "grep 'source activate dat-backend' /home/vagrant/.bashrc",
    require       => [
      Exec['conda-init'],
      Exec['create-environment'],
      File[$env_file],
    ],
  }

  exec { "pre-commit-install":
    command   => "/bin/bash -lc \"pre-commit install\"",
    user      => "vagrant",
    cwd       => "/opt/deploy/data-access-tool-backend",
    path      => "/opt/miniconda/envs/dat-backend/bin/:/usr/bin/",
    logoutput => true,
    require   => [
      Exec['create-environment'],
      Exec['default_env'],
    ],
  }

  exec { 'build-docker-stack':
    command => 'bash -lc "docker compose build"',
    path => '/usr/bin/',
    cwd    => '/opt/deploy/data-access-tool-backend',
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
    command => 'bash -lc "/vagrant/scripts/deploy_to_dev.sh"',
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
  # Non-dev deployments put config specific to them here.
  # TODO: consider setting up docker swarm for non-dev environments
}
