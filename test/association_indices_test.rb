require File.dirname(File.expand_path(__FILE__)) + '/test_helper.rb'

describe "check indices for associations" do
  before(:each) do
    @article = Article.new :title => "DHH drops OpenID on 37signals"
    @article.save

    @article.should be
    @article.title.should == "DHH drops OpenID on 37signals"

    @comment1 = Comment.new :body => "test"
    @comment1.save
    @comment1.should be
    @comment1.body.should == "test"
    @comment1.moderated.should == false
    
    @comment2 = Comment.new :body => "test #2", :moderated => true
    @comment2.save
    @comment2.should be
    @comment2.body.should == "test #2"
    @comment2.moderated.should == true
  end

  it "should properly find associated records (e.g. with :conditions, :order, etc options) '<<' used for association" do
    @article.comments << [@comment1, @comment2]
    @article.comments.count.should == 2

    @article.comments.all(:limit => 1).size.should == 1
    @article.comments.find(:first).should be
    @article.comments.find(:first).id.should == @comment1.id
    @article.comments.find(:last).should be
    @article.comments.find(:last).id.should == @comment2.id

    @article.comments.find(:all, :conditions => {:moderated => true}).size.should == 1
    @article.comments.find(:all, :conditions => {:moderated => false}).size.should == 1
    @article.comments.find(:all, :conditions => {:moderated => true})[0].id.should == @comment2.id
    @article.comments.find(:all, :conditions => {:moderated => false})[0].id.should == @comment1.id

    @article.comments.find(:all, :conditions => {:moderated => true}, :limit => 1).size.should == 1
    @article.comments.find(:all, :conditions => {:moderated => false}, :limit => 1).size.should == 1
    @article.comments.find(:all, :conditions => {:moderated => true}, :limit => 1)[0].id.should == @comment2.id
    @article.comments.find(:all, :conditions => {:moderated => false}, :limit => 1)[0].id.should == @comment1.id

    @article.comments.find(:all, :conditions => {:moderated => true}, :limit => 1, :order => :desc).size.should == 1
    @article.comments.find(:all, :conditions => {:moderated => false}, :limit => 1, :order => :asc).size.should == 1
    @article.comments.find(:all, :conditions => {:moderated => true}, :limit => 1, :order => :desc)[0].id.should == @comment2.id
    @article.comments.find(:all, :conditions => {:moderated => false}, :limit => 1, :order => :asc)[0].id.should == @comment1.id

    @comment1.update_attribute :moderated, true
    @article.comments.find(:all, :conditions => {:moderated => true}).size.should == 2
    @article.comments.find(:all, :conditions => {:moderated => false}).size.should == 0

    @comment1.destroy
    $redis.zrange("article:#{@article.id}:comments:moderated:true", 0, -1).size.should == 1
    $redis.zrange("article:#{@article.id}:comments:moderated:true", 0, -1)[0].should == @comment2.id.to_s
    $redis.zrange("article:#{@article.id}:comments:moderated:false", 0, -1).size.should == 0
    @article.comments.find(:all, :conditions => {:moderated => true}).size.should == 1
    @article.comments.find(:all, :conditions => {:moderated => false}).size.should == 0
  end

  it "should properly find associated records (e.g. with :conditions, :order, etc options) '=' used for association" do
    @article.comments = [@comment1, @comment2]
    @article.comments.count.should == 2
    
    @article.comments.all(:limit => 1).size.should == 1
    @article.comments.find(:first).should be
    @article.comments.find(:first).id.should == @comment1.id
    @article.comments.find(:last).should be
    @article.comments.find(:last).id.should == @comment2.id
    
    @article.comments.find(:all, :conditions => {:moderated => true}).size.should == 1
    @article.comments.find(:all, :conditions => {:moderated => false}).size.should == 1
    @article.comments.find(:all, :conditions => {:moderated => true})[0].id.should == @comment2.id
    @article.comments.find(:all, :conditions => {:moderated => false})[0].id.should == @comment1.id
    
    @article.comments.find(:all, :conditions => {:moderated => true}, :limit => 1).size.should == 1
    @article.comments.find(:all, :conditions => {:moderated => false}, :limit => 1).size.should == 1
    @article.comments.find(:all, :conditions => {:moderated => true}, :limit => 1)[0].id.should == @comment2.id
    @article.comments.find(:all, :conditions => {:moderated => false}, :limit => 1)[0].id.should == @comment1.id
        
    @article.comments.find(:all, :conditions => {:moderated => true}, :limit => 1, :order => :desc).size.should == 1
    @article.comments.find(:all, :conditions => {:moderated => false}, :limit => 1, :order => :asc).size.should == 1
    @article.comments.find(:all, :conditions => {:moderated => true}, :limit => 1, :order => :desc)[0].id.should == @comment2.id
    @article.comments.find(:all, :conditions => {:moderated => false}, :limit => 1, :order => :asc)[0].id.should == @comment1.id
    
    @comment1.update_attribute :moderated, true
    @article.comments.find(:all, :conditions => {:moderated => true}).size.should == 2
    @article.comments.find(:all, :conditions => {:moderated => false}).size.should == 0
    
    @comment1.destroy
    @article.comments.find(:all, :conditions => {:moderated => true}).size.should == 1
    @article.comments.find(:all, :conditions => {:moderated => false}).size.should == 0
    $redis.zrange("article:#{@article.id}:comments:moderated:true", 0, -1).size.should == 1
    $redis.zrange("article:#{@article.id}:comments:moderated:true", 0, -1)[0].should == @comment2.id.to_s
    $redis.zrange("article:#{@article.id}:comments:moderated:false", 0, -1).size.should == 0
  end

  it "should check compound indices for associations" do
    friend1 = User.create :name => "Director", :moderator => true, :moderated_area => "films"
    friend2 = User.create :name => "Admin", :moderator => true, :moderated_area => "all"
    friend3 = User.create :name => "Gena", :moderator => false
    
    me = User.create :name => "german"
    
    me.friends << [friend1, friend2, friend3]
    
    me.friends.count.should == 3
    me.friends.find(:all, :conditions => {:moderator => true}).size.should == 2
    me.friends.find(:all, :conditions => {:moderator => false}).size.should == 1
    
    me.friends.find(:all, :conditions => {:moderator => true, :moderated_area => "films"}).size.should == 1
    me.friends.find(:all, :conditions => {:moderator => true, :moderated_area => "films"})[0].id.should == friend1.id

    # reverse key's order in :conditions hash
    me.friends.find(:all, :conditions => {:moderated_area => "all", :moderator => true}).size.should == 1
    me.friends.find(:all, :conditions => {:moderated_area => "all", :moderator => true})[0].id.should == friend2.id
  end
end
