Gem::Specification.new do |s|
  s.name          = 'logstash-output-azure_event_hub'
  s.version       = '0.1.0'
  s.licenses      = ['Apache License (2.0)']
  s.summary       = 'Writes events to an Azure Event Hub'
  s.description   = 'This gem is a logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/logstash-plugin install logstash-output-azure_event_hub. This gem is not a stand-alone program.'
  s.homepage      = 'https://github.com/TheNathanGift/logstash-output_azure_event_hub'
  s.authors       = ['Nathan Gift']
  s.email         = 'nathanjgift@gmail.com'
  s.require_paths = ['lib', 'vendor/jar-dependencies']

  # Files
  s.files = Dir['lib/**/*', 'spec/**/*', 'vendor/**/*','vendor/jar-dependencies/**/*.jar', 'vendor/jar-dependencies/**/*.rb', '*.gemspec', '*.md', 'CONTRIBUTORS', 'Gemfile', 'LICENSE', 'VERSION', 'NOTICE']

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Metadata "logstash_* => .." are special flags to indicate this a logstash plugin
  s.metadata = {
    "logstash_plugin" => "true",
    "logstash_group" => "output",
    "source_code_uri" => "https://github.com/TheNathanGift/logstash-output_azure_event_hub",
    "allowed_push_host" => "https://rubygems.org"
  }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core-plugin-api", ">= 1.60", "<= 2.99"
  #s.add_runtime_dependency "logstash-core", ">= 6.5.0"
  s.add_runtime_dependency 'logstash-codec-plain'
  s.add_runtime_dependency 'logstash-codec-json'

  s.add_development_dependency 'logstash-devutils'

  # Jar dependencies
  s.add_development_dependency 'jar-dependencies'
end
