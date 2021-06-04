Pod::Spec.new do |s|

  s.name             = "Nog"
  s.version          = "0.3.0"
  s.summary          = "A delicious network request logger in Swift"
  s.description      = "A delicious network request logger in Swift."
  s.homepage         = "https://github.com/hkellaway/Nog"
  s.license          = { :type => "MIT", :file => "LICENSE" }
  s.author           = { "Harlan Kellaway" => "harlan.github@gmail.com" }
  s.source           = { :git => "https://github.com/hkellaway/Nog.git", :tag => s.version.to_s }
  s.module_name   = 'Nog'

  s.swift_version    = "5.3"
  s.platforms        = { :ios => "13.0" }
  s.requires_arc     = true

  s.source_files     = 'Sources/Nog/*.swift'

end
