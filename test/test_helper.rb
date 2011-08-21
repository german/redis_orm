require 'rspec'
require 'rspec/autorun'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'

RSpec.configure do |config|  
  config.before(:all) do
    path_to_conf = File.dirname(File.expand_path(__FILE__)) + "/redis.conf"
    $redis_pid = spawn 'redis-server ' + path_to_conf, :out => "/dev/null"
    sleep(0.3) # must be some delay otherwise "Connection refused - Unable to connect to Redis"
    path_to_socket = File.dirname(File.expand_path(__FILE__)) + "/../redis.sock"
    begin
      $redis = Redis.new(:host => 'localhost', :path => path_to_socket)
    rescue => e
      puts 'Unable to create connection to the redis server: ' + e.message.inspect
      Process.kill 9, $redis_pid.to_i if $redis_pid
    end
  end
  
  config.after(:all) do
    Process.kill 9, $redis_pid.to_i if $redis_pid
  end

  config.after(:each) do
   $redis.flushall if $redis
  end

  config.before(:each) do
    $redis.flushall if $redis
  end
end
