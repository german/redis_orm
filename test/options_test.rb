require 'rspec'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'

class Album < RedisOrm::Base
  property :title, String

  has_one :photo, :as => :front_photo
  has_many :photos, :dependant => :destroy
end

class Category < RedisOrm::Base
  property :title, String

  has_many :photos, :dependant => :nullify
end

class Photo < RedisOrm::Base
  property :image, String
  
  belongs_to :album
  belongs_to :user
  belongs_to :category
end

class User < RedisOrm::Base
  property :name, String
  
  has_one :photo, :dependant => :destroy
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
  
  after(:all) do
    puts 'finish - ' + $redis_pid.to_s
    if $redis_pid
      Process.kill 9, $redis_pid.to_i
    end
  end

  after(:each) do
   $redis.flushall if $redis
  end

  before(:each) do
    $redis.flushall if $redis
    @album = Album.new
    @album.title = "my 1st album"
    @album.save

    @album.should be
    @album.title.should == "my 1st album"

    @photo1 = Photo.new
    @photo1.image = "facepalm.jpg"
    @photo1.save
    @photo1.should be
    @photo1.image.should == "facepalm.jpg"

    @photo2 = Photo.new
    @photo2.image = "boobs.jpg"
    @photo2.save
    @photo2.should be
    @photo2.image.should == "boobs.jpg"
  end

  it "should return correct array when :limit and :offset options are provided" do
    @album.photos.count.should == 0

    @album.photos.all(:limit => 2, :offset => 0).should == []

    @album.photos << [@photo1, @photo2]

    @album.photos.all(:limit => 0, :offset => 0).should == []
    @album.photos.all(:limit => 1, :offset => 0).size.should == 1
    @album.photos.all(:limit => 2, :offset => 0).size.should == 2 #[@photo1, @photo2]

    @album.photos.all(:limit => 0, :offset => 0).should == []
    @album.photos.all(:limit => 1, :offset => 1).size.should == 1 # [@photo2]
    @album.photos.all(:limit => 2, :offset => 2).should == []

    # testing *find* alias to *all*
    @album.photos.find(:limit => 1, :offset => 1).size.should == 1 
  end

  it "should delete associated records when :dependant => :destroy in *has_many* assoc" do
    @album.photos << [@photo1, @photo2]

    @album.photos.count.should == 2

    Photo.count.should == 2
    @album.destroy
    Photo.count.should == 0
    Album.count.should == 0
  end

  it "should *NOT* delete associated records when :dependant => :nullify or empty in *has_many* assoc" do
    Photo.count.should == 2

    category = Category.new
    category.title = "cats"
    category.save

    Category.count.should == 1

    category.photos << [@photo1, @photo2]
    category.photos.count.should == 2

    category.destroy

    Photo.count.should == 2
    Category.count.should == 0
  end

  it "should delete associated records when :dependant => :destroy and leave them otherwise in *has_one* assoc" do
    user = User.new
    user.name = "Dmitrii Samoilov"
    user.save
    user.should be

    user.photo = @photo1

    user.photo.id.should == @photo1.id

    User.count.should == 1
    Photo.count.should == 2
    user.destroy
    Photo.count.should == 1
    User.count.should == 0
  end

  it "should delete link to associated record when record was deleted" do
    @album.photos << [@photo1, @photo2]

    @album.photos.count.should == 2

    Photo.count.should == 2
    @photo1.destroy
    Photo.count.should == 1
    
    @album.photos.count.should == 1
    @album.photos.size.should == 1
  end
end
