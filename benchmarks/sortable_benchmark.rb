require File.expand_path(File.dirname(__FILE__) + '/../lib/redis_orm')
require 'benchmark'

class User < RedisOrm::Base
  property :name, String
  property :age, Integer
  property :wage, Float
  
  index :name
  index :age
end

class SortableUser < RedisOrm::Base
  property :name, String, :sortable => true
  property :age, Integer, :sortable => true
  property :wage, Float, :sortable => true
  
  index :name
  index :age
end

path_to_conf = File.dirname(File.expand_path(__FILE__)) + "/../test/redis.conf"
$redis_pid = spawn 'redis-server ' + path_to_conf, :out => "/dev/null"
sleep(0.3) # must be some delay otherwise "Connection refused - Unable to connect to Redis"
path_to_socket = File.dirname(File.expand_path(__FILE__)) + "/../redis.sock"
begin
  $redis = Redis.new(:host => 'localhost', :path => path_to_socket)
rescue => e
  puts 'Unable to create connection to the redis server: ' + e.message.inspect
  Process.kill 9, $redis_pid.to_i if $redis_pid
end

n = 100
Benchmark.bmbm do |x|
  x.report("creating regular user:") { for i in 1..n; u = User.create(:name => "user#{i}", :age => i, :wage => 100*i); end}
  x.report("creating user w/ sortable attrs:") { for i in 1..n; u = SortableUser.create(:name => "user#{i}", :age => i, :wage => 100*i); end }
end

Benchmark.bmbm do |x|
  x.report("finding regular users:") { User.find(:all, :limit => 5, :offset => 10) }
  x.report("finding users w/ sortable attrs:") { SortableUser.find(:all, :limit => 5, :offset => 10, :order => [:name, :asc]) }
end

$redis.flushall if $redis
Process.kill 9, $redis_pid.to_i if $redis_pid
