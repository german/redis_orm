require 'rails/all'
require 'rspec'
require 'rspec/autorun'

$: << File.dirname(File.expand_path(__FILE__)) + '/../lib/'

module RedisOrmRails
  class Application < ::Rails::Application
  end
end

require 'rspec/rails'
require 'ammeter/init'

RSpec.configure do |config|  
  config.mock_with :rspec
end
