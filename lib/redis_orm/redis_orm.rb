require 'active_support/inflector/inflections'
require 'active_support/inflector/transliterate'
require 'active_support/inflector/methods'
require 'active_support/inflections'
require 'active_support/core_ext/string/inflections'

require 'active_support/core_ext/time/acts_like'
require 'active_support/core_ext/time/calculations'
require 'active_support/core_ext/time/conversions'
#require 'active_support/core_ext/time/marshal'
require 'active_support/core_ext/time/zones'

require 'active_support/core_ext/numeric'
require 'active_support/core_ext/time/calculations' # local_time for to_time(:local)
require 'active_support/core_ext/string/conversions' # to_time

module RedisOrm
  # there is no Boolean class in Ruby so defining a special class to specify TrueClass or FalseClass objects
  class Boolean; end

  # it's raised when found request was initiated on the property/properties which have no index on it
  class NotIndexFound < StandardError
  end

  class RecordNotFound < StandardError
  end
  
  class TypeMismatchError < StandardError
  end

  class ArgumentsMismatch < StandardError
  end
  
  class Index
    attr_accessor :name, :options

    def initialize(name, options)
      @name = name
      @options = options
    end
  end

  class Base
    include ActiveModel::API
    include ActiveModel::Dirty
    extend ActiveModel::Callbacks

    include Utils
    include Associations::HasManyHelper
    
    extend Associations::BelongsTo
    extend Associations::HasMany
    extend Associations::HasOne

    # attr_accessor :persisted

    @@properties = Hash.new{|h,k| h[k] = []}
    @@indices = Hash.new{|h,model_name| h[model_name] = []} # compound indices are available too
    @@associations = Hash.new{|h,model_name| h[model_name] = []}
    @@use_uuid_as_id = {}
    @@descendants = []
    @@expire = Hash.new{|h,k| h[k] = {}}
        
    class << self

      def inherited(from)
        @@descendants << from
      end
      
      def descendants
        @@descendants
      end
      
      # *options* currently supports
      #   *unique* Boolean
      #   *case_insensitive* Boolean
      def index(name, options = {})
        @@indices[model_name] << Index.new(name, options)
      end

      def property(property_name, class_name, options = {})
        @@properties[model_name] << {
          name: property_name, class: class_name.to_s, options: options
        }

        attr_accessor property_name
        define_attribute_methods property_name # for ActiveModel::Dirty
      end

      def timestamps
        if !instance_methods.include?(:created_at) && !instance_methods.include?(:"created_at=")
          property :created_at, DateTime, default: ->{ Time.now }
        end
        
        if !instance_methods.include?(:modified_at) && !instance_methods.include?(:"modified_at=")
          property :modified_at, DateTime, default: ->{ Time.now }
        end
      end
      
      def expire(seconds, options = {})
        @@expire[model_name] = {seconds: seconds, options: options}
      end

      def use_uuid_as_id
        @@use_uuid_as_id[model_name] = true
        @@uuid = UUID.new
      end
      
      def count
        $redis.zcard("#{model_name}:ids").to_i
      end

      def first(options = {})
        find(:first, options)
      end

      def last(options = {})
        find(:last, options)
      end
      
      def find_indices(properties, options = {})
        properties.map!{|p| p.to_sym}
        method_name = options[:first] ? :detect : :select
        
        @@indices[model_name].public_send(method_name) do |index|
          if index.name.is_a?(Array) && index.name.size == properties.size
            # check the elements not taking into account their order
            (index.name & properties).size == properties.size
          elsif !index.name.is_a?(Array) && properties.size == 1
            index.name == properties[0]
          end
        end
      end
      
      def construct_prepared_index(index, conditions_hash)
        prepared_index = model_name.to_s
       
        # in order not to depend on order of keys in *:conditions* hash we rather interate over
        # the index itself and find corresponding values in *:conditions* hash
        if index.name.is_a?(Array)
          index.name.each do |key|
            # raise if User.find_by_firstname_and_castname => there's no *castname* in User's properties
            raise ArgumentsMismatch if !@@properties[model_name].detect{|p| p[:name] == key.to_sym}
            prepared_index += ":#{key}:#{conditions_hash[key]}"
          end
        else
          prepared_index += ":#{index.name}:#{conditions_hash[index.name]}"
        end
              
        prepared_index.downcase! if index.options[:case_insensitive]
        
        prepared_index
      end
      
      # TODO refactor this messy function
      def all(options = {})
        limit = if options[:limit] && options[:offset]
          [options[:offset].to_i, options[:limit].to_i]
        elsif options[:limit]
          [0, options[:limit].to_i]
        else
          [0, -1]
        end
        
        order_max_limit = Time.now.to_f
        ids_key = "#{model_name}:ids"
        index = nil

        prepared_index = if !options[:conditions].blank? && options[:conditions].is_a?(Hash)
          properties = options[:conditions].collect{|key, value| key}
          
          # if some condition includes object => get only the id of this object
          conds = options[:conditions].inject({}) do |sum, item|
            key, value = item
            if value.respond_to?(:model_name)
              sum.merge!({key => value.id})
            else
              sum.merge!({key => value})
            end
          end

          index = find_indices(properties, {first: true})
          
          raise NotIndexFound if !index

          construct_prepared_index(index, conds)
        else
          if options[:order] && options[:order].is_a?(Array)
            model_name
          else
            ids_key
          end
        end

        order_by_property_is_string = false
        
        # if not array => created_at native order (in which ids were pushed to "#{model_name}:ids" set by default)
        direction = if !options[:order].blank?
          property = {}
          dir = if options[:order].is_a?(Array)
            property = @@properties[model_name].detect{|prop| prop[:name].to_s == options[:order].first.to_s}
            # for String values max limit for search key could be 1.0, but for Numeric values there's actually no limit
            order_max_limit = 100_000_000_000
            ids_key = "#{prepared_index}:#{options[:order].first}_ids"
            options[:order].size == 2 ? options[:order].last : 'asc'
          else
            property = @@properties[model_name].detect{|prop| prop[:name].to_s == options[:order].to_s}
            ids_key = prepared_index
            options[:order]
          end
          if property && property[:class].eql?("String") && property[:options][:sortable]
            order_by_property_is_string = true
          end
          dir
        else
          ids_key = prepared_index
          'asc'
        end
        
        if order_by_property_is_string
          if direction.to_s == 'desc'
            ids_length = $redis.llen(ids_key)
            limit = if options[:offset] && options[:limit]
              [(ids_length - options[:offset].to_i - options[:limit].to_i), (ids_length - options[:offset].to_i - 1)]
            elsif options[:limit]
              [ids_length - options[:limit].to_i, ids_length]
            elsif options[:offset]
              [0, (ids_length - options[:offset].to_i - 1)]
            else
              [0, -1]
            end
            $redis.lrange(ids_key, *limit).reverse.compact.collect{|id| find(id.split(':').last)}
          else
            limit = if options[:offset] && options[:limit]
              [options[:offset].to_i, (options[:offset].to_i + options[:limit].to_i)]
            elsif options[:limit]
              [0, options[:limit].to_i - 1]
            elsif options[:offset]
              [options[:offset].to_i, -1]
            else
              [0, -1]
            end
            $redis.lrange(ids_key, *limit).compact.collect{|id| find(id.split(':').last)}
          end
        else
          if index && index.options[:unique]
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
      end

      def find(*args)
        if args.first.is_a?(Array)
          return [] if args.first.empty?
          args.first.map do |id|
            record = $redis.hgetall "#{model_name}:#{id}"
            if record && !record.empty?
              new(record, id, true)
            end
          end.compact
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

      def create(options = {})
        obj = new(options, nil, false)
        obj.save

        # make possible binding related models while creating class instance
        options.each do |k, v|
          if @@associations[model_name].detect{|h| h[:foreign_model] == k || h[:options][:as] == k}
            obj.send("#{k}=", v)
          end
        end
        
        $redis.expire(obj.__redis_record_key, options[:expire_in].to_i) if !options[:expire_in].blank?

        obj
      end
      
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
            id = if index.options[:unique]            
              $redis.get prepared_index
            else
              $redis.zrangebyscore(prepared_index, 0, Time.now.to_f, :limit => [0, 1])[0]
            end
            model_name.to_s.camelize.constantize.find(id)
          elsif method_name =~ /^find_all_by_(\w*)/
            records = []          

            if index.options[:unique]            
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
 
    def __redis_record_key
      "#{model_name}:#{id}"
    end
   
    def set_expire_on_reference_key(key)
      class_expire = @@expire[model_name]

      # if class method *expire* was invoked and number of seconds was specified then set expiry date on the HSET record key
      if class_expire[:seconds]
        set_expire = true

        if class_expire[:options][:if] && class_expire[:options][:if].class == Proc
          # *self* here refers to the instance of class which has_one association
          set_expire = class_expire[:options][:if][self]  # invoking specified *:if* Proc with current record as *self* 
        end

        $redis.expire(key, class_expire[:seconds].to_i) if set_expire
      end
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
      aligned_attributes = {}
      clear_changes_information
      attributes.map do |attribute, value|
        property = @@properties[model_name].find { |prop| prop[:name].to_s == attribute.to_s }
        prop_value = if property && property[:class] != value.class.to_s
          case property[:class]
          when /DateTime|Time/
            value.to_s.to_time(:local) rescue ''
          when 'Integer'
            value.to_i
          when 'Float'
            value.to_f
          when 'RedisOrm::Boolean'
            (value == "false" || value == false) ? false : true
          when /Hash|Array/
            JSON.parse(value) rescue ''
          end
        else
          value
        end

        aligned_attributes[attribute] = prop_value
      end

      if !@persisted
        @@properties[model_name].each do |prop|
          if aligned_attributes[prop[:name]].nil? && !prop[:options][:default].nil?
            calculated_value = if prop[:options][:default].is_a?(Proc)
              prop[:options][:default].call
            else
              prop[:options][:default]
            end

            aligned_attributes[prop[:name]] = calculated_value
          end
        end
      end
      
      super(aligned_attributes)
      
      @persisted = persisted

      # # if this model uses uuid then id is a string otherwise it should be casted to Integer class
      id = @@use_uuid_as_id[model_name] ? id : id.to_i

      instance_variable_set(:"@id", id) if id

      self
    end

    def id
      @id
    end

    alias :to_key :id
    
    def to_s
      inspected = "<#{model_name.name} id: #{@id}, "
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

      _check_mismatched_types_for_values
      
      # store here initial persisted flag so we could invoke :after_create callbacks in the end of *save* function
      was_persisted = persisted?

      if persisted? # then there might be old indices
        _check_indices_for_persisted # remove old indices if needed
      else # !persisted?
        @id = get_next_id
        $redis.zadd "#{model_name}:ids", Time.now.to_f, @id
        @persisted = true
        self.created_at = Time.now if respond_to? :created_at
      end

      # automatically update *modified_at* property if it was defined
      self.modified_at = Time.now if respond_to? :modified_at

      _save_to_redis # main work done here
      _save_new_indices

      changes_applied # for ActiveModel::Dirty

      true # if there were no errors just return true, so *if obj.save* conditions would work
    end

    def find_position_to_insert(sortable_key, value)
      end_index = $redis.llen(sortable_key)

      return 0 if end_index == 0
      
      start_index = 0
      pivot_index = end_index / 2

      start_el = $redis.lindex(sortable_key, start_index)
      end_el   = $redis.lindex(sortable_key, end_index - 1)
      pivot_el = $redis.lindex(sortable_key, pivot_index)

      while start_index != end_index
        # aa..ab..ac..bd <- ad
        if start_el.split(':').first > value # Michael > Abe
          return 0
        elsif end_el.split(':').first < value # Abe < Todd 
          return end_el
        elsif start_el.split(':').first == value # Abe == Abe
          return start_el
        elsif pivot_el.split(':').first == value # Todd == Todd
          return pivot_el
        elsif end_el.split(':').first == value
          return end_el
        elsif (start_el.split(':').first < value) && (pivot_el.split(':').first > value)
          start_index = start_index
          prev_pivot_index = pivot_index
          pivot_index = start_index + ((end_index - pivot_index) / 2)
          end_index   = prev_pivot_index
        elsif (pivot_el.split(':').first < value) && (end_el.split(':').first > value) # M < V && Y > V
          start_index = pivot_index
          pivot_index = pivot_index + ((end_index - pivot_index) / 2)
          end_index   = end_index          
        end
        start_el = $redis.lindex(sortable_key, start_index)
        end_el   = $redis.lindex(sortable_key, end_index - 1)
        pivot_el = $redis.lindex(sortable_key, pivot_index)
      end
      start_el
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
      @@properties[model_name].each do |prop|
        property_value = instance_variable_get(:"@#{prop[:name]}").to_s
        $redis.hdel("#{model_name}:#{@id}", prop[:name].to_s)
        
        if prop[:options][:sortable]
          if prop[:class].eql?("String")
            $redis.lrem "#{model_name}:#{prop[:name]}_ids", 1, "#{property_value}:#{@id}"
          else
            $redis.zrem "#{model_name}:#{prop[:name]}_ids", @id
          end
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
                keys_to_delete = if index.name.is_a?(Array)
                  full_index = index.name.inject([]){|sum, index_part| sum << index_part}.join(':')
                  $redis.keys "#{foreign_model_name}:#{self.public_send(foreign_model_name).id}:#{model_name.to_s.pluralize}:#{full_index}:*"
                else
                  ["#{foreign_model_name}:#{self.send(foreign_model_name).id}:#{model_name.to_s.pluralize}:#{index.name}:#{self.public_send(index.name)}"]
                end
                keys_to_delete.each do |key| 
                  index.options[:unique] ? $redis.del(key) : $redis.zrem(key, @id)
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
        prepared_index = _construct_prepared_index(index) # instance method not class one!

        if index.options[:unique]
          $redis.del(prepared_index)
        else
          $redis.zremrangebyscore(prepared_index, 0, Time.now.to_f)
        end
      end

      true # if there were no errors just return true, so *if* conditions would work
    end
    
  protected
    def _construct_prepared_index(index)
      index_name = if index.name.is_a?(Array) # TODO sort alphabetically
        index.name.inject([model_name]) do |sum, index_part|
          sum += [index_part, self.instance_variable_get(:"@#{index_part}")]
        end.join(':')          
      else
        [model_name, index.name, self.instance_variable_get(:"@#{index.name}")].join(':')
      end
      
      index_name.downcase! if index.options[:case_insensitive]
      index_name
    end

    def _check_mismatched_types_for_values
      # an exception should be raised before all saving procedures if wrong value type is specified (especcially true for Arrays and Hashes)
      @@properties[model_name].each do |prop|
        prop_value = self.send(prop[:name].to_sym)
        
        if prop_value && prop[:class] != prop_value.class.to_s && ['Array', 'Hash'].include?(prop[:class].to_s)
          raise TypeMismatchError 
        end
      end
    end
    
    def _check_indices_for_persisted
      # check whether there's old indices exists and if yes - delete them
      @@properties[model_name].each do |prop|
        # if there were no changes for current property skip it (indices remains the same)
        next if ! self.send(:"#{prop[:name]}_changed?")
        
        prev_prop_value = instance_variable_get(:"@#{prop[:name]}_changes").first
        prop_value = instance_variable_get(:"@#{prop[:name]}")
        # TODO DRY in destroy also
        if prop[:options][:sortable]
          if prop[:class].eql?("String")
            $redis.lrem "#{model_name}:#{prop[:name]}_ids", 1, "#{prev_prop_value}:#{@id}"
            # remove id from every indexed property
            @@indices[model_name].each do |index|
              $redis.lrem "#{_construct_prepared_index(index)}:#{prop[:name]}_ids", 1, "#{prop_value}:#{@id}"
            end
          else
            $redis.zrem "#{model_name}:#{prop[:name]}_ids", @id
            # remove id from every indexed property
            @@indices[model_name].each do |index|
              $redis.zrem "#{_construct_prepared_index(index)}:#{prop[:name]}_ids", @id
            end
          end
        end

        indices = @@indices[model_name].inject([]) do |sum, index|
          if index.name.is_a?(Array)
            if index.name.include?(prop[:name])
              sum << index
            else
              sum
            end
          else
            if index.name == prop[:name]
              sum << index
            else
              sum
            end
          end
        end

        if !indices.empty?
          indices.each do |index|
            if index.name.is_a?(Array)
              keys_to_delete = if index.name.index(prop) == 0
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
                  # if association has :as option use it, otherwise use standard :foreign_model
                  foreign_model_name = assoc[:options][:as] ? assoc[:options][:as].to_sym : assoc[:foreign_model].to_sym
                  if !self.public_send(foreign_model_name).nil?
                    if index.name.is_a?(Array)
                      keys_to_delete = if index.name.index(prop) == 0
                        $redis.keys "#{assoc[:foreign_model]}:#{self.public_send(assoc[:foreign_model]).id}:#{model_name.to_s.pluralize}:#{prop[:name]}#{prev_prop_value}*"
                      else
                        $redis.keys "#{assoc[:foreign_model]}:#{self.public_send(assoc[:foreign_model]).id}:#{model_name.to_s.pluralize}:*#{prop[:name]}:#{prev_prop_value}*"
                      end

                      keys_to_delete.each{|key| $redis.del(key)}
                    else
                      beginning_of_the_key = "#{assoc[:foreign_model]}:#{self.public_send(assoc[:foreign_model]).id}:#{model_name.to_s.pluralize}:#{prop[:name]}:"

                      $redis.del(beginning_of_the_key + prev_prop_value.to_s)

                      index.options[:unique] ? $redis.set((beginning_of_the_key + prop_value.to_s), @id) : $redis.zadd((beginning_of_the_key + prop_value.to_s), Time.now.to_f, @id)
                    end
                  end
                end
              end
            end # deleting associated records *indices*
          end
        end
      end
    end
      
    def _save_to_redis
      @@properties[model_name].each do |prop|
        prop_value = self.send(prop[:name].to_sym)

        if prop_value.nil? && !prop[:options][:default].nil?
          prop_value = prop[:options][:default]
        end

        # cast prop_value to proper class
        prop_value = case prop[:class]
                     when /Time|DateTime/
                       prop_value.to_s
                     when 'Integer'
                       prop_value.to_i
                     when 'Float'
                       prop_value.to_f
                     when 'RedisOrm::Boolean'
                       (prop_value == "false" || prop_value == false) ? 'false' : 'true'
                     when /Array|Hash/
                       prop_value.to_json
                     else
                       prop_value.to_s
                     end

        # set instance variable in order to properly save indexes here
        # instance_variable_set(:"@#{prop[:name]}", prop_value)
        # instance_variable_set :"@#{prop[:name]}_changes", [prop_value]

        #TODO put out of loop
        $redis.hset(__redis_record_key, prop[:name].to_s, prop_value)

        set_expire_on_reference_key(__redis_record_key)
        
        # reducing @#{prop[:name]}_changes array to the last value
        # prop_changes = instance_variable_get :"@#{prop[:name]}_changes"

        # if prop_changes && prop_changes.size > 2
        #   instance_variable_set :"@#{prop[:name]}_changes", [prop_changes.last]
        # end
        
        # if some property need to be sortable add id of the record to the appropriate sorted set
        if prop[:options][:sortable]
          property_value = instance_variable_get(:"@#{prop[:name]}").to_s
          if prop[:class].eql?("String")
            sortable_key = "#{model_name}:#{prop[:name]}_ids"
            el_or_position_to_insert = find_position_to_insert(sortable_key, property_value)
            el_or_position_to_insert == 0 ? $redis.lpush(sortable_key, "#{property_value}:#{@id}") : $redis.linsert(sortable_key, "AFTER", el_or_position_to_insert, "#{property_value}:#{@id}")
            # add to every indexed property
            @@indices[model_name].each do |index|
              sortable_key = "#{_construct_prepared_index(index)}:#{prop[:name]}_ids"
              el_or_position_to_insert == 0 ? $redis.lpush(sortable_key, "#{property_value}:#{@id}") : $redis.linsert(sortable_key, "AFTER", el_or_position_to_insert, "#{property_value}:#{@id}")
            end
          else
            score = case prop[:class]
              when "Integer"; property_value.to_f
              when "Float"; property_value.to_f
              when "RedisOrm::Boolean"; (property_value == true ? 1.0 : 0.0)
              when /Time|DateTime/; property_value.to_f
            end
            $redis.zadd "#{model_name}:#{prop[:name]}_ids", score, @id
            # add to every indexed property
            @@indices[model_name].each do |index|
              $redis.zadd "#{_construct_prepared_index(index)}:#{prop[:name]}_ids", score, @id
            end
          end
        end
      end
    end

    def _save_new_indices
      # save new indices (not *reference* onces (for example not these *belongs_to :note, :index => true*)) in order to sort by finders
      # city:name:Chicago => 1
      @@indices[model_name].reject{|index| index.options[:reference]}.each do |index|
        prepared_index = _construct_prepared_index(index) # instance method not class one!

        if index.options[:unique]
          $redis.set(prepared_index, @id)
        else
          $redis.zadd(prepared_index, Time.now.to_f, @id)
        end
      end
    end
  end
end
