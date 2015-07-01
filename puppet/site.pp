# Load modules and classes
hiera_include('classes')

if $environment != 'ci' {

  ############
  #  NGINX
  ############

  package { 'nginx':
    ensure => 'present'
  }

  exec { 'enable-nginx-logging':
    command => 'sudo chown -R www-data:www-data /var/log/nginx; sudo chmod -R 755 /var/log/nginx',
    path    => '/bin:/usr/bin',
    require => Package['nginx']
  }

  file { 'add-nginx-site':
    path    => '/etc/nginx/sites-available/icebridge',
    source => "/vagrant/puppet/files/nginx/icebridge.conf",
    ensure  => file,
    require => Package['nginx'],
  }

  file { 'enable-nginx-site':
    ensure  => link,
    path    => '/etc/nginx/sites-enabled/icebridge',
    target  => '/etc/nginx/sites-available/icebridge',
    require => File['add-nginx-site']
  }

  exec { "/usr/bin/sudo service nginx restart":
    require => File["enable-nginx-site"]
  }

  exec { "rm-default-conf":
    command => "/bin/rm -f /etc/nginx/conf.d/default.conf || true"
  }

  ############
  #  NODE
  ############

  class { 'nodejs':
    version      => 'stable',
    make_install => false,
  }

  file { '/usr/bin/node':
    ensure  => 'link',
    target  => '/usr/local/node/node-default/bin/node',
    require => Class['nodejs']
  }

  file { '/usr/bin/npm':
    ensure  => 'link',
    target  => '/usr/local/node/node-default/bin/npm',
    require => Class['nodejs']
  }

  $cmd = 'sudo npm install grunt-cli jspm -g'
  exec { 'install-node-deps':
    command => $cmd,
    path    => '/usr/bin',
    require => File['/usr/bin/npm']
  }

  ###########
  #
  ###########

  file { '/etc/init/icebridge-services.conf':
    ensure => file,
    source => "/vagrant/puppet/files/upstart/icebridge-services.conf"
  }

  file { '/etc/init/celery-workers.conf':
    ensure => file,
    source => "/vagrant/puppet/files/upstart/celery-workers.conf"
  }

  file { '/opt/icebridge-portal':
    ensure => 'directory',
    owner  => 'vagrant'
  }

  packagecloud::repo { "rabbitmq/rabbitmq-server":
    type => 'deb'
  }

  package { 'rabbitmq-server':
    ensure => 'present'
  }

  include '::mongodb::server'
}

file { '/opt/icebridge-services':
  ensure => 'directory',
  owner  => 'vagrant'
}
