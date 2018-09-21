# Class: rsync::server
#
# The rsync server. Supports both standard rsync as well as rsync over ssh
#
# Requires:
# #   class xinetd if use_xinetd is set to true
#   class rsync
#
# NOTE:  I have removed xinetd support, since we have
# not imported https://github.com/puppetlabs/puppetlabs-xinetd
# into the WMF puppet repository. - otto

class rsync::server(
    Boolean $use_xinetd = false,  # this parameter should not be used.  xinetd is not available.
    String $address    = '0.0.0.0',
    String $timeout    = '300',
    String $motd_file  = 'UNSET',
    String $log_file   = 'UNSET',
    String $use_chroot = 'yes',
    Optional[Array] $rsync_opts = [],
    Optional[Hash] $rsyncd_conf = {},
) inherits rsync {

  $rsync_fragments = '/etc/rsync.d'
  $rsync_conf      = '/etc/rsyncd.conf'
  $rsync_pid       = '/var/run/rsync.pid'

  # rsync daemon defaults file
  file { '/etc/default/rsync':
    ensure  => present,
    mode    => '0444',
    owner   => 'root',
    group   => 'root',
    content => template('rsync/rsync.default.erb'),
  }

  # if($use_xinetd) {
  #   include xinetd
  #   xinetd::service { 'rsync':
  #     bind        => $address,
  #     port        => '873',
  #     server      => '/usr/bin/rsync',
  #     server_args => '--daemon --config ${rsync_conf}',
  #     require     => Package['rsync'],
  #   }
  # } else {
    service { 'rsync':
      ensure    => running,
      enable    => true,
      subscribe => [ Exec['compile fragments'], File['/etc/default/rsync'] ],
    }
  # }

  if $motd_file != 'UNSET' {
    file { '/etc/rsync-motd':
      source => 'puppet:///modules/rsync/motd',
    }
  }

  file { $rsync_fragments:
    ensure  => directory,
  }

  file { "${rsync_fragments}/header":
    content => template('rsync/header.erb'),
  }

  # perhaps this should be a script
  # this allows you to only have a header and no fragments, which happens
  # by default if you have an rsync::server but not an rsync::repo on a host
  # which happens with cobbler systems by default
  exec { 'compile fragments':
    refreshonly => true,
    command     => "ls ${rsync_fragments}/frag-* 1>/dev/null 2>/dev/null && if [ $? -eq 0 ]; then cat ${rsync_fragments}/header ${rsync_fragments}/frag-* > ${rsync_conf}; else cat ${rsync_fragments}/header > ${rsync_conf}; fi; $(exit 0)",
    subscribe   => File["${rsync_fragments}/header"],
    path        => '/bin:/usr/bin',
  }
}
