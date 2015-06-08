# Load modules and classes
hiera_include('classes')

class { 'nodejs':
  version      => 'stable',
  make_install => false,
}

file { '/usr/bin/node':
  ensure  => 'link',
  target  => '/usr/local/node/node-default/bin/node',
  require => Class['nodejs']
}

$cmd = 'sudo /usr/local/node/node-default/bin/npm install grunt-cli jspm -g'
exec { 'install-node-deps':
  command => $cmd,
  path    => '/usr/bin',
  require => Class['nodejs']
}

if $environment == 'ci' {

  class { '::phantomjs':
      package_version => '1.9.7',
      package_update => true,
      install_dir => '/usr/local/bin',
      source_dir => '/opt',
      timeout => 300
  }

  # For acceptance tests
  package { 'vnc4server': } ->
  package { 'expect': } ->
  exec { 'set_vnc_password':
    path => '/usr/bin/',
    command => 'sudo -i -u jenkins tr -dc A-Z < /dev/urandom | head -c 8 | /usr/bin/expect -c "set passwd [read stdin]; spawn sudo -i -u jenkins vncpasswd; expect \"Password:\"; send -- \"\$passwd\r\"; expect \"Verify:\"; send -- \"\$passwd\r\r\";exit;"'
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
