# encoding: utf-8

require 'rspec'
require 'rspec/autorun'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'

Dir.glob(['test/classes/*.rb', 'test/modules/*.rb']).each do |klassfile|
  require File.dirname(File.expand_path(__FILE__)) + '/../' + klassfile
end


RSpec.configure do |config|  
  config.before(:all) do
    path_to_conf = File.dirname(File.expand_path(__FILE__)) + "/redis.conf"
    RedisOrm.redis_pid = spawn 'redis-server ' + path_to_conf, :out => "/dev/null"
    sleep(0.3) # must be some delay otherwise "Connection refused - Unable to connect to Redis"
    path_to_socket = File.dirname(File.expand_path(__FILE__)) + "/../redis.sock"
    begin
      RedisOrm.redis = Redis.new(:host => 'localhost', :path => path_to_socket)
    rescue => e
      puts 'Unable to create connection to the redis server: ' + e.message.inspect
      Process.kill 9, RedisOrm.redis_pid.to_i if RedisOrm.redis_pid
    end
  end
  
  config.after(:all) do
    Process.kill 9, RedisOrm.redis_pid.to_i if RedisOrm.redis_pid
  end

  config.after(:each) do
   RedisOrm.redis.flushall if RedisOrm.redis
  end

  config.before(:each) do
    RedisOrm.redis.flushall if RedisOrm.redis
  end
end
