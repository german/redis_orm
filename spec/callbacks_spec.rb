require 'spec_helper'

describe "check callbacks" do
  it "should fire after_create/after_destroy callbacks" do
    user = User.new :first_name => "Robert", :last_name => "Pirsig"
    user.save

    $redis.zrank("users:sorted_by_rating", user.id).should == 0

    comment = Comment.create :text => "First!"
    user.comments << comment

    u = User.first
    u.id.should == user.id
    u.comments.count.should == 1
    u.destroy
    u.comments.count.should == 0
  end

  it "should fire before_create/before_destroy callbacks" do
    CutoutAggregator.create

    CutoutAggregator.count.should == 1
    Cutout.create :filename => "1.jpg"
    Cutout.create :filename => "2.jpg"
    CutoutAggregator.last.revision.should == 2
    Cutout.last.destroy
    Cutout.last.destroy
    CutoutAggregator.count.should == 0
  end

  it "should fire after_save/before_save callbacks" do
    comment = Comment.new :text => "      Trim meeee !   "
    comment.save
    Comment.first.text.should == "Trim meeee !"

    user = User.new :first_name => "Robert", :last_name => "Pirsig"
    user.save
    user.karma.should == 1000

    user.comments << comment
    user.comments.count == 1

    c = Comment.first
    c.update_attributes :text => "Another brick in the wall"

    User.first.karma.should == 975
  end
end
