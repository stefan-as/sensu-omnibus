#
# Cookbook Name:: omnibus_sensu
# Recipe:: default
#
# Copyright (c) 2016 Sensu, All Rights Reserved.

include_recipe 'chef-sugar'

if windows?
  msys2_filename = 'msys2-base-x86_64-20160205.tar.xz'
  remote_file "#{ENV['SYSTEMDRIVE']}\\msys2\\.cache\\#{msys2_filename}" do
    source "https://s3-us-west-2.amazonaws.com/sensu-omnibus-cache/#{msys2_filename}"
    action :create
  end

  include_recipe 'chocolatey'

  chocolatey 'dotnet3.5' do
    version '3.5.20160716'
  end

  chocolatey 'windows-sdk-8.1' do
    version '8.100.26654.0'
  end

  chocolatey 'microsoft-build-tools' do
    version '14.0.25420.1'
  end

  chocolatey 'awscli' do
    version '1.11.41'
  end

  # If this is an ephemeral vagrant/test-kitchen instance, we relax the password
  # so that the default password "vagrant" can be used.
  powershell_script 'Disable password complexity requirements' do
    code <<-EOH
      secedit /export /cfg $env:temp/export.cfg
      ((get-content $env:temp/export.cfg) -replace ('PasswordComplexity = 1', 'PasswordComplexity = 0')) | Out-File $env:temp/export.cfg
      secedit /configure /db $env:windir/security/new.sdb /cfg $env:temp/export.cfg /areas SECURITYPOLICY
    EOH
  end
end

if freebsd?
  package "git"
else
  include_recipe "git"

  git_config "user.email" do
    value "support@sensuapp.com"
    options "--global"
  end

  git_config "user.name" do
    value "Sensu Omnibus Builder"
    options "--global"
  end
end

include_recipe "omnibus::default"

case node["platform_family"]
when "rhel"
  # skip signing on Centos 5 because of Reasons
  if Gem::Version.new(node["platform_version"]) >= Gem::Version.new(6)
    package "gpg"
    package "pygpgme"

    file ::File.join(build_user_home, '.gpg_passphrase') do
      owner node["omnibus"]["build_user"]
      mode 0600
      content node["omnibus_sensu"]["gpg_passphrase"]
      sensitive true
    end

    gnupg_tar_path = ::File.join(build_user_home, 'gnupg.tar')

    aws_s3_file gnupg_tar_path do
      bucket node["omnibus_sensu"]["publishers"]["s3"]["cache_bucket"]
      remote_path 'gpg/gnupg.tar'
      aws_access_key node["omnibus_sensu"]["publishers"]["s3"]["access_key_id"]
      aws_secret_access_key  node["omnibus_sensu"]["publishers"]["s3"]["secret_access_key"]
      region node["omnibus_sensu"]["publishers"]["s3"]["region"]
      owner node["omnibus"]["build_user"]
      group node["omnibus"]["build_user_group"]
    end

    execute 'unpack-gpg-tarball' do
      command "tar -xvf #{gnupg_tar_path}"
      cwd '/root'
    end
  end
end

gem_package "ffi-yajl" do
  if windows?
    gem_binary "call C:/omnibus/load-omnibus-toolchain.bat && C:/opscode/omnibus-toolchain/embedded/bin/gem"
  else
    gem_binary "/opt/omnibus-toolchain/bin/gem"
  end
end

directory node["omnibus_sensu"]["project_dir"] do
  user node["omnibus"]["build_user"]
  group node["omnibus"]["build_user_group"]
  recursive true
  action :create
end

project_dir = windows? ? File.join("C:", node["omnibus_sensu"]["project_dir"]) : node["omnibus_sensu"]["project_dir"]

rev = node["omnibus_sensu"]["project_revision"]

case rev
when 'archive'
  directory project_dir do
    user node["omnibus"]["build_user"] unless windows?
    group node["omnibus"]["build_user_group"] unless windows?
    recursive true
    action :create
  end

  archive_file = File.join(project_dir,'archive.zip')
  cookbook_file archive_file do
    source 'archive.zip'
    user node["omnibus"]["build_user"] unless windows?
    group node["omnibus"]["build_user_group"] unless windows?
    action :create
  end

  chef_gem 'rubyzip'

  ruby_block 'expand_archive' do
    block do
      require 'zip'

      Zip.on_exists_proc = true

      Zip::File.open(archive_file) do |arcv|
        arcv.each do |entry|
          fpath = File.join(project_dir, entry.name)
          entry.extract(fpath)
        end
      end
    end
  end
else
  git project_dir do
    repository 'https://github.com/sensu/sensu-omnibus.git'
    revision rev
    user node["omnibus"]["build_user"] unless windows?
    group node["omnibus"]["build_user_group"] unless windows?
    action :sync
  end
end

