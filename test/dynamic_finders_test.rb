require 'rspec'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'

class User < RedisOrm::Base
  property :first_name, String
  property :last_name, String

  index :first_name, :unique => true
  index :last_name,  :unique => true
end

class CustomUser < RedisOrm::Base
  property :first_name, String
  property :last_name, String

  index :first_name, :unique => false
  index :last_name,  :unique => false
  index [:first_name, :last_name], :unique => true
end

describe "check associations" do
  before(:all) do
    path_to_conf = File.dirname(File.expand_path(__FILE__)) + "/redis.conf"
    $redis_pid = spawn 'redis-server ' + path_to_conf, :out=>"/dev/null"
    sleep(1)
    puts 'started - ' + $redis_pid.to_s
    path_to_socket = File.dirname(File.expand_path(__FILE__)) + "/../redis.sock"
    puts 'path_to_socket - ' + path_to_socket.inspect
    $redis = Redis.new(:host => 'localhost', :path => path_to_socket)#:port => 6379)
  end
  
  before(:each) do
    $redis.flushall if $redis    
  end

  after(:each) do
   $redis.flushall if $redis
  end

  after(:all) do
    puts 'finish - ' + $redis_pid.to_s
    if $redis_pid
      Process.kill 9, $redis_pid.to_i
    end
  end

  it "should create and use indexes to implement dynamic finders" do
    user1 = User.new
    user1.first_name = "Dmitrii"
    user1.last_name = "Samoilov"
    user1.save

    User.find_by_first_name("John").should == nil

    user = User.find_by_first_name "Dmitrii"
    user.id.should == user1.id

    User.find_all_by_first_name("Dmitrii").size.should == 1
  end
end
