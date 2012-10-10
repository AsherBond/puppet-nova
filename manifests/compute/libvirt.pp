class nova::compute::libvirt (
  $libvirt_type = 'kvm',
  $vncserver_listen = '127.0.0.1'
) {

  include nova::params

  Service['libvirt'] -> Service['nova-compute']

  if($::nova::params::compute_package_name) {
    package { "nova-compute-${libvirt_type}":
      ensure => present,
      before => Package['nova-compute'],
    }
  }

  package { 'libvirt':
    name   => $::nova::params::libvirt_package_name,
    ensure => present,
  }

  service { 'libvirt' :
    name     => $::nova::params::libvirt_service_name,
    ensure   => running,
    provider => $::nova::params::special_service_provider,
    require  => Package['libvirt'],
  }

  case $libvirt_type {
    'kvm': {
      package { $::nova::params::libvirt_type_kvm:
        ensure => present,
        before => Package['nova-compute'],
      }
    }
  }

    'libvirt_type':     value => $libvirt_type;
    'connection_type':  value => 'libvirt';
    'vncserver_listen': value => $vncserver_listen;
  }
}