template ::File.join(node["omnibus_sensu"]["project_dir"], "omnibus.rb") do
  source "omnibus.rb.erb"
  sensitive true
  user node["omnibus"]["build_user"] unless windows?
  group node["omnibus"]["build_user_group"] unless windows?
  variables(
    :aws_region => node["omnibus_sensu"]["publishers"]["s3"]["region"],
    :aws_access_key_id => node["omnibus_sensu"]["publishers"]["s3"]["access_key_id"],
    :aws_secret_access_key => node["omnibus_sensu"]["publishers"]["s3"]["secret_access_key"],
    :aws_s3_cache_bucket => node["omnibus_sensu"]["publishers"]["s3"]["cache_bucket"]
  )
end

shared_env = {
  "SENSU_VERSION" => node["omnibus_sensu"]["build_version"],
  "BUILD_NUMBER" => node["omnibus_sensu"]["build_iteration"],
}

if windows?
  shared_env.merge!(
    "WINDOWS_TARGET_VERSION" => node["omnibus_sensu"]["windows_target_version"]
  )
end

load_toolchain_cmd = case windows?
                     when true
                       "call #{::File.join(build_user_home, 'load-omnibus-toolchain.bat')}"
                     when false
                       ".  #{::File.join(build_user_home, 'load-omnibus-toolchain.sh')}"
                     end

execute "populate_omnibus_cache_s3" do
  command(
    <<-CODE.gsub(/^ {10}/, '')
          #{load_toolchain_cmd} && \
          bundle install && \
          bundle exec omnibus cache missing && \
          bundle exec omnibus cache populate && \
          bundle exec omnibus cache missing
       CODE
    )
  cwd node["omnibus_sensu"]["project_dir"]
  user "root" unless windows?
  environment shared_env
  not_if { node["omnibus_sensu"]["publishers"]["s3"].any? {|k,v| v.nil? } }
end

case node["platform"]
when "debian"
  # replace omnibus-toolchain tar with system tar as dpkg-deb requires --clamp-mtime now
  if Gem::Version.new(node["platform_version"]) >= Gem::Version.new(9)
    embedded_tar_path = "/opt/omnibus-toolchain/embedded/bin/tar"

    file embedded_tar_path do
      action :delete
    end

    link embedded_tar_path do
      to "/bin/tar"
    end
  end
end

omnibus_build "sensu" do
  project_dir node["omnibus_sensu"]["project_dir"]
  log_level :info
  build_user "root" unless windows?
  environment shared_env
  live_stream true
  timeout 7200
end

pkg_suffix_map = {
  [:ubuntu, :debian]                   => { :default => "deb" },
  [:redhat, :centos, :fedora, :suse]   => { :default => "rpm" },
  :solaris                             => { "5.10" => "solaris", "5.11" => "ips" },
  :aix                                 => { :default => "bff" },
  :freebsd                             => { :default => "txz" },
  :windows                             => { :default => "msi" }
}

artifact_id = [ node["omnibus_sensu"]["build_version"], node["omnibus_sensu"]["build_iteration"] ].join("-")

publish_environment = case windows?
                      when true
                        shared_env.merge({
                            'AWS_REGION' => node["omnibus_sensu"]["publishers"]["s3"]["region"],
                            'AWS_ACCESS_KEY_ID' => node["omnibus_sensu"]["publishers"]["s3"]["access_key_id"],
                            'AWS_SECRET_ACCESS_KEY' => node["omnibus_sensu"]["publishers"]["s3"]["secret_access_key"]
                        })
                      when false
                        shared_env.merge({
                        'USER' => node["omnibus"]["build_user"],
                        'USERNAME' => node["omnibus"]["build_user"],
                        'LOGNAME' => node["omnibus"]["build_user"]
                        })
                      end

case windows?
when true
  arch = windows_arch_i386? ? "i386" : "x86_64"
  win_arch = windows_arch_i386? ? "x86" : "x64"
  win_version = node["omnibus_sensu"]["windows_target_version"]
  msi_name = "sensu-#{artifact_id}-#{win_arch}.msi"
  aws_cli = File.join('C:\"Program Files"\Amazon\AWSCLI\aws')

  [ msi_name, "#{msi_name}.metadata.json" ].each do |pkg_file|
    execute "publish_sensu_#{pkg_file}_s3_windows" do
      command "#{aws_cli} s3 cp pkg\\#{pkg_file} s3://#{node["omnibus_sensu"]["publishers"]["s3"]["artifact_bucket"]}/windows/#{win_version}/#{arch}/#{msi_name}/#{pkg_file}"
      cwd node["omnibus_sensu"]["project_dir"]
      environment publish_environment
      not_if { node["omnibus_sensu"]["publishers"]["s3"].any? {|k,v| v.nil? } }
    end
  end
else
  execute "publish_sensu_#{artifact_id}_s3" do
    command(
      <<-CODE.gsub(/^ {10}/, '')
            #{load_toolchain_cmd}
            bundle exec omnibus publish s3 #{node["omnibus_sensu"]["publishers"]["s3"]["artifact_bucket"]} "pkg/sensu*.#{value_for_platform(pkg_suffix_map)}"
          CODE
    )
    cwd node["omnibus_sensu"]["project_dir"]
    user node["omnibus"]["build_user"] unless windows?
    environment publish_environment
    not_if { node["omnibus_sensu"]["publishers"]["s3"].any? {|k,v| v.nil? } }
  end
end
