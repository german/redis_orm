require 'spec_helper.rb'

describe "check associations" do
  it "should validate presence if image in photo" do
    p = Photo.new
    expect(p.save).to be_falsey
    expect(p.errors).to be
    expect(p.errors[:image]).to include("can't be blank")

    p.image = "test"
    expect(p.save).to be_falsey
    expect(p.errors).to be
    expect(p.errors[:image]).to include("is too short (minimum is 7 characters)")
    expect(p.errors[:image]).to include("is invalid")

    p.image = "facepalm.jpg"
    p.save
    expect(p.errors.blank?).to be true
  end
end
