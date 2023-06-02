Pod::Spec.new do |s|

  s.name         = "HDNetDiagnoService"  #存储库名称
  s.version      = "1.0.0"          #版本号，与tag值一致
  s.summary      = "网络诊断组件" #简介
  s.description  = "一个自用的网络诊断组件"   #描述
  s.homepage     = "https://github.com/zgsh0916/HDNetDiagnoService" #项目主页，不是git地址 不要加.git
  s.license      = { :type => "MIT", :file => "LICENSE" }  #开源协议
  s.author             = { "wangmeng" => "zgsh0916@126.com" } #作者
  s.platform     = :ios, "12.0"  #支持的平台和版本号
  s.source       = { :git => "https://github.com/zgsh0916/HDNetDiagnoService.git", :tag => "1.0.0" } #存储库的git地址，以及tag值
  s.source_files  = "HDNetDiagnoService/*.{h,m}"
  s.requires_arc = true #是否支持ARC

end
