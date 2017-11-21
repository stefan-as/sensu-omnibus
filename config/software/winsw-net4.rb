name "winsw-net4"
default_version "2.0.2"

source url: "https://github.com/kohsuke/winsw/releases/download/winsw-v#{version}/WinSW.NET4.exe"

version "2.0.2" do
  source md5: "636111424c86c47c2ebae8766a377d82"
end

version "2.0.1" do
  source md5: "6f9f9554e66cdf3bb26d80512b7afc4f"
end

relative_path "winsw-v#{version}"

build do
  env = with_standard_compiler_flags(with_embedded_path)
  bin_dir = File.join(install_dir, "bin")

  if windows?
    copy("WinSW.NET4.exe", "#{bin_dir}/WinSW.NET4.exe")
  end
end
