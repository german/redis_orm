require 'active_support/inflector/inflections'
require 'active_support/inflector/transliterate'
require 'active_support/inflector/methods'
require 'active_support/inflections'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/time/calculations' # local_time for to_time(:local)
require 'active_support/core_ext/string/conversions' # to_time

module RedisOrm
  # there is no Boolean class in Ruby so defining a special class to specify TrueClass or FalseClass objects
  class Boolean
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

    extend Associations::BelongsTo
    extend Associations::HasMany
    extend Associations::HasOne

    attr_accessor :persisted

    @@properties = Hash.new{|h,k| h[k] = []}
    @@indices = Hash.new{|h,k| h[k] = []} # compound indices are available too   
    @@associations = Hash.new{|h,k| h[k] = []}
    @@callbacks = Hash.new{|h,k| h[k] = {}}    

    class << self

      def inherited(from)
        [:after_save, :before_save, :after_create, :before_create, :after_destroy, :before_destroy].each do |callback_name|
          @@callbacks[from.model_name][callback_name] = []
        end
      end
     
      # *options* currently supports
      #   *unique* Boolean
      #   *case_insensitive* Boolean TODO 
      def index(name, options = {})
        @@indices[model_name] << {:name => name, :options => options}
      end

      def property(property_name, class_name, options = {})
        @@properties[model_name] << {:name => property_name, :class => class_name.to_s, :options => options}

        send(:define_method, property_name) do
          value = instance_variable_get(:"@#{property_name}")

          return value if value.nil? # we must return nil here so :default option will work when saving, otherwise it'll return "" or 0 or 0.0

          if Time == class_name
            value = begin
              value.to_s.to_time(:local)
            rescue ArgumentError => e
              nil
            end
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
          if instance_variable_get(:"@#{property_name}_changes") && !instance_variable_get(:"@#{property_name}_changes").empty?
            initial_value = instance_variable_get(:"@#{property_name}_changes")[0]
            instance_variable_set(:"@#{property_name}_changes", [initial_value, value])
          elsif instance_variable_get(:"@#{property_name}")
            instance_variable_set(:"@#{property_name}_changes", [self.send(property_name), value])
          else
            instance_variable_set(:"@#{property_name}_changes", [value])
          end

          instance_variable_set(:"@#{property_name}", value)
        end
  
        send(:define_method, :"#{property_name}_changes") do
          instance_variable_get(:"@#{property_name}_changes")
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
        limit = if options[:limit] && options[:offset]
          [options[:offset].to_i, options[:limit].to_i]
        elsif options[:limit]
          [0, options[:limit].to_i]
        end

        if options[:order].to_s == 'desc'
          $redis.zrevrangebyscore("#{model_name}:ids", Time.now.to_i, 0, :limit => limit).compact.collect{|id| find(id)}
        else
          $redis.zrangebyscore("#{model_name}:ids", 0, Time.now.to_i, :limit => limit).compact.collect{|id| find(id)}
        end
      end

      def find(ids)
        if ids.is_a?(Hash)
          all(ids)
        elsif ids.is_a?(Array)
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

      def before_save(callback)        
        @@callbacks[model_name][:before_save] << callback
      end

      def after_create(callback)        
        @@callbacks[model_name][:after_create] << callback
      end

      def before_create(callback)        
        @@callbacks[model_name][:before_create] << callback
      end

      def after_destroy(callback)
        @@callbacks[model_name][:after_destroy] << callback
      end
      
      def before_destroy(callback)        
        @@callbacks[model_name][:before_destroy] << callback
      end

      def create(options = {})
        obj = new(options, nil, false)
        obj.save
        obj
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

      # when object is created with empty attribute set @#{prop[:name]}_changes array properly
      @@properties[model_name].each do |prop|
        if prop[:options][:default]
          instance_variable_set :"@#{prop[:name]}_changes", [prop[:options][:default]]
        else
          instance_variable_set :"@#{prop[:name]}_changes", []
        end
      end
 
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
      # store here initial persisted flag so we could invoke :after_create callbacks in the end of the function
      was_persisted = persisted?

      if persisted? # then there might be old indices
        # check whether there's old indices exists and if yes - delete them
        @@properties[model_name].each do |prop|
          prop_changes = instance_variable_get :"@#{prop[:name]}_changes" 

          next if prop_changes.size < 2
          prev_prop_value = prop_changes.first

          indices = @@indices[model_name].inject([]) do |sum, models_index|
            if models_index[:name].is_a?(Array)
              if models_index[:name].include?(prop[:name])
                sum << models_index
              else
                sum
              end
            else
              if models_index[:name] == prop[:name]
                sum << models_index
              else
                sum
              end
            end
          end

          if !indices.empty?
            indices.each do |index|
              if index[:name].is_a?(Array)
                keys_to_delete = if index[:name].index(prop) == 0
                  $redis.keys "#{model_name}:#{prop[:name]}#{prev_prop_value}*"
                else
                  $redis.keys "#{model_name}:*#{prop[:name]}:#{prev_prop_value}*"
                end

                keys_to_delete.each{|key| puts 'key - ' + key.inspect; $redis.del(key)}
              else
                key_to_delete = "#{model_name}:#{prop[:name]}:#{prev_prop_value}"
                $redis.del key_to_delete
              end
            end
          end
        end
      else # !persisted?
        @@callbacks[model_name][:before_create].each do |callback|
          self.send(callback)
        end

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

        if prop_value.nil? && !prop[:options][:default].nil?
          prop_value = prop[:options][:default]
          # set instance variable in order to properly save indexes here
          self.instance_variable_set(:"@#{prop[:name]}", prop[:options][:default]) 
        end

        $redis.hset("#{model_name}:#{id}", prop[:name].to_s, prop_value)

        # reducing @#{prop[:name]}_changes array to last value
        prop_changes = instance_variable_get :"@#{prop[:name]}_changes"
        if prop_changes && prop_changes.size > 2
          instance_variable_set :"@#{prop[:name]}_changes", [prop_changes.last]
        end
      end

      # save new indices in order to sort by finders
      # city:name:Харьков => 1
      @@indices[model_name].each do |index|
        prepared_index = if index[:name].is_a?(Array) # TODO sort alphabetically
          index[:name].inject([model_name]) do |sum, index_part|
            sum += [index_part, self.instance_variable_get(:"@#{index_part}").to_s]
          end.join(':')
        else
          [model_name, index[:name], self.instance_variable_get(:"@#{index[:name]}").to_s].join(':')
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

      if ! was_persisted
        @@callbacks[model_name][:after_create].each do |callback|
          self.send(callback)
        end
      end

      true # if there were no errors just return true, so *if* conditions would work
    end

    def update_attributes(attributes)
      if attributes.is_a?(Hash)
        attributes.each do |key, value|
          self.send("#{key}=".to_sym, value) if self.respond_to?("#{key}=".to_sym)
        end
      end
      save
    end

    def update_attribute(attribute_name, attribute_value)
      self.send("#{attribute_name}=".to_sym, attribute_value) if self.respond_to?("#{attribute_name}=".to_sym)
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
            records.each do |r|
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

      true # if there were no errors just return true, so *if* conditions would work
    end    
  end
end
