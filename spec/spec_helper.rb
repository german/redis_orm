require 'rails/all'
require 'rspec'
require_relative '../lib/redis_orm'

$: << File.dirname(File.expand_path(__FILE__)) + '/../lib/'

module RedisOrmRails
  class Application < ::Rails::Application
  end
end

require 'rspec/rails'
require 'ammeter/init'

Dir.glob(['spec/classes/*.rb', 'spec/modules/*.rb']).each do |klassfile|
  require File.dirname(File.expand_path(__FILE__)) + '/../' + klassfile
end

RSpec.configure do |config|  
  config.mock_with :rspec

  config.before(:all) do
    begin
      $redis = Redis.new(:host => 'localhost')
    rescue => e
      puts 'Unable to create connection to the redis server: ' + e.message.inspect
      Process.kill 9, $redis_pid.to_i if $redis_pid
    end
  end
  
  config.after(:all) do
    Process.kill 9, $redis_pid.to_i if $redis_pid
  end

  config.after(:each) do
   $redis.flushall if $redis
  end

  config.before(:each) do
    $redis.flushall if $redis
  end
end
