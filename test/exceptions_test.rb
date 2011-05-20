require 'rspec'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'

class User < RedisOrm::Base
  property :name, String
  property :age, Integer
  property :created_at, Time

  has_one :profile
end

class Profile < RedisOrm::Base
  property :title, String

  belongs_to :user
end

class Jigsaw < RedisOrm::Base
  property :title, String

  belongs_to :user
end

describe "exceptions test" do
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

  it "should raise an exception if association is provided with improper class" do
    User.count.should == 0

    user = User.new
    user.name = "german"
    user.save

    user.should be
    user.name.should == "german"
    User.count.should == 1

    jigsaw = Jigsaw.new
    jigsaw.title = "123"
    jigsaw.save

    # RedisOrm::TypeMismatchError
    lambda { user.profile = jigsaw }.should raise_error
  end   
end
