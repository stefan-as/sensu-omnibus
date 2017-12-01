name "winsw-net2"
default_version "2.0.2"

source url: "https://github.com/kohsuke/winsw/releases/download/winsw-v#{version}/WinSW.NET2.exe"

version "2.0.2" do
  source md5: "89f3bf7878064613ff5ec4ddc87611e5"
end

version "2.0.1" do
  source md5: "307f288ca5d23c0afb37908a40bedd85"
end

relative_path "winsw-v#{version}"

build do
  env = with_standard_compiler_flags(with_embedded_path)
  bin_dir = File.join(install_dir, "bin")

  if windows?
    copy("WinSW.NET2.exe", "#{bin_dir}/WinSW.NET2.exe")
  end
end
