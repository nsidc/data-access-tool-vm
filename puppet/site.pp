# Load modules and classes
hiera_include('classes')

if $environment != 'ci' {

############
#  NGINX
############

  include nginx

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
    notify  => Service["nginx"],
    require => File['add-nginx-site']
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

  $hiera_project = hiera('project')
  $application_root = "/opt/${hiera_project}"

  exec { "rm-default-conf":
    command => "/bin/rm -f /etc/nginx/conf.d/default.conf || true"
  }

  file { '/opt/icebridge-portal':
    ensure => 'directory',
    owner  => 'vagrant'
  }
}
