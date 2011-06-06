require 'rspec'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'

class Album < RedisOrm::Base
  property :title, String

  has_one :photo, :as => :front_photo
  has_many :photos, :dependent => :destroy
end

class Category < RedisOrm::Base
  property :title, String

  has_many :photos, :dependent => :nullify
end

class Photo < RedisOrm::Base
  property :image, String
  
  belongs_to :album
  belongs_to :user
  belongs_to :category
end

class User < RedisOrm::Base
  property :name, String
  
  has_one :photo, :dependent => :destroy
end

describe "test options" do
  before(:all) do
    path_to_conf = File.dirname(File.expand_path(__FILE__)) + "/redis.conf"
    $redis_pid = spawn 'redis-server ' + path_to_conf, :out => "/dev/null"
    sleep(0.3) # must be some delay otherwise "Connection refused - Unable to connect to Redis"
    path_to_socket = File.dirname(File.expand_path(__FILE__)) + "/../redis.sock"
    $redis = Redis.new(:host => 'localhost', :path => path_to_socket)
  end
  
  after(:all) do
    Process.kill 9, $redis_pid.to_i if $redis_pid
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

    @album.photos.find(:all, :limit => 1, :offset => 1).size.should == 1 
  end

  it "should return correct array when :order option is provided" do
    Photo.all(:order => "asc").map{|p| p.id}.should == [@photo1.id, @photo2.id]
    Photo.all(:order => "desc").map{|p| p.id}.should == [@photo2.id, @photo1.id]

    Photo.all(:order => "asc", :limit => 1).map{|p| p.id}.should == [@photo1.id]
    Photo.all(:order => "desc", :limit => 1).map{|p| p.id}.should == [@photo2.id]

    Photo.all(:order => "asc", :limit => 1, :offset => 1).map{|p| p.id}.should == [@photo2.id]
    Photo.all(:order => "desc", :limit => 1, :offset => 1).map{|p| p.id}.should == [@photo1.id]

    # testing #find method
    Photo.find(:all, :order => "asc").map{|p| p.id}.should == [@photo1.id, @photo2.id]
    Photo.find(:all, :order => "desc").map{|p| p.id}.should == [@photo2.id, @photo1.id]

    Photo.find(:all, :order => "asc", :limit => 1).map{|p| p.id}.should == [@photo1.id]
    Photo.find(:all, :order => "desc", :limit => 1).map{|p| p.id}.should == [@photo2.id]

    Photo.find(:first, :order => "asc", :limit => 1, :offset => 1).id.should == @photo2.id
    Photo.find(:first, :order => "desc", :limit => 1, :offset => 1).id.should == @photo1.id

    Photo.find(:last, :order => "asc").id.should == @photo2.id
    Photo.find(:last, :order => "desc").id.should == @photo1.id
    
    @album.photos.count.should == 0
    @album.photos.all(:limit => 2, :offset => 0).should == []
    @album.photos << @photo2
    @album.photos << @photo1

    @album.photos.all(:order => "asc").map{|p| p.id}.should == [@photo2.id, @photo1.id]
    @album.photos.all(:order => "desc").map{|p| p.id}.should == [@photo1.id, @photo2.id]
    @album.photos.all(:order => "asc", :limit => 1).map{|p| p.id}.should == [@photo2.id]
    @album.photos.all(:order => "desc", :limit => 1).map{|p| p.id}.should == [@photo1.id]
    @album.photos.all(:order => "asc", :limit => 1, :offset => 1).map{|p| p.id}.should == [@photo1.id]
    @album.photos.all(:order => "desc", :limit => 1, :offset => 1).map{|p| p.id}.should == [@photo2.id]

    @album.photos.find(:all, :order => "asc").map{|p| p.id}.should == [@photo2.id, @photo1.id]
    @album.photos.find(:all, :order => "desc").map{|p| p.id}.should == [@photo1.id, @photo2.id]
    
    @album.photos.find(:first, :order => "asc").id.should == @photo2.id
    @album.photos.find(:first, :order => "desc").id.should == @photo1.id

    @album.photos.find(:last, :order => "asc").id.should == @photo1.id
    @album.photos.find(:last, :order => "desc").id.should == @photo2.id
        
    @album.photos.find(:last, :order => "desc", :offset => 2).should == nil
    @album.photos.find(:first, :order => "desc", :offset => 2).should == nil
    
    @album.photos.find(:all, :order => "asc", :limit => 1, :offset => 1).map{|p| p.id}.should == [@photo1.id]
    @album.photos.find(:all, :order => "desc", :limit => 1, :offset => 1).map{|p| p.id}.should == [@photo2.id]
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
