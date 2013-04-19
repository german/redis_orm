require 'spec_helper'

require 'rails/generators/redis_orm/model/model_generator'

describe RedisOrm::Generators::ModelGenerator do
  destination File.expand_path(File.join(File.dirname(__FILE__), 
                               '..', '..', 'tmp'))

  before do
    prepare_destination
    run_generator args
  end
  subject { file('app/models/post.rb') }

  context "Given only model's name" do
    let(:args) { %w[post] }

    it { should exist }
  end
  context "Given model's name and attributes" do
    let(:args) { %w[post title:string created_at:time] }

    it { should exist }
    it "should define properties" do
      should contain /property\s+title,\sString/
    end
  end

end
