require 'rubygems'
require 'rake'
=begin
require 'echoe'

Echoe.new('redis_orm', '0.0.1') do |p|
  p.description    = "almost ActiveRecord compatible ORM for Redis key-value storage"
  p.url            = "http://github.com/german/redis_orm"
  p.author         = "Dmitrii Samoilov"
  p.email          = "germaninthetown@gmail.com"
  p.dependencies   = ["activesupport"]
end
=end
require 'rake'
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
