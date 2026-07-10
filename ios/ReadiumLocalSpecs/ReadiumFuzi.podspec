Pod::Spec.new do |s|
  s.name         = "ReadiumFuzi"
  s.version      = "4.0.0"
  s.license      = "MIT"
  s.summary      = "A fast & lightweight XML & HTML parser in Swift with XPath & CSS support"
  s.homepage     = "https://github.com/readium/Fuzi"
  s.social_media_url   = "https://twitter.com/AdamoCheng"
  s.author             = { "Ce Zheng" => "cezheng.cs@gmail.com" }
  s.source       = { :http => "https://github.com/readium/Fuzi/archive/refs/tags/4.0.0.zip", :type => "zip" }

  s.ios.deployment_target = "13.0"
  s.source_files  = "**/Sources/*.swift"
  s.requires_arc = true
  s.library = "xml2"
  s.xcconfig = { "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2" }
end
