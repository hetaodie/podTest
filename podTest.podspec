Pod::Spec.new do |s|
  s.name         = "podTest"
  s.version      = "1.0.0"
  s.summary      = "The package of useful tools, include categories and classes"
  s.homepage     = "https://github.com/hetaodie/podTest.git"
  s.license      = "MIT"
  s.authors      = { 'tangjr' => 'hetaodie@gmail.com'}
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/hetaodie/podTest.git", :tag => s.version }
  s.source_files = 'RTCAVCaptureDemo'
end
