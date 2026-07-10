Pod::Spec.new do |s|
  s.name = "ReadiumZIPFoundation"
  s.version = "3.0.1"
  s.license = "MIT"
  s.summary = "Effortless ZIP Handling in Swift"
  s.homepage = "https://github.com/readium/ZIPFoundation"
  s.social_media_url = "http://twitter.com/weichsel"
  s.authors = { "Thomas Zoechling" => "thomas@peakstep.com" }
  s.source = { :http => "https://github.com/readium/ZIPFoundation/archive/refs/tags/3.0.1.zip", :type => "zip" }
  s.swift_versions = ["5.0"]

  s.ios.deployment_target = "13.0"
  s.osx.deployment_target = "11.0"

  s.source_files = "**/Sources/ZIPFoundation/*.swift"
  s.resource_bundles = {
    "ReadiumZIPFoundation_Privacy" => ["**/Sources/ZIPFoundation/Resources/PrivacyInfo.xcprivacy"],
  }
end
