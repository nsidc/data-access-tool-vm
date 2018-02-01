# Load modules and classes
lookup('classes', {merge => unique}).include

$datasetorders_env = $environment ? {
  /(dev|integration)/ => 'integration',
  /qa/                => 'qa',
  /staging/           => 'staging',
  /blue/              => 'production',
  /production/        => 'production',
  default             => 'integration'
}

file { 'app-share':
  path   => "/share/apps/icebridge-portal/${datasetorders_env}",
  ensure => "directory"
}
->
file { 'rabbitmq-db-dir':
  path => "/share/apps/icebridge-portal/${datasetorders_env}/rabbitmq",
  ensure => "directory"
}
->
file { 'data-share':
  path   => "/share/apps/icebridge-order-data/${datasetorders_env}",
  ensure => "directory"
}
->
file { 'envvars':
  ensure  => file,
  content => vault_template('/vagrant/puppet/templates/datasetorders.erb'),
  path    => '/etc/profile.d/envvars.sh'
}
->
file { 'datasetorders.sh':
  ensure => present,
  path   => '/etc/profile.d/datasetorders.sh'
}
->
file_line {'set DATASETORDERS_ENV':
  path    => '/etc/profile.d/datasetorders.sh',
  line    => "export DATASETORDERS_ENV=${datasetorders_env}",
  before  => Exec['swarm']
}

if $environment == 'dev' {

  exec { 'setup node':
    command => 'curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash - && sudo apt-get install -y nodejs',
    path => '/usr/bin'
  }

  package { 'jq': }

  exec { 'clone datasetorders-stack':
    command => 'mkdir -p /home/vagrant/datasetorders && git clone git@bitbucket.org:nsidc/dataset-orders-stack.git /home/vagrant/datasetorders/datasetorders-stack',
    creates => '/home/vagrant/datasetorders/datasetorders-stack',
    path => '/usr/bin:/bin'
  }

  # don't check this in
  exec { 'dev branch':
    command => 'git checkout dataset-orders',
    cwd => '/home/vagrant/datasetorders/datasetorders-stack',
    path => '/usr/bin',
    require => [Exec['clone datasetorders-stack'], Package['jq']]
  } ->

  exec { 'clone all the datasetorders repos':
    command => 'bash ./scripts/clone-dev.sh',
    cwd => '/home/vagrant/datasetorders/datasetorders-stack',
    path => '/bin:/usr/bin:/usr/local/bin',
    require => [Exec['clone datasetorders-stack'], Package['jq']]
  }

  exec { 'vagrant permissions':
    command => 'chown -R vagrant:vagrant /home/vagrant/datasetorders',
    path => '/bin',
    require => [Exec['clone all the datasetorders repos']]
  }
}

exec { 'swarm':
  command => 'docker swarm init --advertise-addr eth0:2377 --listen-addr eth0:2377 || true',
  path => ['/usr/bin', '/usr/sbin',]
}
->
vcsrepo { "/home/vagrant/datasetorders/datasetorders-stack":
  ensure   => present,
  provider => git,
  source   => 'git@bitbucket.org:nsidc/dataset-orders-stack.git',
  owner    => 'vagrant',
  group    => 'vagrant'
}
->
file { '/home/vagrant/datasetorders/datasetorders-stack/scripts/docker-cleanup.sh':
  ensure => present,
  mode => 'u+x'
}
->
cron { 'docker-cleanup':
  command => '/home/vagrant/datasetorders/datasetorders-stack/scripts/docker-cleanup.sh',
  user    => 'vagrant',
  hour    => '*'
}
