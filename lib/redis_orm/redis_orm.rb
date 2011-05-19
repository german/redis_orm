require 'active_support/inflector/inflections'
require 'active_support/inflector/transliterate'
require 'active_support/inflector/methods'
require 'active_support/inflections'
require 'active_support/core_ext/string/inflections'

module RedisOrm
  module Associations
    class HasMany
      def initialize(reciever_model_name, reciever_id, foreign_models)
        @records = [] #records.to_a
        @reciever_model_name = reciever_model_name
        @reciever_id = reciever_id
        @foreign_models = foreign_models
        @fetched = false
      end

      def fetch
        @records = @foreign_models.to_s.singularize.camelize.constantize.find($redis.zrevrangebyscore "#{@reciever_model_name}:#{@reciever_id}:#{@foreign_models}", Time.now.to_i, 0)
        @fetched = true
      end

      def [](index)
        fetch if !@fetched
        @records[index]
      end

      # user = User.find(1)
      # user.avatars << Avatar.find(23) => user:1:avatars => [23]
      def <<(new_records)
        new_records.to_a.each do |record|
          #puts 'record - ' + record.inspect
          $redis.zadd("#{@reciever_model_name}:#{@reciever_id}:#{record.model_name.pluralize}", Time.now.to_i, record.id)

          # article.comments << [comment1, comment2] 
          # iterate through the array of comments and create backlink
          # check whether *record* object has *has_many* declaration and TODO it states *self.model_name* in plural and there is no record yet from the *record*'s side (in order not to provoke recursion)
          
          if record.get_associations.detect{|h| h[:type] == :has_many && h[:foreign_models] == @reciever_model_name.pluralize.to_sym} && record.model_name.to_s.camelize.constantize.find(@reciever_id).nil?
                        
            $redis.zadd("#{record.model_name}:#{record.id}:#{@reciever_model_name}", Time.now.to_i, @reciever_id)
            

          # check whether *record* object has *has_one* declaration and TODO it states *self.model_name* and there is no record yet from the *record*'s side (in order not to provoke recursion)
          elsif record.get_associations.detect{|h| [:has_one, :belongs_to].include?(h[:type]) && h[:foreign_model] == @reciever_model_name.to_sym} && record.send(@reciever_model_name.to_sym).nil?
            
            $redis.set("#{record.model_name}:#{record.id}:#{@reciever_model_name}", @reciever_id)
            #record.send("#{@reciever_model_name}=", self)            
          end
        end
      end

      def all(options = {})
        if options[:limit] && options[:offset]
          # ZREVRANGEBYSCORE album:ids 1305451611 1305443260 LIMIT 0, 2
          record_ids = $redis.zrevrangebyscore("#{@reciever_model_name}:#{@reciever_id}:#{@foreign_models}", Time.now.to_i, 0, :limit => [options[:offset].to_i, options[:limit].to_i])
          @fetched = true
          @records = @foreign_models.to_s.singularize.camelize.constantize.find(record_ids)
        elsif options[:limit]
          record_ids = $redis.zrevrangebyscore("#{@reciever_model_name}:#{@reciever_id}:#{@foreign_models}", Time.now.to_i, 0, :limit => [0, options[:limit].to_i])
          @fetched = true
          @records = @foreign_models.to_s.singularize.camelize.constantize.find(record_ids)
        else
          fetch if !@fetched
          @records
        end
      end

      alias :find :all

      def count
        $redis.zcard "#{@reciever_model_name}:#{@reciever_id}:#{@foreign_models}"
      end

      def method_missing(method_name, *args, &block)
        fetch if !@fetched
        @records.send(method_name, *args, &block)        
      end
    end
  end

  class TypeMismatchError < StandardError
  end

  class ArgumentsMismatch < StandardError
  end

  class Base
    include ActiveModelBehavior

    attr_accessor :persisted

    @@properties = Hash.new{|h,k| h[k] = []}
    @@indices = Hash.new{|h,k| h[k] = []} # compound indices are available too   
    @@associations = Hash.new{|h,k| h[k] = []}
    @@callbacks = Hash.new{|h,k| h[k] = {}}    

    class << self

      def inherited(from)
        @@callbacks[from.model_name][:after_save] = []
        @@callbacks[from.model_name][:before_save] = []
        @@callbacks[from.model_name][:after_destroy] = []
        @@callbacks[from.model_name][:before_destroy] = []
      end
     
      def index(name, options = {})
        @@indices[model_name] << name
      end

      # class Avatar < RedisOrm::Base
      #   belongs_to :user
      # end 
      #
      # class User < RedisOrm::Base
      #   has_many :avatars
      # end 
      #
      # avatar.user => avatar:234:user => 1 => User.find(1)
      def belongs_to(foreign_model, options = {})
        @@associations[model_name] << {:type => :belongs_to, :foreign_model => foreign_model, :options => options}

        foreign_model_name = if options[:as]
          options[:as].to_sym
        else
          foreign_model.to_sym
        end

        define_method foreign_model_name.to_sym do
          foreign_model.to_s.camelize.constantize.find($redis.get "#{model_name}:#{@id}:#{foreign_model_name}")
        end

        # look = Look.create :title => 'test'
        # look.user = User.find(1) => look:23:user => 1
        define_method "#{foreign_model_name}=" do |assoc_with_record|
          if assoc_with_record.model_name == foreign_model.to_s
            $redis.set("#{model_name}:#{id}:#{foreign_model_name}", assoc_with_record.id)
          else
            raise TypeMismatchError
          end

          # check whether *assoc_with_record* object has *has_many* declaration and TODO it states *self.model_name* in plural and there is no record yet from the *assoc_with_record*'s side (in order not to provoke recursion)
          if @@associations[assoc_with_record.model_name].detect{|h| h[:type] == :has_many && h[:foreign_models] == model_name.pluralize.to_sym} && !$redis.zrank("#{assoc_with_record.model_name}:#{assoc_with_record.id}:#{model_name.pluralize}", self.id)            
            assoc_with_record.send(model_name.pluralize.to_sym).send(:"<<", self)

          # check whether *assoc_with_record* object has *has_one* declaration and TODO it states *self.model_name* and there is no record yet from the *assoc_with_record*'s side (in order not to provoke recursion)
          elsif @@associations[assoc_with_record.model_name].detect{|h| h[:type] == :has_one && h[:foreign_model] == model_name.to_sym} && assoc_with_record.send(model_name.to_sym).nil?
            assoc_with_record.send("#{model_name}=", self)            
          end
        end
      end

      # user.avatars => user:1:avatars => [1, 22, 234] => Avatar.find([1, 22, 234])
      # options
      #   *:dependant* key: either *destroy* or *nullify* (default)
      def has_many(foreign_models, options = {})
        @@associations[model_name] << {:type => :has_many, :foreign_models => foreign_models, :options => options}

        define_method foreign_models.to_sym do
          #records = foreign_models.to_s.singularize.camelize.constantize.find($redis.smembers "#{model_name}:#{@id}:#{foreign_models}")
          #Associations::HasMany.new(model_name, id, records)
          Associations::HasMany.new(model_name, id, foreign_models)
        end
      end

      # user.avatars => user:1:avatars => [1, 22, 234] => Avatar.find([1, 22, 234])
      # *options* is a hash and can hold:
      #   *:as* key
      #   *:dependant* key: either *destroy* or *nullify* (default)
      def has_one(foreign_model, options = {})
        @@associations[model_name] << {:type => :has_one, :foreign_model => foreign_model, :options => options}

        foreign_model_name = if options[:as]
          options[:as].to_sym
        else
          foreign_model.to_sym
        end

        define_method foreign_model_name do
          foreign_model.to_s.camelize.constantize.find($redis.get "#{model_name}:#{@id}:#{foreign_model_name}")
        end     

        # profile = Profile.create :title => 'test'
        # user.profile = profile => user:23:profile => 1
        define_method "#{foreign_model_name}=" do |assoc_with_record|
          # we need to store this to clear old associations later
          old_assoc = self.send(assoc_with_record.model_name)
          #puts 'old_assoc - ' + old_assoc.inspect

          if assoc_with_record.model_name == foreign_model.to_s
            $redis.set("#{model_name}:#{id}:#{foreign_model_name}", assoc_with_record.id)
          else
            raise TypeMismatchError
          end

