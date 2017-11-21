name "sensu-gem"
default_version "0.26.1"

dependency "ruby"
dependency "rubygems"
dependency "libffi"
if freebsd? && ohai['os_version'].to_i < 1100000
  dependency "rubysl-readline-gem"
else
  dependency "rb-readline-gem"
end
dependency "eventmachine"

if windows?
  dependency "winsw-net2"
  dependency "winsw-net4"
end

build do
  env = with_standard_compiler_flags(with_embedded_path)

  patch_env = env.dup

  files_dir = "#{project.files_path}/#{name}"

  gem_install_extras = ""

  if solaris_10?
    gem_install_extras << " --with-cflags=\"-fms-extensions\""
  end

  gem "install sensu" \
      " --version '#{version}'" \
      " --bindir '#{install_dir}/embedded/bin'" \
      " --no-ri --no-rdoc" \
      " -- #{gem_install_extras}", env: env

  gem "install sensu-plugin" \
      " --version '1.4.5'" \
      " --no-ri --no-rdoc", env: env

  gem "install sensu-plugin" \
      " --version '2.0.1'" \
      " --no-ri --no-rdoc", env: env

  share_dir = File.join(install_dir, "embedded", "share", "sensu")
  bin_dir = File.join(install_dir, "bin")
  embedded_bin_dir = File.join(install_dir, "embedded", "bin")

  if freebsd?
    etc_dir = "/usr/local/etc"
    usr_bin_dir = "/usr/local/bin"
  elsif mac_os_x?
    etc_dir = "/etc"
    usr_bin_dir = "/usr/local/bin"
  else
    etc_dir = "/etc"
    usr_bin_dir = "/usr/bin"
  end

  # make directories
  mkdir("#{install_dir}/bin")
  mkdir("#{etc_dir}/sensu")
  mkdir("#{etc_dir}/sensu/conf.d")
  mkdir("#{etc_dir}/sensu/extensions")
  mkdir("#{etc_dir}/sensu/plugins")
  mkdir("/var/log/sensu")
  mkdir("/var/run/sensu")
  mkdir("/var/cache/sensu")
  mkdir("#{etc_dir}/logrotate.d")
  mkdir("/lib/svc/manifest/site") if solaris?
  mkdir("#{etc_dir}/default") unless rhel? || debian? # if directory doesn't exist would be better

  # until we can figure out how to control files outside of install_dir on
  # windows, let's create a conf.d directory in c:/opt/sensu for configuration
  if windows?
    mkdir("#{install_dir}/conf.d")
  end

  # The packager for FreeBSD does not support adding empty directories to the
  # package manifest. To work around this limitation we add .sensu-keep files
  # in each empty directory.
  if freebsd?
    touch("#{etc_dir}/sensu/conf.d/.sensu-keep")
    touch("#{etc_dir}/sensu/extensions/.sensu-keep")
    touch("#{etc_dir}/sensu/plugins/.sensu-keep")
    touch("/var/log/sensu/.sensu-keep")
    touch("/var/run/sensu/.sensu-keep")
    touch("/var/cache/sensu/.sensu-keep")
    project.extra_package_file("#{etc_dir}/sensu/conf.d/.sensu-keep")
    project.extra_package_file("#{etc_dir}/sensu/extensions/.sensu-keep")
    project.extra_package_file("#{etc_dir}/sensu/plugins/.sensu-keep")
    project.extra_package_file("/var/log/sensu/.sensu-keep")
    project.extra_package_file("/var/run/sensu/.sensu-keep")
    project.extra_package_file("/var/cache/sensu/.sensu-keep")
  else
    project.extra_package_file("#{etc_dir}/sensu/conf.d")
    project.extra_package_file("#{etc_dir}/sensu/extensions")
    project.extra_package_file("#{etc_dir}/sensu/plugins")
    project.extra_package_file("/var/log/sensu")
    project.extra_package_file("/var/run/sensu")
    project.extra_package_file("/var/cache/sensu")
  end

  # sensu-install (in omnibus bin dir)
  if windows?
    copy("#{files_dir}/sensu-install.bat", "#{bin_dir}/sensu-install")
  else
    copy("#{files_dir}/bin/sensu-install", bin_dir)
    copy("#{files_dir}/bin/sensu-install", "#{usr_bin_dir}/sensu-install")
    command("chmod +x #{bin_dir}/sensu-install")
    command("chmod +x #{usr_bin_dir}/sensu-install")
  end

  # misc files
  copy("#{files_dir}/default/sensu", "#{etc_dir}/default/sensu")
  copy("#{files_dir}/logrotate.d/sensu", "#{etc_dir}/logrotate.d/sensu")

  # add config & extra package files (files outside of /opt/sensu)
  if linux?
    # only deb and rpm packagers honor config_file directives
    project.config_file("#{etc_dir}/default/sensu")
    project.config_file("#{etc_dir}/logrotate.d/sensu")
  end

  project.extra_package_file("#{etc_dir}/default/sensu")
  project.extra_package_file("#{etc_dir}/logrotate.d/sensu")
  project.extra_package_file("#{usr_bin_dir}/sensu-install")

  # sensu-service
  copy("#{files_dir}/bin/sensu-service", bin_dir)
  command("chmod +x #{bin_dir}/sensu-service")

  # determine which service manager to use
  platform = ohai["platform"]
  platform_family = ohai["platform_family"]
  platform_version = ohai["platform_version"]
  service_manager = Helpers::service_manager_for(platform, platform_version)

  # Platforms with systemd as the default service manager symlink /var/run to
  # /run and its contents are not persisted across reboots. To ensure that
  # /var/run/sensu is recreated on boot a tmpfiles.d config file must be
  # created.
  if service_manager == :systemd
    options = {
      source: "tmpfilesd/sensu.conf.erb",
      dest: "#{etc_dir}/tmpfiles.d/sensu.conf",
      mode: 0644
    }
    erb(options)
    project.extra_package_file("#{etc_dir}/tmpfiles.d/sensu.conf")
  end

  # service wrappers
  service_dir = Helpers::directory_for_service(platform_family, service_manager)

  # render the sensu service templates to their destination
  Helpers::services(service_manager).each do |sensu_service|
    filename = Helpers::filename_for_service(service_manager, sensu_service)
    destination = File.join(service_dir, filename)
    options = {
      source: "#{service_manager}/sensu-service.erb",
      dest: destination,
      vars: {
        :service_name => sensu_service,
        :service_shortname => sensu_service.gsub(/sensu[-_]/, "")
      },
      mode: Helpers::permissions_for_service_manager(service_manager)
    }
    erb(options)
    project.extra_package_file(destination)
  end

  # make symlinks
  if windows?
    copy("#{files_dir}/sensu-client-windows.xml", "#{bin_dir}/sensu-client.xml")
    copy("#{files_dir}/sensu-client.exe.config", "#{bin_dir}/sensu-client.exe.config")
  else
    link("#{embedded_bin_dir}/sensu-client", "#{bin_dir}/sensu-client")
    link("#{embedded_bin_dir}/sensu-server", "#{bin_dir}/sensu-server")
    link("#{embedded_bin_dir}/sensu-api", "#{bin_dir}/sensu-api")
  end
end
