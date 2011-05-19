module RedisOrm
  module Utils
    def score(string)
      base = '1.'
      base.<< string.unpack("U*").map{|c| "%05i" % c}.join
    end
  end
end
