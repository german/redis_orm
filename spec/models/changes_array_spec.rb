require 'spec_helper.rb'

describe "check associations" do
  it "should return correct _changes array" do
    user = User.new name: "german"
    expect(user.name_changed?).to be_falsey
    
    expect(user.name_changes).to eq(["german"])
    user.save
    
    expect(user.name_changes).to eq(["german"])
    user.name = "germaninthetown"
    expect(user.name_changes).to eq(["german", "germaninthetown"])
    expect(user.name_changed?).to be_truthy
    user.save

    user = User.first
    expect(user.name).to eq("germaninthetown")
    expect(user.name_changed?).to be_falsey
    expect(user.name_changes).to eq(["germaninthetown"])
    user.name = "german"
    expect(user.name_changed?).to be_truthy
    expect(user.name_changes).to eq(["germaninthetown", "german"])
  end
end
