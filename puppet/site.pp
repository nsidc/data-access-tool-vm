# Load modules and classes
hiera_include('classes')

if $environment != 'ci' {

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
    ensure => 'directory'
  }
}