#puts 'assoc_with_record.model_name - ' + assoc_with_record.model_name.inspect
#puts '@@associations[assoc_with_record.model_name] ' + @@associations[assoc_with_record.model_name].inspect

          # check whether *assoc_with_record* object has *belongs_to* declaration and TODO it states *self.model_name* and there is no record yet from the *assoc_with_record*'s side (in order not to provoke recursion)
          if @@associations[assoc_with_record.model_name].detect{|h| [:belongs_to, :has_one].include?(h[:type]) && h[:foreign_model] == model_name.to_sym} && assoc_with_record.send(model_name.to_sym).nil?
            assoc_with_record.send("#{model_name}=", self)
          elsif @@associations[assoc_with_record.model_name].detect{|h| :has_many == h[:type] && h[:foreign_models] == model_name.to_s.pluralize.to_sym} && !$redis.zrank("#{assoc_with_record.model_name}:#{assoc_with_record.id}:#{model_name.pluralize}", self.id)
            # remove old assoc 
            # $redis.zrank "city:2:profiles", 12                       
            if old_assoc
              #puts 'key - ' + "#{assoc_with_record.model_name}:#{old_assoc.id}:#{model_name.to_s.pluralize}"
              #puts 'self.id - ' + self.id.to_s
              $redis.zrem "#{assoc_with_record.model_name}:#{old_assoc.id}:#{model_name.to_s.pluralize}", self.id
            end
            # create/add new ones
            assoc_with_record.send(model_name.pluralize.to_sym).send(:"<<", self)
          end
        end
      end

      def property(property_name, class_name)
        @@properties[model_name] << property_name

        send(:define_method, property_name) do
          instance_variable_get(:"@#{property_name}")
        end

        send(:define_method, :"#{property_name}=") do |value|
          instance_variable_set(:"@#{property_name}", value)
        end
      end

      def count
        $redis.zcard("#{model_name}:ids").to_i
      end

      def first
        id = $redis.zrangebyscore("#{model_name}:ids", 0, Time.now.to_i, :limit => [0, 1])
        id.empty? ? nil : find(id[0])
      end

      def last
        id = $redis.zrevrangebyscore("#{model_name}:ids", Time.now.to_i, 0, :limit => [0, 1])
        id.empty? ? nil : find(id[0])
      end

      def all(options = {})
        if options[:limit] && options[:offset]
          $redis.zrevrangebyscore("#{model_name}:ids", Time.now.to_i, 0, :limit => [options[:offset].to_i, options[:limit].to_i]).compact.collect{|id| find(id)}
        elsif options[:limit]
          # ZREVRANGEBYSCORE album:ids 1305451611 1305443260 LIMIT 0, 2
          $redis.zrevrangebyscore("#{model_name}:ids", Time.now.to_i, 0, :limit => [0, options[:limit].to_i]).compact.collect{|id| find(id)}
        else
          $redis.zrange("#{model_name}:ids", 0, -1).compact.collect{|id| find(id)}
        end
      end

      def find(ids)
        if(ids.is_a?(Array))
          ids.inject([]) do |array, id|
            record = $redis.hgetall "#{model_name}:#{id}"
            if record && !record.empty?
              array << new(id, record, true)
            end
          end
        else
          id = ids
          record = $redis.hgetall "#{model_name}:#{id}"
          if record && record.empty?
            nil
          else
            new(id, record, true)
          end
        end        
      end

      def after_save(callback)        
        @@callbacks[model_name][:after_save] << callback
      end

      def before_destroy(callback)        
        @@callbacks[model_name][:before_destroy] << callback
      end

      def create(options = {})
        obj = new
        options.each do |key, value|
          obj.send(:key, value) if obj.respond_to?(:key)
        end
      end

      # dynamic finders
      def method_missing(method_name, *args, &block)
        if method_name =~ /^find_by_(\w*)/
          record = nil
          if $1
            properties = $1.split('_and_')
            raise ArgumentsMismatch if properties.size != args.size            
            properties.each_with_index do |prop, i|              
              id = $redis.get "#{model_name}:#{prop}:#{args[i].to_s}"              
              record = model_name.to_s.camelize.constantize.find(id) if id
            end
          end
          record
        elsif method_name =~ /^find_all_by_(\w*)/
          records = []
          if $1
            properties = $1.split('_and_')
            raise ArgumentsMismatch if properties.size != args.size            
            properties.each_with_index do |prop, i|
              keys = $redis.keys "#{model_name}:#{prop}:#{args[i].to_s}"
              if !keys.empty?
                keys.each do |key|
                  records << model_name.to_s.camelize.constantize.find($redis.get(keys[0]))
                end
              end
            end
          end
          records
        else
          nil
        end
      end
    end

    # could be invoked from has_many module (<< method)
    def to_a
      [self]
    end

    # is called from RedisOrm::Associations::HasMany to save backlinks to saved records
    def get_associations
      @@associations[self.model_name]
    end

    def initialize(id = nil, hash = nil, persisted = false)
      @persisted = persisted
      
      instance_variable_set(:"@id", id.to_i) if id

      if hash && hash.is_a?(Hash)
        @@properties[model_name].each do |prop|          
          instance_variable_set(:"@#{prop}", hash[prop.to_s]) if hash[prop.to_s]
        end
      end
      self
    end

    def id
      @id
    end

    def persisted?
      @persisted
    end

    def save
      if !persisted?
        @id = $redis.incr("#{model_name}:id")
        $redis.zadd "#{model_name}:ids", Time.now.to_i, @id
        @persisted = true
      end

      @@callbacks[model_name][:before_save].each do |callback|
        self.send(callback)
      end

      @@properties[model_name].each do |prop|
        #puts 'self.send(prop.to_sym) - ' + self.send(prop.to_sym).to_s
        $redis.hset("#{model_name}:#{id}", prop.to_s, self.send(prop.to_sym))
      end

      # save indices in order to sort by finders
      # city:name:Харьков => 1
      @@indices[model_name].each do |index|
        if index.is_a?(Array) # TODO sort alphabetically
          prepared_index = index.inject([model_name]) do |sum, index_part|
            sum += [index_part, self.instance_variable_get(:"@#{index_part}")]
          end.join(':')
          $redis.set(prepared_index, @id)
        else
          prepared_index = [model_name, index, self.instance_variable_get(:"@#{index}")].join(':')
          $redis.set(prepared_index, @id)        
        end
      end

      @@callbacks[model_name][:after_save].each do |callback|
        self.send(callback)
      end
    end

    def update_attributes(attributes)
      if attributes.is_a?(Hash)
        attributes.each do |key, value|
          self.send("#{key}=".to_sym, value) if self.respond_to?("#{key}=".to_sym)
        end
      end
    end

    def destroy
      @@callbacks[model_name][:before_destroy].each do |callback|
        self.send(callback)
      end

      @@properties[model_name].each do |prop|
        $redis.hdel("#{model_name}:#{@id}", prop.to_s)
      end

      $redis.zrem "#{model_name}:ids", @id

      # also we need to delete *links* to associated records
      if !@@associations[model_name].empty?
        @@associations[model_name].each do |assoc|

          foreign_model  = ""
          records = []

          case assoc[:type]
            when :belongs_to
              foreign_model = assoc[:foreign_model].to_s
              foreign_model_name = assoc[:options][:as] ? assoc[:options][:as] : assoc[:foreign_model]
              records << self.send(foreign_model_name)

              $redis.del "#{model_name}:#{@id}:#{assoc[:foreign_model]}"
            when :has_one
              foreign_model = assoc[:foreign_model].to_s
              foreign_model_name = assoc[:options][:as] ? assoc[:options][:as] : assoc[:foreign_model]
              records << self.send(foreign_model_name)

              $redis.del "#{model_name}:#{@id}:#{assoc[:foreign_model]}"
            when :has_many
              foreign_model = assoc[:foreign_models].to_s.singularize
              foreign_models_name = assoc[:options][:as] ? assoc[:options][:as] : assoc[:foreign_models]
              records += self.send(foreign_models_name)

              # delete all members             
              $redis.zremrangebyscore "#{model_name}:#{@id}:#{assoc[:foreign_models]}", 0, Time.now.to_i              
          end

