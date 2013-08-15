Pod::Spec.new do |s|
  s.name     = 'JSAppleScript'
  s.version  = '0.0.1'
  s.license  = 'MIT'
  s.summary  = 'Simple, helpful library for using your Objective-C variables within a bundled AppleScript or OSAScript.'
  s.homepage = 'https://github.com/johnnyclem/JCAppleScript'
  s.author   = { 'John Clem' => 'johnnyclem@gmail.com' }

  s.source   = { :git => 'https://github.com/johnnyclem/JCAppleScript.git', :tag => 'v0.0.1' }

  s.source_files = '*.{h,m}'

  s.frameworks = 'Foundation'
end
