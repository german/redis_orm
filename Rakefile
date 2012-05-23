require 'rubygems'
require 'rake'
require 'rake/testtask'

=begin
require 'echoe'

Echoe.new('redis_orm', '0.6.2') do |p|
  p.description    = "ORM for Redis (advanced key-value storage) with ActiveRecord API"
  p.url            = "https://github.com/german/redis_orm"
  p.author         = "Dmitrii Samoilov"
  p.email          = "germaninthetown@gmail.com"
  p.dependencies   = ["activesupport >=3.0.0", "activemodel >=3.0.0", "redis >=2.2.0", "uuid >=2.3.2"]
  p.development_dependencies   = ["rspec >=2.5.0"]
end
=end

task :default => :test

desc 'Test the redis_orm functionality'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end
