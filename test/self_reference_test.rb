require 'rspec'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'



describe "test self reference" do
  before(:all) do
    path_to_conf = File.dirname(File.expand_path(__FILE__)) + "/redis.conf"
    $redis_pid = spawn 'redis-server ' + path_to_conf, :out=>"/dev/null"
    sleep(1)
    path_to_socket = File.dirname(File.expand_path(__FILE__)) + "/../redis.sock"
    $redis = Redis.new(:host => 'localhost', :path => path_to_socket)#:port => 6379)
  end
  
  after(:all) do    
    Process.kill(9, $redis_pid.to_i) if $redis_pid
  end

  after(:each) do
   $redis.flushall if $redis
  end

  before(:each) do
    $redis.flushall if $redis
  end

  
end
