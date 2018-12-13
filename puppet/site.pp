# Load modules and classes
lookup('classes', {merge => unique}).include

$stackdir = '/home/vagrant/hermes/hermes-stack'

if $::environment == 'dev' {
  $dev_name = chomp(generate('/bin/sed', 's/^dev\.[^.]*\.\([^.]*\).*$/\1/', '/etc/fqdn'))
}

$db_host = $::environment ? {
  'dev'        => "dev.hermes-db.${dev_name}.dev.int.nsidc.org",
  'production' => "hermes-db.apps.int.nsidc.org",
  default      => "${::environment}.hermes-db.apps.int.nsidc.org",
}

$nfs_share_postfix = $::environment ? {
  'dev'   => "${::environment}/${dev_name}",
  'ci'    => '',
  default => "${::environment}"
}

nsidc_nfs::sharemount { '/share/apps/hermes':
  options => 'rw',
  project => 'apps',
  share   => "hermes/${nfs_share_postfix}",
}
nsidc_nfs::sharemount { '/share/apps/hermes-orders':
  options => 'rw',
  project => 'appdata',
  share   => "hermes-orders/${nfs_share_postfix}",
}
nsidc_nfs::sharemount { '/share/logs/hermes':
  options => 'rw',
  project => 'logs',
  share   => "hermes/${nfs_share_postfix}",
}

exec { 'install docker and compose':
  command => '/vagrant/puppet/scripts/install-docker.sh',
}

# Our VMs have an older version of vmware-tools which can cause failure to SSH to machines running docker
package { 'open-vm-tools': }

if $::environment != 'ci' {
  file { 'rabbitmq-db-dir':
    path   => "/share/apps/hermes/rabbitmq",
    ensure => "directory",
    require => Nsidc_nfs::Sharemount['/share/apps/hermes']
  }
  ->
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
  }
  ->
  cron { 'docker-cleanup':
    command => "${stackdir}/scripts/docker-cleanup.sh",
    user    => 'vagrant',
    hour    => '*',
    minute    => '0',
  }

  if $environment == 'dev' {
    File { "${stackdir}/docker-compose.override.yml":
      ensure  => link,
      target  => "${stackdir}/docker-compose.dev.yml",
      owner   => vagrant,
      require => Vcsrepo['clone hermes-stack'],
    } ->
    exec { 'build hermes-stack':
      command => '/bin/bash -c "./scripts/build-dev.sh"',
      cwd     => "${stackdir}",
      timeout => 600,
      require => [Exec['install docker and compose'],
                  File["${stackdir}/service-versions.env"],
                  Exec['clone all the hermes repos'],
                  File['envvars']],
      # sometimes getting a mysterious error from docker-compose build that
      # resolves by simply trying again; finding the root of that problem would be
      # better than retrying here
      tries => 3
    } ->
    exec { 'start hermes-stack':
      command => '/bin/bash -lc "./scripts/start-dev.sh"',
      cwd     => "${stackdir}",
      # sometimes getting a mysterious error from docker-compose build that
      # resolves by simply trying again; finding the root of that problem would be
      # better than retrying here
      tries   => 3,
      require => [Exec['install docker and compose'],
                  File['envvars'],
                  Package['jq'],
                  Nsidc_nfs::Sharemount['/share/logs/hermes'],
                  Nsidc_nfs::Sharemount['/share/apps/hermes'],
                  Nsidc_nfs::Sharemount['/share/apps/hermes-orders']]
    }
  }
  else {
    exec { 'swarm':
      command => 'docker swarm init --advertise-addr eth0:2377 --listen-addr eth0:2377 || true',
      path    => ['/usr/bin', '/usr/sbin',],
      require => Exec['install docker and compose'],
    }
    ->
    exec { 'start hermes-stack':
      command => '/bin/bash -lc "/home/vagrant/hermes/hermes-stack/scripts/deploy.sh"',
      cwd     => "${stackdir}",
      require => [Exec['install docker and compose'],
                  File["${stackdir}/service-versions.env"],
                  Exec['swarm'],
                  File['envvars'],
                  Package['jq'],
                  Nsidc_nfs::Sharemount['/share/logs/hermes'],
                  Nsidc_nfs::Sharemount['/share/apps/hermes'],
                  Nsidc_nfs::Sharemount['/share/apps/hermes-orders']]
    }
  }
}
