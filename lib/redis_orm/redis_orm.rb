require 'active_support/inflector/inflections'
require 'active_support/inflector/transliterate'
require 'active_support/inflector/methods'
require 'active_support/inflections'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/time/calculations' # local_time for to_time(:local)
require 'active_support/core_ext/string/conversions' # to_time

module RedisOrm
  class Boolean
  end

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

  # it's raised when found request was initiated on the property/properties which have no index on it
  class NotIndexFound < StandardError
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
     
      # *options* currently supports
      #   *unique* Boolean
      #   *case_insencetive* Boolean TODO 
      def index(name, options = {})
        @@indices[model_name] << {:name => name, :options => options}
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
          old_assoc = self.send(foreign_model_name)

          if assoc_with_record.model_name == foreign_model.to_s
            $redis.set("#{model_name}:#{id}:#{foreign_model_name}", assoc_with_record.id)
          else
            raise TypeMismatchError
          end

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

      def property(property_name, class_name, options = {})
        @@properties[model_name] << {:name => property_name, :class => class_name.to_s, :options => options}

        send(:define_method, property_name) do
          value = instance_variable_get(:"@#{property_name}")

          return value if value.nil? # we must return nil here so :default option will work when saving

          if Time == class_name
            value = value.to_s.to_time(:local)
          elsif Integer == class_name
            value = value.to_i
          elsif Float == class_name
            value = value.to_f
          elsif RedisOrm::Boolean == class_name
            value = (value == "false" ? false : true)
          end
          value
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
          return [] if ids.empty?
          ids.inject([]) do |array, id|
            record = $redis.hgetall "#{model_name}:#{id}"
            if record && !record.empty?
              array << new(record, id, true)
            end
          end
        else
          return nil if ids.nil?
          id = ids
          record = $redis.hgetall "#{model_name}:#{id}"
          if record && record.empty?
            nil
          else
            new(record, id, true)
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
        obj = new(options, nil, false)
        obj.save
      end

      # dynamic finders
      def method_missing(method_name, *args, &block)
        if method_name =~ /^find_(all_)?by_(\w*)/
          prepared_index = model_name.to_s
          index = if $2
            properties = $2.split('_and_')
            raise ArgumentsMismatch if properties.size != args.size
            
            properties.each_with_index do |prop, i|
              # raise if User.find_by_firstname_and_castname => there's no *castname* in User's properties
              raise ArgumentsMismatch if !@@properties[model_name].detect{|p| p[:name] == prop.to_sym}
              prepared_index += ":#{prop}:#{args[i].to_s}"
            end

            @@indices[model_name].detect do |models_index|
              if models_index[:name].is_a?(Array) && models_index[:name].size == properties.size
                models_index[:name] == properties.map{|p| p.to_sym}
              elsif !models_index[:name].is_a?(Array) && properties.size == 1
                models_index[:name] == properties[0].to_sym
              end
            end
          end

          raise NotIndexFound if !index

          if method_name =~ /^find_by_(\w*)/                      
            id = if index[:options][:unique]            
              $redis.get prepared_index
            else
              $redis.zrangebyscore(prepared_index, 0, Time.now.to_i, :limit => [0, 1])[0]
            end
            model_name.to_s.camelize.constantize.find(id)
          elsif method_name =~ /^find_all_by_(\w*)/
            records = []          

            if index[:options][:unique]            
              id = $redis.get prepared_index
              records << model_name.to_s.camelize.constantize.find(id)
            else
              ids = $redis.zrangebyscore(prepared_index, 0, Time.now.to_i)
              records += model_name.to_s.camelize.constantize.find(ids)
            end          

            records
          else
            nil
          end
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

    def initialize(attributes = {}, id = nil, persisted = false)
      @persisted = persisted
      
      instance_variable_set(:"@id", id.to_i) if id

      if attributes.is_a?(Hash) && !attributes.empty?        
        attributes.each do |key, value|
          self.send("#{key}=".to_sym, value) if self.respond_to?("#{key}=".to_sym)
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

        if @@properties[model_name].detect{|p| p[:name] == :created_at }
          self.created_at = Time.now
        end
      end

      @@callbacks[model_name][:before_save].each do |callback|
        self.send(callback)
      end

      if @@properties[model_name].detect{|p| p[:name] == :modified_at }
        self.modified_at = Time.now
      end

      @@properties[model_name].each do |prop|
        prop_value = self.send(prop[:name].to_sym)
        if prop_value.nil? && prop[:options][:default]
          prop_value = prop[:options][:default]
        end
        $redis.hset("#{model_name}:#{id}", prop[:name].to_s, prop_value)
      end

      # save indices in order to sort by finders
      # city:name:Харьков => 1
      @@indices[model_name].each do |index|
        prepared_index = if index[:name].is_a?(Array) # TODO sort alphabetically
          index[:name].inject([model_name]) do |sum, index_part|
            sum += [index_part, self.instance_variable_get(:"@#{index_part}")]
          end.join(':')
        else
          [model_name, index[:name], self.instance_variable_get(:"@#{index[:name]}")].join(':')
        end

        if index[:options][:unique]
          $redis.set(prepared_index, @id)
        else
          $redis.zadd(prepared_index, Time.now.to_i, @id)
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
      save
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
        prepared_index = if index[:name].is_a?(Array) # TODO sort alphabetically
          index[:name].inject([model_name]) do |sum, index_part|
            sum += [index_part, self.instance_variable_get(:"@#{index_part}")]
          end.join(':')          
        else
          [model_name, index[:name], self.instance_variable_get(:"@#{index[:name]}")].join(':')
        end

        if index[:options][:unique]
          $redis.del(prepared_index)
        else
          $redis.zremrangebyscore(prepared_index, 0, Time.now.to_i)
        end
      end
      
      @@callbacks[model_name][:after_destroy].each do |callback|
        self.send(callback)
      end
    end    
  end
end
