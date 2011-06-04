require 'rubygems'
require 'rake'
=begin
require 'echoe'

Echoe.new('redis_orm', '0.2') do |p|
  p.description    = "ORM for Redis advanced key-value storage"
  p.url            = "https://github.com/german/redis_orm"
  p.author         = "Dmitrii Samoilov"
  p.email          = "germaninthetown@gmail.com"
  p.dependencies   = ["activesupport >=3.0.0", "activemodel >=3.0.0", "redis >=2.2.0"]
  p.development_dependencies   = ["rspec >=2.5.0"]
end
=end

#require 'rake/testtask'
#$LOAD_PATH << File.join(File.dirname(__FILE__), 'lib')

=begin
desc 'Test the redis_orm gem.'
Rake::TestTask.new(:test) do |t|
  #t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end
=end

task :test do |t|
  Dir['test/**/*_test.rb'].each do |file|
    puts `ruby -I./lib #{file}`
  end
end
