require 'rspec'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'

class User < RedisOrm::Base
  property :name, String
  property :age, Integer, :default => 26
  property :gender, RedisOrm::Boolean, :default => true
end

describe "check associations" do
  before(:all) do
    path_to_conf = File.dirname(File.expand_path(__FILE__)) + "/redis.conf"
    $redis_pid = spawn 'redis-server ' + path_to_conf, :out=>"/dev/null"
    sleep(1)
    path_to_socket = File.dirname(File.expand_path(__FILE__)) + "/../redis.sock"
    $redis = Redis.new(:host => 'localhost', :path => path_to_socket)#:port => 6379)
  end
  
  before(:each) do
    $redis.flushall if $redis
  end

  after(:each) do
   $redis.flushall if $redis
  end

  after(:all) do
    if $redis_pid
      Process.kill 9, $redis_pid.to_i
    end
  end

  it "should return correct _changes array" do
    user = User.new :name => "german"

    user.name_changes.should == ["german"]
    user.save
    user.name_changes.should == ["german"]
    user.name = "germaninthetown"
    user.name_changes.should == ["german", "germaninthetown"]
    user.save

    user = User.first
    user.name.should == "germaninthetown"
    user.name_changes.should == ["germaninthetown"]
    user.name = "german"
    user.name_changes.should == ["germaninthetown", "german"]
  end
end
