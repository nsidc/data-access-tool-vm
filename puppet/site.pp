# Load modules and classes
hiera_include('classes')

if $environment == 'ci' {

  class { 'nodejs':
    version      => 'stable',
    make_install => false,
  }

  file { '/usr/bin/node':
    ensure  => 'link',
    target  => '/usr/local/node/node-default/bin/node',
    require => Class['nodejs']
  }

  $cmd = 'sudo /usr/local/node/node-default/bin/npm install grunt-cli -g'
  exec { 'install-node-deps':
    command => $cmd,
    path    => '/usr/bin',
    require => Class['nodejs']
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
