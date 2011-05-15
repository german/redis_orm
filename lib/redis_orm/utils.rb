module RedisOrm
  module Utils
    def score(string)
      base = '1.'
      base.<< string.split("").collect{|c| '%03d' % c.unpack('c')}[0...6].join
    end
  end
end
