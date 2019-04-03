# Load modules and classes
lookup('classes', {merge => unique}).include

$stackdir = '/home/vagrant/hermes/hermes-stack'
$docker_nfs_volumes = ['/share/apps/hermes/rabbitmq', '/share/logs/hermes/api',
  '/share/logs/hermes/notification', '/share/logs/hermes/webserver', '/share/logs/hermes/workers',]

if $::environment == 'dev' {
  $dev_name = chomp(generate('/bin/sed', 's/^dev\.[^.]*\.\([^.]*\).*$/\1/', '/etc/fqdn'))
}

$esi_environment = $::environment ? {
  'staging' => 'uat',
  default   => 'prod',
}

$db_host = $::environment ? {
  'dev'        => "dev.hermes2-db.${dev_name}.dev.int.nsidc.org",
  'production' => "hermes2-db.apps.int.nsidc.org",
  default      => "${::environment}.hermes2-db.apps.int.nsidc.org",
}
$ops_emails = $::environment ? {
  'production' => 'ops@nsidc.org',
  'qa'         => 'stephanie.heacox@nsidc.org',
  default      => '',
}

$nfs_share_postfix = $::environment ? {
  'dev'   => "${::environment}/${dev_name}",
  'ci'    => '',
  default => "${::environment}"
}

nsidc_nfs::sharemount { '/share/apps/hermes':
  options => 'rw',
  project => 'apps',
  share   => "hermes/__2__/${nfs_share_postfix}",
}
nsidc_nfs::sharemount { '/share/apps/hermes-orders':
  options => 'rw',
  project => 'appdata',
  share   => "hermes-orders/${nfs_share_postfix}",
}
nsidc_nfs::sharemount { '/share/logs/hermes':
  options => 'rw',
  project => 'logs',
  share   => "hermes/__2__/${nfs_share_postfix}",
}

# Our VMs have an older version of vmware-tools which can cause failure to SSH to machines running docker
package { 'open-vm-tools': }

if $::environment != 'ci' {
  exec { 'install docker and compose':
    command => '/vagrant/puppet/scripts/install-docker.sh',
  }

  # Because our containers must run as non-root users to write on NFS, we need to pre-chown all volumes
  file { $docker_nfs_volumes:
    ensure  => 'directory',
    owner   => 'vagrant',
    group   => 'docker',
    require => Nsidc_nfs::Sharemount['/share/logs/hermes', '/share/apps/hermes',],
  } ->
  file { 'envvars':
    ensure  => file,
    content => vault_template('/vagrant/puppet/templates/hermes.erb'),
    path    => '/etc/profile.d/envvars.sh'
  }

  file { '/home/vagrant/hermes':
    ensure => directory,
    owner  => vagrant,
  } ->
  vcsrepo { 'clone hermes-stack':
    ensure   => present,
    path     => '/home/vagrant/hermes/hermes-stack',
    provider => git,
    source   => 'git@bitbucket.org:nsidc/hermes-stack.git',
    owner    => 'vagrant',
    group    => 'vagrant'
  }

  package { 'jq': }

  if $environment == 'dev' {

    exec { 'setup node':
      command => 'curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash - && sudo apt-get install -y nodejs',
      path    => '/usr/bin'
    }

    exec { 'clone all the hermes repos':
      command => 'bash ./scripts/clone-dev.sh',
      cwd     => '/home/vagrant/hermes/hermes-stack',
      path    => '/bin:/usr/bin:/usr/local/bin',
      require => [Package['jq'],
                  Vcsrepo['clone hermes-stack']]
    } ->

    exec { 'vagrant permissions':
      command => 'chown -R vagrant:vagrant /home/vagrant/hermes',
      path    => '/bin'
    }
  }

  $service_versions_target = $::environment ? {
    'production' => 'prod',
    'staging'    => 'prod',
    'qa'         => 'prod',
    default      => 'integration',
  }
  file { "${stackdir}/service-versions.env":
    ensure  => link,
    target  => "${stackdir}/service-versions.${service_versions_target}.env",
    owner   => vagrant,
    require => Vcsrepo['clone hermes-stack'],
  }

  file { "${stackdir}/scripts/docker-cleanup.sh":
    ensure  => present,
    mode    => 'u+x',
    require => [Exec['install docker and compose'], Vcsrepo['clone hermes-stack']],
  } ->
  cron { 'docker-cleanup':
    command => "${stackdir}/scripts/docker-cleanup.sh",
    user    => 'vagrant',
    hour    => '*',
    minute  => '0',
  }

  if $environment == 'dev' {
    file { "${stackdir}/docker-compose.override.yml":
      ensure  => link,
      target  => "${stackdir}/docker-compose.dev.yml",
      owner   => vagrant,
      require => Vcsrepo['clone hermes-stack'],
    } ->
    exec { 'build hermes-stack':
      command => '/bin/bash -c "./scripts/build-dev.sh"',
      cwd     => "${stackdir}",
      user    => 'vagrant',
      timeout => 600,
      require => [Exec['install docker and compose'],
                  File["${stackdir}/service-versions.env"],
                  Exec['clone all the hermes repos'],
                  File['envvars']],
      # sometimes getting a mysterious error from docker-compose build that
      # resolves by simply trying again; finding the root of that problem would be
      # better than retrying here
      tries   => 3
    } ->
    exec { 'start hermes-stack':
      command => '/bin/bash -lc "./scripts/start-dev.sh"',
      cwd     => "${stackdir}",
      user    => 'vagrant',
      # sometimes getting a mysterious error from docker-compose build that
      # resolves by simply trying again; finding the root of that problem would be
      # better than retrying here
      tries   => 3,
      require => [Exec['install docker and compose'],
                  File['envvars'],
                  Package['jq'],
                  File[$docker_nfs_volumes],
                  Nsidc_nfs::Sharemount['/share/apps/hermes-orders']]
    }
  }
  else {
    exec { 'swarm':
      command => 'docker swarm init --advertise-addr eth0:2377 --listen-addr eth0:2377 || true',
      user    => 'vagrant',
      path    => ['/usr/bin', '/usr/sbin',],
      require => Exec['install docker and compose'],
    } ->
    exec { 'start hermes-stack':
      command => '/bin/bash -lc "/home/vagrant/hermes/hermes-stack/scripts/deploy.sh"',
      cwd     => "${stackdir}",
      user    => 'vagrant',
      require => [Exec['install docker and compose'],
                  File["${stackdir}/service-versions.env"],
                  Exec['swarm'],
                  File['envvars'],
                  Package['jq'],
                  File[$docker_nfs_volumes],
                  Nsidc_nfs::Sharemount['/share/apps/hermes-orders']]
    }
  }
}
