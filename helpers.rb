module Helpers
  SERVICE_MANAGERS = [
    :systemd,
    :sysvinit,
    :rcd,
    :smf,
  ].freeze

  def self.service_manager_for(platform, version)
    case platform
    when /redhat/, /centos/, /scientific/, /amazon/
      case
      when version < "7"
        :sysvinit
      when version >= "7"
        :systemd
      end
    when /debian/, /raspbian/
      case
      when version < "8"
        :sysvinit
      when version >= "8"
        :systemd
      end
    when /ubuntu/
      case
      when version < "15.04"
        :sysvinit
      when version >= "15.04"
        :systemd
      end
    when /freebsd/
      :rcd
    when /aix/
      :ssys
    when /solaris2/
      :smf
    when /windows/
      :windows
    when /mac_os_x/
      :launchd
    else
      raise "#{platform} is not a supported build target"
    end
  end

  def self.services(service_manager)
    services = [
      "sensu-api",
      "sensu-client",
      "sensu-server",
    ]
    case service_manager
    when :rcd
      services.map! do |service|
        service.gsub("-", "_")
      end
    when :ssys
      services = [] # service is installed by postinst script
    when :windows
      services = []  # TODO: windows
    end
    services
  end

  def self.directory_for_service(platform_family, service_manager)
    unknown_combo = "No service directory defined for service manager " +
      "\"#{service_manager}\" on platform \"#{platform_family}\""
    case service_manager
    when :systemd
      "/usr/lib/systemd/system"
    when :sysvinit
      case platform_family
      when "debian"
        "/etc/init.d"
      when "rhel"
        "/etc/rc.d/init.d"
      else
        raise unknown_combo
      end
    when :rcd
      "/usr/local/etc/rc.d"
    when :smf
      "/lib/svc/manifest/site"
    when :ssys
      "" # service is installed by postinst script
    when :windows
      "" # TODO: windows
    when :launchd
      "/Library/LaunchDaemons"
    else
      raise unknown_combo
    end
  end

  def self.filename_for_service(service_manager, service)
    case service_manager
    when :systemd
      "#{service}.service"
    when :sysvinit
      service
    when :rcd
      service.gsub("_", "-")
    when :smf
      "#{service}.xml"
    when :windows
      ""  # TODO: windows
    when :launchd
      "org.sensuapp.#{service}.plist"
    else
      raise "Could not determine filename for #{service} and #{service_manager}"
    end
  end

  def self.permissions_for_service_manager(service_manager)
    case service_manager
    when :systemd
      0644
    else
      0755
    end
  end
end