puts 'from destroy foreign_model - ' + foreign_model.inspect
if !records.empty?
  puts 'from destroy records[0] - ' + records[0].inspect
end
puts 'from destroy records.compact.empty? - ' + records.compact.empty?.inspect

          # check whether foreign_model also has an assoc to the destroying record
          # and remove an id of destroing record from each of associated sets
          if !records.compact.empty?
            records.compact.each do |record|
              # we make 3 different checks rather then 1 with elsif to ensure that all associations will be processed
              # it's covered in test/option_test in "should delete link to associated record when record was deleted" scenario
              # for if class Album; has_one :photo, :as => :front_photo; has_many :photos; end
              # end some photo from the album will be deleted w/o these checks only first has_one will be triggered
              if @@associations[foreign_model].detect{|h| h[:type] == :belongs_to && h[:foreign_model] == model_name.to_sym}
                puts 'from destr :belongs_to - ' + "#{foreign_model}:#{record.id}:#{model_name}"
                $redis.del "#{foreign_model}:#{record.id}:#{model_name}"
              end
              
              if @@associations[foreign_model].detect{|h| h[:type] == :has_one && h[:foreign_model] == model_name.to_sym}
                puts 'from destr :has_one - ' + "#{foreign_model}:#{record.id}:#{model_name}"
                $redis.del "#{foreign_model}:#{record.id}:#{model_name}"
              end

              if @@associations[foreign_model].detect{|h| h[:type] == :has_many && h[:foreign_models] == model_name.pluralize.to_sym}
                puts "from destr :has_many - " + "#{foreign_model}:#{record.id}:#{model_name.pluralize}"
                $redis.zrem "#{foreign_model}:#{record.id}:#{model_name.pluralize}", @id
              end
            end
          end

          if assoc[:options][:dependant] == :destroy
            puts 'assoc[:options][:dependant] - ' + assoc[:options][:dependant].inspect
            puts 'records.size - ' + records.size.inspect
            records.each do |r|
              puts 'r - ' + r.inspect
              r.destroy
            end
          end
        end
      end      

      # we need to ensure that smembers are correct after removal of the record
      @@indices[model_name].each do |index|
        if index.is_a?(Array) # TODO sort alphabetically
          prepared_index = index.inject([model_name]) do |sum, index_part|
            sum += [index_part, self.instance_variable_get(:"@#{index_part}")]
          end.join(':')
          $redis.del(prepared_index)
        else
          prepared_index = [model_name, index, self.instance_variable_get(:"@#{index}")].join(':')
          $redis.del(prepared_index)
        end
      end
      
      @@callbacks[model_name][:after_destroy].each do |callback|
        self.send(callback)
      end
    end    
  end
end
