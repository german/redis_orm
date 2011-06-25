require File.dirname(File.expand_path(__FILE__)) + '/test_helper.rb'

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
  property :image_type, String
  
  property :checked, RedisOrm::Boolean, :default => false
  index :checked
  
  property :inverted, RedisOrm::Boolean, :default => true
  index :inverted
  
  index :image
  index [:image, :image_type]
  
  belongs_to :album
  belongs_to :user
  belongs_to :category
end

class User < RedisOrm::Base
  property :name, String
  
  has_one :photo, :dependent => :destroy
end

describe "test options" do
  before(:each) do
    @album = Album.new
    @album.title = "my 1st album"
    @album.save

    @album.should be
    @album.title.should == "my 1st album"

    @photo1 = Photo.new :image => "facepalm.jpg", :image_type => "jpg", :checked => true
    @photo1.save
    @photo1.should be
    @photo1.image.should == "facepalm.jpg"
    @photo1.image_type.should == "jpg"

    @photo2 = Photo.new :image => "boobs.png", :image_type => "png", :inverted => false
    @photo2.save
    @photo2.should be
    @photo2.image.should == "boobs.png"
    @photo2.image_type.should == "png"
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
    
    Photo.find(:all).size.should == 2
    Photo.find(:first).id.should == @photo1.id
    Photo.find(:last).id.should == @photo2.id
    
    Photo.find(:all, :conditions => {:image => "facepalm.jpg"}).size.should == 1
    Photo.find(:all, :conditions => {:image => "boobs.png"}).size.should == 1

    Photo.find(:all, :conditions => {:image => "facepalm.jpg", :image_type => "jpg"}).size.should == 1
    Photo.find(:all, :conditions => {:image => "boobs.png", :image_type => "png"}).size.should == 1
        
    Photo.find(:first, :conditions => {:image => "facepalm.jpg"}).id.should == @photo1.id
    Photo.find(:first, :conditions => {:image => "boobs.png"}).id.should == @photo2.id
    
    Photo.find(:first, :conditions => {:image => "facepalm.jpg", :image_type => "jpg"}).id.should == @photo1.id
    Photo.find(:first, :conditions => {:image => "boobs.png", :image_type => "png"}).id.should == @photo2.id
    
    Photo.find(:last, :conditions => {:image => "facepalm.jpg"}).id.should == @photo1.id
    Photo.find(:last, :conditions => {:image => "boobs.png"}).id.should == @photo2.id
    
    Photo.find(:last, :conditions => {:image => "facepalm.jpg", :image_type => "jpg"}).id.should == @photo1.id
    Photo.find(:last, :conditions => {:image => "boobs.png", :image_type => "png"}).id.should == @photo2.id
  end

  it "should correctly save boolean values" do
    $redis.hgetall("photo:#{@photo1.id}")["inverted"].should == "true"
    $redis.hgetall("photo:#{@photo2.id}")["inverted"].should == "false"

    @photo1.inverted.should == true 
    @photo2.inverted.should == false
        
    $redis.zrange("photo:inverted:true", 0, -1).should include(@photo1.id.to_s)
    $redis.zrange("photo:inverted:false", 0, -1).should include(@photo2.id.to_s)
    
    $redis.hgetall("photo:#{@photo1.id}")["checked"].should == "true"
    $redis.hgetall("photo:#{@photo2.id}")["checked"].should == "false"
    
    @photo1.checked.should == true
    @photo2.checked.should == false
    
    $redis.zrange("photo:checked:true", 0, -1).should include(@photo1.id.to_s)
    $redis.zrange("photo:checked:false", 0, -1).should include(@photo2.id.to_s)
  end

  it "should search on bool values properly" do
    Photo.find(:all, :conditions => {:checked => true}).size.should == 1
    Photo.find(:all, :conditions => {:checked => true}).first.id.should == @photo1.id
    Photo.find(:all, :conditions => {:checked => false}).size.should == 1
    Photo.find(:all, :conditions => {:checked => false}).first.id.should == @photo2.id
    
    Photo.find(:all, :conditions => {:inverted => true}).size.should == 1
    Photo.find(:all, :conditions => {:inverted => true}).first.id.should == @photo1.id
    Photo.find(:all, :conditions => {:inverted => false}).size.should == 1
    Photo.find(:all, :conditions => {:inverted => false}).first.id.should == @photo2.id
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
