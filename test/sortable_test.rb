require File.dirname(File.expand_path(__FILE__)) + '/test_helper.rb'

describe "test options" do
  before(:each) do
    @dan     = SortableUser.create :name => "Daniel",   :age => 26, :wage => 40000.0,   :address => "Bellevue"
    @abe     = SortableUser.create :name => "Abe",      :age => 30, :wage => 100000.0,  :address => "Bellevue"
    @michael = SortableUser.create :name => "Michael",  :age => 25, :wage => 60000.0,   :address => "Bellevue"
    @todd    = SortableUser.create :name => "Todd",     :age => 22, :wage => 30000.0,   :address => "Bellevue"
  end

  it "should return records in specified order" do
    RedisOrm.redis.llen("sortable_user:name_ids").to_i.should == SortableUser.count
    RedisOrm.redis.zcard("sortable_user:age_ids").to_i.should == SortableUser.count
    RedisOrm.redis.zcard("sortable_user:wage_ids").to_i.should == SortableUser.count
    
    SortableUser.find(:all, :order => [:name, :asc]).should == [@abe, @dan, @michael, @todd]
    SortableUser.find(:all, :order => [:name, :desc]).should == [@todd, @michael, @dan, @abe]
    
    SortableUser.find(:all, :order => [:age, :asc]).should == [@todd, @michael, @dan, @abe]
    SortableUser.find(:all, :order => [:age, :desc]).should == [@abe, @dan, @michael, @todd]
    
    SortableUser.find(:all, :order => [:wage, :asc]).should == [@todd, @dan, @michael, @abe]
    SortableUser.find(:all, :order => [:wage, :desc]).should == [@abe, @michael, @dan, @todd]
  end

  it "should return records which met specified conditions in specified order" do
    @abe2    = SortableUser.create :name => "Abe",      :age => 12, :wage => 10.0,      :address => "Santa Fe"
    
    # :asc should be default value for property in :order clause
    SortableUser.find(:all, :conditions => {:name => "Abe"}, :order => [:wage]).should == [@abe2, @abe]
    
    SortableUser.find(:all, :conditions => {:name => "Abe"}, :order => [:wage, :desc]).should == [@abe, @abe2]
    SortableUser.find(:all, :conditions => {:name => "Abe"}, :order => [:wage, :asc]).should == [@abe2, @abe]
    
    SortableUser.find(:all, :conditions => {:name => "Abe"}, :order => [:age, :desc]).should == [@abe, @abe2]
    SortableUser.find(:all, :conditions => {:name => "Abe"}, :order => [:age, :asc]).should == [@abe2, @abe]
    
    SortableUser.find(:all, :conditions => {:name => "Abe"}, :order => [:wage, :desc]).should == [@abe, @abe2]
    SortableUser.find(:all, :conditions => {:name => "Abe"}, :order => [:wage, :asc]).should == [@abe2, @abe]
  end

  it "should update keys after the persisted object was edited and sort properly" do
    @abe.update_attributes :name => "Zed", :age => 12, :wage => 10.0, :address => "Santa Fe"

    RedisOrm.redis.llen("sortable_user:name_ids").to_i.should == SortableUser.count
    RedisOrm.redis.zcard("sortable_user:age_ids").to_i.should == SortableUser.count
    RedisOrm.redis.zcard("sortable_user:wage_ids").to_i.should == SortableUser.count

    SortableUser.find(:all, :order => [:name, :asc]).should == [@dan, @michael, @todd, @abe]
    SortableUser.find(:all, :order => [:name, :desc]).should == [@abe, @todd, @michael, @dan]
        
    SortableUser.find(:all, :order => [:age, :asc]).should == [@abe, @todd, @michael, @dan]
    SortableUser.find(:all, :order => [:age, :desc]).should == [@dan, @michael, @todd, @abe]
    
    SortableUser.find(:all, :order => [:wage, :asc]).should == [@abe, @todd, @dan, @michael]
    SortableUser.find(:all, :order => [:wage, :desc]).should == [@michael, @dan, @todd, @abe]
  end

  it "should update keys after the persisted object was deleted and sort properly" do
    user_count = SortableUser.count
    @abe.destroy

    RedisOrm.redis.llen("sortable_user:name_ids").to_i.should == user_count - 1
    RedisOrm.redis.zcard("sortable_user:age_ids").to_i.should == user_count - 1
    RedisOrm.redis.zcard("sortable_user:wage_ids").to_i.should == user_count - 1

    SortableUser.find(:all, :order => [:name, :asc]).should == [@dan, @michael, @todd]
    SortableUser.find(:all, :order => [:name, :desc]).should == [@todd, @michael, @dan]
        
    SortableUser.find(:all, :order => [:age, :asc]).should == [@todd, @michael, @dan]
    SortableUser.find(:all, :order => [:age, :desc]).should == [@dan, @michael, @todd]
    
    SortableUser.find(:all, :order => [:wage, :asc]).should == [@todd, @dan, @michael]
    SortableUser.find(:all, :order => [:wage, :desc]).should == [@michael, @dan, @todd]
  end

  it "should sort objects with more than 3-4 symbols" do
    vladislav = SortableUser.create :name => "Vladislav", :age => 19, :wage => 120.0
    vladimir = SortableUser.create :name => "Vladimir", :age => 22, :wage => 220.5
    vlad = SortableUser.create :name => "Vlad", :age => 29, :wage => 1200.0
    
    SortableUser.find(:all, :order => [:name, :desc], :limit => 3).should == [vladislav, vladimir, vlad]
    SortableUser.find(:all, :order => [:name, :desc], :limit => 2, :offset => 4).should == [@michael, @dan]
    SortableUser.find(:all, :order => [:name, :desc], :offset => 3).should == [@todd, @michael, @dan, @abe]
    SortableUser.find(:all, :order => [:name, :desc]).should == [vladislav, vladimir, vlad, @todd, @michael, @dan, @abe]

    SortableUser.find(:all, :order => [:name, :asc], :limit => 3, :offset => 4).should == [vlad, vladimir, vladislav]
    SortableUser.find(:all, :order => [:name, :asc], :offset => 3).should == [@todd, vlad, vladimir, vladislav]
    SortableUser.find(:all, :order => [:name, :asc], :limit => 3).should == [@abe, @dan, @michael]
    SortableUser.find(:all, :order => [:name, :asc]).should == [@abe, @dan, @michael, @todd, vlad, vladimir, vladislav]
  end

  it "should properly handle multiple users with almost the same names" do
    users = [@abe, @todd, @michael, @dan]
    20.times{|i| users << SortableUser.create(:name => "user#{i}") }
    users.sort{|n,m| n.name <=> m.name}.should == SortableUser.all(:order => [:name, :asc])
  end

  it "should properly handle multiple users with almost the same names (descending order)" do
    rev_users = [@abe, @todd, @michael, @dan]
    20.times{|i| rev_users << SortableUser.create(:name => "user#{i}") }
    SortableUser.all(:order => [:name, :desc]).should == rev_users.sort{|n,m| n.name <=> m.name}.reverse
  end

  it "should properly store records with the same names" do
    users = [@abe, @todd, @michael, @dan]
    users << SortableUser.create(:name => "user#1")
    users << SortableUser.create(:name => "user#2")
    users << SortableUser.create(:name => "user#1")
    users << SortableUser.create(:name => "user#2")

    # we pluck only *name* here since it didn't sort by id (and it could be messed up)
    SortableUser.all(:order => [:name, :desc]).map{|u| u.name}.should == users.sort{|n,m| n.name <=> m.name}.map{|u| u.name}.reverse
    SortableUser.all(:order => [:name, :asc]).map{|u| u.name}.should == users.sort{|n,m| n.name <=> m.name}.map{|u| u.name}
  end
end
