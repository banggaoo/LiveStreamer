#
# Be sure to run `pod lib lint LiveStreamer.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'LiveStreamer'
  s.version          = '0.5.8'
  s.summary          = 'Live Streaming.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = 'Live Streaming for iOS.'

  s.homepage         = 'https://github.com/banggaoo/LiveStreamer'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'banggaoo' => 'banggaoo@naver.com' }
  s.source           = { :git => 'https://github.com/banggaoo/LiveStreamer.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'

  s.source_files = 'LiveStreamer/Classes/**/*'
  
  s.swift_version = '5.0'
  # s.swift_versions = ['3.2', '4.0', '4.2']

end
