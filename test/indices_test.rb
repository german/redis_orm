require 'rspec'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'

class User < RedisOrm::Base
  property :first_name, String
  property :last_name, String

  index :first_name
  index :last_name
  index [:first_name, :last_name]
end

describe "check indices" do
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

  it "should change index accordingly to the changes in the model" do
    user = User.new :first_name => "Robert", :last_name => "Pirsig"
    user.save

    u = User.find_by_first_name("Robert")
    u.id.should == user.id

    u = User.find_by_first_name_and_last_name("Robert", "Pirsig")
    u.id.should == user.id

    u.first_name = "Chris"
    u.save

    User.find_by_first_name("Robert").should == nil

    User.find_by_first_name_and_last_name("Robert", "Pirsig").should == nil

    User.find_by_first_name("Chris").id.should == user.id
    User.find_by_last_name("Pirsig").id.should == user.id
    User.find_by_first_name_and_last_name("Chris", "Pirsig").id.should == user.id    
  end

  it "should change index accordingly to the changes in the model (test #update_attributes method)" do
    user = User.new :first_name => "Robert", :last_name => "Pirsig"
    user.save

    u = User.find_by_first_name("Robert")
    u.id.should == user.id

    u = User.find_by_first_name_and_last_name("Robert", "Pirsig")
    u.id.should == user.id

    u.update_attributes :first_name => "Christofer", :last_name => "Robin"

    User.find_by_first_name("Robert").should == nil
    User.find_by_last_name("Pirsig").should == nil
    User.find_by_first_name_and_last_name("Robert", "Pirsig").should == nil

    User.find_by_first_name("Christofer").id.should == user.id
    User.find_by_last_name("Robin").id.should == user.id
    User.find_by_first_name_and_last_name("Christofer", "Robin").id.should == user.id    
  end
end
