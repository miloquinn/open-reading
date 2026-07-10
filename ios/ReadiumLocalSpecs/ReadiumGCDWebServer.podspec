Pod::Spec.new do |s|
  s.name     = "ReadiumGCDWebServer"
  s.version  = "4.0.1"
  s.author   = { "Pierre-Olivier Latour" => "info@pol-online.net" }
  s.license  = { :type => "BSD" }
  s.homepage = "https://github.com/readium/GCDWebServer"
  s.summary  = "Lightweight GCD based HTTP server for OS X & iOS"

  s.source   = { :http => "https://github.com/readium/GCDWebServer/archive/refs/tags/4.0.1.zip", :type => "zip" }
  s.ios.deployment_target = "11.0"
  s.requires_arc = true
  s.source_files = "**/GCDWebServer/**/*.{h,m}"
  s.exclude_files = "**/GCDWebServer/include/*"
  s.ios.library = "z"
  s.ios.frameworks = "MobileCoreServices", "CFNetwork"
end
