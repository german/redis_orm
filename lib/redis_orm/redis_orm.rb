# -*- encoding: utf-8 -*-

require 'active_support/inflector/inflections'
require 'active_support/inflector/transliterate'
require 'active_support/inflector/methods'
require 'active_support/inflections'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/time/calculations' # local_time for to_time(:local)
require 'active_support/core_ext/string/conversions' # to_time

require 'active_model/validator'
require 'active_model/validations'

module RedisOrm
  # there is no Boolean class in Ruby so defining a special class to specify TrueClass or FalseClass objects
  class Boolean
  end

  # it's raised when found request was initiated on the property/properties which have no index on it
  class NotIndexFound < StandardError
  end

  class RecordNotFound < StandardError
  end
  
  class TypeMismatchError < StandardError
  end

  class ArgumentsMismatch < StandardError
  end
  
  class Base
    include ActiveModel::Validations
    include ActiveModelBehavior
    include Utils
    include Associations::HasManyHelper
    
    extend Associations::BelongsTo
    extend Associations::HasMany
    extend Associations::HasOne

    attr_accessor :persisted

    @@properties = Hash.new{|h,k| h[k] = []}
    @@indices = Hash.new{|h,k| h[k] = []} # compound indices are available too
    @@associations = Hash.new{|h,k| h[k] = []}
    @@callbacks = Hash.new{|h,k| h[k] = {}}
    @@use_uuid_as_id = {}
    @@descendants = []
    
    class << self

      def inherited(from)
        [:after_save, :before_save, :after_create, :before_create, :after_destroy, :before_destroy].each do |callback_name|
          @@callbacks[from.model_name][callback_name] = []
        end
        
        @@descendants << from
      end
      
      def descendants
        @@descendants
      end
      
      # *options* currently supports
      #   *unique* Boolean
      #   *case_insensitive* Boolean
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
            value = ((value == "false" || value == false) ? false : true)
          end
          value
        end
    
        send(:define_method, "#{property_name}=".to_sym) do |value|
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
  
        send(:define_method, "#{property_name}_changes".to_sym) do
          instance_variable_get(:"@#{property_name}_changes")
        end
        
        send(:define_method, "#{property_name}_changed?".to_sym) do
          instance_variable_get(:"@#{property_name}_changes").size > 1
        end
      end

      def timestamps
        #if !@@properties[model_name].detect{|p| p[:name] == :created_at && p[:class] == "Time"}
        if !instance_methods.include?(:created_at) && !instance_methods.include?(:"created_at=")
          property :created_at, Time
        end
        
        #if !@@properties[model_name].detect{|p| p[:name] == :modified_at && p[:class] == "Time"}
        if !instance_methods.include?(:modified_at) && !instance_methods.include?(:"modified_at=")
          property :modified_at, Time
        end
      end
      
      def use_uuid_as_id
        @@use_uuid_as_id[model_name] = true
        @@uuid = UUID.new
      end
      
      def count
        $redis.zcard("#{model_name}:ids").to_i
      end

      def first(options = {})
        if options.empty?
          id = $redis.zrangebyscore("#{model_name}:ids", 0, Time.now.to_f, :limit => [0, 1])
          id.empty? ? nil : find(id[0])
        else
          find(:first, options)
        end
      end

      def last(options = {})
        if options.empty?
          id = $redis.zrevrangebyscore("#{model_name}:ids", Time.now.to_f, 0, :limit => [0, 1])
          id.empty? ? nil : find(id[0])
        else
          find(:last, options)
        end
      end
      
      def find_indices(properties, options = {})
        properties.map!{|p| p.to_sym}
        method = options[:first] ? :detect : :select
        
        @@indices[model_name].send(method) do |models_index|
          if models_index[:name].is_a?(Array) && models_index[:name].size == properties.size
            # check the elements not taking into account their order
            (models_index[:name] & properties).size == properties.size
          elsif !models_index[:name].is_a?(Array) && properties.size == 1
            models_index[:name] == properties[0]
          end
        end
      end
      
      def construct_prepared_index(index, conditions_hash)
        prepared_index = model_name.to_s
       
        # in order not to depend on order of keys in *:conditions* hash we rather interate over the index itself and find corresponding values in *:conditions* hash
        if index[:name].is_a?(Array)
          index[:name].each do |key|
            # raise if User.find_by_firstname_and_castname => there's no *castname* in User's properties
            raise ArgumentsMismatch if !@@properties[model_name].detect{|p| p[:name] == key.to_sym}
            prepared_index += ":#{key}:#{conditions_hash[key]}"
          end
        else
          prepared_index += ":#{index[:name]}:#{conditions_hash[index[:name]]}"
        end
              
        prepared_index.downcase! if index[:options][:case_insensitive]
        
        prepared_index
      end
      
      # TODO refactor this messy function
      def all(options = {})
        limit = if options[:limit] && options[:offset]
          [options[:offset].to_i, options[:limit].to_i]
        elsif options[:limit]
          [0, options[:limit].to_i]
        end
        
        order_max_limit = Time.now.to_f
        ids_key = "#{model_name}:ids"
        index = nil

        prepared_index = if !options[:conditions].blank? && options[:conditions].is_a?(Hash)
          properties = options[:conditions].collect{|key, value| key}
          index = find_indices(properties, :first => true)
          
          raise NotIndexFound if !index

          construct_prepared_index(index, options[:conditions])
        else
          if options[:order] && options[:order].is_a?(Array)
            model_name
          else
            ids_key
          end
        end

        # if not array => created_at native order (in which ids were pushed to "#{model_name}:ids" set by default)
        direction = if !options[:order].blank?
          if options[:order].is_a?(Array)
            # for String values max limit for search key could be 1.0, but for Numeric values there's actually no limit
            order_max_limit = 100_000_000_000
            ids_key = "#{prepared_index}:#{options[:order].first}_ids"
            options[:order].size == 2 ? options[:order].last : 'asc'
          else
            ids_key = prepared_index
            options[:order]
          end
        else
          ids_key = prepared_index
          'asc'
        end

        if index && index[:options][:unique]
          id = $redis.get prepared_index
          model_name.to_s.camelize.constantize.find(id)
        else
          if direction.to_s == 'desc'
            $redis.zrevrangebyscore(ids_key, order_max_limit, 0, :limit => limit).compact.collect{|id| find(id)}
          else
            $redis.zrangebyscore(ids_key, 0, order_max_limit, :limit => limit).compact.collect{|id| find(id)}
          end
        end
      end

      def find(*args)
        if args.first.is_a?(Array)
          return [] if args.first.empty?
          args.first.inject([]) do |array, id|
            record = $redis.hgetall "#{model_name}:#{id}"
            if record && !record.empty?
              array << new(record, id, true)
            end
          end
        else
          return nil if args.empty? || args.first.nil?
          case first = args.shift
            when :all
              options = args.last
              options = {} if !options.is_a?(Hash)
              all(options)
            when :first
              options = args.last
              options = {} if !options.is_a?(Hash)
              all(options.merge({:limit => 1}))[0]
            when :last
              options = args.last
              options = {} if !options.is_a?(Hash)
              reversed = options[:order] == 'desc' ? 'asc' : 'desc'
              all(options.merge({:limit => 1, :order => reversed}))[0]
            else
              id = first
              record = $redis.hgetall "#{model_name}:#{id}"
              record && record.empty? ? nil : new(record, id, true)
          end
        end        
      end

      def find!(*args)
        result = find(*args)
        if result.nil?
          raise RecordNotFound
        else
          result
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

        # make possible binding related models while creating class instance
        options.each do |k, v|
          if @@associations[model_name].detect{|h| h[:foreign_model] == k || h[:options][:as] == k}
            obj.send("#{k}=", v)
          end
        end

        obj
      end      
      
      alias :create! :create
      
      # dynamic finders
      def method_missing(method_name, *args, &block)
        if method_name =~ /^find_(all_)?by_(\w*)/
          
          index = if $2
            properties = $2.split('_and_')
            raise ArgumentsMismatch if properties.size != args.size
            properties_hash = {}
            properties.each_with_index do |prop, i| 
              properties_hash.merge!({prop.to_sym => args[i]})
            end
            find_indices(properties, :first => true)
          end

          raise NotIndexFound if !index
          
          prepared_index = construct_prepared_index(index, properties_hash)

          if method_name =~ /^find_by_(\w*)/
            id = if index[:options][:unique]            
              $redis.get prepared_index
            else
              $redis.zrangebyscore(prepared_index, 0, Time.now.to_f, :limit => [0, 1])[0]
            end
            model_name.to_s.camelize.constantize.find(id)
          elsif method_name =~ /^find_all_by_(\w*)/
            records = []          

            if index[:options][:unique]            
              id = $redis.get prepared_index
              records << model_name.to_s.camelize.constantize.find(id)
            else
              ids = $redis.zrangebyscore(prepared_index, 0, Time.now.to_f)
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

    # is called from RedisOrm::Associations::HasMany to correctly save indices for associated records
    def get_indices
      @@indices[self.model_name]
    end
    
    def initialize(attributes = {}, id = nil, persisted = false)
      @persisted = persisted

      # if this model uses uuid then id is a string otherwise it should be casted to Integer class
      id = @@use_uuid_as_id[model_name] ? id : id.to_i

      instance_variable_set(:"@id", id) if id

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

    alias :to_key :id
    
    def to_s
      inspected = "<#{model_name.capitalize} id: #{@id}, "
      inspected += @@properties[model_name].inject([]) do |sum, prop|
        property_value = instance_variable_get(:"@#{prop[:name]}")
        property_value = '"' + property_value.to_s + '"' if prop[:class].eql?("String")
        property_value = 'nil' if property_value.nil?
        sum << "#{prop[:name]}: " + property_value.to_s
      end.join(', ')
      inspected += ">"
      inspected
    end
    
    def ==(other)
      raise "this object could be comparable only with object of the same class" if other.class != self.class
      same = true
      @@properties[model_name].each do |prop|
        self_var = instance_variable_get(:"@#{prop[:name]}")
        same = false if other.send(prop[:name]).to_s != self_var.to_s
      end
      same = false if self.id != other.id
      same
    end
    
    def persisted?
      @persisted
    end

    def get_next_id
      if @@use_uuid_as_id[model_name]
        @@uuid.generate(:compact)
      else
        $redis.incr("#{model_name}:id")
      end
    end
    
    def save
      return false if !valid?

      # store here initial persisted flag so we could invoke :after_create callbacks in the end of the function
      was_persisted = persisted?

      if persisted? # then there might be old indices
        # check whether there's old indices exists and if yes - delete them
        @@properties[model_name].each do |prop|
          # if there were no changes for current property skip it (indices remains the same)
          next if ! self.send(:"#{prop[:name]}_changed?")
          
          prev_prop_value = instance_variable_get(:"@#{prop[:name]}_changes").first
          prop_value = instance_variable_get(:"@#{prop[:name]}")

          if prop[:options][:sortable]
            $redis.zrem "#{model_name}:#{prop[:name]}_ids", @id
            # remove id from every indexed property
            @@indices[model_name].each do |index|
              $redis.zrem "#{construct_prepared_index(index)}:#{prop[:name]}_ids", @id
            end
          end

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

                keys_to_delete.each{|key| $redis.del(key)}
              else
                key_to_delete = "#{model_name}:#{prop[:name]}:#{prev_prop_value}"
                $redis.del key_to_delete
              end

              # also we need to delete associated records *indices*
              if !@@associations[model_name].empty?
                @@associations[model_name].each do |assoc|
                  if :belongs_to == assoc[:type]
                    if !self.send(assoc[:foreign_model]).nil?
                      if index[:name].is_a?(Array)
                        keys_to_delete = if index[:name].index(prop) == 0
                          $redis.keys "#{assoc[:foreign_model]}:#{self.send(assoc[:foreign_model]).id}:#{model_name.to_s.pluralize}:#{prop[:name]}#{prev_prop_value}*"
                        else
                          $redis.keys "#{assoc[:foreign_model]}:#{self.send(assoc[:foreign_model]).id}:#{model_name.to_s.pluralize}:*#{prop[:name]}:#{prev_prop_value}*"
                        end

                        keys_to_delete.each{|key| $redis.del(key)}
                      else
                        beginning_of_the_key = "#{assoc[:foreign_model]}:#{self.send(assoc[:foreign_model]).id}:#{model_name.to_s.pluralize}:#{prop[:name]}:"

                        $redis.del(beginning_of_the_key + prev_prop_value.to_s)

                        index[:options][:unique] ? $redis.set((beginning_of_the_key + prop_value.to_s), @id) : $redis.zadd((beginning_of_the_key + prop_value.to_s), Time.now.to_f, @id)
                      end
                    end
                  end
                end
              end # deleting associated records *indices*

            end
          end
        end
      else # !persisted?        
        @@callbacks[model_name][:before_create].each do |callback|
          self.send(callback)
        end
 
        @id = get_next_id
        $redis.zadd "#{model_name}:ids", Time.now.to_f, @id
        @persisted = true
        self.created_at = Time.now if respond_to? :created_at
      end

      @@callbacks[model_name][:before_save].each do |callback|
        self.send(callback)
      end

      # automatically update *modified_at* property if it was defined
      self.modified_at = Time.now if respond_to? :modified_at

      @@properties[model_name].each do |prop|
        prop_value = self.send(prop[:name].to_sym)
        
        if prop_value.nil? && !prop[:options][:default].nil?
          prop_value = prop[:options][:default]
          # set instance variable in order to properly save indexes here
          self.instance_variable_set(:"@#{prop[:name]}", prop[:options][:default])
          instance_variable_set :"@#{prop[:name]}_changes", [prop[:options][:default]]
        end

        $redis.hset("#{model_name}:#{id}", prop[:name].to_s, prop_value)

        # reducing @#{prop[:name]}_changes array to the last value
        prop_changes = instance_variable_get :"@#{prop[:name]}_changes"

        if prop_changes && prop_changes.size > 2
          instance_variable_set :"@#{prop[:name]}_changes", [prop_changes.last]
        end
        
        # if some property need to be sortable add id of the record to the appropriate sorted set
        if prop[:options][:sortable]
          property_value = instance_variable_get(:"@#{prop[:name]}")
          score = case prop[:class]
            when "Integer"; property_value.to_f
            when "Float"; property_value.to_f
            when "String"; calculate_key_for_zset(property_value)
            when "RedisOrm::Boolean"; (property_value == true ? 1.0 : 0.0)
            when "Time"; property_value.to_f
          end
          $redis.zadd "#{model_name}:#{prop[:name]}_ids", score, @id
          # add to every indexed property
          @@indices[model_name].each do |index|
            $redis.zadd "#{construct_prepared_index(index)}:#{prop[:name]}_ids", score, @id
          end
        end
      end

      # save new indices in order to sort by finders
      # city:name:Chicago => 1
      @@indices[model_name].each do |index|
        prepared_index = construct_prepared_index(index) # instance method not class one!

        if index[:options][:unique]
          $redis.set(prepared_index, @id)
        else
          $redis.zadd(prepared_index, Time.now.to_f, @id)
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
        $redis.hdel("#{model_name}:#{@id}", prop[:name].to_s)
        
        if prop[:options][:sortable]
          $redis.zrem "#{model_name}:#{prop[:name]}_ids", @id
        end
      end

      $redis.zrem "#{model_name}:ids", @id

      # also we need to delete *indices* of associated records
      if !@@associations[model_name].empty?
        @@associations[model_name].each do |assoc|        
          if :belongs_to == assoc[:type]
            # if assoc has :as option
            foreign_model_name = assoc[:options][:as] ? assoc[:options][:as].to_sym : assoc[:foreign_model].to_sym
            
            if !self.send(foreign_model_name).nil?
              @@indices[model_name].each do |index|
                keys_to_delete = if index[:name].is_a?(Array)
                  full_index = index[:name].inject([]){|sum, index_part| sum << index_part}.join(':')
                  $redis.keys "#{foreign_model_name}:#{self.send(foreign_model_name).id}:#{model_name.to_s.pluralize}:#{full_index}:*"
                else
                  ["#{foreign_model_name}:#{self.send(foreign_model_name).id}:#{model_name.to_s.pluralize}:#{index[:name]}:#{self.send(index[:name])}"]
                end
                keys_to_delete.each do |key| 
                  index[:options][:unique] ? $redis.del(key) : $redis.zrem(key, @id)
                end
              end
            end
          end
        end
      end
      
      # also we need to delete *links* to associated records
      if !@@associations[model_name].empty?
        @@associations[model_name].each do |assoc|

          foreign_model  = ""
          records = []

          case assoc[:type]
            when :belongs_to
              foreign_model = assoc[:foreign_model].to_s
              foreign_model_name = assoc[:options][:as] ? assoc[:options][:as] : assoc[:foreign_model]
              if assoc[:options][:polymorphic]
                records << self.send(foreign_model_name)
                # get real foreign_model's name in order to delete backlinks properly
                foreign_model = $redis.get("#{model_name}:#{id}:#{foreign_model_name}_type")
                $redis.del("#{model_name}:#{id}:#{foreign_model_name}_type")
                $redis.del("#{model_name}:#{id}:#{foreign_model_name}_id")
              else
                records << self.send(foreign_model_name)
                $redis.del "#{model_name}:#{@id}:#{assoc[:foreign_model]}"
              end
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
              $redis.zremrangebyscore "#{model_name}:#{@id}:#{assoc[:foreign_models]}", 0, Time.now.to_f
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
                $redis.del "#{foreign_model}:#{record.id}:#{model_name}"
              end

              if @@associations[foreign_model].detect{|h| h[:type] == :has_one && h[:foreign_model] == model_name.to_sym}
                $redis.del "#{foreign_model}:#{record.id}:#{model_name}"
              end

              if @@associations[foreign_model].detect{|h| h[:type] == :has_many && h[:foreign_models] == model_name.pluralize.to_sym}
                $redis.zrem "#{foreign_model}:#{record.id}:#{model_name.pluralize}", @id
              end
            end
          end

          if assoc[:options][:dependent] == :destroy
            if !records.compact.empty?
              records.compact.each do |r|
                r.destroy
              end
            end
          end
        end
      end

      # remove all associated indices
      @@indices[model_name].each do |index|
        prepared_index = construct_prepared_index(index) # instance method not class one!

        if index[:options][:unique]
          $redis.del(prepared_index)
        else
          $redis.zremrangebyscore(prepared_index, 0, Time.now.to_f)
        end
      end

      @@callbacks[model_name][:after_destroy].each do |callback|
        self.send(callback)
      end

      true # if there were no errors just return true, so *if* conditions would work
    end
    
    protected
      def construct_prepared_index(index)
        prepared_index = if index[:name].is_a?(Array) # TODO sort alphabetically
          index[:name].inject([model_name]) do |sum, index_part|
            sum += [index_part, self.instance_variable_get(:"@#{index_part}")]
          end.join(':')          
        else
          [model_name, index[:name], self.instance_variable_get(:"@#{index[:name]}")].join(':')
        end
        
        prepared_index.downcase! if index[:options][:case_insensitive]
        
        prepared_index
      end
  end
end
