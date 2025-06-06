# == Class: nova::vncproxy
#
# Configures nova vnc proxy
#
# === Parameters:
#
# [*enabled*]
#   (optional) Whether to run the vncproxy service
#   Defaults to true
#
# [*manage_service*]
#   (optional) Whether to start/stop the service
#   Defaults to true
#
# [*host*]
#   (optional) Host on which to listen for incoming requests
#   Defaults to '0.0.0.0'
#
# [*port*]
#   (optional) Port on which to listen for incoming requests
#   Defaults to 6080
#
# [*ensure_package*]
#   (optional) The state of the nova-novncproxy package
#   Defaults to 'present'
#
# [*vncproxy_protocol*]
#   (optional) The protocol to communicate with the VNC proxy server
#   Defaults to 'http'
#
# [*vncproxy_path*]
#   (optional) The path at the end of the uri for communication with the VNC
#   proxy server
#   Defaults to '/vnc_auto.html'
#
# [*allow_noauth*]
#   (optional) Whether connections to unauthenticated/unencrypted VNC servers
#   are permitted.
#   Defaults to true
#
# [*allow_vencrypt*]
#   (optional) Whether connections to VNC servers supporting vencrypt are
#   permitted.
#   Defaults to false
#
# [*vencrypt_key*]
#   (optional) path to the private key to use when connecting to VNC servers
#   supporting vencrypt
#   Required when allow_vencrypt is true.
#   Defaults to undef
#
# [*vencrypt_cert*]
#   (optional) path to the certificate to use when connecting to VNC servers
#   supporting vencrypt
#   Required when allow_vencrypt is true.
#   Defaults to undef
#
# [*vencrypt_ca*]
#   (optional) path to the certificate authority cert to use when connecting
#   to VNC servers that supporting vencrypt
#   Defaults to $facts['os_service_default']
#
class nova::vncproxy(
  Boolean $enabled                         = true,
  Boolean $manage_service                  = true,
  Enum['http', 'https'] $vncproxy_protocol = 'http',
  String[1] $host                          = '0.0.0.0',
  Stdlib::Port $port                       = 6080,
  String $vncproxy_path                    = '/vnc_auto.html',
  $ensure_package                          = 'present',
  Boolean $allow_noauth                    = true,
  Boolean $allow_vencrypt                  = false,
  $vencrypt_key                            = undef,
  $vencrypt_cert                           = undef,
  $vencrypt_ca                             = $facts['os_service_default'],
) {

  include nova::deps
  include nova::params

  if (!$allow_noauth and !$allow_vencrypt) {
    fail('Either allow_noauth or allow_vencrypt must be true')
  }

  if $allow_vencrypt {

    if (!$vencrypt_cert or !$vencrypt_key) {
      fail('vencrypt_cert and vencrypt_key are required when allow_vencrypt is true')
    }
    nova_config {
      'vnc/vencrypt_ca_certs':    value => $vencrypt_ca;
      'vnc/vencrypt_client_cert': value => $vencrypt_cert;
      'vnc/vencrypt_client_key':  value => $vencrypt_key;
    }

    if $allow_noauth {
      $auth_schemes = 'vencrypt,none'
    } else {
      $auth_schemes = 'vencrypt'
    }
  } else {
    nova_config {
      'vnc/vencrypt_ca_certs':    ensure => absent;
      'vnc/vencrypt_client_cert': ensure => absent;
      'vnc/vencrypt_client_key':  ensure => absent;
    }

    $auth_schemes = 'none'
  }

  # Nodes running novncproxy do *not* need (and in fact, don't care)
  # about [vnc]/enable to be set. This setting is for compute nodes,
  # where we must select VNC or SPICE so that it can be passed on to
  # libvirt which passes it as parameter when starting VMs with KVM.
  # Therefore, this setting is set within compute.pp only.
  nova_config {
    'vnc/novncproxy_host': value => $host;
    'vnc/novncproxy_port': value => $port;
    'vnc/auth_schemes':    value => $auth_schemes;
  }

  # The Debian package needs some scheduling:
  # 1/ Install the packagin
  # 2/ Fix /etc/default/nova-consoleproxy
  # 3/ Start the service
  # Other OS don't need this scheduling and can use
  # the standard nova::generic_service
  if $facts['os']['name'] == 'Debian' {
    if $enabled {
      file_line { '/etc/default/nova-consoleproxy:NOVA_CONSOLE_PROXY_TYPE':
        path    => '/etc/default/nova-consoleproxy',
        match   => '^NOVA_CONSOLE_PROXY_TYPE=(.*)$',
        line    => 'NOVA_CONSOLE_PROXY_TYPE=novnc',
        tag     => 'nova-consoleproxy',
        require => Anchor['nova::config::begin'],
        notify  => Anchor['nova::config::end'],
      }
    }
  }
  nova::generic_service { 'vncproxy':
    enabled        => $enabled,
    manage_service => $manage_service,
    package_name   => $::nova::params::vncproxy_package_name,
    service_name   => $::nova::params::vncproxy_service_name,
    ensure_package => $ensure_package,
  }

}
