# Load modules and classes
hiera_include('classes')

if $environment == 'ci' {
  # install npm, grunt
  include nodejs

  package { 'grunt-cli':
    ensure => present,
    provider => 'npm',
    require => Class['nodejs'],
  }

  # willdurand-nodejs installs the executables into
  # /usr/local/node/node-default/bin/, we want access to them on the
  # PATH, so create symlinks in /usr/local/bin

  $node_path = '/usr/local/node/node-default/bin'

  file { '/usr/local/bin/node':
    ensure => 'link',
    target => "$node_path/node",
    require => Class['nodejs']
  }

  file { '/usr/local/bin/npm':
    ensure => 'link',
    target => "$node_path/npm",
    require => Class['nodejs']
  }

  file { '/usr/local/bin/grunt':
    ensure => 'link',
    target => "$node_path/grunt",
    require => Package['grunt-cli']
  }
} else {

  $hiera_project = hiera('project')
  $application_root = "/opt/${hiera_project}"

  class { 'nginx': }

  nginx::resource::vhost { 'icebridge':
    www_root => $application_root,
  }

  # remove default nginx config
  nginx::resource::vhost { 'localhost' :
    www_root => '/usr/share/nginx/html',
    ensure  =>  absent
  }

  exec { "rm-default-conf":
    command => "/bin/rm -f /etc/nginx/conf.d/default.conf || true"
  }
}
