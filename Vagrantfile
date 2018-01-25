# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.provider :vsphere do |vsphere|
    vsphere.memory_mb = 8192
    vsphere.cpu_count = 4
  end

  config.vm.provision :shell do |s|
    s.name = 'emacs'
    s.inline = 'sudo add-apt-repository -y ppa:kelleyk/emacs ; '\
               'sudo apt-get update ; '\
               'sudo apt-get install -y emacs25 ; '

  end

  config.vm.provision :shell do |s|
    s.name = 'dotfiles'
    s.inline = 'cd /home/vagrant/michaeljb-dotfiles/ && ./all.sh'
  end
end
