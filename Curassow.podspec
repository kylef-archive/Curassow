Pod::Spec.new do |s|
  s.name = 'Curassow'
  s.version = '0.5.0'
  s.summary = 'Swift HTTP server using the pre-fork worker model'
  s.homepage = 'https://curassow.fuller.li/'
  s.license = { :type => 'BSD', :file => 'LICENSE' }
  s.author = { 'Kyle Fuller' => 'kyle@fuller.li' }
  s.social_media_url = 'http://twitter.com/kylefuller'
  s.source = { :git => 'https://github.com/kylef/Curassow.git', :tag => s.version }
  s.source_files = 'Sources/*.swift'
  s.requires_arc = true
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.9'
  s.dependency 'Nest', '~> 0.3'
  s.dependency 'Inquiline', '~> 0.3'
  s.dependency 'Commander', '~> 0.4'
  s.dependency 'fd', '~> 0.1'
end